<#
.SYNOPSIS
  Connects to Azure and add an existing virtual machine (ARM only) in a resource group to a new or existing availability set
  or move to a new or existing availability set. 

.DESCRIPTION
  This runbook connects to Azure and performs the following tasks :
  	- Stops the specified virtual machine
	- Store the virtual machine configuration
	- Remove the virtual machine from Azure
	- Recreate the virtual machine with existing name, existing vhd, existing nic and new/existing availability set.
	- Starts the specified virtual machine
  
.PARAMETER AzureSubscriptionName  
   Optional with default of "WCC Production EA".  
   The name of An Automation variable asset that contains the GUID for this Azure subscription.  
   To use an asset with a different name you can pass the asset name as a runbook input parameter or change the default value for the input parameter.  

.PARAMETER VMName
   Mandatory with no default.
   The name of the virtual machine which you want to add a new data disk.
   It must be the name of an ARM virtual machine.

.PARAMETER ResourceGroupName
   Mandatory with no default.
   The name of the resource group which contains the targeted virtual machine. 
    
.PARAMETER CreateNewAvailabilitySet
   Mandatory with no default.
   Yes or No input. 
   New or existing availability set.

.PARAMETER AvailabilitySetName
   Mandatory with no default.
   The name for the Availability Set to create, move or add to.
   It must be a unique name for a new availability set or existing name.
   
.NOTES
	Created By: Eric Yew - OLIKKA
	LAST EDIT: May 1, 2018
	By: Eric Yew
	SOURCE: https://github.com/ericyew/AzureAutomation/blob/master/Set-AvailabilitySet.ps1
#>

param (
    [Parameter(Mandatory=$false)] 
    [String] $AzureSubscriptionName = "1-Prod, 2-Dev/Test, 3-Website *Defaults to Prod*",

    [parameter(Mandatory=$true)] 
    [String] $VMName,

	[parameter(Mandatory=$true)] 
    [String] $CreateNewAvailabilitySet = "Yes / No / Remove *Default to No*",
	
	[parameter(Mandatory=$true)] 
    [String] $AvailabilitySetName,
	
    [parameter(Mandatory=$true)] 
    [String] $ResourceGroupName	
) 

# Enable Verbose logging for testing
#    $VerbosePreference = "Continue"

# Error Checking: Trim white space from both ends of string enter.
$VMName = $VMName -replace '\s',''
$AzureSubscriptionName = $AzureSubscriptionName.trim()	
$AvailabilitySetName = $AvailabilitySetName -replace '\s',''
$ResourceGroupName = $ResourceGroupName -replace '\s',''
$CreateNewAvailabilitySet = $CreateNewAvailabilitySet.trim()

# Determine to Create/Remove/Use existing availability set
    if($CreateNewAvailabilitySet -eq "Yes / No / Remove *Default to No*")
    {
        $CreateNewAvailabilitySet = "No"
    }

# Retrieve subscription name from variable asset if not specified
    if($AzureSubscriptionName -eq "1" -Or $AzureSubscriptionName -eq "1-Prod, 2-Dev/Test, 3-Website *Defaults to Prod*")
    {
        $AzureSubscriptionName = Get-AutomationVariable -Name 'Prod Subscription Name'
        if($AzureSubscriptionName.length -gt 0)
        {
            Write-Output "Specified subscription name/ID: [$AzureSubscriptionName]"
        }
        else
        {
            throw "No variable asset with name 'Prod Subscription Name' was found. Either specify an Azure subscription name or define the 'Prod Subscription Name' variable setting"
        }
    }
    elseIf($AzureSubscriptionName -eq "2")
    {
        $AzureSubscriptionName = Get-AutomationVariable -Name 'DevTest Subscription Name'
        if($AzureSubscriptionName.length -gt 0)
        {
            Write-Output "Specified subscription name/ID: [$AzureSubscriptionName]"
        }
        else
        {
            throw "No variable asset with name 'DevTest Subscription Name' was found. Either specify an Azure subscription name or define the 'DevTest Subscription Name' variable setting"
        }
    }
    elseIf($AzureSubscriptionName -eq "3")
    {
        $AzureSubscriptionName = Get-AutomationVariable -Name 'Website Subscription Name'
        if($AzureSubscriptionName.length -gt 0)
        {
            Write-Output "Specified subscription name/ID: [$AzureSubscriptionName]"
        }
        else
        {
            throw "No variable asset with name 'Website Subscription Name' was found. Either specify an Azure subscription name or define the 'Website Subscription Name' variable setting"
        }
    }
    else
    {
        if($AzureSubscriptionName.length -gt 0)
        {
            Write-Output "Specified subscription name/ID: [$AzureSubscriptionName]"
        }
        else
        {
            throw "No variable asset or subscription with name $AzureSubscriptionName was found. Either specify an Azure subscription name or specify 1,2 or 3 options"
        }
    }

