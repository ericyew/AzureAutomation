<#
.SYNOPSIS
    Convert UnManaged VM to Managed VM
    Also it does convert the Unmanaged Data Disks to Managed

.DESCRIPTION
  This runbook connects to Azure and performs the following tasks :
  	- Stops the specified virtual machine
	- Converts unmanaged disk to managed disk
	- Starts the specified virtual machine

.PARAMETER VMName
   Mandatory with no default.
   The name of the virtual machine which you want to add a new data disk.
   It must be the name of an ARM virtual machine.

.PARAMETER ResourceGroupName
   Mandatory with no default.
   The name of the resource group which contains the targeted virtual machine. 
    
.NOTES
	Created By: Eric Yew - OLIKKA
	LAST EDIT: April 30, 2018
	By: Eric Yew
#>

param(
    [Parameter(Mandatory=$false)] 
    [String] $AzureSubscriptionName = "WCC Production EA",

    [Parameter(Position = 0, Mandatory = $true)]
    [string]
    $ResourceGroupName,

    [Parameter(Position = 1, Mandatory = $true)]
    [string]
    $VMName
)

# Enable Verbose logging for testing
#    $VerbosePreference = "Continue"

#Error Checking: Trim white space from both ends of string enter.
    $VMName = $VMName -replace '\s',''
    $AzureSubscriptionName = $AzureSubscriptionName -replace '\s',''
    $ResourceGroupName = $ResourceGroupName -replace '\s',''

#Connect to Azure
    $Conn = Get-AutomationConnection -Name AzureRunAsConnection
    $Cert = Get-AutomationCertificate -Name 'AzureRunAsCertificate'
    Write-Verbose "$Conn $Cert"
    Connect-AzureRmAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Cert.Thumbprint

#Stop the VM
    "Shutting down the virtual machine ..."
    $RmPState = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status -ErrorAction SilentlyContinue -WarningAction SilentlyContinue).Statuses.Code[1]

    if ($RmPState -eq 'PowerState/deallocated')
    {
        "$VMName is already shut down."
    }
    else
    {
        $StopSts = Stop-AzureRmVM -Name $VMName -ResourceGroupName $ResourceGroupName -Force -ErrorAction Stop
        "The virtual machine has been stopped."
    }

#Converts unmanaged disk to managed
    "Converting the VM to Managed VM including Disks "
    ConvertTo-AzureRmVMManagedDisk -ResourceGroupName $ResourceGroupName -VMName $VMName

"VM converted to managed disk completed!"
