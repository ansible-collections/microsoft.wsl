#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils._ArgumentSpecs
#AnsibleRequires -PowerShell ..module_utils._WslUtils

$commonOptions = Get-WslCommandCommonOptionsDict
$moduleOptions = @{
    gather_online = @{ type = "bool"; default = $False }
}
$spec = @{
    options = $commonOptions + $moduleOptions
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$gather_online = $module.Params.gather_online
$module.Result.distributions = @{}

$wslExe = Test-WslInstall -module $module


function Get-Status {
    $stdout, $stderr = Invoke-WslCommand `
        -wslExe $wslExe `
        -module $module `
        -arguments @("--status") `
        -successCodes @(0, -444)

    $versionMatch = $stdout | Select-String -Pattern 'Default Version: (\d+)'
    $module.Result.default_version = if ($versionMatch) { [int]$versionMatch.Matches.Groups[1].Value } else { $null }
    $distroMatch = $stdout | Select-String -Pattern 'Default Distribution: (.+)'
    $module.Result.default_distribution = if ($distroMatch) { $distroMatch.Matches.Groups[1].Value.Trim() } else { $null }
}


function Get-LocalDistroInfo {
    $stdout, $stderr = Invoke-WslCommand `
        -wslExe $wslExe `
        -module $module `
        -arguments @("--list", "--verbose")

    $lines = Split-StdText $stdout
    $distributions = @{}
    foreach ($line in ($lines | Select-Object -Skip 1)) {
        if ($line -match '^\s*(\*)?\s*(.+?)\s+(Stopped|Running|Installing|Uninstalling|Converting|Exporting)\s+(\d+)\s*$') {
            $distributions[$Matches[2].Trim()] = @{
                name = $Matches[2].Trim()
                state = $Matches[3]
                version = [int]$Matches[4]
                is_default = ($null -ne $Matches[1])
            }
        }
    }
    $module.Result.distributions.local = $distributions
}


function Get-OnlineDistroInfo {
    $stdout, $stderr = Invoke-WslCommand `
        -wslExe $wslExe `
        -module $module `
        -arguments @("--list", "--online")

    $lines = Split-StdText $stdout
    $distributions = @{}
    foreach ($line in ($lines | Select-Object -Skip 1)) {
        if ($line -match '^\s*(.+?)\s{2,}(.+?)\s*$') {
            $name = $Matches[1].Trim()
            if ($name -eq "NAME") { continue }
            $distributions[$name] = @{
                name = $name
                friendly_name = $Matches[2].Trim()
            }
        }
    }
    $module.Result.distributions.online = $distributions
}


Get-Status
Get-LocalDistroInfo
if ($gather_online) {
    Get-OnlineDistroInfo
}

$module.ExitJson()
