<#
.SYNOPSIS 
   This script configures a DRAC to a standard config
.DESCRIPTION
   This script will apply the appropriate config in the config folder, as well 
   as generating a secure passwords and storing in Secret Server. It will also 
   update firmware to the applicable firmware in the firmware folder.
   
   If a file is passed to the hostname field, it will loop over each value and
   apply the configuration.
   
.NOTES 
   File Name  : Set-DRACConfig
   Author     : John Sneddon - john.sneddon@monashhealth.org
   Version    : 1.0
  
  CHANGELOG
  1.0 - Initial script. 
  
  There's probably a lot to clean up with this, but good enough for now...
  
.INPUTS
   No inputs required
.OUTPUTS
   No outputs
#>
################################################################################
#                               CONFIGURATION                                  #
################################################################################
# Path to racadm executable
$racadmExe = "C:\Program Files\Dell\SysMgt\rac5\racadm.exe"
# Secret Server win auth webservice URL
$SecretServerURL = "https://secretserver.internal.southernhealth.org.au/winauthwebservices/sswinauthwebservice.asmx"
# SS template to use
$SecretTemplate = "Dell DRAC Account" 
# SS folder to store passwords in
$SecretServerFolder = "DRAC"

################################################################################
#                               INITIALISATION                                 #
################################################################################
Clear-Host
Write-Host "Loading Requirements..." -NoNewline
# Add WPF Type
Add-Type -AssemblyName PresentationFramework
# Check if RacAdm is available
if (-not (Test-Path $racadmExe))
{
   Write-Error "RacAdmin not located in $racadmExe"
   exit
}
Write-Host "Done"

# Hide the Powershell window
Add-Type -Name "Methods" -Namespace "UIWin32" -PassThru -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);' | Out-Null
$Handle = (Get-Process -id $Pid).MainWindowHandle
[UIWin32.Methods]::ShowWindow($Handle, 0) | Out-Null

################################################################################
#                                  FUNCTIONS                                   #
################################################################################

