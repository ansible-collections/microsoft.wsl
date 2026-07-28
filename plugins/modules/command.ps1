#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils._ArgumentSpecs
#AnsibleRequires -PowerShell ..module_utils._WslUtils
#AnsibleRequires -PowerShell ..module_utils._Distributions

$commonOptions = Get-WslCommandCommonOptionsDict
$commonOptions.log_command_output.default = $true
$moduleOptions = @{
    name = @{ type = "str"; required = $true }
    command = @{ type = "str"; required = $true }
    user = @{ type = "str" }
    working_directory = @{ type = "str" }
    executable = @{ type = "str"; default = "/bin/sh" }
}
$spec = @{
    options = $commonOptions + $moduleOptions
    supports_check_mode = $false
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$name = $module.Params.name
$command = $module.Params.command

$wslExe = Test-WslInstall -module $module

$currentDistro = Get-DistributionRuntimeInfo -wslExe $wslExe -module $module -name $name -flat
if ($null -eq $currentDistro) {
    $module.FailJson("The distribution '$name' was not found.")
}

$wslArgs = [System.Collections.Generic.List[string]]::new()
$wslArgs.AddRange([string[]]@("-d", $name))

if ($null -ne $module.Params.user) {
    $wslArgs.AddRange([string[]]@("-u", $module.Params.user))
}

if ($null -ne $module.Params.working_directory) {
    $wslArgs.AddRange([string[]]@("--cd", $module.Params.working_directory))
}

$executable = $module.Params.executable
$wslArgs.AddRange([string[]]@("-e", $executable, "-c", $command))

# reset stdout/stderr. We want to log the previous command output for debugging purposes, but
# now that the module has made it this far, we really only want to capture the output from the
# actual command.
@('stdout', 'stdout_lines', 'stderr', 'stderr_lines') | ForEach-Object { $module.result.Remove($_) | out-null }

$result = Invoke-WslCommand `
    -wslExe $wslExe `
    -module $module `
    -arguments $wslArgs `
    -continueOnError `
    -rawOutput

$module.Result.changed = $true
$module.Result.rc = $result.exit_code

if ($result.exit_code -ne 0) {
    if ($module.Result.stderr_lines) {
        $message = $module.Result.stderr_lines[-1]
    }
    else {
        $message = "Command exited with non-zero exit code $($result.exit_code)"
    }
    $module.FailJson($message)
}

$module.ExitJson()
