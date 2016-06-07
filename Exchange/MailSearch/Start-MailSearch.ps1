<#
.SYNOPSIS
   This script aims to make Exchange searches slightly less painful
.DESCRIPTION
   Pretty GUI wrapper arounf mailbox search.
.NOTES
   File Name  : Start-MailSearch
   Author     : John Sneddon - john.sneddon@monashhealth.org
   Version    : 1.5.1

  CHANGELOG
  1.0   - Initial script. Taken from Dave's script, and wrapped a nice UI around it
  1.1   - Add a checkbox to actually do the deletecontent
  1.2   - Added Search Criteria
  1.3   - Add Option to run with delete if only searching. Hide the PS window.
  1.4.0 - Add Sender search Criteria
  1.5.0 - Add Date
  1.5.1 - Add Date range options, slight refactor of code

.INPUTS
   No inputs required
.OUTPUTS
   No outputs
#>
Function Write-Status ($Message, $Status)
{
   switch ($Status)
   {
      "OK"    {   Write-Host ("`r {0}{1}[" -f $Message, "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-($Message.Length+8))) -NoNewline
                  Write-Host -ForegroundColor Green " OK " -NoNewLine
                  Write-Host "]"
              }
      "FAIL"  {   Write-Host ("`r {0}{1}[" -f $Message, "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-($Message.Length+8))) -NoNewline
                  Write-Host -ForegroundColor Red "FAIL" -NoNewLine
                  Write-Host "]"
              }
      "N/A"  {   Write-Host ("`r {0}{1}[ N/A]" -f $Message, "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-($Message.Length+8)))
              }
      default {   Write-Host (" {0}{1}[    ]" -f $Message, "".PadRight((Get-Host).ui.RawUI.WindowSize.Width-($Message.Length+8))) -NoNewline }
   }
}

function Show-PSWindow
{
   $Form.Hide()
   [UIWin32.Methods]::ShowWindow($Handle, 5) | Out-Null
}

function Show-SearchDialog
{
   #[UIWin32.Methods]::ShowWindow($Handle, 0) | out-null
   $Form.ShowDialog() | out-null
}

function Invoke-MailboxSearch
{
   Param (
      [string[]]$SearchIdentityList,
      [string]$SearchQuerySubject,
      [string]$SearchBody,
      [string]$SearchSender,
      [string]$SearchAttach,
      [string]$TargetMailbox,
      [string]$TargetMailboxFolder,
      $DateFrom,
      $DateTo,
      [Bool]$DeleteContent
   )
   Show-PSWindow
   Write-Host "Starting Search..."

   $SearchIdentityList = $SearchIdentityList -split "`r`n"

   # Search Query - Build from supplied text
   $SearchQueryString  = ""
   if ($SearchQuerySubject)
   {
      $SearchQueryString += ('AND Subject:"{0}" ' -f $SearchQuerySubject)
   }
   if ($SearchBody)
   {
      $SearchQueryString += ('AND Body:"{0}" ' -f $SearchBody)
   }
   if ($SearchSender)
   {
      $SearchQueryString += ('AND From:"{0}" ' -f $SearchSender)
   }
   if ($SearchAttach)
   {
      $SearchQueryString += ('AND attachment={0} ' -f $SearchAttach)
   }

   # Do some basic validation on dates
   if ($DateFrom -gt $DateTo)
   {
      $DateFrom = (Get-Date ($DateTo)).AddDays(-1)
   }
   if ($DateTo -lt $DateFrom)
   {
      $DateTo = (Get-Date ($DateFrom)).AddDays(1)
   }

   if ($DateFrom -eq $DateTo)
   {
      $SearchQueryString += ('AND Received:{0}' -f ($DateFrom.ToString("yyyy-MM-dd")))
   }
   else
   {
      $SearchQueryString += ('AND Received:{0}..{1} ' -f ($DateFrom.ToString("yyyy-MM-dd"), $DateTo.ToString("yyyy-MM-dd")))
   }

   # Trim off the extra "AND"
   $SearchQueryString = $SearchQueryString.Trim("AND ")

   Write-Verbose "Searching: $SearchQueryString"

   Write-Host "Resolving unique mailboxes..."
   $SearchMailbox = @()
   $SearchIdentityList | Sort-Object -Unique | %{$SearchMailbox += Get-Mailbox $_ -ErrorAction SilentlyContinue }

   # Cycle through the identities to search.  Check deletion is on/off and -force is on/off depending on whether you want to be
   # prompted for deletion.  Deletion is -DeleteContent
   $i = 0;
   $totalRemoved = 0
   if ($SearchMailbox.count -gt 0)
   {
      foreach ($SearchIdentity in $SearchMailbox)
      {
         try
         {
            $PercentComplete = ($i*100/$SearchIdentityList.Count)
            Write-Progress -Activity "Searching Mailboxes" -Status ("{0}% - {1}" -f $PercentComplete, $SearchIdentity) -PercentComplete $PercentComplete
            if ($DeleteContent)
            {
               $result = Search-Mailbox -identity $SearchIdentity -SearchQuery $SearchQueryString -targetmailbox $TargetMailbox -targetfolder $TargetMailboxFolder -loglevel Full -deletecontent -force -WarningAction SilentlyContinue
            }
            else
            {
               $result = Search-Mailbox -identity $SearchIdentity -SearchQuery $SearchQueryString -targetmailbox $TargetMailbox -targetfolder $TargetMailboxFolder -loglevel Full -LogOnly -force -WarningAction SilentlyContinue
            }
            Write-Host ("{0}: {1} items found" -f $SearchIdentity.Name, $result.ResultItemsCount)
            $totalRemoved += $result.ResultItemsCount
         }
         catch
         {
            # Do nothing, just suppress the error
            Write-Error "Search Failed with query: $SearchQueryString"
         }
         $i++
      }
   }
   Write-Progress -Activity "Searching Mailboxes" -Status "Done" -Completed

   Write-Host "-------------------------------------"
   Write-Host ("{0} Email addresses in source list" -f $SearchIdentityList.count)
   Write-Host ("{0} Unique addresses" -f ($SearchIdentityList | Sort-Object -Unique).count)
   Write-Host ("{0} valid Mailboxes" -f $SearchMailbox.count)
   Write-Host ("{0} items found" -f $totalRemoved)
   Write-Host ""
   if (-not $DeleteContent)
   {
      Write-Host -ForegroundColor Yellow "********* Search only - Emails not deleted *********"

      $Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Yes"
      $No = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "No"
      $Update = New-Object System.Management.Automation.Host.ChoiceDescription "&Update", "Update Search"
      $options = [System.Management.Automation.Host.ChoiceDescription[]]($Yes, $No, $Update)
      $result = $host.ui.PromptForChoice("Do you want to run the search again and delete content?", "Delete?", $options, 0)
      switch ($result)
      {
         0 {   # Run it again with delete
               Invoke-MailboxSearch $txtSearchMB.Text `
                                    $txtSearchString.Text `
                                    $txtSearchBody.Text `
                                    $txtSearchSender.Text `
                                    $txtSearchAttach.Text `
                                    $txtTgtMB.Text `
                                    $txtTgtFolder.Text `
                                    $dpDateFrom.SelectedDate `
                                    $dpDateTo.SelectedDate `
                                    $true
           }
         1 {   <# Do nothing  #> }
         2 {   Show-SearchDialog }
      }
   }
   else
   {
      $Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Yes"
      $No = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "No"
      $options = [System.Management.Automation.Host.ChoiceDescription[]]($No, $Yes)
      $result = $host.ui.PromptForChoice("Do you want to run another search?", "Run another?", $options, 0)
      switch ($result)
      {
         0 { Exit }
         1 { Show-SearchDialog }
      }
   }
}

################################################################################
#                                INITIALISATION                                #
################################################################################
Clear-Host
Write-Status "Loading Requirements..."

# Add WPF Type
Add-Type -AssemblyName PresentationFramework

# Add the Exchange Snapin if not already loaded, so you don't have to open the exchange shell
if (!(Get-PSSnapin -name Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue) -and
    (Get-PSSnapin -Name Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue -Registered).Count -gt 0)
{
    Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn
}
Write-Status "Loading Requirements..." "OK"

# Get the window handle to enable show/hide
Add-Type -Name "Methods" -Namespace "UIWin32" -PassThru -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);' | Out-Null
$Handle = (Get-Process -id $Pid).MainWindowHandle


################################################################################
#                                     GUI                                      #
################################################################################
# Use XAML to define the form, data to be populated in code
[xml]$XAML_Main = @"
   <Window
      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      Height="500" Width="500" Title="Exchange Search">
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
         <DockPanel DockPanel.Dock="Bottom" Height="30">
            <Button Name="btnSearch" Height="30" Content="Start Search" VerticalAlignment="Top" />
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
                     <RowDefinition Height="5" />
                     <RowDefinition Height="30" />
                     <RowDefinition Height="5" />
                     <RowDefinition Height="30" />
                     <RowDefinition Height="5" />
                     <RowDefinition />
                     <RowDefinition Height="5" />
                     <RowDefinition Height="30" />
                  </Grid.RowDefinitions>
                  <Label Content="Target Mailbox" Width="170" Grid.Row="0" Grid.Column="0" />
                  <TextBox Name="txtTgtMB" HorizontalAlignment="Stretch" Height="30" Grid.Row="0" Grid.Column="1"  TextWrapping="Wrap" Text="" />

                  <Label Content="Target Folder" Width="170" Grid.Row="2" Grid.Column="0" />
                  <TextBox Name="txtTgtFolder" HorizontalAlignment="Stretch" Height="30" Grid.Row="2" Grid.Column="1" TextWrapping="Wrap" Text="" />

                  <Label Content="Search Subject" Width="170" Grid.Row="4" Grid.Column="0" />
                  <TextBox Name="txtSearchString" HorizontalAlignment="Stretch" Height="30" Grid.Row="4" Grid.Column="1" TextWrapping="Wrap" Text="" />

                  <Label Content="Search Body" Width="170" Grid.Row="6" Grid.Column="0" />
                  <TextBox Name="txtSearchBody" HorizontalAlignment="Stretch" Height="30" Grid.Row="6" Grid.Column="1" TextWrapping="Wrap" Text="" />

                  <Label Content="Search Sender" Width="170" Grid.Row="8" Grid.Column="0" />
                  <TextBox Name="txtSearchSender" HorizontalAlignment="Stretch" Height="30" Grid.Row="8" Grid.Column="1" TextWrapping="Wrap" Text="" />

                  <Label Content="Search Attachments" Width="170" Grid.Row="10" Grid.Column="0" />
                  <TextBox Name="txtSearchAttach" HorizontalAlignment="Stretch" Height="30" Grid.Row="10" Grid.Column="1" TextWrapping="Wrap" Text="*.zip" />

                  <Label Content="Search Dates" Width="170" Grid.Row="12" Grid.Column="0" />
                  <StackPanel Grid.Row="12" Grid.Column="1" Orientation="Horizontal" >
                     <DatePicker Name="dpDateFrom" SelectedDateFormat="Short" FirstDayOfWeek="Monday" />
                     <TextBlock Margin="10,0,10,0">to</TextBlock>
                     <DatePicker Name="dpDateTo" SelectedDateFormat="Short" FirstDayOfWeek="Monday" />
                  </StackPanel>

                  <Label Content="Email addresses" Width="170" Height="Auto" Grid.Row="14" Grid.Column="0" />
                  <TextBox Name="txtSearchMB" Grid.Row="14" Grid.Column="1" TextWrapping="Wrap" Text="" AcceptsReturn="True" HorizontalAlignment="Stretch" VerticalScrollBarVisibility="Visible" />

                  <Label Content="Delete?" Width="170" Height="Auto" Grid.Row="16" Grid.Column="0" />
                  <CheckBox Name="chkDelete" IsChecked="False" Grid.Row="16" Grid.Column="1">
                     <TextBlock>
                             <Run Foreground="Red" FontWeight="Bold">Delete Email from Mailboxes</Run>
                     </TextBlock>
                   </CheckBox>
               </Grid>
         </DockPanel>
      </DockPanel>
   </Window>
"@

#Read XAML
$reader=(New-Object System.Xml.XmlNodeReader $XAML_Main)
Try{$Form=[Windows.Markup.XamlReader]::Load( $reader )}
Catch{Write-Error $l.XAMLError; Read-host; exit}

# Read form controls into Powershell Objects for ease of modifcation
$XAML_Main.SelectNodes("//*[@Name]") |
   foreach {Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name)}

################################################################################
#                                POPULATE FORM                                 #
################################################################################
$Form.Title += " - version " + (((Get-Content $MyInvocation.MyCommand.Path |  select-string "Version    : ([0-9.]+)") -split ":")[1])

$txtTgtMB.Text = $env:Username -replace "_a", ""
$txtTgtFolder.Text = ("Search Results - {0}" -f (get-date -Format "yyyyMMdd"))

$dpDateFrom.SelectedDate = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd" )
$dpDateTo.SelectedDate = Get-Date -Format "yyyy-MM-dd"

################################################################################
#                                    EVENTS                                    #
################################################################################
# Add Search button handler
$btnSearch.Add_Click({Invoke-MailboxSearch $txtSearchMB.Text `
                                           $txtSearchString.Text `
                                           $txtSearchBody.Text `
                                           $txtSearchSender.Text `
                                           $txtSearchAttach.Text `
                                           $txtTgtMB.Text `
                                           $txtTgtFolder.Text `
                                           $dpDateFrom.SelectedDate `
                                           $dpDateTo.SelectedDate `
                                           $chkDelete.IsChecked })

################################################################################
#                                    DISPLAY                                   #
################################################################################
Show-SearchDialog
