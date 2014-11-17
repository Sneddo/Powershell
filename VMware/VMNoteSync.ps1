<# 
.SYNOPSIS 
	Script syncs details from AD to vCenter notes. 
.DESCRIPTION
	Script performs the following general steps:
	1. Find all VMs in all linked vCenter servers. 
	2. Query AD to find the Description and ManagedBy attibutes of the computer
	   account. 
	3. The ManagedBy attribute is then resolved to individual users/groups
	4. This information is then written back to vCenter
.NOTES 
    File Name  : VMNoteSync.ps1 
    Author     : John Sneddon - @JohnSneddonAU
	Version    : 1.1.6
.PARAMETER VCServers
   Specify which vCenter server(s) to connect to
.PARAMETER LogFile
   Specify the path to the logfile. Path to file must exist. Only used when
   DEBUG is set
.PARAMETER DEBUG	
	Enable Debug logging
.PARAMETER Verbose	
	Enable verbose output
.EXAMPLE 
	Normal operation
    ./VMNoteSync.ps1
.EXAMPLE
	

#>
# 1.0.0 - Initial release
# 1.1.0 - Only set notes if they differ
# 1.1.1 - Bug fixes for groups not resolving correctly
# 1.1.2 - Added step to update PowerCLI defaults to prevent script hanging
# 1.1.3 - Write to logfile to aid debugging, move to parameters
# 1.1.4 - Further work on Log file, bug fixes
# 1.1.5 - Fix for server name not showing
# 1.1.6 - Remove employer-specific code for release to web

param 
(
#   [Parameter(Mandatory=$true)]
   [string[]]$VCServers = Read-Host "Enter vCenter Server Address",
    
   # Set log locations
   [ValidateScript({Split-Path $_ | Test-Path})]
   [string]$LogFile="C:\Program Files\KIT\VMware\debug.log",
   
   [switch]$DEBUG,
   [switch]$verbose,
   
   # Email details
   $mailServer = "smtp.yourdomain.com",
   $mailFrom = ("VMware Reports<{0}@yourdomain.com>" -f $env:computername),
   $mailSubject = "VM Notes updated",
   $mailTo = @("you@yourdomain.com"),
   
   [switch]$WhatIf
)

# Setup email style
$emailContent = @"
<html>
	<head>
		<style type='text/css'>
			body { font-family: Calibri, Arial, sans-serif; font-size: 12px;}
			th { text-align: left; border-bottom: 2px solid black; font-size: 11px; }
			td { border-bottom: 1px solid silver; font-size: 11px; }
			table { border-collapse: collapse; width: 600px }
			p, h1, h2, h3 { margin: 0; padding 0 }
			.reportsection { width: 100%; padding: 10px; margin-bottom: 20px }
			.alt { Background: silver }
		</style>
	</head>
	<body>
	<h1>VM notes updated</h1>
	<p>This list contains any VM notes that have been updated from AD information</p>
"@

# AD cmdlets ignore ErrorAction parameter, ignore errors and handle errors by returned value
$EAP = $ErrorActionPreference
$ErrorActionPreference = "silentlyContinue"

################################################################################
#                               FUNCTIONS                                      #    
################################################################################
# Function to output to CLI and optionally file
function Write-Log ($str, $showInCLI=$true)
{
   $outStr = ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $str)
   if ($showInCLI)
   {
      Write-Host $outStr
   }

   # if in debug mode, output to file
   if ($script:DEBUG)
   {
      ($script:debugLog).WriteLine($outStr)
      ($script:debugLog).flush()
   }
}

###############################################################################
#                                   Setup                                     #
###############################################################################
# setup log file and write script start time to file
if ($DEBUG)
{
    $debugLog = [System.IO.StreamWriter] $LogFile
    Write-Log ("Script Started {0}" -f (Get-Date)) $false 
}


###############################################################################
#                               Retrieve VMs                                  #
###############################################################################
# Add snapin and connect to VC
Write-Log "Connecting to vCenter..."
Add-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue
Connect-VIServer -Server $VCServers -AllLinked | Out-Null

# Allow multiple connections
Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -confirm:$false | Out-Null

# get all Powered on VMs - ignore test PCs
Write-Log "Fetching VMs..."
$VMs = (Get-VM * | Where {$_.Powerstate -eq "PoweredOn" -and $_.Name -notmatch "^TPC.*" -and $_.Name -notmatch "PCWIN7DEV*"})

# create a blank array and fill it with custom objects with all annotations
Write-Log "Fetching VM Notes..."
$VMList = @()
foreach ($VM in $VMs)
{
   if ($verbose)
   {
      Write-Log "`t $($VM.Name)"
   }
	$tmpObj = New-Object PSObject -Property @{"Name" = $VM.Name}
	( $VM | Get-Annotation | foreach {$tmpObj | Add-Member NoteProperty $_.Name $_.Value})
	$VMList += $tmpObj

	Write-Progress -Activity "Fetching VM details..." -Status $VM.Name -PercentComplete (($VMList.count/$VMs.count)*100)
}
Write-Progress -Activity "Fetching VM details..." -Status "Complete" -Completed

###############################################################################
#                              Find info from AD                              #
###############################################################################
Write-Log "Finding Description/Manager information..."
Import-Module ActiveDirectory

