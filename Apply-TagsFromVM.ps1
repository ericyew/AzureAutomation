<#
.SYNOPSIS
  Connects to Azure and check VM resources for tags. Apply tags to nic and disk resources.

.DESCRIPTION
  This runbooks check resources for tags on VM. If tags does exist, it ensure nic and disk resources are tagged with the same tags.

.PARAMETER SubscriptionName
   Optional with default of "1-Prod".
   The name of an Azure Subscription stored in Automation Variables. To use an subscription with a different name you can pass the subscription name as a runbook input parameter or change
   the default value for this input parameter.
   
   To reduce error, create automation account variables called "Prod Subscription Name" and "DevTest Subscription Name"

.NOTES
	Created By: Eric Yew - OLIKKA
	LAST EDIT: Apr 30, 2019
	By: Eric Yew
	SOURCE: https://github.com/ericyew/AzureAutomation/blob/master/Apply-TagsFromVM.ps1
#>

# Returns strings with status messages
[OutputType([String])]

param (
    [Parameter(Mandatory=$false)] 
    [String] $SubscriptionName = "1-Prod, 2-Dev/Test *Defaults to Prod*"
)

# Error Checking: Trim white space from both ends of string enter.
$SubscriptionName = $SubscriptionName.trim()	

# Retrieve subscription name from variable asset if not specified
    if($SubscriptionName -eq "1" -Or $SubscriptionName -eq "1-Prod, 2-Dev/Test *Defaults to Prod*")
    {
        $SubscriptionName = Get-AutomationVariable -Name 'Prod Subscription Name'
        $SubscriptionID = Get-AutomationVariable -Name 'Prod Subscription ID'
        if($SubscriptionName.length -gt 0)
        {
            Write-Output "Specified subscription name: [$SubscriptionName]"
        }
        else
        {
            throw "No variable asset with name 'Prod Subscription Name' was found. Either specify an Azure subscription name or define the 'Prod Subscription Name' variable setting"
        }
    }
    elseIf($SubscriptionName -eq "2")
    {
        $SubscriptionName = Get-AutomationVariable -Name 'DevTest Subscription Name'
        $SubscriptionID = Get-AutomationVariable -Name 'DevTest Subscription ID'
        if($SubscriptionName.length -gt 0)
        {
            Write-Output "Specified subscription name: [$SubscriptionName]"
        }
        else
        {
            throw "No variable asset with name 'DevTest Subscription Name' was found. Either specify an Azure subscription name or define the 'DevTest Subscription Name' variable setting"
        }
    }
    else
    {
        if($SubscriptionName.length -gt 0)
        {
            Write-Output "Specified subscription name/ID: [$SubscriptionName]"
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

#Use Subscription ID if Prod or DevTest subscription to avoid errors should Subscription be renamed
    if($SubscriptionName -eq "1" -Or $SubscriptionName -eq "1-Prod, 2-Dev/Test *Defaults to Prod*" -Or $SubscriptionName -eq "2")
    {
        Select-AzureRmSubscription -SubscriptionId $SubscriptionID
    }
    else
    {
        Select-AzureRmSubscription -SubscriptionName $SubscriptionName
    }


#List all VMs within the Subscription
$VMs = Get-AzureRmVM

#For each VM resources, apply the Tag of the VM
Foreach ($vm in $VMs)
{
    $nicID = $null
    $osDisk = $null
    $dataDiskID = $null
    $Tags = $null

    If($vm.Tags -ne ""){
        $VmRgName = $vm.Resourcegroupname
        $Tags = $vm.Tags
        $nicID = $vm.NetworkProfile.NetworkInterfaces.Id
    
        write-output "Applying Tags to $nicID"
        $SetTag = Set-AzureRmResource -ResourceId $nicID -Tag $Tags -Force

        #Check for managed disk
        If($vm.StorageProfile.OsDisk.managedDisk){
            $osDisk = Get-AzureRmDisk -DiskName $vm.StorageProfile.OsDisk.Name -ResourceGroupName $VmRgName
            $osDiskID = $osDisk.Id
        
            write-output "Applying Tags to $osDiskID"
            $SetTag = Set-AzureRmResource -ResourceId $osDiskID -Tag $Tags -Force

            If ($vm.datadisks) {
                Foreach($dataDisk in $vm.datadisks) {
                    $dataDiskInfo = Get-AzureRmDisk -DiskName $dataDisk.name -ResourceGroupName $VmRgName
                    $dataDiskID = $dataDiskInfo.Id
                    write-output "Applying Tags to $dataDiskID"
                    $SetTag = Set-AzureRmResource -ResourceId $dataDiskID -Tag $Tags -Force
                }
            }
        }     
    }
    Else{
        Write-Output "$vm.name not Tagged!"
    }
}
