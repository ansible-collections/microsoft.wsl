$script:ParamToConfKeyMapping = @{
    mount_fs_tab = "mountFsTab"
    generate_hosts = "generateHosts"
    generate_resolv_conf = "generateResolvConf"
    append_windows_path = "appendWindowsPath"
    protect_binfmt = "protectBinfmt"
    use_windows_timezone = "useWindowsTimezone"
}

$script:ConfKeyToParamMapping = @{}
foreach ($entry in $script:ParamToConfKeyMapping.GetEnumerator()) {
    $script:ConfKeyToParamMapping[$entry.Value] = $entry.Key
}


function Resolve-ConfKey {
    <#
    .SYNOPSIS
        Converts a snake_case Ansible parameter name to its camelCase wsl.conf key.
    .PARAMETER paramKey
        The Ansible parameter name.
    .OUTPUTS
        System.String. The corresponding wsl.conf key name.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$paramKey
    )
    if ($script:ParamToConfKeyMapping.ContainsKey($paramKey)) {
        return $script:ParamToConfKeyMapping[$paramKey]
    }
    return $paramKey
}


function Resolve-ParamKey {
    <#
    .SYNOPSIS
        Converts a camelCase wsl.conf key to its snake_case Ansible parameter name.
    .PARAMETER confKey
        The wsl.conf key name.
    .OUTPUTS
        System.String. The corresponding Ansible parameter name.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$confKey
    )
    if ($script:ConfKeyToParamMapping.ContainsKey($confKey)) {
        return $script:ConfKeyToParamMapping[$confKey]
    }
    return $confKey
}


function ConvertTo-ConfValue {
    <#
    .SYNOPSIS
        Converts an Ansible parameter value to its wsl.conf string representation.
    .PARAMETER value
        The value to convert.
    .OUTPUTS
        System.String.
    #>
    param ($value)
    if ($value -is [bool]) {
        return "$value".ToLower()
    }
    return "$value"
}


function ConvertTo-SnakeCaseConfig {
    <#
    .SYNOPSIS
        Converts a parsed wsl.conf config to use snake_case key names.
    .PARAMETER config
        An OrderedDictionary of sections from Read-WslConf.
    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary.
    #>
    param (
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$config
    )

    $result = [ordered]@{}
    foreach ($section in $config.GetEnumerator()) {
        $result[$section.Key] = [ordered]@{}
        foreach ($entry in $section.Value.GetEnumerator()) {
            $paramKey = Resolve-ParamKey -confKey $entry.Key
            $result[$section.Key][$paramKey] = $entry.Value
        }
    }
    return $result
}


function Get-WslConfPath {
    <#
    .SYNOPSIS
        Returns the Windows UNC path to a distribution's wsl.conf file.
    .PARAMETER name
        The WSL distribution name.
    .OUTPUTS
        System.String. The UNC path to /etc/wsl.conf.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$name
    )

    return "\\wsl.localhost\$name\etc\wsl.conf"
}


function Read-WslConf {
    <#
    .SYNOPSIS
        Reads and parses an INI-format wsl.conf file.
    .DESCRIPTION
        Parses the file at the given path into an OrderedDictionary of sections,
        each containing an OrderedDictionary of key-value pairs. Skips comments
        and blank lines. Returns an empty OrderedDictionary if the file does not exist.
    .PARAMETER path
        The filesystem path to the wsl.conf file.
    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$path
    )

    $config = [ordered]@{}

    if (-not (Test-Path -LiteralPath $path)) {
        return $config
    }

    $currentSection = $null
    foreach ($line in (Get-Content -LiteralPath $path)) {
        $trimmed = $line.Trim()

        if ($trimmed -eq '' -or $trimmed.StartsWith('#') -or $trimmed.StartsWith(';')) {
            continue
        }

        if ($trimmed -match '^\[(.+)\]$') {
            $currentSection = $Matches[1].Trim()
            if (-not $config.Contains($currentSection)) {
                $config[$currentSection] = [ordered]@{}
            }
            continue
        }

        if ($null -ne $currentSection -and $trimmed -match '^([^=]+)=(.*)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            $config[$currentSection][$key] = $value
        }
    }

    return $config
}


function ConvertTo-WslConfText {
    <#
    .SYNOPSIS
        Converts a parsed config OrderedDictionary to INI-format text.
    .PARAMETER config
        An OrderedDictionary of sections.
    .OUTPUTS
        System.String. The INI-format text representation.
    #>
    param (
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$config
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $firstSection = $true

    foreach ($section in $config.GetEnumerator()) {
        if ($section.Value.Count -eq 0) {
            continue
        }

        if (-not $firstSection) {
            $lines.Add("")
        }
        $firstSection = $false

        $lines.Add("[$($section.Key)]")
        foreach ($entry in $section.Value.GetEnumerator()) {
            $lines.Add("$($entry.Key)=$($entry.Value)")
        }
    }

    return ($lines -join "`n")
}
