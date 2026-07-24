#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils._ArgumentSpecs
#AnsibleRequires -PowerShell ..module_utils._WslUtils
#AnsibleRequires -PowerShell ..module_utils._Distributions

$commonOptions = Get-WslCommandCommonOptionsDict
$moduleOptions = @{
    name = @{ type = "str"; required = $true }
    dest = @{ type = "str"; required = $true }
    vhd = @{ type = "bool"; default = $false }
}
$spec = @{
    options = $commonOptions + $moduleOptions
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$name = $module.Params.name
$dest = $module.Params.dest

$wslExe = Test-WslInstall -module $module

$module.Diff.before = @{}
$module.Diff.after = @{}

if (Test-Path -LiteralPath $dest) {
    $module.ExitJson()
}

$currentDistro = Get-DistributionRuntimeInfo -wslExe $wslExe -module $module -name $name -flat
if ($null -eq $currentDistro) {
    $module.FailJson("The distribution '$name' was not found. Cannot export a distribution that does not exist.")
}

$module.Result.changed = $true
$module.Diff.after = @{ "dest" = $dest }

if ($module.CheckMode) {
    $module.ExitJson()
}

$exportParams = [System.Collections.Generic.List[string]]::new()
$exportParams.AddRange([string[]]@("--export", $name, $dest))
if ($module.Params.vhd) { $exportParams.Add("--vhd") }

Invoke-WslCommand `
    -wslExe $wslExe `
    -module $module `
    -arguments $exportParams | Out-Null

$module.ExitJson()
