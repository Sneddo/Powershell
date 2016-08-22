# Requires -Modules DHCPServer -RunAsAdministrator
Import-Module DHCPServer

<#
.SYNOPSIS
   Migrate a scope from the Source DHCP server to a new server
.DESCRIPTION

.NOTES
   File Name  : Invoke-DHCPMigration.ps1
   Author     : John Sneddon
   Version    : 1.0.0

.PARAMETER Source
   Source DHCP server.
.PARAMETER Scope
   Scope to migrate
.PARAMETER Destination
   Destination DHCP Server
.PARAMETER BackupPath
   Path to backup DHCP server on import
#>
function Invoke-DHCPMigration
{
   [CmdletBinding()]
   param
   (
      [Parameter(Mandatory=$true)]
      [string$Source,

      [Parameter(Mandatory=$true)]
      [string]$Scope,

      [Parameter(Mandatory=$true)]
      [string]$Destination,

      [string]$BackupPath="C:\DHCP\Backup",

      [switch]$DisableScope=$false
   )
   Begin
   {
      # Validate Source server is alive and is DHCP server
      if (-not (Test-Connection $Source -Quiet -Count 1))
      {
         Write-Error "Source server unavailable"
      }
      else
      {
         try
         {
            Get-DhcpServerv4Statistics -ComputerName $Source | Out-Null
         }
         catch
         {
            Write-Error "Cannot connect to Source DHCP server"
         }
      }

      # Validate Destination server is alive and is DHCP server
      if (-not (Test-Connection $Destination -Quiet -Count 1))
      {
         Write-Error "Destination server unavailable"
      }
      else
      {
         try
         {
            Get-DhcpServerv4Statistics -ComputerName $Destination | Out-Null
         }
         catch
         {
            Write-Error "Cannot connect to Destination DHCP server"
         }
      }

      # Validate Scope is valid
      <# Fix this later - use regex to determine ipv4/6
      try
      {
         Invoke-Expression "Get-DhcpServer$($version)scope -ComputerName $source -ScopeId $Scope"
      }
      catch
      {
         Write-Error "Could not get scope information from source server"
      }
      #>
   }

   Process
   {
      $File = ("{0}\{1}.xml" -f $Env:temp, $Scope)

      if ($DisableScope)
      {
         Write-Verbose "Disable Scope on Source server"
         Set-DhcpServerv4Scope -ScopeId $Scope -ComputerName $Source -State InActive
      }
      Write-Verbose "Exporting scope to file: $File"
      Export-DhcpServer -ComputerName $Source -ScopeId $Scope -Leases -File $File -Force

      Write-Verbose "Importing scope"
      Import-DhcpServer -ComputerName $Destination -File $File -BackupPath $BackupPath -Leases -ScopeOverwrite -Force

      if ($DisableScope)
      {
         Write-Verbose "Enable Scope on Destination server"
         Set-DhcpServerv4Scope -ScopeId $Scope -ComputerName $Destination -State Active
      }
   }

   End
   {
         Write-Verbose "Deleting migration file: $File"
         Remove-Item $File -Force
   }
}
