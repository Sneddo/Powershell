param (
   $UMDBServer="CSOSQL37INS2\INS2",
   $UMDBName="VC_UpMgr",
   $UpdateID,
   $UpdateRepositoryPath = 'C:\Users\sneddonj\Powershell\Scripts\VMware\UpdateManager\',
   $ArchivePath = 'C:\Users\sneddonj\Powershell\Scripts\VMware\UpdateManager\Archive'
)
$MetaFilePath = 'Repo\metadata-hp-esxi5.0uX-bundle-1.3.5-3.zip' ##########################

$DBServer = $null
$SQL = @{"UpdateDetail"="SELECT VCI_UPDATES.ID, VCI_UPDATES.TITLE, VCI_UPDATES.VENDOR, VCI_UPDATES.RELEASEDATE, 
                                VCI_UPDATES.DESCRIPTION, VCI_UPDATES.HYPERLINK, VCI_METADATA_FILES.RELATIVE_PATH, 
                                VCI_UPDATES.METADATAFILEID
                         FROM VCI_UPDATES INNER JOIN VCI_METADATA_FILES ON VCI_UPDATES.METADATAFILEID = VCI_METADATA_FILES.ID 
                         WHERE VCI_UPDATES.ID = {0}" }



#### TODO: INSERT SQL FUNCTIONS ####
function Connect-UMSQLServer
{
   param (
      [Parameter(Mandatory=$true)]
      [string]$Server=(Read-Host "Update Manager SQL Server"),
      
      [Parameter(Mandatory=$true)]
      [string]$Database=(Read-Host "Database Name")
      )
   
   # build the query string and try to connect
   $connString = ("Server={0};Database={1};Integrated Security=True" -f $Server, $Database)
   
   if (Test-DBServer $connString)
   {
      $script:DBServer = $connString
   }
}

function Test-DBServer
{
   param ([string]$connString)

   $SqlConnection = New-Object System.Data.SqlClient.SqlConnection($connString)
   
   try 
   {
      $SqlConnection.Open()
      $SqlConnection.Close()
      
      return $true;      
   }
   catch
   {
      Write-Error "Could not connect to database"
      return $false
   }
}

function Get-SQLResult($Query)
{
   $results = @()

   $SqlConnection = New-Object System.Data.SqlClient.SqlConnection($script:DBServer)
   $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
   $SqlCmd.CommandText = $Query
   $SqlCmd.Connection = $SqlConnection
   $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
   $SqlAdapter.SelectCommand = $SqlCmd
   $dt = New-Object System.Data.DataTable
   $SqlAdapter.Fill($dt) | Out-Null
   $SqlConnection.Close()

   return [array]$dt.rows
}

function Set-UpdateDeleteLog
{
   param ( [int]$updateID )

   "[{0}] Update ID [{1}] deleted by {2}" -f (get-date -UFormat "%D %T"), $updateID, $env:username | Out-File ("{0}\UpdateDeletes.log" -f $ArchivePath) -Append  
}

################################################################################
Connect-UMSQLServer $UMDBServer $UMDBName

# Get Update detail and confirm delete
$UpdateDetail = Get-SQLResult ($SQL["UpdateDetail"] -f $UpdateID)

Write-Warning "You are about to mark a patch as deleted. This is not officially supported by VMware"
$UpdateDetail | fl

$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Export the mailbox."
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Don't export"
$YesNoOptions = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$result = $host.ui.PromptForChoice("Delete Patch", "Are you sure you want to delete this patch?", $YesNoOptions, 0) 
		
if ($result -ne 0) # No
{
   break;
}


# UPDATE VCI_UPDATES SET Deleted=1 WHERE ID = ##
# Log which IDs have been marked as deleted - to enable revert

<#
# Check if metadata file is used for other updates
# If deleted = total, we have an orphaned update package
# Find RELATIVE_PATH from VCI_METADATA_FILES
#### TODO: $MetaFilePath
$vibRoot = ("{0}\{1}" -f $UpdateRepositoryPath, ($MetaFilePath -replace "(.*)\\(.*)$", '$1'))
# Open ZIP file and extract vmware.xml
$shellApp = New-object -com Shell.Application
$zipFile = $shellApp.nameSpace(("{0}\{1}" -f $UpdateRepositoryPath, $MetaFilePath))
$item = $zipfiles | where {$_.path -match "vmware.xml"}
$shellApp.NameSpace($env:temp).CopyHere($item)

[xml]$metadata = Get-Content ("{0}\vmware.xml" -f $env:temp)
# Loop over viblist element and move the VIBs
foreach ($vib in $metadata.metadataResponse.bulletin.vibList.vib)
{               
   $VIBPath = ("{0}\{1}" -f $vibRoot, $vib.vibFile.relativePath.Replace("/", "\"))
   $DestPath = ("{0}\{1}\{2}" -f $ArchivePath, ($MetaFilePath -replace "(.*)\\(.*)$", '$1'), $vib.vibFile.relativePath.Replace("/", "\"))
   
   # Check the VIB exists - seen some HP metadata with missing VIBs
   if (Test-Path $VIBPath)
   {
      # Create the destination folder structure if required
      if (!(Test-Path ($DestPath -replace "(.*)\\(.*)$", '$1')))
      {
         New-Item ($DestPath -replace "(.*)\\(.*)$", '$1') -ItemType Directory | Out-Null
      }
      # Delete (or move) VIB               
      Write-Verbose "Moving $VIBPath to $DestPath"
      Move-Item -Path $VIBPath -Destination $destPath
      
      # Check Source path is empty- if so, delete it
      ##### TO DO #####
   }
   else
   {
      Write-Warning "$VIBPath does not exist!"
   }
}
# Move the metadata file
Write-Host "Moving metadata"
Move-Item ("{0}\{1}" -f $UpdateRepositoryPath, $MetaFilePath) ("{0}\{1}" -f $ArchivePath, $MetaFilePath)

# Log row data from VCI_METADATA_FILES to enable revert
# Delete from VCI_METADATA_FILES where ID = VCI_UPDATES.Metadatafileid

 
#######################################################################################
# Cleanup function - check for any metadata files that are no longer required
# SELECT SUM(Deleted) AS Deleted, Count(*) AS total, METADATAFILEID FROM VCI_UPDATES GROUP BY Metadatafileid

#>