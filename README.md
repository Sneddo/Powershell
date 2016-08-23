Personal Collection of Powershell scripts. No guarantees provided with any of these scripts.

Exchange
=================
* **Start-MailSearch.ps1** - Pretty GUI wrapper around mailbox search.

Games
=================
* **Get-SteamAchievements.ps1** - Get achievement stats from Steam

Profile
================
* **Microsoft.PowerShell_profile.ps1** - current Powershell profile. 

Server
=================
* DHCP
  * **Invoke-DHCPMigration.ps1** -Migrate a scope from the Source DHCP server to a new server
  * **Sync-DHCPScope.ps1** -Triggered based on events from DHCP server to sync reservations
* Dell
  * **Set-DRACConfig.ps1** - This script configures a DRAC to a standard config
* Windows
  * **Enable-CleanMgr.ps1** - Used to simplify "install" of CleanMgr on Windows servers
  * **Invoke-WindowsUpdates.ps1** - Run updates on a server

VMware
=================
* **Compare-VCRole.ps1** - Generate a HTML report comparing two vCenter roles
* **Enable-HotAdd.ps1** - To enable Hot-add for CPU and memory (requires VM reboot to become active)
* **Export-VCSADatabase.ps1** - 	Very Basic DB backup for VCSA - UNTESTED
* **Get-HostRAIDLevel** - Get RAID config for hosts
* **RVToolsExport.ps1** - Performs full export from RVTools. Archives old versions.
* **Set-PostDeployConfig.ps1** - Post deploy script to configure VMs
* **Set-UpdateTools.ps1** - Set VMware tools to update on reboot 
* **VMNoteSync.ps1** - Sync VM annotations from AD information (description and manager) 
