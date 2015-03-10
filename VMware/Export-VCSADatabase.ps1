$VCServers = @{$VCServers = @{"server" = @{"SshHostKeyFingerprint" = "ssh-rsa 1024 xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"; "Username" = "root"; "Password" = "SECURESTRING"; }}

$BackupLocation = "C:\temp\"

"[{0}] Adding PowerCLI Snapin..." -f (Get-Date -Format "HH:mm:ss")
Add-PSSnapIn VMware.VimAutomation.Core

foreach ($VCServer in $VCServers.Keys.GetEnumerator())
{
   "[{0}] Connecting to vCenter ({1})..." -f (Get-Date -Format "HH:mm:ss"), $VCServer
   Connect-VIServer $VCServer | Out-Null
   
   
   $Cred = (New-Object System.Management.Automation.PSCredential $VCServers[$VCServer].Username, ($VCServers[$VCServer].Password | ConvertTo-SecureString))
   $remoteFile = "/tmp/DBBackup-{0}-{1}.bak.gz" -f $VCServer, (Get-Date -f "yyyyMMdd")
   
   $cmd = "cd /opt/vmware/vpostgres/1.0/bin/; ./pg_dump VCDB -U vc -Fp -c | gzip > {0}" -f $remoteFile

   "[{0}] Starting backup..." -f (Get-Date -Format "HH:mm:ss")
   $r = Invoke-VMScript -VM (Get-VM $VCServer) -ScriptText $cmd -GuestCredential $cred
   
   if ($r.ExitCode -eq 0)
   {
      "[{0}] Backup successful" -f (Get-Date -Format "HH:mm:ss")
      try
      {
         # Load WinSCP .NET assembly
         Add-Type -Path "WinSCPnet.dll"
       
         # Setup session options
         $sessionOptions = New-Object WinSCP.SessionOptions
         $sessionOptions.Protocol = [WinSCP.Protocol]::Sftp
         $sessionOptions.HostName = $VCServer 
         $sessionOptions.UserName = $VCServers[$VCServer].Username
         $sessionOptions.Password = $Cred.GetNetworkCredential().Password
         $sessionOptions.SshHostKeyFingerprint = $VCServers[$VCServer].SshHostKeyFingerprint
       
         $session = New-Object WinSCP.Session
       
         try
         {
            "[{0}] SFTP Connect" -f (Get-Date -Format "HH:mm:ss")
            # Connect
            $session.Open($sessionOptions)
       
            "[{0}] Begin transfer" -f (Get-Date -Format "HH:mm:ss")
            $transferResult = $session.GetFiles($remoteFile, $BackupLocation, $true)
            
            # Throw on any error
            $transferResult.Check()
            
            "[{0}] Transfer Complete" -f (Get-Date -Format "HH:mm:ss")
         }
         finally
         {
            # Disconnect, clean up
            $session.Dispose()
         }
      }
      catch [Exception]
      {
         "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $_.Exception.Message
      }
   }
   else
   {
      "[{0}] Backup FAILED" -f (Get-Date -Format "HH:mm:ss")
   }
   
   Disconnect-VIServer $VCServer | Out-Null
}
