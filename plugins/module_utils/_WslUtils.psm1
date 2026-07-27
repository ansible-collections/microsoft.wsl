function Test-WslInstall {
    <#
    .SYNOPSIS
        Verifies that wsl.exe is available on the system.
    .DESCRIPTION
        Checks for the presence of wsl.exe using Get-Command. If not found,
        fails the module with an error message.
    .PARAMETER module
        The Ansible.Basic.AnsibleModule instance.
    .OUTPUTS
        System.Management.Automation.ApplicationInfo. The wsl.exe command object.
    #>
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$module
    )

    $wslExe = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if ($null -eq $wslExe) {
        $module.FailJson("wsl.exe was not found. Ensure that Windows Subsystem for Linux is installed.")
    }

    return $wslExe
}


function Split-StdText {
    <#
    .SYNOPSIS
        Splits a block of text into trimmed, non-empty lines.
    .PARAMETER text
        The raw text to split, typically stdout or stderr from a process.
    .OUTPUTS
        System.String[]. An array of trimmed, non-empty lines.
    #>
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$text
    )

    $text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
}


function Write-StdText {
    <#
    .SYNOPSIS
        Appends stdout and stderr text to the module result.
    .DESCRIPTION
        Accumulates command output in the module's Result dictionary. Initializes
        the stdout/stderr keys if they do not already exist, then appends the
        provided text to both the raw string and the split lines list.
    .PARAMETER module
        The Ansible.Basic.AnsibleModule instance.
    .PARAMETER stdout
        The standard output text to append.
    .PARAMETER stderr
        The standard error text to append.
    #>
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$module,

        [ValidateNotNull()]
        [string]$stdout = "",

        [ValidateNotNull()]
        [string]$stderr = ""
    )

    if (-not $module.Result.ContainsKey('stdout')) {
        $module.Result.stdout = ""
        $module.Result.stdout_lines = [System.Collections.Generic.List[string]]::new()
    }

    if (-not $module.Result.ContainsKey('stderr')) {
        $module.Result.stderr = ""
        $module.Result.stderr_lines = [System.Collections.Generic.List[string]]::new()
    }

    $module.Result.stdout += $stdout
    $module.Result.stderr += $stderr
    $module.Result.stdout_lines.AddRange([string[]]@(Split-StdText -text $stdout))
    $module.Result.stderr_lines.AddRange([string[]]@(Split-StdText -text $stderr))
}


function Invoke-WslCommand {
    <#
    .SYNOPSIS
        Runs a wsl.exe command and returns its output.
    .DESCRIPTION
        Executes wsl.exe with the given arguments using System.Diagnostics.Process
        with Unicode encoding. If the module's log_command_output parameter is true,
        or if the exit code is not in successCodes, the output is appended to the
        module result via Write-StdText. A non-success exit code fails the module.
    .PARAMETER wslExe
        The wsl.exe command object returned by Test-WslInstall.
    .PARAMETER module
        The Ansible.Basic.AnsibleModule instance.
    .PARAMETER arguments
        An array of arguments to pass to wsl.exe.
    .PARAMETER successCodes
        An array of exit codes considered successful. Defaults to @(0).
    .OUTPUTS
        System.String[]. A two-element array of (stdout, stderr).
    #>
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$wslExe,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$module,

        [ValidateNotNull()]
        [array]$arguments = @(),

        [ValidateNotNull()]
        [array]$successCodes = @(0)
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $wslExe.Source
    $psi.Arguments = (
        $arguments | ForEach-Object {
            if ($_ -match '[\s"]') { "`"$($_ -replace '"', '\"')`"" } else { $_ }
        }
    ) -join ' '
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    # WSL uses utf16 by default but is "investigating" making utf8 the default in the
    # future
    $psi.EnvironmentVariables["WSL_UTF8"] = "1"
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($psi)
    # one read needs to be async,
    # https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.standardoutput
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $process.WaitForExit()

    # Handle error exit codes gracefully
    if ($process.ExitCode -notin $successCodes) {
        $module.Result.command_arguments = $arguments
        # wsl logs errors as regular text, so we need to reassign the stdout to stderr
        if ($stderr -eq "") {
            $stderr = $stdout
            $stdout = ""
        }
        Write-StdText -module $module -stdout $stdout -stderr $stderr
        $message = "WSL command returned an unexpected exit code, $($process.ExitCode)"
        if ($stderr.length -gt 0) {
            $message += ": $stderr"
        }
        $module.FailJson($message)
    }

    if (($module.Params.log_command_output -eq $True)) {
        Write-StdText -module $module -stdout $stdout -stderr $stderr
    }

    return $stdout, $stderr
}


function Compare-DesiredVsActual {
    param (
        [string]$attributeName,
        $desired,
        $actual,
        [object]$diff = $null
    )

    if ($null -eq $desired) {
        return $False
    }

    if ($desired -ne $actual) {
        if ($null -ne $diff) {
            $diff.before[$attributeName] = $actual
            $diff.after[$attributeName] = $desired
        }
        return $True
    }

    return $False
}
