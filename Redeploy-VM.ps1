<#
.SYNOPSIS
  Connects to Azure, delete and readd an existing virtual machine (ARM only). This is to potentially fix any issues with a VM. 
  
.DESCRIPTION
  This runbook connects to Azure and performs the following tasks :
  	- Stops the specified virtual machine
	- Store the virtual machine configuration
	- Remove the virtual machine from Azure
	- Recreate the virtual machine with existing name, vhd, nic and availability set.
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
    
.NOTES
	Created By: Eric Yew
	LAST EDIT: July 19, 2016
		By: Eric Yew
#>

param (
    [Parameter(Mandatory=$false)] 
    [String] $AzureSubscriptionName = "SGG-Infrastructure-Prod-SCE",

    [parameter(Mandatory=$true)] 
    [String] $VMName,

<#	[parameter(Mandatory=$true)] 
    [String] $CreateNewAvailabilitySet,
	
	[parameter(Mandatory=$true)] 
    [String] $AvailabilitySetName,
#>	
    [parameter(Mandatory=$true)] 
    [String] $ResourceGroupName	
) 

#Error Checking: Trim white space from both ends of string enter.
$VMName = $VMName -replace '\s',''
$AzureSubscriptionName = $AzureSubscriptionName -replace '\s',''
# $CreateNewAvailabilitySet = $CreateNewAvailabilitySet -replace '\s',''	
# $AvailabilitySetName = $AvailabilitySetName -replace '\s',''
$ResourceGroupName = $ResourceGroupName -replace '\s',''

# Getting automation assets
$AzureCred = Get-AutomationPSCredential -Name 'PSAdmin' -ErrorAction Stop

# Connecting to Azure
$null = Add-AzureRmAccount -Credential $AzureCred -SubscriptionName $AzureSubscriptionName -ErrorAction Stop

# Getting the virtual machine
$VM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction Stop
$VMConfig = $VM
$location = $vm.location

<#
If($CreateNewAvailabilitySet -eq 'Yes' -Or $CreateNewAvailabilitySet -eq 'Y'){
	$as = New-AzureRmAvailabilitySet `
	    -Name $AvailabilitySetName `
	    -ResourceGroupName $ResourceGroupName `
	    -Location $location     
}
ElseIf ($CreateNewAvailabilitySet -eq 'No' -Or $CreateNewAvailabilitySet -eq 'N'){
	$as = 
        Get-AzureRmAvailabilitySet `
            -ResourceGroupName $ResourceGroupName `
            -Name $AvailabilitySetName -ErrorAction Stop		
}
Else {
	Write-Output $CreateNewAvailabilitySet
	$ErrorActionPreference = "Stop"
	Write-Error –Message "Runbook stopped as CreateNewAvailabilitySet should be Yes or No"	
}
#>

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

<#
# Set VM config to include new Availability Set
    $asRef = New-Object Microsoft.Azure.Management.Compute.Models.SubResource
    $asRef.Id = $as.Id
    $vm.AvailabilitySetReference = $asRef # To remove VM from Availability Set, set to $null
#>
	
#Reconfigure and Clean-up VM config to reflect deployment from attached disks
    $vm.StorageProfile.OSDisk.Name = $vmName
    $vm.StorageProfile.OSDisk.CreateOption = "Attach"
    $vm.StorageProfile.DataDisks | 
        ForEach-Object { $_.CreateOption = "Attach" }
    $vm.StorageProfile.ImageReference = $null
    $vm.OSProfile = $null

#Remove the virtual machine from Azure
Remove-AzureRmVM -VMName $VMName -ResourceGroupName $ResourceGroupName -Force -ErrorAction Stop
"Removing the virtual machine ..."

#Recreate the virtual machine with the new name
New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $VM.Location -VM $VM -Verbose
"Recreating the virtual machine ..."

"The virtual machine has been recreated and started."
