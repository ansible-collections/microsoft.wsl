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
    src = @{ type = "path"; required = $true }
    location = @{ type = "path"; required = $true }
    version = @{ type = "int"; choices = @(1, 2) }
    vhd = @{ type = "bool"; default = $false }
    remove_src = @{ type = "bool"; default = $false }
}
$spec = @{
    options = $commonOptions + $moduleOptions
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$name = $module.Params.name
$src = $module.Params.src
$location = $module.Params.location

$wslExe = Test-WslInstall -module $module

$module.Diff.before = @{}
$module.Diff.after = @{}

$currentDistro = Get-DistributionRuntimeInfo -wslExe $wslExe -module $module -name $name -flat
if ($null -ne $currentDistro) {
    $module.ExitJson()
}

if (-not (Test-Path -LiteralPath $src)) {
    $module.FailJson("The source file '$src' was not found. Cannot import a distribution from a file that does not exist.")
}

$module.Result.changed = $true
$module.Diff.after = @{ "name" = $name }

if ($module.CheckMode) {
    $module.ExitJson()
}

$importParams = [System.Collections.Generic.List[string]]::new()
$importParams.AddRange([string[]]@("--import", $name, $location, $src))
if ($module.Params.vhd) { $importParams.Add("--vhd") }
if ($module.Params.version) { $importParams.AddRange([string[]]@("--version", "$($module.Params.version)")) }

Invoke-WslCommand `
    -wslExe $wslExe `
    -module $module `
    -arguments $importParams | Out-Null

if ($module.Params.remove_src) {
    try {
        Remove-Item -LiteralPath $src -Force
    }
    catch {
        $module.FailJson(
            "The distribution was successfully imported, but the source file could not be removed: $($_.Exception.Message)",
            $_
        )
    }
}

$module.ExitJson()
