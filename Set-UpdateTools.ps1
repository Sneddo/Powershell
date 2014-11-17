<# 
.SYNOPSIS 
   Quick script to set VMware tools to update on reboot.

.DESCRIPTION
   Sets all VMs in specified vCenter to update tools on reboot. 

.NOTES 
   File Name  : Set-UpdateTools.ps1 
   Author     : John Sneddon
   Version    : 1.0
   
.PARAMETER ComputerName
   Specify the vCenter server name
#>
param 
(
   [ValidateScript({Test-Connection $_ -Quiet -Count 1})] 
   [string]$ComputerName
)

# Adding PowerCLI core snapin
if (!(get-pssnapin -name VMware.VimAutomation.Core -erroraction silentlycontinue)) {
	add-pssnapin VMware.VimAutomation.Core
}


Connect-VIServer $ComputerName

$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
$vmConfigSpec.Tools = New-Object VMware.Vim.ToolsConfigInfo
$vmConfigSpec.Tools.ToolsUpgradePolicy = "UpgradeAtPowerCycle"

Foreach ($vm in (Get-View -ViewType VirtualMachine)) {
   $vm.ReconfigVM($vmConfigSpec)
}
