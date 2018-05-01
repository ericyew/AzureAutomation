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
    [String] $AzureSubscriptionName = "1-Prod, 2-Dev/Test, 3-Website *Defaults to Prod*",

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
    $AzureSubscriptionName = $AzureSubscriptionName.trim()
    $ResourceGroupName = $ResourceGroupName -replace '\s',''
    
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

# Connect to Azure
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

# Check for Availability Set and Type
    $VM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction Stop
    $as = Get-AzureRmResource -ResourceId $VM.AvailabilitySetReference.ID
    If($as.Sku.name -eq 'Classic')
    {
        $asRgName = $as.ResourceGroupName
        $asName = $as.Name

        $avSet = Get-AzureRmAvailabilitySet -ResourceGroupName $asRgName -Name $asName
        Update-AzureRmAvailabilitySet -AvailabilitySet $avSet -Sku Aligned -ErrorVariable errorMsg -ErrorAction SilentlyContinue
        If ($errorMsg -ne $null)
        {
            $avSet.PlatformFaultDomainCount = 2
            Update-AzureRmAvailabilitySet -AvailabilitySet $avSet -Sku Aligned
        }
    }

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
