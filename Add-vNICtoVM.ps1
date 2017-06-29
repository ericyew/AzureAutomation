<#
.SYNOPSIS
  Connects to Azure add a new vNic to an existing VM. 

.DESCRIPTION
  This runbook connects to Azure and performs the following tasks :
  	- Creates the vNic and assign a name
    - Stops the specified virtual machine
	- Add the new vNic to the VM
	- Starts the specified virtual machine
  
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
    
.PARAMETER vNetName
   Mandatory with no default.
   An existing Virtual Network to attach the vNIC to.

.PARAMETER vNetResourceGroupName
   Mandatory with no default.
   The name of the resource group which contains the virtual network (vNet).

.PARAMETER SubnetName
   Mandatory with no default.
   The name of the Subnet to attach the vNic to.

.PARAMETER IPAddress
   Mandatory with no default.
   A static IP in the subnet to be assigned to the vNic

.PARAMETER PowerOnVm
   Mandatory with no default.
   Yes input will power on VM after adding new vNic. If more than 1 vNic is to be added, keep this blank and run the runbook a second time for the 2nd vNic.
   
.NOTES
	Created By: Eric Yew
	LAST EDIT: June 29, 2017
	Last Edited By: Eric Yew
    Source: https://github.com/ericyew/AzureAutomation/blob/master/Add-vNICtoVM.ps1
#>

#Parameters input from runbook
    param (
        [Parameter(Mandatory=$false)] 
        [String] $AzureSubscriptionName = "SGG-Infrastructure-Prod-SCE",
       
        [parameter(Mandatory=$true)] 
        [String] $VMName,

        [parameter(Mandatory=$true)] 
        [String] $ResourceGroupName,

        [parameter(Mandatory=$true)] 
        [String] $vNetName,

        [parameter(Mandatory=$true)] 
        [String] $vNetResourceGroupName,

        [parameter(Mandatory=$true)] 
        [String] $SubnetName,

        [parameter(Mandatory=$true)] 
        [String] $IPAddress,

        [parameter(Mandatory=$false)] 
        [String] $PowerOnVm = 'yes'
    ) 

#Error Checking: Trim white space in string entered.
    $AzureSubscriptionName = $AzureSubscriptionName -replace '\s',''
    $ResourceGroupName = $ResourceGroupName -replace '\s',''
    $VMName = $VMName -replace '\s',''
    $vNetName = $vNetName -replace '\s',''
    $SubnetName = $SubnetName -replace '\s',''
    $IPAddress = $IPAddress -replace '\s',''
    $PowerOnVm = $PowerOnVM.ToLower() -replace '\s',''

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
 
#Add the new NIC
    $NewNIC = Get-AzureRmNetworkInterface -Name $NICName -ResourceGroupName $NICResourceGroup
    $VM = Add-AzureRmVMNetworkInterface -VM $VM -Id $NewNIC.Id
    
# Show the Network interfaces
    $VM.NetworkProfile.NetworkInterfaces

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

#Update the VM configuration
    Update-AzureRmVM -VM $VM -ResourceGroupName $ResourceGroupName

#Start VM
    If ($StartVM -eq 'yes')
        {
            Start-AzureRmVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName
        }
