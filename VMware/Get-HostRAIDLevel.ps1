<# 
.SYNOPSIS 
   Get the RAID config of all hosts

.DESCRIPTION
   Get the RAID detail for ESX hosts

.NOTES 
   File Name  : Get-HostRAIDLevel.ps1
   Author     : John Sneddon
   Version    : 1.0.0
#>
$timeout = 2
$HostCred = Get-Credential
$CIOpt = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -Encoding Utf8 -UseSsl

$VMH = Get-VMHost | Where {$_.PowerState -eq "PoweredOn" -and $_.ConnectionState -eq "Connected" }

$i=0
foreach ($h in $VMH)
{
	$RAID = "CIM Error"
	Write-Progress -Activity "Fetching RAID detail" -status $h.name -percentcomplete ($i/($vmh.count))
	$Session = New-CimSession -Authentication Basic -Credential $HostCred -ComputerName $h.Name -port 443 -SessionOption $CIOpt  -OperationTimeoutSec $timeout -ErrorAction SilentlyContinue 2>$null 3>$null
	if ($Session)
	{
		$RAID = Get-CimInstance -CimSession $Session  -OperationTimeoutSec $timeout -ClassName CIM_StorageVolume -ErrorAction SilentlyContinue 2>$null 3>$null | Select -expandproperty ElementName
	}
	New-object PSObject -Property @{"Name" = $h.Name; "ESX"=$h.Version; "RAID" = $RAID }
	$i=$i+100
}
Write-Progress -Status "Done" -Activity "Done" -Completed
