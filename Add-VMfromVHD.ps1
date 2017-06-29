<#
    .SYNOPSIS
        Connects to Azure and create a new VM from an existing VHD.

    .DESCRIPTION
        This runbook connects to Azure and performs the following tasks :
        - Creates a VM Config
        - Copies vNic config from another VM's vNic
        - Creates the VM
    
    .PARAMETER AzureSubscriptionName  
        Optional with default of "SGG-Infrastructure-Prod-SCE".  
        The name of An Automation variable asset that contains the GUID for this Azure subscription.  
        To use an asset with a different name you can pass the asset name as a runbook input parameter or change the default value for the input parameter.  
    
    .PARAMETER VMName
        Mandatory with no default.
        The name of the new virtual machine to be created
        It must be the name of an ARM virtual machine.
    
    .PARAMETER ResourceGroupName
        Mandatory with no default.
        The name of the resource group which the new virtual machine will reside in.
        
    .PARAMETER VhdUri
        Mandatory with no default.
        The vhd uri for the OS disk.
    
    .PARAMETER VMNetIntfName
        Mandatory with no default.
        The name of the network interface.
    
    .PARAMETER VMNameNetIntfCopyFrom
        Mandatory with no default.
        The name of network interface to copy config from (vNic).
    
    .PARAMETER VMSize
        Mandatory with no default.
        The size of the VM.
    
    .PARAMETER CreateNewAvailabilitySet
        Mandatory with no default.
        Yes or No input. Yes will create a new availability set. No will use an existing one.

    .PARAMETER AvailabilitySetName
        Mandatory with no default.
        A name for the availability set.

    .PARAMETER location
        Mandatory with no default.
        The location to create the VM.        

    .NOTES
        AUTHOR: Eric Yew
        LASTEDIT: Mar 14, 2016
        SOURCE: https://github.com/ericyew/AzureAutomation/blob/master/Add-VMfromVHD.ps1
#>

param (
    [Parameter(Mandatory=$false)] 
    [String] $AzureSubscriptionName = "SGG-Infrastructure-Prod-SCE",

    [parameter(Mandatory=$true)] 
    [String] $VMName,

	[parameter(Mandatory=$true)] 
    [String] $ResourceGroupName,	
	
	[parameter(Mandatory=$true)] 
    [String] $VhdUri,

	[parameter(Mandatory=$true)] 
    [String] $VMNetIntfName,

	[parameter(Mandatory=$true)] 
    [String] $VMNameNetIntfCopyFrom,	

	[parameter(Mandatory=$true)] 
    [String] $VMSize = "Standard_A2",
		
	[parameter(Mandatory=$true)] 
    [String] $CreateNewAvailabilitySet,
	
	[parameter(Mandatory=$true)] 
    [String] $AvailabilitySetName,
	
	[parameter(Mandatory=$true)] 
    [String] $location
) 

    $connectionName = "AzureRunAsConnection"
    try
    {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

        "Logging in to Azure..."
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    }
    catch {
        if (!$servicePrincipalConnection)
        {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        } else{
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }

#Error Checking: Trim white space in string entered.
    $AzureSubscriptionName = $AzureSubscriptionName -replace '\s',''
    $ResourceGroupName = $ResourceGroupName -replace '\s',''
    $VMName = $VMName -replace '\s',''
    $VhdUri = $VhdUri -replace '\s',''
    $VMNetIntf = $VMNetIntf -replace '\s',''
    $VMNameNetIntfCopyFrom = $VMNameNetIntfCopyFrom -replace '\s',''
    $VMSize = $VMSize -replace '\s',''
    $CreateNewAvailabilitySet = $CreateNewAvailabilitySet -replace '\s',''
    $AvailabilitySetName = $AvailabilitySetName -replace '\s',''
    $location = $location -replace '\s',''

#Create Virtual Machine configuration
    $VMConf = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize

#Attach VHD to config
    $VMConf | Set-AzureRmVMOSDisk -VhdUri $VhdUri -Name $VMName -CreateOption attach -Windows -Caching ReadWrite

#Copy nic configuration from another NIC
    $nic = Get-AzureRmNetworkInterface -Name $VMNetIntfName -ResourceGroupName $ResourceGroupName
    $netprof = (Get-AzureRmVM -VMName $VMNameNetIntfCopyFrom -ResourceGroupName $ResourceGroupName).NetworkProfile
    $netprof.NetworkInterfaces[0].id = $nic.Id
    $VMConf.NetworkProfile = $netprof

#Create Virtual Machine from Config
    New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VMConf -Verbose
