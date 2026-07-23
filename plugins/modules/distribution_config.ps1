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
    name = @{ type = "str"; required = $true }
    state = @{ type = "str"; default = "present"; choices = @("present", "absent") }
    terminate = @{ type = "bool"; default = $false }
    automount = @{
        type = "dict"
        options = @{
            enabled = @{ type = "bool" }
            mount_fs_tab = @{ type = "bool" }
            root = @{ type = "str" }
            options = @{ type = "str" }
        }
    }
    network = @{
        type = "dict"
        options = @{
            generate_hosts = @{ type = "bool" }
            generate_resolv_conf = @{ type = "bool" }
            hostname = @{ type = "str" }
        }
    }
    interop = @{
        type = "dict"
        options = @{
            enabled = @{ type = "bool" }
            append_windows_path = @{ type = "bool" }
        }
    }
    user = @{
        type = "dict"
        options = @{
            default = @{ type = "str" }
        }
    }
    boot = @{
        type = "dict"
        options = @{
            command = @{ type = "str" }
            systemd = @{ type = "bool" }
            protect_binfmt = @{ type = "bool" }
        }
    }
    gpu = @{
        type = "dict"
        options = @{
            enabled = @{ type = "bool" }
        }
    }
    time = @{
        type = "dict"
        options = @{
            use_windows_timezone = @{ type = "bool" }
        }
    }
}
$spec = @{
    options = $commonOptions + $moduleOptions
    supports_check_mode = $true
}


Function Set-WslConfSection {
    param(
        [System.Collections.Specialized.OrderedDictionary]$Config,
        [string]$SectionName,
        [System.Collections.IDictionary]$SectionParams
    )

    $changed = $false

    if (-not $Config.Contains($SectionName)) {
        $Config[$SectionName] = [ordered]@{}
    }

    foreach ($param in $SectionParams.GetEnumerator()) {
        if ($null -eq $param.Value) {
            continue
        }

        $confKey = Resolve-ConfKey -paramKey $param.Key
        $confValue = ConvertTo-ConfValue -value $param.Value
        $confSection = $Config[$SectionName]

        if (-not $confSection.Contains($confKey) -or $confSection[$confKey] -ne $confValue) {
            $confSection[$confKey] = $confValue
            $changed = $true
        }
    }

    return $changed
}


Function Remove-WslConfSection {
    param(
        [System.Collections.Specialized.OrderedDictionary]$Config,
        [string]$SectionName,
        [System.Collections.IDictionary]$SectionParams
    )

    if (-not $Config.Contains($SectionName)) {
        return $false
    }

    $nonNullParams = @{}
    foreach ($key in $SectionParams.Keys) {
        if ($null -eq $SectionParams[$key]) {
            continue
        }
        $nonNullParams[$key] = $SectionParams[$key]
    }

    if ($nonNullParams.Count -eq 0) {
        $Config.Remove($SectionName)
        return $true
    }

    $changed = $false
    foreach ($param in $nonNullParams.GetEnumerator()) {
        $confKey = Resolve-ConfKey -paramKey $param.Key

        if ($Config[$SectionName].Contains($confKey)) {
            $Config[$SectionName].Remove($confKey)
            $changed = $true
        }
    }

    if ($Config[$SectionName].Count -eq 0) {
        $Config.Remove($SectionName)
        $changed = $true
    }

    return $changed
}



$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$name = $module.Params.name
$state = $module.Params.state
$terminate = $module.Params.terminate

$wslExe = Test-WslInstall -module $module

$currentDistro = Get-DistributionRuntimeInfo -wslExe $wslExe -module $module -name $name -flat
if ($null -eq $currentDistro) {
    $module.FailJson("The distribution '$name' was not found.")
}

$sectionNames = @("automount", "network", "interop", "user", "boot", "gpu", "time")

# Ensure the distribution is running so the UNC filesystem path is accessible
Invoke-WslCommand `
    -wslExe $wslExe `
    -module $module `
    -arguments @("-d", $name, "--", "true") | Out-Null

$confPath = Get-WslConfPath -name $name
$config = Read-WslConf -path $confPath

$beforeSnake = ConvertTo-SnakeCaseConfig -config $config

foreach ($sectionName in $sectionNames) {
    $changed = $false
    $sectionParams = $module.Params.$sectionName
    if ($null -eq $sectionParams) {
        continue
    }

    if ($state -eq "present") {
        $changed = Set-WslConfSection `
            -Config $config `
            -SectionName $sectionName `
            -SectionParams $sectionParams
    }
    elseif ($state -eq "absent") {
        $changed = Remove-WslConfSection `
            -Config $config `
            -SectionName $sectionName `
            -SectionParams $sectionParams
    }

    if ($changed) {
        $module.Result.changed = $true
    }
}

if ($module.Result.changed) {
    $module.Diff.before = $beforeSnake
    $module.Diff.after = ConvertTo-SnakeCaseConfig -config $config
    $afterText = ConvertTo-WslConfText -config $config

    if (-not $module.CheckMode) {
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($confPath, $afterText + "`n", $utf8NoBom)

        if ($terminate) {
            Invoke-WslCommand `
                -wslExe $wslExe `
                -module $module `
                -arguments @("--terminate", $name) | Out-Null
        }
    }
}

$module.ExitJson()
