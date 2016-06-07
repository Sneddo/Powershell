<#
.SYNOPSIS
   Post deploy script to configure VMs
.DESCRIPTION
   Configurations applied
      * AD Object move
      * Change CD Drive letter to Z:
      * Initialise Data disks (2012+ only at this stage)
      * SCOM Agent Install
      * Update Group Policy
      * Install Updates

.NOTES
   Author     : John Sneddon
   Version    : 1.2.1
#>
################################################################################
#                                 CONFIGURATION                                #
################################################################################
# This is the only section that should require changes

# $Config is a hashtable with the key as the environment (i.e. Prod or Test),
# and values as a hastable of the following:
# OU          - [string] which OU should the AD object be moved to (DN)
# WSUSDefault - [string] Change the group to this after patching (ServerAutoWeek2)
# memberOf    - [string[]] AD Groups to add the server to
$Config = @{"Prod" = @{ "OU"          = "";
                        "WSUSDefault" = "ServerAutoWeek2";
                        "memberOf"    = @("",
                                          "") };
            "Test" = @{ "OU"          = ""}
            }


# Set Path of master script
$Script = "\\Server\share\Set-PostDeployConfig.ps1"
# Set Local Path
$LocalScript = "C:\windows\temp\Set-PostDeployConfig.ps1"
# Require user account to be in this domain
$UserDomain = "SOUTHERNHEALTH"

################################################################################
#                                  FUNCTIONS                                   #
################################################################################
Function Get-ScriptVersion ($Path)
{
   return [version](Get-Content $Path | Select-String -Pattern "Version\s*:").toString().split(":")[1].Trim()
}

