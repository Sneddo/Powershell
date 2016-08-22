<# 
.SYNOPSIS 
   Triggered based on events from DHCP server to sync reservations.
   
.DESCRIPTION
   Script is trigged based on events 106 and 107 in DHCP server event log to 
   sync DHCP reservations in a particular scope to failover partner.
 
.NOTES 
   File Name  : Invoke-DHCPSync.ps1 
   Author     : John Sneddon - @JohnSneddonAU
   Version    : 1.0.0
 
.LINK
   http://www.sneddo.net/2015/05/dhcp-fail-over/
 
.INPUTS
   No inputs required
.OUTPUTS
   None
 
.PARAMETER eventRecordID
   Event ID of the triggering event
 
.PARAMETER eventChannel
   Event Channel of the triggering event - will always be Microsoft-Windows-Dhcp-Server/Operational
#>
param($eventRecordID,$eventChannel)
 
$regKey = "SYSTEM\CurrentControlSet\Services\DHCPServer\Parameters"
$regKeyName = "SyncInProgress"
 
# Get the exact event
$event = Get-WinEvent -LogName $eventChannel -FilterXPath "<QueryList><Query Id='0' Path='$eventChannel'><Select Path='$eventChannel'>*[System[(EventRecordID=$eventRecordID)]]</Select></Query></QueryList>"
 
if (!(Get-Item Registry::HKEY_LOCAL_MACHINE\$regkey -ErrorAction SilentlyContinue).Value)
{
   # Match the event Property to ScopeID - Format [[172.x.x.x]Scope name]
   if ($event.Properties[1].value -match "\[\[(.*)\].*\]")
   {
      $date = Get-date
      $scope = $Matches[1]
      $state = (Get-DhcpServerv4Scope $scope).State
      
      # Get scope and find the partner 
      $partner = (Get-DhcpServerv4Failover -ScopeId $scope).PartnerServer
      
      # set reg key on partner
      $BaseKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$partner)
      $SubKey = $BaseKey.OpenSubKey($regKey,$true)
      $SubKey.SetValue($regKeyName , 1, [Microsoft.Win32.RegistryValueKind]::DWORD)
      
      # start replication
      Invoke-DhcpServerv4FailoverReplication –ScopeID $scope -Force
      
      # Remove reg key from partner
      $SubKey.SetValue($regKeyName , 0, [Microsoft.Win32.RegistryValueKind]::DWORD)
   }
}
