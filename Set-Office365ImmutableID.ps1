<# 
	.SYNOPSIS
		Set a custom attribute to an AD Object utilising the Office 365 ImmutableID
	
	.DESCRIPTION
		This runbook is designed to run within a domain and set a custom attribute utilising the 
		Office 365 ImmutableID instead of the default ObjectGUID attribute.
	
	.PARAMETER
        Domain
            Domain Name of the AD Forest to connect to
        
        Site1
            First AD Site to search for a DC
        
        Site2
            Second AD Site to search for a DC

        DomainCredential
            Credential Asset in Azure Automation to connect to domain

        ADSearchBase
            AD Search Base in the format "OU=organisational unit,DC=mydomain,DC=local"

        VerboseOutput
            Output verbose logs during testing. Set to $true if required

	.REQUIREMENTS
		This runbook requires the following to be installed on the hybrid worker server
			- Windows Azure Active Directory Module - http://go.microsoft.com/fwlink/p/?linkid=236297
			- Windows Active Directory RSAT Feature (need Active Directory Module)
		This runbook requires the following permissions
			- Credential asset that acts as a Service Account in On-Premise Active Directory
				- Read/Write Permissions on accounts within scope of the runbook (or domain admins :) )
				- Password that does not expire
		Installation
		1. Enter required parameters for the domain
		2. Test this runbook in the test pane to confirm outputting desired outcome
            Set VerboseOutput to $true for verbose logging in output pane while testing
		3. If all works as desired create a scheduled task for this runbook to run with an on prem
           credentials asset

	.NOTES
		Author: Jean-Pierre Simonis
		Modified By: Eric Yew
		LASTEDIT: Feb 8, 2017
    Source: https://github.com/ericyew/AzureHybridWorkers/blob/master/Set-O365ImmutableID.ps1

	.CHANGE LOG
		16/06/2016 v1.0 - Initial Release
			Features
			- Create Unique O365 ImmutableID based on ObjectGUID attribute and store it in a custom attribute
			- Logging Engine to screen, file, event log with custom eventlog source name
			- Full Error trapping and handing
			- Customisable to OU, User Filter, Source and Target attributes
		6/02/2017 - Modified to work with Azure Hybrid Worker
            - Removed logging to file and event logs option
            - Embedded call to runbook Connect-RemoteDomain.ps1 to connect to a trusted domain
                -https://github.com/ericyew/AzureHybridWorkers/blob/master/Connect-RemoteDomain.ps1
            - Updated logging to output to job history
                -Only warning and Errors are always logged,
                    verbose logging needs to be enabled for runbook for informational logging
                -Verbose logging to output to test pane by setting parameter to $true
#>

# Connect to Remote Domain
    param (
        [parameter(Mandatory=$false)] 
        [String] $Domain = "slatergordon.com.au",
        
        [parameter(Mandatory=$false)] 
        [String] $Site1 = "AzureASE",
        
        [parameter(Mandatory=$false)] 
        [String] $Site2 = "MelbDataCentre",

        [parameter(Mandatory=$false)] 
        [String] $DomainCredential = "SGAU serviceadmin",

        [parameter(Mandatory=$false)] 
    	[String] $ADSearchBase = "OU=SlaterGordon,DC=slatergordon,DC=com,DC=au",

        [parameter(Mandatory=$false)] 
    	[String] $VerboseOutput = $false
    )

# Connect to trusted remote domain    
    If($Domain -ne "slatergordon.group"){
        .\Connect-RemoteDomain.ps1 `
                -Domain $Domain `
                -Site1 $Site1 `
                -Site2 $Site2 `
                -DomainCredential $DomainCredential
    }

# Enable Verbose logging for testing
    If($VerboseOutput){
        $VerbosePreference = "Continue"}