#Connect to Azure
    try
    {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection=Get-AutomationConnection -Name AzureRunAsConnection         

        "Logging in to Azure..."
        Connect-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    }
    catch {
        if (!$servicePrincipalConnection)
        {
            $ErrorMessage = "Connection AzureRunAsConnection not found."
            throw $ErrorMessage
        } else{
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
    Select-AzureRmSubscription -SubscriptionName $AzureSubscriptionName

# Getting the virtual machine
    $VM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction Stop
    $VMConfig = $VM
    $location = $vm.location

# Create, add or remove availability set from VM Config
If($CreateNewAvailabilitySet -eq 'Yes' -Or $CreateNewAvailabilitySet -eq 'Y'){
	# Check if unmanaged disk
    If ($VM.StorageProfile.OsDisk.ManagedDisk -eq $null)
    {
        $as = New-AzureRmAvailabilitySet `
            -Name $AvailabilitySetName `
            -ResourceGroupName $ResourceGroupName `
            -Location $location
    }
    Else 
    {
        $as = New-AzureRmAvailabilitySet `
            -Name $AvailabilitySetName `
            -ResourceGroupName $ResourceGroupName `
            -Location $location
            -PlatformFaultDomainCount 2 `
            -PlatformUpdateDomainCount 5 `
            -Sku 'Aligned'  
    } 
}
ElseIf ($CreateNewAvailabilitySet -eq 'No' -Or $CreateNewAvailabilitySet -eq 'N'){
	$as = 
        Get-AzureRmAvailabilitySet `
            -ResourceGroupName $ResourceGroupName `
            -Name $AvailabilitySetName -ErrorAction Stop		
}
ElseIf ($CreateNewAvailabilitySet -eq 'Remove' -Or $CreateNewAvailabilitySet -eq 'R'){
	$as = $null	
}
Else {
	Write-Output $CreateNewAvailabilitySet
	$ErrorActionPreference = "Stop"
	Write-Error –Message "Runbook stopped as CreateNewAvailabilitySet should be Yes or No"	
}

"Shutting down the virtual machine ..."
$RmPState = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status -ErrorAction SilentlyContinue -WarningAction SilentlyContinue).Statuses.Code[1]

if ($RmPState -eq 'PowerState/deallocated')
{
    "$VMName is already shut down."
}
else
{
    $StopSts = $VM | Stop-AzureRmVM -Force -ErrorAction Stop
    "The virtual machine has been stopped."
}

# Set VM config to include new Availability Set
    $asRef = New-Object Microsoft.Azure.Management.Compute.Models.SubResource
    If ($as -eq $null)
    {
        $vm.AvailabilitySetReference = $null
    }
    else
    {
        $asRef.Id = $as.Id
        $vm.AvailabilitySetReference = $asRef # To remove VM from Availability Set, set to $null
    } 
	
#Reconfigure and Clean-up VM config to reflect deployment from attached disks
    $vm.StorageProfile.OSDisk.CreateOption = "Attach"
    $vm.StorageProfile.DataDisks | 
        ForEach-Object { $_.CreateOption = "Attach" }
    $vm.StorageProfile.ImageReference = $null
    $vm.OSProfile = $null

#Remove the virtual machine from Azure
    Remove-AzureRmVM -VMName $VMName -ResourceGroupName $ResourceGroupName -Force -ErrorAction Stop

#Recreate the virtual machine with the new name
    New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $VM.Location -VM $VM -Verbose

"The virtual machine $VMName availability set has been changed and started."
