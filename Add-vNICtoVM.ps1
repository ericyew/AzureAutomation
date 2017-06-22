<#
.SYNOPSIS
  Connects to Azure and create a new virtual machine (ARM only) from an existing VHDs and add it to a resource group to a new or existing availability set
  or move to a new or existing availability set.

.DESCRIPTION
  This runbook connects to Azure and performs the following tasks :
  	- Stops the specified virtual machine
	- Store the virtual machine configuration
	- Remove the virtual machine from Azure
	- Recreate the virtual machine with existing name, existing vhd, existing nic and new/existing availability set.
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
	Created By: Eric Yew
	LAST EDIT: June 22, 2017
	Last Edited By: Eric Yew
#>

#Parameters input from runbook
    param (
        [Parameter(Mandatory=$false)] 
        [String] $AzureSubscriptionName = "SGG-Infrastructure-Prod-SCE",

        [parameter(Mandatory=$true)] 
        [String] $ResourceGroupName,	
        
        [parameter(Mandatory=$true)] 
        [String] $VMName,

        [parameter(Mandatory=$true)] 
        [String] $vNetName,

        [parameter(Mandatory=$true)] 
        [String] $vNetResourceGroupName,

        [parameter(Mandatory=$true)] 
        [String] $SubnetName,

        [parameter(Mandatory=$true)] 
        [String] $IPAddress,

        [parameter(Mandatory=$false)] 
        [String] $NumOfNewNIC = "1"
    ) 

#Error Checking: Trim white space in string entered.
    $AzureSubscriptionName = $AzureSubscriptionName -replace '\s',''
    $ResourceGroupName = $ResourceGroupName -replace '\s',''
    $VMName = $VMName -replace '\s',''
    $vNetName = $vNetName -replace '\s',''
    $SubnetName = $SubnetName -replace '\s',''
    $IPAddress = $IPAddress -replace '\s',''

# Getting automation assets
    $AzureCred = Get-AutomationPSCredential -Name 'PSAdmin' -ErrorAction Stop

# Connecting to Azure
    $null = Add-AzureRmAccount -Credential $AzureCred -SubscriptionName $AzureSubscriptionName -ErrorAction Stop

#Get virtual network and subnet id
    $VNET = Get-AzureRmVirtualNetwork -Name $vNetName -ResourceGroupName $vNetResourceGroupName
    $SubnetID = (Get-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $VNET).Id

#Get the VM
    $VM = Get-AzureRmVM -Name $VMname -ResourceGroupName $ResourceGroupName
    $location = $VM.Location

#Assign a NIC name
    $nicNameArray = $vm.NetworkInterfaceIDs[0] -split '/'
    $NICName = $nicNameArray[8]
    $NICName = $nicName.Substring(0,$nicName.Length-1)
    $NICName = $nicName + $VM.NetworkInterfaceIDs.Count
    $NICResourceGroup = $ResourceGroupName

    New-AzureRmNetworkInterface -Name $NICName -ResourceGroupName $NICResourceGroup -Location $Location -SubnetId $SubnetID -PrivateIpAddress $IPAddress
 
#Add the second NIC
#    $NewNIC = Get-AzureRmNetworkInterface -Name $NICName -ResourceGroupName $NICResourceGroup
#    $VM = Add-AzureRmVMNetworkInterface -VM $VM -Id $NewNIC.Id
    
    # Show the Network interfaces
#    $VM.NetworkProfile.NetworkInterfaces

#Shutdown VM
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

#Update the VM configuration (The VM will be restarted)
    Update-AzureRmVM -VM $VM -ResourceGroupName $ResourceGroupName