function Invoke-DRACConfig
{
   Param
   (
      [string]$DRAC,
      [string]$DRACUser,
      [string]$DRACPass,
      [Boolean]$Backup
   )
   $Form.Hide()
   [UIWin32.Methods]::ShowWindow($Handle, 5) | Out-Null

   # If we have a file path, retrieve the contents
   if (Test-Path $DRAC)
   {
      [string[]]$DRAC = Get-Content $DRAC
   }
   
   $i = 0;
   foreach ($dracInstance in $DRAC)
   {
      Write-Progress -Activity "Configuring DRAC" -Status $dracInstance -PercentComplete ($i*100/$DRAC.count)
      # RacAdm only uses IPs, so resolve the hostname to IP
      try 
      {
         $DRACIP = [system.net.DNS]::Resolve($dracInstance).AddressList[0].IPAddressToString
      }
      catch
      {
         $DRACIP = ""
         Write-warning ("{0} cannot be resolved" -f $dracInstance) 
         continue
      }
      
      if ($DRACIP)
      {
         # Try to determine DRAC verion
         Write-Debug "$racadmExe -r $DRACIP -u $DRACUser -p $DRACPass getconfig -g idracinfo -o idractype 2>&1"
         $racOut = . "$racadmExe" -r $DRACIP -u $DRACUser -p $DRACPass getconfig -g idracinfo -o idractype 2>&1

         # Catch exception- e.g. Login failure
         if (($racOut | ?{ $_ -is [System.Management.Automation.ErrorRecord] }).count -gt 0)
         {
            $version = "???"
            $status = ($racOut | ?{ $_ -is [System.Management.Automation.ErrorRecord] })[0].exception
         }
         else
         {
            switch ([int]($racOut -match "^[0-9]+$")[0])
            {
               6  { $version = "drac5" }
               10 { $version = "drac6" }
               16 { $version = "drac7" }
               32 { $version = "drac8" }
               33 { $version = "drac8" }
               default { $version = ""}
            }

            switch ($version)
            {
               "drac5"  { $status = "DRAC5 is not supported" }
               "drac6"  { 
                           if ($Backup)
                           {
                              Write-Host "Performing Backup"
                              $tempFile = ("Backup/{0}-{1}.txt" -f (Get-Date -f "yyyyMMdd"), $dracInstance)
                              $racOut = . "$racadmExe" -r $DRACIP -u $DRACUser -p $DRACPass getconfig -f $tempFile;
                           }
               
                           # Get a random Password
                           $password = Get-SecretServerPassword
                           Write-Debug "New Password: $password"
                           
                           # Read the config and replace the root password
                           $config = Get-Content "Config\drac6.txt"
                           $config = $config -replace "{Password}", $password
                           
                           # Write to a temp file 
                           $tempFile = ("{0}{1}.txt" -f [System.IO.Path]::GetTempPath(), $dracInstance)
                           $config | Out-File $tempFile -Encoding utf8
                           
                           Write-Debug "Importing Config"
                           Write-Debug "$racadmExe -r $DRACIP -u $DRACUser -p $DRACPass config -f $tempFile 2>&1;"
                           $racOut = . "$racadmExe" -r $DRACIP -u $DRACUser -p $DRACPass config -f $tempFile 2>&1;
                           
                           $status = $racOut[-1]
                           
                           Remove-Item $tempFile
                           if ($status -match "RAC configuration from file completed successfully")
                           {
                              # Update Secret Server
                              Write-Debug "Updating Secret Server"
                              Set-SecretServerPassword $dracInstance "root" $password ""
                           }
               
                        } 
               "drac7"  {
                           if ($Backup)
                           {
                              Write-Host "Performing Backup"
                              $tempFile = ("Backup/{0}-{1}.xml" -f (Get-Date -f "yyyyMMdd"), $dracInstance)
                              $racOut = . "$racadmExe" -r $DRACIP -u $DRACUser -p $DRACPass get -t xml -f $tempFile;
                           }
               
                           # Get a random Password
                           $password = Get-SecretServerPassword
                           Write-Debug "New Password: $password"
                           
                           # Read the config and replace the root password
                           [xml]$config = Get-Content "Config\drac7.xml"
                           ($config.SystemConfiguration.Component.Attribute | where {$_.Name -eq "Users.2#Password"})."#text" = $password
                           
                           # Write to a temp file 
                           $tempFile = ("{0}{1}.xml" -f [System.IO.Path]::GetTempPath(), $dracInstance)
                           $config.Save($tempFile)
                           
                           Write-Debug "Importing Config"
                           Write-Debug "$racadmExe -r $DRACIP -u $DRACUser -p $DRACPass set -t xml -f $tempFile;"
                           $racOut = . "$racadmExe" -r $DRACIP -u $DRACUser -p $DRACPass set -t xml -f $tempFile;
                           # DRAC 7 creates a job to import the config, get the status of the job
                           if ([string]$racOut -match "jobqueue view -i (JID_.*)""") 
                           {
                              $jobID = $Matches[1]
                              Write-Debug "Job found: $jobID"
                              
                              $jobComplete = $false
                              while (-not $jobComplete)
                              {
                                 $racOut = . "$racadmExe" -r $DRACIP -u $DRACUser -p $DRACPass jobqueue view -i $jobID 2>&1
                                 # if the password has already changed, we'll get a login failure
                                 if ($racOut -match "ERROR: Login failed - invalid username or password")
                                 {
                                    $tmpPass = $DRACPass
                                    $DRACPass = $password
                                 }
                                 # Loop for a while until the job is complete
                                 if ([string]$racOut -match "Percent Complete=\[([^]]*)\]")
                                 {
                                    Write-Debug "Job complete: $($Matches[1])"
                                    if ($Matches[1] -eq "100")
                                    {
                                       $jobComplete = $true
                                    }
                                    else
                                    {
                                       Start-Sleep -Seconds 10
                                    }
                                 }
                                 if ([string]$racOut -match "Message=\[([^]]*)\]")
                                 {
                                    $status = $Matches[1]
                                 }
                              }
                              if ($tmpPass)
                              {
                                 $DRACPass = $tmpPass
                              }
                           }
                           else
                           {
                              write-Debug $racOut.ToString()
                           }
                           Remove-Item $tempFile
                           if ($status -match "Successfully exported system configuration XML file." -or
                               $status -match "Import of system configuration XML file operation completed with errors.")
                           {
                              # Update Secret Server
                              Write-Debug "Updating Secret Server"
                              Set-SecretServerPassword $dracInstance "root" $password ""
                           }
                        }
               "drac8"  {
                           if ($Backup)
                           {
                              Write-Host "Performing Backup"
                              $tempFile = ("Backup/{0}-{1}.xml" -f (Get-Date -f "yyyyMMdd"), $dracInstance)
                              $racOut = . "$racadmExe" -r $DRACIP -u $DRACUser -p $DRACPass get -t xml -f $tempFile;
                           }
               
                           # Get a random Password
                           $password = Get-SecretServerPassword
                           Write-Debug "New Password: $password"
                           
                           # Read the config and replace the root password
                           [xml]$config = Get-Content "Config\drac8.xml"
                           ($config.SystemConfiguration.Component.Attribute | where {$_.Name -eq "Users.2#Password"})."#text" = $password
                           
                           # Write to a temp file 
                           $tempFile = ("{0}{1}.xml" -f [System.IO.Path]::GetTempPath(), $dracInstance)
                           $config.Save($tempFile)
                           
                           Write-Debug "Importing Config"
                           Write-Debug "$racadmExe -r $DRACIP -u $DRACUser -p $DRACPass set -t xml -f $tempFile;"
                           $racOut = . "$racadmExe" -r $DRACIP -u $DRACUser -p $DRACPass set -t xml -f $tempFile;
                           # DRAC 7 creates a job to import the config, get the status of the job
                           if ([string]$racOut -match "jobqueue view -i (JID_.*)""") 
                           {
                              $jobID = $Matches[1]
                              Write-Debug "Job found: $jobID"
                              
                              $jobComplete = $false
                              while (-not $jobComplete)
                              {
                                 $racOut = . "$racadmExe" -r $DRACIP -u $DRACUser -p $DRACPass jobqueue view -i $jobID 2>&1
                                 # if the password has already changed, we'll get a login failure
                                 if ($racOut -match "ERROR: Login failed - invalid username or password")
                                 {
                                    $tmpPass = $DRACPass
                                    $DRACPass = $password
                                 }
                                 # Loop for a while until the job is complete
                                 if ([string]$racOut -match "Percent Complete=\[([^]]*)\]")
                                 {
                                    Write-Debug "Job complete: $($Matches[1])"
                                    if ($Matches[1] -eq "100")
                                    {
                                       $jobComplete = $true
                                    }
                                    else
                                    {
                                       Start-Sleep -Seconds 10
                                    }
                                 }
                                 if ([string]$racOut -match "Message=\[([^]]*)\]")
                                 {
                                    $status = $Matches[1]
                                 }
                              }
                              if ($tmpPass)
                              {
                                 $DRACPass = $tmpPass
                              }
                           }
                           else
                           {
                              write-Debug $racOut.ToString()
                           }
                           Remove-Item $tempFile
                           if ($status -match "Successfully exported system configuration XML file." -or
                               $status -match "Import of system configuration XML file operation completed with errors.")
                           {
                              # Update Secret Server
                              Write-Debug "Updating Secret Server"
                              Set-SecretServerPassword $dracInstance "root" $password ""
                           }
                        }
               default  {}
            }
         }
         Write-Host ("{0}[{1}] ({2}): {3}" -f $dracInstance, $DRACIP, $version, $status)
      }
   }
   Write-Progress -Activity "Configuring DRAC" -Status "Complete" -Completed
}

