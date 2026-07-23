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

        if (-not $Config[$SectionName].Contains($confKey) -or $Config[$SectionName][$confKey] -ne $confValue) {
            $Config[$SectionName][$confKey] = $confValue
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

    $changed = $false

    if (-not $Config.Contains($SectionName)) {
        return $changed
    }

    $hasExplicitValues = $false
    foreach ($param in $SectionParams.GetEnumerator()) {
        if ($null -ne $param.Value) {
            $hasExplicitValues = $true
            break
        }
    }

    if (-not $hasExplicitValues) {
        $Config.Remove($SectionName)
        return $true
    }

    foreach ($param in $SectionParams.GetEnumerator()) {
        if ($null -eq $param.Value) {
            continue
        }

        $confKey = Resolve-ConfKey -paramKey $param.Key

        if ($Config[$SectionName].Contains($confKey)) {
            $Config[$SectionName].Remove($confKey)
            $changed = $true
        }
    }

    if ($Config[$SectionName].Count -eq 0) {
        $Config.Remove($SectionName)
    }

    return $changed
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$name = $module.Params.name
$state = $module.Params.state

$wslExe = Test-WslInstall -module $module

$currentDistro = Get-DistributionRuntimeInfo -wslExe $wslExe -module $module -name $name -flat
if ($null -eq $currentDistro) {
    $module.FailJson("The distribution '$name' was not found.")
}

$sectionNames = @("automount", "network", "interop", "user", "boot", "gpu", "time")

# Ensure the distribution is running so the UNC filesystem path is accessible
Invoke-WslCommand -wslExe $wslExe -module $module -arguments @("-d", $name, "--", "true")

$confPath = Get-WslConfPath -name $name
$config = Read-WslConf -path $confPath

$beforeText = ConvertTo-WslConfText -config $config

$changed = $false

foreach ($sectionName in $sectionNames) {
    $sectionParams = $module.Params.$sectionName
    if ($null -eq $sectionParams) {
        continue
    }

    if ($state -eq "present") {
        $changed = Set-WslConfSection -Config $config -SectionName $sectionName -SectionParams $sectionParams
    }
    elseif ($state -eq "absent") {
        $changed = Remove-WslConfSection -Config $config -SectionName $sectionName -SectionParams $sectionParams
    }
}

$afterText = ConvertTo-WslConfText -config $config

$module.Result.changed = $changed
$module.Diff.before = $beforeText
$module.Diff.after = $afterText

if ($changed -and (-not $module.CheckMode)) {
    Write-WslConf -path $confPath -config $config
}

$module.ExitJson()
