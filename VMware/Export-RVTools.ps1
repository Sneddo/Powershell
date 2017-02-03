<# 
.SYNOPSIS 
   Performs full export from RVTools
.DESCRIPTION
   Performs full export from RVTools. Archives old versions.
.NOTES 
   File Name  : Export-RVTools.ps1 
   Author     : John Sneddon
   Version    : 1.0.0
.PARAMETER Servers
   Specify which vCenter server(s) to connect to
.PARAMETER BasePath
   Specify the path to export to. Server name and date appended.
.PARAMETER OldFileDays
   How many days to retain copies
#>
param
(
   $Servers = @("Server"),
   $BasePath = "C:\Scripts\Powershell\RVToolsExport\Archive",
   $OldFileDays = 30
)

$Date = (Get-Date -f "yyyyMMdd")

foreach ($Server in $Servers)
{
   # Create Directory
   New-Item -Path "$BasePath\$Server\$Date" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

   # Run Export
   . "C:\Program Files (x86)\RobWare\RVTools\RVTools.exe" -passthroughAuth -s "$Server.internal.southernhealth.org.au" -c ExportAll2csv -d "$BasePath\$Server\$Date"

   # Cleanup old files
   $Items = Get-ChildItem "$BasePath\$server"
   foreach ($item in $items)
   {
      $itemDate = ("{0}/{1}/{2}" -f $item.name.Substring(6,2),$item.name.Substring(4,2),$item.name.Substring(0,4))
      
      if ((((Get-date).AddDays(-$OldFileDays))-(Get-Date($itemDate))).Days -gt 0)
      {
         $item | Remove-Item -Recurse
      }
   }
}
