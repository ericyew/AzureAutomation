<#
.SYNOPSIS
  Connects to Azure and check resources for tags. Apply tags to resources.

.DESCRIPTION
  This runbooks check resources for mandatory tags. If tags does not exist, it will apply tags from resource groups.

.PARAMETER SubscriptionName
   Optional with default of "1-Prod".
   The name of an Azure Subscription stored in Automation Variables. To use an subscription with a different name you can pass the subscription name as a runbook input parameter or change
   the default value for this input parameter.
   
   To reduce error, create automation account variables called "Prod Subscription Name" and "DevTest Subscription Name"

.NOTES
    Created By: Eric Yew - OLIKKA
    LAST EDIT: Apr 30, 2019
    By: Eric Yew
    SOURCE: https://github.com/ericyew/AzureAutomation/blob/master/Apply-TagsFromRG.ps1
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


#List all Resources within the Subscription
    $Resources = Get-AzureRmResource

#For each Resource apply the Tag of the Resource Group
    Foreach ($resource in $Resources)
    {
        $Rgname = $resource.Resourcegroupname

        $resourceid = $resource.resourceId
        $RGTags = (Get-AzureRmResourceGroup -Name $Rgname).Tags

        $resourcetags = $resource.Tags
        
        If($resource.ResourceType -ne "Microsoft.OperationsManagement/solutions" -Or $resource.ResourceType -notcontains "microsoft.insights")
        {
            If ($resourcetags -eq $null)
                {
                    write-output "Applying the following Tags1 to $resourceid"
                    $Settag = Set-AzureRmResource -ResourceId $resourceid -Tag $RGTags -Force
                
                }
            Else
                {
                    $RGTagFinal = @{}
                    $RGTagFinal = $RGTags                  
                            Foreach ($resourcetag in $resourcetags.GetEnumerator())
                            {                
                                If ($RGTags.Name -notcontains $resourcetag.Name)
                                    {                        
                                            #write-Output "Name doesn't exist in RG Tags adding to Hash Table"
                                            Write-Output $resourcetag.Name
                                            Write-Output $resourcetag.Value
                                            $RGTagFinal.Add($resourcetag.Name,$resourcetag.Value)
                                    }    
                            }
                    write-Output "Applying the following Tags2 to $resourceid $RGTagFinal"
                    $Settag = Set-AzureRmResource -ResourceId $resourceid -Tag $RGTagFinal -Force
                }   
        }
    }
