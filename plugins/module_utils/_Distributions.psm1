function Get-DistributionRuntimeInfo {
    <#
    .SYNOPSIS
        Gets runtime information for WSL distributions.
    .DESCRIPTION
        Runs 'wsl --list --verbose' and parses the output to extract
        the name, state, version, and default status of each distribution.
        Can return all distributions or filter by name.
    .PARAMETER wslExe
        The wsl.exe command object returned by Test-WslInstall.
    .PARAMETER module
        The Ansible.Basic.AnsibleModule instance.
    .PARAMETER name
        Optional distribution name to filter results.
    .PARAMETER flat
        If set, returns a single hashtable for the matched distribution
        instead of a dictionary keyed by name. Returns $null if not found.
    .OUTPUTS
        System.Collections.Hashtable. A dictionary of distributions keyed
        by name, or a single hashtable when -flat is used.
    #>
    param (
        [object]$wslExe,
        [object]$module,
        [string]$name,
        [switch]$flat
    )
    $result = Invoke-WslCommand `
        -wslExe $wslExe `
        -module $module `
        -arguments @("--list", "--verbose") `
        -successCodes @(0, -1)  # -1 if no distros are found

    $lines = Split-StdText $result.stdout
    $distributions = @{}
    foreach ($line in ($lines | Select-Object -Skip 1)) {
        if ($line -match '^\s*(\*)?\s*(.+?)\s+(Stopped|Running|Installing|Uninstalling|Converting|Exporting)\s+(\d+)\s*$') {
            $distroName = $Matches[2].Trim()
            if ((-not [string]::IsNullOrEmpty($name)) -and ($name -ne $distroName)) {
                continue
            }
            $distributions[$distroName] = @{
                name = $distroName
                state = $Matches[3]
                version = [int]$Matches[4]
                is_default = ($null -ne $Matches[1])
            }
        }
    }

    if ($flat) {
        if ($distributions.Count -eq 0) {
            return $null
        }
        return $distributions.Values | Select-Object -First 1
    }
    return $distributions
}


function Get-VhdFileInfo {
    <#
    .SYNOPSIS
        Gets file information for a VHD file.
    .DESCRIPTION
        Checks if the VHD file exists at the given path and returns its
        sparse attribute and size rounded to the nearest whole gigabyte.
    .PARAMETER vhdPath
        The full path to the VHD file.
    .OUTPUTS
        System.Collections.Hashtable. A hashtable with is_sparse and size
        keys, or $null if the file does not exist.
    #>
    param (
        [string]$vhdPath
    )

    if (-not (Test-Path -LiteralPath $vhdPath)) { return $null }
    $fileInfo = Get-Item -LiteralPath $vhdPath
    $sizeInGb = ($fileInfo.Length / 1GB)

    return @{
        "is_sparse" = (($fileInfo.Attributes -band [System.IO.FileAttributes]::SparseFile) -ne 0)
        "size" = "$([math]::Round($sizeInGb, [MidpointRounding]::AwayFromZero))GB"
    }
}


function Get-DistributionInstallInfo {
    param (
        [string]$name,
        [switch]$flat
    )
    $baseRegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
    $output = @{}
    if (-not (Test-Path -LiteralPath $baseRegPath)) { if ($flat) { return $null } else { return $output } }
    foreach ($key in (Get-ChildItem -LiteralPath $baseRegPath | Where-Object { $_.Property -contains "BasePath" })) {
        $props = Get-ItemProperty -LiteralPath $key.PSPath
        $distroName = $props.DistributionName
        if ((-not [string]::IsNullOrEmpty($name)) -and ($name -ne $distroName)) {
            continue
        }
        $data = @{
            location = $props.BasePath
            default_uid = $props.DefaultUid
            flavor = $props.Flavor
            os_version = $props.OsVersion
            vhd_file_name = $props.VhdFileName
        }

        $vhdInfo = Get-VhdFileInfo -vhdPath (Join-Path $data.location $data.vhd_file_name)
        if ($null -ne $vhdInfo) {
            $data.is_sparse = $vhdInfo.is_sparse
            $data.size = $vhdInfo.size
        }
        $output[$distroName] = $data
    }

    if ($flat) {
        if ($output.Count -eq 0) {
            return $null
        }
        return $output.Values | Select-Object -First 1
    }
    return $output
}
