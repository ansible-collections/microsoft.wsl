function Get-WslCommandCommonOptionsDict {
    return @{
        log_command_output = @{ type = "bool"; default = $False }
    }
}