# On-Premise Active Directory Provisioning Configuration
    	#Base DN to start user search from
    		$global:ADDSSearchBase = $ADSearchBase
	    #Search Scope 0 = Base, 1 = One Level, 2 = SubTree
    		$global:ADDSSearchScope = "2"
	    #Search ResultSet Size some number eg 100 or All = All Results
    		$global:ADDSResultSetSize = "All"
	    #User Filter
		    $global:ADDSUserFilter = "*"
	    #Attribute to Store Office 365 ImmutableID
		    $global:ADDSUserO365ImmutableTargetAttribute = "msDS-cloudExtensionAttribute1"

#########################
#       Functions       #
#########################

#Function to Import Modules with error handling
Function Import-MyModule 
{ 
Param([string]$name) 
    if(-not(Get-Module -name $name)) 
    { 
        if(Get-Module -ListAvailable $name) 
        { 
            Import-Module -Name $name 
            #Write-Verbose "Imported module $name"
        } 
        else 
        { 
            Write-Error "Module $name is not installed. Exiting..."
            Throw "Module $name is not installed. Exiting..." 
        }
    } 
    else 
    { 
        Write-Warning "Module $name is already loaded..."
    } 
}  

Function Collect-O365Users
{
param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Alias('ADSFilter')]
    [string]
    $DSFilter,
    [Parameter(
        Position=1, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Alias('TargetProperty')]
    [string]
    $DSTargetProperty,
    [Parameter(
        Position=2, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Alias('SearchBase')]
    [string]
	$DSSrchBase,
	[Parameter(
        Position=3, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Alias('SearchScope')]
    [string]
	$DSSrchScope,
	[Parameter(
        Position=4, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Alias('ResultSetSize')]
    [string]
	$DSResultSize
)
   try 
    {	 
		#Write to job history
		Write-Verbose "Collecting Office 365 User List"
		#Determine Result Size
		if ($DSResultSize -eq "All") {
			#Clear ResultSetSize Variable
			$DSResultSize = $null
			#Collect AD Users All Results
			$CollectUsers = Get-ADUser -filter $DSFilter -Properties $DSTargetProperty -SearchBase $DSSrchBase -SearchScope $DSSrchScope | Select-Object Name,UserPrincipalName,SamAccountName,$DSTargetProperty   
			#Write to job history
            Write-Verbose "Collecting Users from $DSSrchBase filtered by $DSFilter"
			Write-Verbose "Collecting Office 365 User List complete"
			#Return Values on completion
			Return $CollectUsers
			
			} else {
			#Do Nothing and use configured result size
			#Collect AD Users All Results
			$CollectUsers = Get-ADUser -filter $DSFilter -Properties $DSTargetProperty -SearchBase $DSSrchBase -SearchScope $DSSrchScope -ResultSetSize $DSResultSize | Select-Object Name,UserPrincipalName,SamAccountName,$DSTargetProperty   
			#Write to job history
			Write-Verbose "Collecting Users from $DSSrchBase filtered by $DSFilter"
			Write-Verbose "Collecting Office 365 User List complete"
			#Return Values on completion
			Return $CollectUsers
		}
    } 
    catch [system.exception]
    {
		$err = $_.Exception.Message
		Write-Error "Could not Collect Users from $DSSrchBase filtered by $DSFilter, `r`nError: $err"
    }
}

Function Determine-UsersToUpdate
{
param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Alias('UserList')]
    [Array]
    $DSUserList,
    [Parameter(
        Position=1, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Alias('TargetProperty')]
    [string]
    $DSTargetProperty    
)
   try 
    {	 
		#Write to Job Output
		    Write-Verbose "Determining users requiring updates"
		#Create User to Update Array Variable
		    $UsersToUpdate = @()
		#Begin checking supplied users to determine if TargetProperty has already been set
		    ForEach ($user in $DSUserList)
		    {
		        #Routine to check if TargetProperty is not set for the user 
		        $checkCloudAttrib = $user.$DSTargetProperty
                #Friendly user name variable
		        $DSuser = $user.'Name'
		        #Write-Verbose "Checking $DSuser if $DSTargetProperty is set"
		        if ($checkCloudAttrib -eq $null) {
			        Write-Verbose " - The user $DSuser does not have $DSTargetProperty set."
			        #Add User to the UsersToUpdate Array Variable
			        $UsersToUpdate = $UsersToUpdate + $user
			    }
		        else {
			    #Write-Verbose " - The user $DSuser already has $DSTargetProperty set."
				    #Routine to determine is possibly set with an value other than expected
				    if ($checkCloudAttrib.length -ne 24) {
					    Write-Verbose "   - The user $DSuser may have an unexpected value in $DSTargetProperty set."
			 	    }		    
			    }
		    }
		
		#Write to Log
		Write-Verbose "Determining users requiring updates complete"
	
		#Return Values on completion
		Return $UsersToUpdate

    } 
    catch [system.exception]
    {
		$err = $_.Exception.Message
		Write-Error "Could not determine the users required to be updated, `r`nError: $err"
    }
}

Function Apply-O365ImmutableID
{
param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Alias('UserList')]
    [Array]
    $DSUserList,
    [Parameter(
        Position=1, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Alias('TargetProperty')]
    [string]
    $DSTargetProperty    
)
   try 
    {	 
		#Write to Job History
		Write-Verbose "Applying O365 Immutable ID to required users..."

		#Routine to apply O365 ImmutableID attribute
		ForEach ($user in $DSUserList)
		{
		#Friendly user name variable
		$DSuser = $user.'Name'
		#AD User account name variable
		$aduser = $user.'SamAccountName'
		Write-Verbose "Setting $DSuser $DSTargetProperty to the same value as ObjectGUID"

		#convert the objectguid to string and set this value into the TargetProperty attribute as the immutable id
		$objectguidstring = Get-ADUser -Identity $aduser -Properties ObjectGUID | select ObjectGUID | foreach {[system.convert]::ToBase64String(([GUID]($_.ObjectGUID)).tobytearray())}
		Write-Verbose "Clearing $DSuser $DSTargetProperty"
		Set-ADUser -Identity $aduser -Clear $DSTargetProperty
		Write-Verbose "Setting $DSuser $DSTargetProperty to the same value as ObjectGUID"
		Set-ADUser -Identity $aduser -Replace @{$DSTargetProperty=$objectguidstring}
		}
		
		#Write to Job History
		Write-Verbose "Applying O365 Immutable ID to required users complete"
    } 
    catch [system.exception]
    {
		$err = $_.Exception.Message
		Write-Error "Could not apply O365 Immutable ID to required users, `r`nError: $err"
    }
}

