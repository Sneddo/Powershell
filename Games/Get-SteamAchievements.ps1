<# 
.SYNOPSIS 
   Grab achievement stats for a Steam account

.DESCRIPTION
   Scrapes achievement data for a Steam profile. Must be set to public to work.

.NOTES 
   File Name  : Get-SteamAchievements.ps1
   Author     : John Sneddon
   Version    : 1.0.0
#>

$User = Read-Host "Steam short name"
$webclient = new-object System.Net.WebClient
$GamesURLContent = $webclient.DownloadString("http://steamcommunity.com/id/{0}/games/?tab=all" -f $User)

$Achieves = @()

if ($GamesURLContent.Content -match "var rgGames = \[(.*)\]")
{
   $Games = (ConvertFrom-Json ("[{0}]" -f $Matches[1])) | Where {$_.availStatLinks.achievements -and ($_.hours_forever -gt 0)}

   foreach ($Game in $Games)
   {
      $GameAchieveContent = Invoke-WebRequest ("http://steamcommunity.com/id/{0}/stats/{1}/?tab=achievements" -f $User, $Game.friendlyURL)
      
      if ($GameAchieveContent -match "([0-9]+) of ([0-9]+) \(([0-9]+)%\) achievements earned")
      {
         Write-Host ("{0} {1}/{2} ({3})" -f $Game.Name, $Matches[1], $Matches[2], $Matches[3])
         $Achieves += New-Object PSObject -Property @{"Name" = $Game.Name; "Completed" = [int]$Matches[1]; "Total" = [int]$Matches[2]; "Percentage" = [int]$Matches[3] }
      }
      else
      {
         Write-Warning ("No achievement progress found for {0}" -f $Game.Name)
         $Achieves += New-Object PSObject -Property @{"Name" = $Game.Name; "Completed" = 0; "Total" = 0; "Percentage" = 0 }
      }
   }
}

$Achieves | Sort-Object Name | Select Name, Completed, Total, Percentage
