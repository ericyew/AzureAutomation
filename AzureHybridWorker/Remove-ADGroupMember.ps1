<#
    .DESCRIPTION
        This is an Azure Hybrid Worker Runbook.
        This runbook will run the Connect-RemoteDomain.ps1 runbook to:
            This runbook will connect to a trusted domain with a credential for the domain. 
            It will look for a domain controller in AD Site1 first,
            if non found, it will look for one in AD Site2,
            if also non found, it will store the first DC found. 
        It will then remove a user/member from the group specified.

    .NOTES
        AUTHOR: Eric Yew
        LASTEDIT: Feb 3, 2017
        SOURCE: https://github.com/ericyew/AzureAutomation/tree/master/AzureHybridWorker
#>

param (
	[parameter(Mandatory=$false)] 
    [String] $Domain = "slatergordon.com.au",
	
	[parameter(Mandatory=$false)] 
    [String] $Site1 = "AzureASE",
	
	[parameter(Mandatory=$false)] 
    [String] $Site2 = "MelbDataCentre",

    [parameter(Mandatory=$false)] 
    [String] $DomainCredential = "SGAU serviceadmin",

    [parameter(Mandatory=$true)] 
    [String] $GroupName,

    [parameter(Mandatory=$true)] 
    [String] $MemberSamID   

) 

.\Connect-RemoteDomain.ps1 `
		-Domain $Domain `
		-Site1 $Site1 `
		-Site2 $Site2 `
		-DomainCredential $DomainCredential

Remove-ADGroupMember -Identity $GroupName -Members $MemberSamID -Confirm:$false
