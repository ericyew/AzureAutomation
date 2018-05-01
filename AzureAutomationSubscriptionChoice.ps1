<#
    .DESCRIPTION
        An example runbook which gets all the ARM resources using the Run As Account (Service Principal)

    .NOTES
        AUTHOR: Azure Automation Team
        LASTEDIT: Mar 14, 2016
#>

param(
    [Parameter(Mandatory=$false)] 
    [String] $AzureSubscriptionName = "1-Prod, 2-Dev/Test, 3-Website *Defaults to Prod*"
)

# Error Checking: Trim white space from both ends of string enter.
    $AzureSubscriptionName = $AzureSubscriptionName.trim() # -replace '\s',''
    
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

#Get all ARM resources from all resource groups
$ResourceGroups = Get-AzureRmResourceGroup 

foreach ($ResourceGroup in $ResourceGroups)
{    
    Write-Output ("Showing resources in resource group " + $ResourceGroup.ResourceGroupName)
    $Resources = Find-AzureRmResource -ResourceGroupNameContains $ResourceGroup.ResourceGroupName | Select ResourceName, ResourceType
    ForEach ($Resource in $Resources)
    {
        Write-Output ($Resource.ResourceName + " of type " +  $Resource.ResourceType)
    }
    Write-Output ("")
} 
