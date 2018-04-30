<#
.SYNOPSIS
  Connects to Azure and add an existing virtual machine (ARM only) in a resource group to a new or existing availability set
  or move to a new or existing availability set. 

.DESCRIPTION
  This runbook connects to Azure and performs the following tasks :
  	- Stops the specified virtual machine
	- Store the virtual machine configuration
	- Remove the virtual machine from Azure
	- Recreate the virtual machine with existing name, existing vhd, existing nic and new/existing/remove availability set.
	- Starts the specified virtual machine
  
.PARAMETER AzureCredentialAssetName
   Optional with default of "AzureCredential".
   The name of an Automation credential asset that contains the Azure AD user credential with authorization for this subscription. 
   To use an asset with a different name you can pass the asset name as a runbook input parameter or change the default value for the input parameter.

.PARAMETER AzureSubscriptionName  
   Optional with default of "SGG-Infrastructure-Prod-SCE".  
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
	LAST EDIT: April 30, 2016
	By: Eric Yew
	SOURCE: https://github.com/ericyew/AzureAutomation/blob/master/ChangeAdd-AvailabilitySet.ps1
#>

param (
    [Parameter(Mandatory=$false)] 
    [String] $AzureSubscriptionName = "WCC Production EA",

    [parameter(Mandatory=$true)] 
    [String] $VMName,

	[parameter(Mandatory=$true)] 
    [String] $CreateNewAvailabilitySet = "Yes/No/Remove. Default to No",
	
	[parameter(Mandatory=$true)] 
    [String] $AvailabilitySetName,
	
    [parameter(Mandatory=$true)] 
    [String] $ResourceGroupName	
) 

# Enable Verbose logging for testing
#    $VerbosePreference = "Continue"

# Error Checking: Trim white space from both ends of string enter.
$VMName = $VMName -replace '\s',''
$AzureSubscriptionName = $AzureSubscriptionName -replace '\s',''	
$AvailabilitySetName = $AvailabilitySetName -replace '\s',''
$ResourceGroupName = $ResourceGroupName -replace '\s',''

# Determine Create/Remove/use existing availability set
    if($CreateNewAvailabilitySet -eq "Yes/No/Remove. Default to No")
    {
        $CreateNewAvailabilitySet = "No"
    }
    else
    {
        $CreateNewAvailabilitySet = $CreateNewAvailabilitySet -replace '\s',''
    }

# Connect to Azure
    $Conn = Get-AutomationConnection -Name AzureRunAsConnection
    $Cert = Get-AutomationCertificate -Name 'AzureRunAsCertificate'
    #Write-Verbose "$Conn $Cert"
    Connect-AzureRmAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Cert.Thumbprint

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

"The virtual machine has been added to availability group and started."