<#
Generate a password using SecretServer
#>
function Get-SecretServerPassword
{
   # Connect to web service
   $SecretServer = New-WebServiceProxy -uri $SecretServerURL -UseDefaultCredential
   
   # Generate a password
   $password = $SecretServer.GeneratePassword(1);
   
   if ($password.GeneratedPassword)
   {
      return $password.GeneratedPassword;
   }
   else
   {
      return $false
   }
}


function Set-SecretServerPassword
{
   param
   (
      [string]$hostname,
      [string]$username,
      [string]$password,
      [string]$notes=""
   )
   # Connect to web service
   $SecretServer = New-WebServiceProxy -uri $SecretServerURL -UseDefaultCredential
   
   # Get the FolderId
   $SecretFolderId = $SecretServer.SearchFolders($SecretServerFolder).folders.id
   
   # see if the item exists already, if so update
   if ($SecretServer.SearchSecretsByFolder($hostname, $SecretFolderId, $false, $false, $false).SecretSummaries)
   {
      $Secret = $SecretServer.SearchSecretsByFolder($hostname, $SecretFolderId, $false, $false, $false).SecretSummaries[0]
      $Secret = $SecretServer.GetSecret($Secret.SecretId, $null, $null).Secret
      ($Secret.Items | where {$_.FieldName -eq "Password"}).value = $password
      $result = $SecretServer.UpdateSecret($Secret)
   }
   # Does not exist, add it
   else
   {
      # Get the list of fields
      $SecretTemplate = $SecretServer.GetSecretTemplates().SecretTemplates | where {$_.Name -match $SecretTemplate }
      
      $FieldIDs = $SecretTemplate.Fields | Select -ExpandProperty Id
      
      $FieldValues = @()
      foreach ($field in $SecretTemplate.Fields)
      {
         $FieldValues += (Get-Variable $field.DisplayName).value
      }
      
      $SecretServer.AddSecret($SecretTemplate.Id, $hostname, $FieldIDs, $FieldValues, $SecretFolderId)
   }
}

