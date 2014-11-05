<# 
.SYNOPSIS 
   Enable memory and CPU hot-add for 2008 R2 servers
.DESCRIPTION
   Basic script to bulk update VMs to enable CPU and memory Hot add. Only 
   supports Server 2008 R2 at present, and VM will require a reboot for option
   to be available to use.
.NOTES 
   File Name  : Enable-HotAdd.ps1 
   Author     : John Sneddon - @JohnSneddonAU
   Version    : 1.0

   Version History
   ---------------
   1.0.0 - Initial release
   
.INPUTS
   vCenter Server must be specified
.OUTPUTS
    HTML formatted email or HTML File
   
.PARAMETER vCenter
    Specify the vCenter server(s) to connect to  

.EXAMPLE
   ./Enable-HotAdd -vCenter "vc.fqdn.domain.com"
#>    
param 
(
   [ValidateScript({Test-Connection -Count 1 -Quiet -ComputerName $_})]
   $vCenter=Read-Host "Enter vCenter Server name"
)

function Enable-CPUMemHotAdd ($VMView)
{
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec

    $extra = New-Object VMware.Vim.optionvalue
    $extra.Key="vcpu.hotadd"
    $extra.Value="true"
    $vmConfigSpec.extraconfig += $extra

    $extra = New-Object VMware.Vim.optionvalue
    $extra.Key="mem.hotadd"
    $extra.Value="true"
    $vmConfigSpec.extraconfig += $extra

    $vmview.ReconfigVM($vmConfigSpec)
}
# Add Snapin
if (!(Get-PSSnapin -name VMware.VimAutomation.Core -erroraction silentlycontinue)) {
	Add-PSSnapin VMware.VimAutomation.Core
}
Connect-VIServer $vCenter

$VMs = Get-View -ViewType VirtualMachine | ?{$_.guest.guestFullName -eq "Microsoft Windows Server 2008 R2 (64-bit)"}

$i = 0
foreach ($VM in $VMs)
{
	$perc = (100*$i++)/$VMs.Count
	Write-Progress -Activity ("Updating VM ({0} of {1})" -f $i, $VMs.Count) -Status ("{0:n2}% - {1}" -f $perc, $VM.Name) -PercentComplete $perc
	Enable-CPUMemHotAdd $VM
}
Write-Progress -Activity "Updating VM" -Status "Done" -Completed
