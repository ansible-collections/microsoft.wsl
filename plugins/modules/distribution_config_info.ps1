#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils._ArgumentSpecs
#AnsibleRequires -PowerShell ..module_utils._WslUtils
#AnsibleRequires -PowerShell ..module_utils._Distributions
#AnsibleRequires -PowerShell ..module_utils._WslConf

$commonOptions = Get-WslCommandCommonOptionsDict
$moduleOptions = @{
    name = @{ type = "str" }
}
$spec = @{
    options = $commonOptions + $moduleOptions
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$name = $module.Params.name

$wslExe = Test-WslInstall -module $module

$distributions = Get-DistributionRuntimeInfo -wslExe $wslExe -module $module -name $name

if (-not [string]::IsNullOrEmpty($name) -and -not $distributions.Contains($name)) {
    $module.FailJson("The distribution '$name' was not found.")
}

$configs = @{}
foreach ($distroName in $distributions.Keys) {
    # Ensure the distribution is running so the UNC filesystem path is accessible
    Invoke-WslCommand `
        -wslExe $wslExe `
        -module $module `
        -arguments @("-d", $distroName, "--", "true") | Out-Null
    $confPath = Get-WslConfPath -name $distroName
    $parsedConfig = ConvertTo-SnakeCaseConfig -config (Read-WslConf -path $confPath)
    $configs[$distroName] = @{
        name = $distroName
        config = $parsedConfig
    }
}

$module.Result.configs = $configs

$module.ExitJson()