################################################################################
#                                    GUI                                       #
################################################################################
# Use XAML to define the form, data to be populated in code
[xml]$XAML_Main = @"
   <Window
      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      Height="255" Width="500" Title="DRAC Config">
      <Window.Resources>
         <Style TargetType="Label">
            <Setter Property="Height" Value="30" />
            <Setter Property="Background" Value="#0A77BA" />
            <Setter Property="Foreground" Value="White" />
            <Setter Property="VerticalAlignment" Value="Top" />
            <Setter Property="HorizontalAlignment" Value="Left" />
         </Style>
      </Window.Resources>
      <DockPanel Height="Auto">
         <DockPanel DockPanel.Dock="Bottom" Height="30" Margin="5">
            <Button Name="btnConfig" Height="30" Content="Configure" VerticalAlignment="Top" />
         </DockPanel>
         <DockPanel DockPanel.Dock="Top" Height="Auto">
               <Grid Margin="5,5,5,5">
               <Grid.ColumnDefinitions>  
                  <ColumnDefinition Width="175"/>  
                  <ColumnDefinition />  
               </Grid.ColumnDefinitions>  
               <Grid.RowDefinitions>  
                  <RowDefinition Height="30" />  
                  <RowDefinition Height="5" />
                  <RowDefinition Height="30" />  
                  <RowDefinition Height="5" />
                  <RowDefinition Height="30" />  
                  <RowDefinition Height="5" />
                  <RowDefinition Height="30" /> 
                  <RowDefinition Height="5" />
                  <RowDefinition Height="30" /> 
               </Grid.RowDefinitions> 
               <Label Content="DRAC Address" Width="170" Grid.Row="0" Grid.Column="0" />
               <DockPanel Grid.Row="0" Grid.Column="1" Width="Auto" >
                  <Button Name="btnBrowse" Height="30" Content="..." DockPanel.Dock="Right" Width="30" ToolTip="You can specify a text file of DRACs to bulk configure" />
                  <TextBox Name="txtDRACAddress" Width="Auto" Height="30" TextWrapping="Wrap" Text="172.30.x.x" />
               </DockPanel>
                  <Label Content="DRAC Username" Width="170" Grid.Row="2" Grid.Column="0" />
                  <ComboBox Name="txtDRACUser" Height="30" Grid.Row="2" Grid.Column="1" IsEditable="True" SelectedIndex="0"> 
                     <ComboBoxItem>root</ComboBoxItem>
                     <ComboBoxItem>{USER}</ComboBoxItem>
                  </ComboBox>
                  <Label Content="DRAC Password" Width="170" Grid.Row="4" Grid.Column="0" />
                  <PasswordBox Name="txtDRACPass" Grid.Row="4" Grid.Column="1" /> 
                  <!--
                  <Label Content="Update Firmware?" Width="170" Height="Auto" Grid.Row="8" Grid.Column="0" />
                  <CheckBox Name="chkFirmware" IsChecked="False" Grid.Row="8" Grid.Column="1" IsEnabled="False" ToolTip="Not Implemented...yet...or ever, who knows?">
                     <TextBlock>Update Firmware?</TextBlock>
                  </CheckBox>
                  -->
                  <Label Content="Backup Settings?" Width="170" Height="Auto" Grid.Row="6" Grid.Column="0" />
                  <CheckBox Name="chkBackup" IsChecked="False" Grid.Row="6" Grid.Column="1" ToolTip="Create a backup of existing configuration">
                     <TextBlock>Create Backup</TextBlock>
                  </CheckBox>
               </Grid>
         </DockPanel>
      </DockPanel>
   </Window>
"@

#Read XAML
$reader=(New-Object System.Xml.XmlNodeReader $XAML_Main) 
Try{$Form=[Windows.Markup.XamlReader]::Load( $reader )}
Catch{Write-Error $l.XAMLError; exit}

# Read form controls into Powershell Objects for ease of modification
$XAML_Main.SelectNodes("//*[@Name]") | %{Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name)}

################################################################################
#                                POPULATE FORM                                 #
################################################################################
# Populate form inputs
$txtDRACUser.items[1].Content = ("{0}\{1}" -f ($Env:UserDNSDomain).ToLower(), $Env:Username)

# Configure a Browse Dialog
[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
$browseDialog = New-Object System.Windows.Forms.OpenFileDialog
$browseDialog.DefaultExt = '.txt'
$browseDialog.Filter = 'Text Files|*.txt|All Files|*.*'
$browseDialog.FilterIndex = 0
$browseDialog.InitialDirectory = $pwd
$browseDialog.Multiselect = $false
$browseDialog.RestoreDirectory = $true
$browseDialog.Title = "Select text file containing DRACs"
$browseDialog.ValidateNames = $true

################################################################################
#                                    EVENTS                                    #
################################################################################
# Add Browse button handler
$btnBrowse.Add_Click({$browseDialog.ShowDialog(); $txtDRACAddress.Text = $browseDialog.FileName})
# Add Config button handler
$btnConfig.Add_Click({Invoke-DRACConfig $txtDRACAddress.Text $txtDRACUser.SelectedItem.Content $txtDRACPass.Password $chkBackup.IsChecked})

################################################################################
#                                    DISPLAY                                   #
################################################################################
$Form.ShowDialog() | out-null