#########################
#        Modules        #
#########################

Write-Verbose "Loading Required PowerShell Modules"

#Active Directory
Import-MyModule ActiveDirectory

#########################
#       Execution       #
#########################

##Collect Office 365 User List
$UserList = Collect-O365Users $global:ADDSUserFilter $global:ADDSUserO365ImmutableTargetAttribute $global:ADDSSearchBase $global:ADDSSearchScope $global:ADDSResultSetSize

##Determine users that require O365 ImmutableID
#Check if userlist is not empty otherwise exit script
If ($UserList -ne $null){ 
	$UsersToUpdate = Determine-UsersToUpdate $UserList $global:ADDSUserO365ImmutableTargetAttribute
} else {
	Write-Warning "No O365 Users were found. Exiting.."
	Write-Verbose "Office 365 ImmutableID Assignment Script Completed - $TimeDate"
	#Quit Script
	Exit
}

##Apply New Office 365 ImmutableID to required users
#Check if Users requiring update list is not empty otherwise exit script
If ($UsersToUpdate -ne $null){ 
	$UpdateUsers = Apply-O365ImmutableID $UsersToUpdate $global:ADDSUserO365ImmutableTargetAttribute
} else {
	Write-Verbose "No O365 Users required updating"
	Write-Verbose "Office 365 Immutable ID Assignment Script Completed"
	#Quit Script
	Exit
}

## End of Script
    Write-Verbose "Office 365 Immutable ID Assignment Script Completed"
