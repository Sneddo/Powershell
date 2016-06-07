<# 
.SYNOPSIS 
   Enables CleanMgr on the system

.DESCRIPTION
   Copies the required files to use CleanMgr on a 2008 to 2012 server

.NOTES 
   File Name  : Enable-CleanMgr.ps1 
   Author     : John Sneddon
   Version    : 1.0  
#>
$OS = (Get-WMIObject Win32_OperatingSystem).Caption -match "Microsoft Windows Server (20[0-9]{2} (R2)?) Enterprise|Standard"
switch ($Matches[1])
{
   "2012"
   {
      Copy-Item "$($env:SystemRoot)\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.2.9200.16384_none_c60dddc5e750072a\cleanmgr.exe" "$($env:SystemRoot)\System32"
      Copy-Item "$($env:SystemRoot)\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.2.9200.16384_en-us_b6a01752226afbb3\cleanmgr.exe.mui" "$($env:SystemRoot)\System32\en-US"   
   }   
   "2008 R2"
   { 
      Copy-Item "$($env:SystemRoot)\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.1.7600.16385_none_c9392808773cd7da\cleanmgr.exe" "$($env:SystemRoot)\System32"
      Copy-Item "$($env:SystemRoot)\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.1.7600.16385_en-us_b9cb6194b257cc63\cleanmgr.exe.mui" "$($env:SystemRoot)\System32\en-US"
   }
   "2008"
   {
      switch ((Get-WMIObject Win32_OperatingSystem).OSArchitecture)
      {
         "64-bit"
         {
            Copy-Item "$($env:SystemRoot)\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.0.6001.18000_none_c962d1e515e94269\cleanmgr.exe" "$($env:SystemRoot)\System32"
            Copy-Item "$($env:SystemRoot)\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.0.6001.18000_en-us_b9f50b71510436f2\cleanmgr.exe.mui" "$($env:SystemRoot)\System32\en-US"
         }
         "32-bit"
         {
            Copy-Item "$($env:SystemRoot)\winsxs\x86_microsoft-windows-cleanmgr_31bf3856ad364e35_6.0.6001.18000_none_6d4436615d8bd133\cleanmgr.exe" "$($env:SystemRoot)\System32"
            Copy-Item "$($env:SystemRoot)\winsxs\x86_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.0.6001.18000_en-us_5dd66fed98a6c5bc\cleanmgr.exe.mui" "$($env:SystemRoot)\System32\en-US"
         }
      }
   }
}
