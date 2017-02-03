<# 
.SYNOPSIS 
   Script sends a HTML formatted email to user containing a list of AD
   account created in the period specified.

.DESCRIPTION
   Sends an email to the specified email address with the parameters specified.
	Email contains a list of AD user accounts that were created in the specified
	period, containing the SamAccountName, account used to create the account, 
	and  when it was created.
	
	The "owner" permission is used to determine the creating account, however if
	the creator is a member of "Domain Admins" group, the name will not be 
	displayed. 
	
.NOTES 
    Author	: John Sneddon
	Twitter	: @JohnSneddonAU
	Web		: http://www.sneddo.net

.PARAMETER daysToReport
	Integer containing the number of days in reporting period. Defaults to 7.
	
.PARAMETER mailServer
	Outgoing Mail (SMTP) server address. If not supplied, script will prompt 
	for address.

.PARAMETER mailFrom
	Address to use as the from address. If not supplied, script will prompt 
	for address.
	
.PARAMETER mailTo
	Email address of recipient. If not supplied, script will prompt 
	for address.
	
.PARAMETER mailSubject
	Subject line for the email. Defaults to "AD accounts created in past x days"
	Where x is the value of daysToReport parameter

.EXAMPLE
	Send email to foo@bar.com using mail.bar.com as SMTP server, 
	from foobar@bar.com containing accounts created in the past 7 days.
	
	AuditNewAccounts.ps1 -mailTo foo@bar.com -mailServer mail.bar.com -mailFrom foobar@bar.com
	
.EXAMPLE
	Report on accounts created in past day
	AuditNewAccounts.ps1 -daysToReport 1 -mailTo foo@bar.com -mailServer mail.bar.com -mailFrom foobar@bar.com
#>
param (
		[int]$daysToReport=7,
		[string]$mailServer = (Read-Host "Enter mail server address"),
		[string]$mailFrom = (Read-Host "Send email from"),
		[string]$mailTo = (Read-Host "Send email to"),
		[string]$mailSubject = "AD accounts created in past $daysToReport days"
		)

# Import AD Module
Import-Module ActiveDirectory
		
# Get date object for today minus $daysToReport
$d = (Get-Date).AddDays(-$daysToReport)

# Get AD users created since then and return owner, 
$users = Get-ADUser -filter {whenCreated -gt $d} -properties whenCreated, nTSecurityDescriptor | 
			Select-Object SamAccountName, Name, @{"Name"="Creator"; "Expression"={$_.nTSecurityDescriptor.owner}}, whenCreated

# Create a basic HTML table
$mailContent = $users | ConvertTo-HTML -body "Users created since $d"

# send email
Send-MailMessage -From $mailFrom -To $mailTo -Subject $mailSubject -SmtpServer $mailServer -BodyAsHtml $mailContent