Function Write-Status ($Message, $Status)
{
   switch ($Status)
   {
      "OK"    {   Write-Host ("`r {0}{1}[" -f $Message, "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-($Message.Length+8))) -NoNewline
                  Write-Host -ForegroundColor Green " OK " -NoNewLine
                  Write-Host "]"
              }
      "FAIL"  {   Write-Host ("`r {0}{1}[" -f $Message, "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-($Message.Length+8))) -NoNewline
                  Write-Host -ForegroundColor Red "FAIL" -NoNewLine
                  Write-Host "]"
              }
      "N/A"  {   Write-Host ("`r {0}{1}[ N/A]" -f $Message, "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-($Message.Length+8)))
              }
      default {   Write-Host (" {0}{1}[    ]" -f $Message, "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-($Message.Length+8))) -NoNewline }
   }
}

################################################################################
#                                     INIT                                     #
################################################################################
# Requires a SOUTHERNHEALTH account
if ($env:USERDOMAIN -ne $UserDomain)
{
   Write-Warning "Not logged in as $UserDomain account. Please login as your admin account to complete configuration"
   $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
   break
}

# Script must be run as administrator
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
   $arguments = "& '" + $myinvocation.mycommand.definition + "'"
   Start-Process powershell -Verb runAs -ArgumentList $arguments
   Break
}

# Check if there is a newer version of the script
if ((Get-ScriptVersion $LocalScript) -lt (Get-ScriptVersion $script))
{
   Write-Warning "Newer version available!"
   Copy-Item $Script $LocalScript
   & $LocalScript
   break
}

################################################################################
#                                INFO GATHERING                                #
################################################################################
## Header #
Write-Host "Monash Health Post-deployment configuration"

## Gather Information
$Prod = New-Object System.Management.Automation.Host.ChoiceDescription "&Prod", "Production"
$Test = New-Object System.Management.Automation.Host.ChoiceDescription "&Test", "Test"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($Prod, $Test)
$result = $host.ui.PromptForChoice("Choose environment", "Is the server Production or Test?", $options, 0)
switch ($result)
{
   0 { $Environment = "Prod"; }
   1 { $Environment = "Test"; }
}

# Get the Server description for BGInfo
$ServerDesc = Read-Host "Server Description"

Clear-Host
Write-Host ""
Write-Host ""

################################################################################
#                                   FUNCTION                                   #
################################################################################
######## Active Directory ########
# Move the AD Object
Write-Status "Moving AD Object"
Try
{
   Import-Module ActiveDirectory
   Get-ADComputer $env:ComputerName | Move-ADObject -TargetPath $Config[$Environment].OU
   Write-Status "Moving AD Object" "OK"
}
catch
{
   Write-Status "Moving AD Object" "FAIL"
}

## Update Group Policy ##
Write-Status "Updating Group Policy"
$r = Start-Process -FilePath "C:\Windows\System32\gpupdate.exe" -ArgumentList "/Force" -NoNewWindow -Wait -RedirectStandardOutput null -PassThru
if ($r.ExitCode -eq 0)
{
   Write-Status "Updating Group Policy" "OK"
}
else
{
   Write-Status "Updating Group Policy" "FAIL"
}

######## Server Description ########
Write-Status "Setting Server Description"
$os = Get-WmiObject Win32_OperatingSystem
$os.Description = $ServerDesc
$os.Put() | Out-Null
Write-Status "Setting Server Description" "OK"

######## Drives ########
# Change drive letter of all CD drives, starting with Z: and work backwards
Write-Status "Changing CD Drive letters"
Try
{
   $i = 0;
   Get-WmiObject Win32_cdromdrive | %{ $a = (mountvol $_.drive /l).Trim(); mountvol $_.drive /d; mountvol (([char](122-$i++)).ToString()+':') $a}
   # Wait for a bit - otherwise the drive letter not always available
   Start-Sleep -Seconds 5
   Write-Status "Changing CD Drive letters" "OK"
}
catch
{
   Write-Status "Changing CD Drive letters" "FAIL"
}

# Use the Storage cmdlets if available
Write-Host " Initialising Disks" -NoNewline
if (@(Get-Command Get-Disk -ErrorAction SilentlyContinue).Count -gt 0)
{
   # Initialize and format any extra disks
   $dataDisks = Get-Disk | Where partitionstyle -eq 'raw'

   if ($dataDisks -gt 1)
   {
      $i = 0
      foreach ($disk in $dataDisks)
      {
         Write-Status ("   Initialising Disk {0}:" -f ([char](100+$i)))
         $disk | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -UseMaximumSize | Format-Volume -FileSystem NTFS -Confirm:$false | Out-Null

         # Assign a drive letter - do this second otherwise we get an annoying prompt to format the disks
         $disk | Get-Partition | Where { $_.Type -eq "Basic" } | Set-Partition -NewDriveLetter ([char](100+$i))
         Write-Status ("   Initialising Disk {0}:" -f ([char](100+$i))) "OK"
         $i++
      }
   }
   else
   {
      # No Data disks
      Write-Status "Initialising Disks" "N/A"
   }
}
else
{
   Write-Warning "Storage cmdlets not available, you must be deploying an old OS"
   Write-Status "Initialising Disks" "N/A"
}

########## Software ##########
## Install SCOM
if ($Environment -eq "Prod")
{
   Write-Status "Installing SCOM Agent"
   . $Env:WinDir\System32\msiexec.exe /i "\\Server\Share\SCOM-latest\MOMAgent.msi" /qn USE_SETTINGS_FROM_AD=0 USE_MANUALLY_SPECIFIED_SETTINGS=1 MANAGEMENT_GROUP=SOUTHERNHEALTH MANAGEMENT_SERVER_DNS=SHCLASCOAPP01 SECURE_PORT=5723 ACTIONS_USE_COMPUTER_ACCOUNT=1 AcceptEndUserLicenseAgreement=1
   Write-Status "Installing SCOM Agent" "OK"
}

## Regenerate WSUS Client ID - 2008 seems to occasionally have trouble with WSUS otherwise
if ((Get-WMIObject win32_OperatingSystem).Caption -match "Server 2008")
{
   Write-Status "Fix 2008 WSUS Settings"
   Stop-Service wuauserv
   Remove-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate SusClientID
   Remove-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate AccountDomainSid
   Remove-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate TargetGroup
   Remove-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate TargetGroupEnabled
   Start-Service wuauserv
   Write-Status "Fix 2008 WSUS Settings" "OK"
}

## Install Updates
Write-Status "Searching for Windows Updates"
# Search for relevant updates.
$SearchResult = (New-Object -ComObject Microsoft.Update.Searcher).Search("IsInstalled=0 and Type='Software'").Updates
Write-Status "Searching for Windows Updates" "OK"


if ($SearchResult)
{
   Write-Status ("Installing Windows Updates [{0}]" -f $SearchResult.Count)

   # Download updates.
   Write-Status "Downloading Updates"
   $Downloader = ( New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
   $Downloader.Updates = $SearchResult
   $Downloader.Download() | Out-Null
   Write-Status " Downloading Updates" "OK"

   # Install updates.
   Write-Status " Installing Updates"
   $Installer = New-Object -ComObject Microsoft.Update.Installer
   $Installer.Updates = $SearchResult
   $Result = $Installer.Install() | Out-Null
   Write-Status ("Installing Windows Updates [{0}]" -f $SearchResult.Count) "OK"
}
else
{
   Write-Status "Installing Windows Updates" "N/A"
}

## Set Reg keys for Prod Servers
# Set WSUS Group
if ($Environment -eq "Prod")
{
   Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name TargetGroup $Config[$Environment].WSUSDefault
}

## Add to RDP Timeout group by default
foreach ($grp in $Config[$Environment].memberOf)
{
   Add-ADGroupMember -Identity $grp -Members ("{0}$" -f $Env:Computername)
}

Write-Host ""
Write-Host "Remember to:"
Write-Host "   * Create Wiki page"
Write-Host "   * Approve SCOM Agent"
Write-Host "   * Add to Hobbit"
Write-Host "   * Add to Backups"

################################################################################
#                                   FINALISE                                   #
################################################################################
# Remove from Run regkey
Remove-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run DeployScript
# Delete Script
Remove-Item $LocalScript

# Reboot
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Reboots the computer"
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Do not reboot"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$result = $host.ui.PromptForChoice("Reboot Required", "Do you want to reboot now?", $options, 0)

if ($result -eq 0)
{
   Restart-Computer
}

<#
CHANGELOG
---------
1.0.0 - Initial version
        Configurations applied
         * AD Object move
         * Change CD Drive letter to Z:
         * Initialise Data disks (2012+ only at this stage)
         * SCOM Agent Install
         * Update Group Policy
         * Install Updates
1.1.0 - Bugs fixed
         * Suppress additional output from WMI set
        Enhancements
         * Better feedback on Windows Update progress (no hang on search)
1.1.1 - Added Additional steps reminder
1.2.0 - Add memberOf config  to add computer object to groups
1.2.1 - Add to ServerAutoWeek2 group
#>
