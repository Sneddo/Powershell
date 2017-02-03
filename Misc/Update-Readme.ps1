<# 
.SYNOPSIS 
   Quick script to recreate README.md

.DESCRIPTION
   Loop over child items and generate a new README.md content from script headers.

.NOTES 
   File Name  : Update-Readme.ps1 
   Author     : John Sneddon
   Version    : 1.0.0
#>

function Get-ScriptSynopsis
{
   param ($File)
   
   try 
   {
      $synopsis = (Select-String -path $File -pattern ".SYNOPSIS" -Context 1).Context.PostContext.trim()
   }
   catch
   {
      Write-Warning ("No Synopsis found for {0}" -f $File)
      $synopsis = ""
   }
   
   return $synopsis
}

$currDirectory = ""

$content = "Personal Collection of Powershell scripts. No guarantees provided with any of these scripts.`n`n"

foreach ($dir in (Get-ChildItem -Directory -Path ../ | Where-Object {$_.Name -notmatch "^_"} | Sort-Object Name))
{
   $indent = ""
   $prevSubDir = ""
   $content += ("`n{0}`n=================`n" -f $dir.Name)
   foreach ($script in (Get-ChildItem -Path $dir.FullName -Recurse -Filter *.ps1 ))
   {
      $subDir = $script.DirectoryName.replace($dir.FullName, "").Trim("\")
      
      if ($subDir -ne "")
      {
         if ($SubDir -ne $prevSubDir)
         {
            if ($indent.length -ge 2) 
            { 
               $indent = $indent.Substring(2) 
            }
            $content += ("{0}* {1}`n" -f $indent, $subDir)
            $indent += "  "
         }
         else
         {
            #$indent = $indent.Substring(2)
         }
         $prevSubDir = $SubDir

      }
      else 
      {
         $indent = ""
      }
      $currDirectory = $script.Directory.name
      $content += ("{0}* **{1}** - {2}`n" -f $indent, $script.name, (Get-ScriptSynopsis $Script.FullName))
   }
}
$content | Out-File ..\README.md

# Changelog
# =========
# 1.0.0 - 2017-02-03 - Initial release
