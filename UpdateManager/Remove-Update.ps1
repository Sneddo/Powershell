param (
   $UpdateID,
   $UpdateRepositoryPath = 'C:\Users\sneddonj\Powershell\Scripts\VMware\UpdateManager\',
   $ArchivePath = 'C:\Users\sneddonj\Powershell\Scripts\VMware\UpdateManager\Archive'
)
#### TODO: INSERT SQL FUNCTIONS ####

# Get Update detail and confirm delete

# UPDATE VCI_UPDATES SET Deleted=1 WHERE ID = ##
# Log which IDs have been marked as deleted - to enable revert

# Check if metadata file is used for other updates
# If deleted = total, we have an orphaned update package
# Find RELATIVE_PATH from VCI_METADATA_FILES
$MetaFilePath = 'Repo\metadata-hp-esxi5.0uX-bundle-1.3.5-3.zip' ##########################
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