# Set Profile version - Used for update check
$Version= 0.50
# Profile location - should be network accessible share
$ProfileLocation = "\\server\path\_profile\Microsoft.Powershell_profile.ps1"

# Personal drive
$PersonalDrive = "\\server\path\user"

# Set History settings here - for persistent history accross sessions
$HistoryLocation = "\\server\path\_profile\history.xml"
$HistoryCount = 500   # Max: ([Int16]::MaxValue)

# PSReadLine Location - directory containing module
$PSReadLineLocation = "\\server\path\_profile\PSReadline"

# Array of vCenter servers to prompt to join when PowerCLI snapin loaded
$vCenterServers = @("server1", "server2", "server3")


################################################################################
#                                   FUNCTIONS                                  #
################################################################################
function Install-PowerCLIXmlSerializer {
  <#
    .SYNOPSIS
      Installs all the PowerCLI XmlSerializers.
 
    .DESCRIPTION
      Installs all the PowerCLI XmlSerializers.
      This is needed to speed-up the execution of the first PowerCLI cmdlet that is run in a PowerCLI session.
      After you install a new version of PowerCLI you only have to run this function once.
      If you use both the 32-bit and the 64-bit version of PowerCLI then you have to run this function in both versions.
      You must run this function with administrative privileges enabled.
 
    .EXAMPLE
      PS C:\> Install-PowerCLIXmlSerializers
 
    .INPUTS
      None
 
    .OUTPUTS
      System.String
 
    .NOTES
      Author:  Robert van den Nieuwendijk
      Date:    18-2-2012
      Version: 1.0
	
	.LINK
		http://rvdnieuwendijk.com/2012/02/18/function-to-speed-up-the-execution-of-the-first-powercli-cmdlet/
  #>
   
  # Create an alias for ngen.exe
  Set-Alias ngen (Join-Path ([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) ngen.exe)
   
  # Install all the PowerCLI XmlSerializers
  Get-ChildItem -Path $env:SystemRoot\assembly\GAC_MSIL\VimService*.XmlSerializers | `
  ForEach-Object {
    if ($_) {
      $Name = $_.Name
      Get-ChildItem -Path $_
    }
  } | `
  Select-Object -Property @{N="Name";E={$Name}},@{N="Version";E={$_.Name.Split("_")[0]}},@{N="PublicKeyToken";E={$_.Name.Split("_")[-1]}} | `
  ForEach-Object {
    if ($_) {
      ngen install "$($_.Name), Version=$($_.Version), Culture=neutral, PublicKeyToken=$($_.PublicKeyToken)"
    }
  }
}

function Get-Addons
{
<#
	.SYNOPSIS
		Returns a two-column list of Modules and snapins available on this machine
 
    .DESCRIPTION
		Prints a two-column list of all Available Modules and all registered snapins.
 
    .EXAMPLE
      PS C:\> Get-Addons
 
    .INPUTS
      None
 
    .OUTPUTS
      System.String
 
    .NOTES
      Author:  John Sneddon
      Date:    13-10-2014
      Version: 1.0
  #>
	$m = Get-Module -ListAvailable | Select -expandproperty Name
	$s = Get-PSSnapin -Registered | Select -ExpandProperty Name
	$colwidth = (Get-Host).ui.RawUI.WindowSize.Width/2

	# Header
	Write-Host "".Padright((Get-Host).ui.RawUI.WindowSize.Width-1, "=")
	Write-Host ("| Available Modules{0}| Available Snapins{1}|" -f "".PadRight($colWidth-20), ("".PadRight($colWidth-20)))
	Write-Host "".Padright((Get-Host).ui.RawUI.WindowSize.Width-1, "=")
	for ($i = 0; $i -lt [System.Math]::Max($m.count, $s.count); $i++)
	{
		if ($m[$i])
		{
			Write-Host ("| {0}|" -f $m[$i].PadRight($colWidth-3)) -NoNewLine
		}
		else
		{
			Write-Host ("|{0}|" -f "".PadRight($colWidth-2)) -NoNewLine
		}
		if ($s[$i])
		{
			Write-Host (" {0}|" -f $s[$i].PadRight($colWidth-3) )
		}
		else
		{
			Write-Host ("{0}|" -f "".PadRight($colWidth-2))
		}
	}
	Write-Host "".Padright((Get-Host).ui.RawUI.WindowSize.Width-1, "-")
	Write-Host
}

function Add-PowerCLISnapin
{
	if (!(Get-PSSnapin -name VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
		Write-Host ("Adding PowerCLI Core{0}[    ]" -f "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-27)) -NoNewline
		try 
		{
			Add-PSSnapin VMware.VimAutomation.Core
			Write-Host ("`rAdding PowerCLI Core{0}[" -f "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-27)) -NoNewline
			Write-Host -ForegroundColor Green " OK " -NoNewLine
			$Host.UI.RawUI.WindowTitle += " [VM]"
		}
		catch 
		{
			Write-Host("`rAdding PowerCLI Core{0}[" -f "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-27)) -NoNewline
			Write-Host -ForegroundColor Red "FAIL" -NoNewLine
		}
		Write-Host "]"
	}
	
	Write-Host (Get-PowerCLIVersion).ToString()
	
	$vCenter = Get-Menu -Title "Connect to vCenter" -Question "Do you want to connect to a vCenter?" -Options $vCenterServers -AddNoOption

	if ($vCenter)
	{
		Connect-VIServer $vCenter -Credential (Get-Credential -UserName $env:username -Message "Enter vCentre Credentials") | Out-Null
	}
}
function Add-ExchangeSnapin
{
	if (!(Get-PSSnapin -name Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue)) {
		if ((Get-PSSnapin -Name Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue -Registered).Count -gt 0)
		{
			Write-Host ("Adding Exchange Snapin{0}[    ]" -f "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-29)) -NoNewline
			try 
			{
				Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn
				Write-Host ("`rAdding Exchange Snapin{0}[" -f "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-29)) -NoNewline
				Write-Host -ForegroundColor Green " OK " -NoNewLine
				$Host.UI.RawUI.WindowTitle += " [Exchange]"
			}
			catch 
			{
				Write-Host("`rAdding Exchange Snapin{0}[" -f "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-29)) -NoNewline
				Write-Host -ForegroundColor Red "FAIL" -NoNewLine
			}
			Write-Host "]"
		}
		else
		{
			Write-Warning "Exchange Snapin not available on this host"
		}
	}
}

function Add-ADModule
{
	if (!(Get-Module -name ActiveDirectoy -ErrorAction SilentlyContinue)) {
		Write-Host ("Adding Active Directory Module {0}[    ]" -f "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-37)) -NoNewline
		try 
		{
			Import-Module ActiveDirectory
			Write-Host ("`rAdding Active Directory Module{0}[" -f "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-37)) -NoNewline
			Write-Host -ForegroundColor Green " OK " -NoNewLine
			$Host.UI.RawUI.WindowTitle += " [AD]"
		}
		catch 
		{
			Write-Host("`rAdding Active Directory Module{0}[" -f "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-37)) -NoNewline
			Write-Host -ForegroundColor Red "FAIL" -NoNewLine
		}
		Write-Host "]"
	}
}

# Generate a Powershell console menu
function Get-Menu
{
	param ([String]$Title, [string]$Question, [string[]]$Options, [switch]$AddNoOption)
	$MenuOptions = @()
	
	if ($AddNoOption)
	{
		$MenuOptions += (New-Object System.Management.Automation.Host.ChoiceDescription "&No", "No")
	}
	
	for ($i = 1; $i -le $Options.Count; $i++)
	{
		$MenuOptions += (New-Object System.Management.Automation.Host.ChoiceDescription "&$i $($Options[$i-1])", $Options[$i-1])
	}
	
	$result = $host.ui.PromptForChoice($title, $Question, $MenuOptions, 0)
   
   if ($AddNoOption)
   {
      $result = $result-1
   }
   
	if ($AddNoOption -and $result -eq 0)
	{
		return $null
	}
	return $Options[$result]
}

################################################################################
#                                    ALIASES                                   #
################################################################################
Set-Alias vm Add-PowerCLISnapin
Set-Alias ad Add-ADModule
Set-Alias ex Add-ExchangeSnapin

################################################################################
#                                     INIT                                     #
################################################################################
# Check if profile exists or Profile is latest
if ((!(Test-Path $Profile)) -or ($Version -lt (Get-Content $ProfileLocation | Select-String -Pattern "\$+Version\s*=").toString().split("=")[1].Trim()))
{
	if (!(Test-Path $Profile))
	{
		New-Item  -Type Directory (Split-Path $profile) | Out-Null
	}
	Copy-Item $ProfileLocation $Profile
	& $Profile
	break
}
# Check if PSReadLine is installed
if (! (Get-Module PSReadLine))
{
   # Copy the directory to the local profile location
   Copy-Item $PSReadLineLocation ("{0}\Modules\PSReadLine" -f (Split-Path $profile)) -Recurse -Force
   Import-Module PSReadLine
}
else
{
   Import-Module PSReadLine
}

# Check if the H: drive is mapped
if ($PersonalDrive -and -not (Test-Path "H:"))
{
   New-PSDrive -Name "H" -PSProvider FileSystem -Root $PersonalDrive -Persist | Out-Null
}

Register-EngineEvent -SourceIdentifier powershell.exiting -SupportEvent -Action {
    Get-History -Count $HistoryCount | Export-Clixml $HistoryLocation
}

# Load History
Import-CliXML $HistoryLocation | Add-History

################################################################################
#                                     STYLE                                    #
################################################################################
$Host.UI.RawUI.BackgroundColor = 'Black'
$Host.UI.RawUI.ForegroundColor = 'White'
$Host.PrivateData.ErrorForegroundColor = 'Red'
$Host.PrivateData.ErrorBackgroundColor = 'Black'
$Host.PrivateData.WarningForegroundColor = 'Yellow'
$Host.PrivateData.WarningBackgroundColor = 'Black'
$Host.PrivateData.DebugForegroundColor = 'Cyan'
$Host.PrivateData.DebugBackgroundColor = 'Black'
$Host.PrivateData.VerboseForegroundColor = 'DarkGray'
$Host.PrivateData.VerboseBackgroundColor = 'Black'
$Host.PrivateData.ProgressForegroundColor = 'White'
$Host.PrivateData.ProgressBackgroundColor = 'DarkGray'

# Set Console Size
$pshost = Get-Host
$pswindow = $pshost.ui.rawui

$newsize = $pswindow.buffersize
$newsize.height = 3000
$newsize.width = 120
$pswindow.buffersize = $newsize

$newsize = $pswindow.windowsize
$newsize.height = 50
$newsize.width = 120
$pswindow.windowsize = $newsize

# Set Title
if ($Host.UI.RawUI.WindowTitle -match "Administrator:")
{
	$IsAdmin = $true
	$Admin = "*"
}

$Host.UI.RawUI.WindowTitle = ("PS{0} - User {1}{2} on {3}" -f $host.Version.ToString(), $env:username, $Admin, $env:ComputerName)
Clear-Host

################################################################################
#                                    HEADER                                    #
################################################################################
Write-Host -ForegroundColor Green "".Padright((Get-Host).ui.RawUI.WindowSize.Width-1, "-")
Write-Host -ForegroundColor Green " Profile Version: " -NoNewline
Write-Host $Version
Write-Host -ForegroundColor Green " User: ".PadRight(18) -NoNewLine
if ($env:username -match "_a$")
{ 
	Write-Host -ForegroundColor Red $env:username
}
else
{
	Write-Host $env:username
}
Write-Host -ForegroundColor Green "".Padright((Get-Host).ui.RawUI.WindowSize.Width-1, "-")
Write-Host 
