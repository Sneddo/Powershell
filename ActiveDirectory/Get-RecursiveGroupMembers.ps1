<# 
.SYNOPSIS 
   Get all members of AD group, and nested groups

.DESCRIPTION
   Get all members of AD group, and nested groups

.NOTES 
   File Name  : Get-RecursiveGroupMembers.ps1
   Author     : John Sneddon
   Version    : 1.0.0
   
.REQUIREMENTS
   WinSCP
#>

function Get-RecursiveGroupMembers ($grp)
{
	$grpMembers = Get-ADGroup $grp -properties members
	$tmpMembers =@()
	
	foreach ($member in $grpMembers.members)
	{
		$mem = Get-ADObject $member
		
		if ($mem.ObjectClass -eq "group")
		{
			$tmpMembers += Get-RecursiveGroupMembers $member
		}
		else
		{
			# user only
			$tmpMembers += $member
		}
	}
	
	$tmpMembers
}