$ManageGroups = @{} # Keep track of resolved groups to speed things up
$ADList = @{}       # Hash table to store Description/Manager for server 

# Find SME and System Owner
for ($i=0; $i -lt $VMList.count; $i++)
{
   try
   {
      $Computername = Get-ADComputer $VMList[$i].Name -Properties Description, ManagedBy
   }
   catch
   {
      $ComputerName = $null
   }
   $Manager = ""

   # Check if there is a manager listed
   if ($computerName.ManagedBy -ne $null)
   {
      if ($ManageGroups.Keys -notcontains $computerName.ManagedBy)
      {
         $addGroup = $true;

		try
		{
		   $managers = Get-ADGroupMember $computerName.ManagedBy
		
		   if ($managers -ne $null)
		   {	
			  foreach ($manager in $managers)
			  {
				$Manager +=  ";"+$manager.name
			  }
		   }
		}
		catch
		{
		   # getting the group failed, the field must be a user - set as System Owner
		   $addGroup = $false
		   $Manager = ";"+(Get-ADUser $computername.ManagedBy).Name
		}

         # trim Manager strings to remove first semicolon
         # if no Manger, return a hyphen         
         if ($Manager.length -gt 0)
         {
            $Manager = $Manager.SubString(1)
         }
         else 
         {
            $Manager = "-"
         }
         
         # Add the details to a hashtable to avoid looking it up again
         if ($addGroup)
         {
            $ManageGroups.Add($computerName.ManagedBy,@{"Manager"=$Manager;"Description"=$computerName.Description})
         }
      }
      # We have seen this group before
      else
      {
         $Manager = $ManageGroups[$computerName.ManagedBy]["Manager"]
         $Description = $ManageGroups[$computerName.ManagedBy]["Description"]
      }

      # Create a new object and assign to $ADList
      $ADList.Add($computerName.Name, @{"Manager" = $Manager;
                                        "Description" = $computerName.Description})
      Write-Progress -Activity "Finding Description/Manager" -Status $Computername.Name -PercentComplete ((100*$i)/$VMList.count) -ErrorAction SilentlyContinue
      if ($verbose)
      {
         Write-Log (New-Object PSObject -Property @{ "Manager" = $Manager; "Description" = $computerName.Description } | Format-Table)
      }
   }
}
Write-Progress -Activity "Finding Description/Manager" -Status "Complete!" -Completed

###############################################################################
#                             Set Notes on VMs                                #
###############################################################################
Write-Log "Importing notes..."
$updates = @()
foreach ($VM in $VMList)
{
   if ($ADList.Keys -contains $VM.Name)
   {
      # Get VM object reference
      $VMref = $VMs | Where {$_.Name -eq $VM.Name}
    
      if ($WhatIf)
      {
         if ($ADList[$VM.Name]["Description"] -ne $VM.Description)
         {
            $VMref | Set-Annotation -CustomAttribute "Description" -Value $ADList[$VM.Name]["Description"] -Whatif
         }
         if ($ADList[$VM.Name]["Manager"] -ne $VM."Manager")
         {
            $VMref | Set-Annotation -CustomAttribute "Manager" -Value $ADList[$VM.Name]["Manager"] -Whatif
         }
      }
      else
      {
         foreach ($field in @("Description", "Manager"))
         {
            if ($ADList[$VM.Name][$field] -ne $VM.$field)
            {
               ($VMref | Set-Annotation -CustomAttribute $field -Value $ADList[$VM.Name][$field])
               $updates += New-Object PSObject -Property @{"Server" = $VM.Name;
                                                           "Field" = $field;
                                                           "Value" = $ADList[$VM.Name][$field]}
               if ($verbose)
               {
                  Write-Log "$($VM.Name) - $field updated $($ADList[$VM.Name][$field])"
               }
            }
         }
      }
   }
   else
   {
      if ($verbose)
      {
         Write-Log "$($VM.Name) - No update required"
      }
   }
}

# Close VC connection 
Disconnect-VIServer * -Confirm:$False

###############################################################################
#                        Send email with updates made                         #
###############################################################################
if ($updates.count -gt 0)
{
	Write-Log "Sending Email..."
	$emailContent += "<table><tr><th>Server</th><th>Field</th><th>Old Value</th><th>New Value</th></tr>"
	for ($i = 0; $i -lt $updates.count; $i++)
	{
		# Setup zebra table classes
		if ($i%2) {	$class='alt' } else { $class='normal' }
		
		# Get Old value
		$OldValue = ($VMList | ?{$_.Name -eq $updates[$i].Server} | Select -ExpandProperty $updates[$i].Field)
		$updates[$i]
		$emailContent += ("<tr class='{0}'><td>{1}</td><td>{2}</td><td>{3}</td><td>{4}</td></tr>" -f $class, $updates[$i].Server, $updates[$i].Field, $oldValue, $updates[$i].Value)
	}
	$emailContent += "</table></body></html>"
	Send-MailMessage -From $mailFrom -To $mailTo -Subject $mailSubject -SmtpServer $mailServer -BodyAsHtml $emailContent
}
else
{
	Write-Log "No changes, no email generated"
}

# Close fileStream if used
if ($DEBUG)
{
   $debugLog.close()
}

# Reset EAP
$ErrorActionPreference = $EAP
