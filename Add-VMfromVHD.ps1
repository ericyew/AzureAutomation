<#
    .DESCRIPTION
        xxxx

    .NOTES
        AUTHOR: Eric Yew
        LASTEDIT: Mar 14, 2016
#>

param (
    [Parameter(Mandatory=$false)] 
    [String] $AzureSubscriptionName = "SGG-Infrastructure-Prod-SCE",

	[parameter(Mandatory=$true)] 
    [String] $ResourceGroupName	
	
    [parameter(Mandatory=$true)] 
    [String] $VMName,

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
