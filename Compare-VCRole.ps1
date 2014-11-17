<# 
.SYNOPSIS 
   Generate a HTML report comparing two vCenter roles

.DESCRIPTION
   Generate a HTML report containing the differences between two vCenter roles.
   
   Items highlighted in green are present in that role, but not the other.

.NOTES 
   File Name  : Compare-VCRole.ps1 
   Author     : John Sneddon
   Version    : 1.0
   
.PARAMETER ComputerName
   Specify the vCenter server name
.PARAMETER Role1
   First Role
.PARAMETER Role2
   Second Role
#>
Param 
(
   [ValidateScript({Test-Connection $_ -Quiet -Count 1})] 
   [string]$ComputerName,
   [string]$Role1,
   [string]$Role2
)

$report = @"
<html>
    <head>
        <style type='text/css'>
            body { font-family: Calibri, Arial, sans-serif; font-size: 12px;}
            .reportsection { padding: 0 10px 20px 10px; }
            table { border-collapse: collapse; width: 100%;}
            th, td {font-size: 11px; margin: 0; padding 0}
            th { text-align: left; border-bottom: 2px solid black; }
            td { border-bottom: 1px solid silver; vertical-align: top; padding-left: 5px}
            p { margin-bottom: 10px }
            .add { color: green }
            .remove { color: red }
        </style>
    </head>
    <body>
    <table>
      <p>This report shows differences between two vCenter roles. Those highlighted in green are added to the role compared to the other role.</p>
      <tr><th>$($role1)</th><th>$($role2)</th></tr>
"@
# Import Snapin
if (!(Get-PSSnapin -name VMware.VimAutomation.Core -erroraction silentlycontinue)) {
	Add-PSSnapin VMware.VimAutomation.Core
}

# Connect to vCenter
Connect-VIServer -Server $ComputerName | Out-Null

# Get role privileges and differences
$role1 = Get-VIRole $role1
$role2 = Get-VIRole $role2
$diff = Compare-Object $role1.PrivilegeList $role2.PrivilegeList

$i = 0
$c = $role1.PrivilegeList.count+$role1.PrivilegeList.count
$report += "<tr><td><ul>"
foreach ($p in $role1.PrivilegeList)
{
   Write-Progress -Activity "Compiling differences" -Status "Role1" -PercentComplete ($i*100/$c)
   $pObj = (Get-VIPrivilege -Id $p)
   
   switch (($diff | Where {$_.inputobject -eq $p}).sideIndicator)
   {
      "<="    { $class = " class='add'" }
      "=>"    { $class = " class='delete'" }
      default { $class = "" }
   }
   $report += ("<li{0}>{1}\{2}</li>" -f $class, $pObj.ParentGroup, $pObj.Name)
   $i++
}
$report += "</ul></td><td><ul>"
foreach ($p in $role2.PrivilegeList)
{
   Write-Progress -Activity "Compiling differences" -Status "Role2" -PercentComplete ($i*100/$c)
   $pObj = (Get-VIPrivilege -Id $p)
   
   switch (($diff | Where {$_.inputobject -eq $p}).sideIndicator)
   {
      "=>"    { $class = " class='add'" }
      "<="    { $class = " class='delete'" }
      default { $class = "" }
   }
   $report += ("<li{0}>{1}\{2}</li>" -f $class, ($pObj.ParentGroup), ($pObj.Name))
}
Write-Progress -Activity "Compiling differences" -Status "Complete"  -Completed
$report += "</ul></td></tr></table></body></html>"

$report | out-file "$($env:temp)\r.html"
. "$($env:temp)\r.html"
