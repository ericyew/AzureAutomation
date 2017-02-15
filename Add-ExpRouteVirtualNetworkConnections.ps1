<#
.SYNOPSIS
    Connect to Azure and creates a connection between an Express Route Circuit
    and a Virtual Network in 2 different subscriptions

.DESCRIPTION
    This runbook connects to Azure and performs the following tasks :
        - Connect to Azure
        - Create authorization key on the ExpressRoute Circuit
        - Set up connections between express route circuit and Virtual network gateway

.NOTES
    AUTHOR:  Eric Yew
    LASTEDIT: November 10, 2016
#>

param (
    [Parameter(Mandatory=$false)] 
    [String] $AzureSubscriptionForExpressRoute = "SGG-Infrastructure-Prod-SCE",

	[parameter(Mandatory=$true)] 
    [String] $ExpressRouteCircuitResourceGroup,

    [parameter(Mandatory=$true)] 
    [String] $ExpressRouteCircuit,

	[parameter(Mandatory=$true)] 
    [String] $AzureSubscriptionForVirtualNetwork,

	[parameter(Mandatory=$true)] 
    [String] $VirtualNetworkGatewayResourceGroup,

	[parameter(Mandatory=$true)] 
    [String] $VirtualNetworkGateway
) 

# Connect To Azure
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

# Error Checking: Trim white space in string entered.
    $AzureSubscriptionForExpressRoute  = $AzureSubscriptionForExpressRoute -replace '\s',''
    $ExpressRouteCircuitResourceGroup = $ExpressRouteCircuitResourceGroup -replace '\s',''
    $ExpressRouteCircuit = $ExpressRouteCircuit -replace '\s',''
    $AzureSubscriptionForVirtualNetwork = $AzureSubscriptionForVirtualNetwork -replace '\s',''
    $VirtualNetworkGatewayResourceGroup = $VirtualNetworkGatewayResourceGroup -replace '\s',''
    $VirtualNetworkGateway = $VirtualNetworkGateway -replace '\s',''

# Reassign parameter string
    $subscriptionId = $AzureSubscriptionForExpressRoute
    $subscriptionId2 = $AzureSubscriptionForVirtualNetwork
    $gwrg = $VirtualNetworkGatewayResourceGroup
 
# Connect to Express Route Circuit Subscription
    Select-AzureRmSubscription -SubscriptionId $subscriptionId
    $rg = $ExpressRouteCircuitResourceGroup
    $circuit = Get-AzureRmExpressRouteCircuit -Name $ExpressRouteCircuit -ResourceGroupName $rg

# Select the Virtual Network Gateway
    Select-AzureRmSubscription -SubscriptionId $subscriptionId2
    $gw = Get-AzureRmVirtualNetworkGateway -ResourceGroupName $gwrg -Name $VirtualNetworkGateway

# Set connections name
    $connectionsName = $ExpressRouteCircuit + "-to-" + $VirtualNetworkGateway

# Create Authorisation:
    Select-AzureRmSubscription -SubscriptionId $subscriptionId
    Add-AzureRmExpressRouteCircuitAuthorization -ExpressRouteCircuit $circuit -Name $connectionsName
    Set-AzureRmExpressRouteCircuit -ExpressRouteCircuit $circuit

# Get Peer ID and Authorization Key
    $ERCID = Get-AzureRmExpressRouteCircuit -Name $ExpressRouteCircuit -ResourceGroupName $rg   
    $id = $ERCID.Id
    $AuthKey = Foreach ($Key in ($ERCID.Authorizations.GetEnumerator() | Where-Object {$_.Name -eq $connectionsName})) {$Key.AuthorizationKey}

# Set up connection
    Select-AzureRmSubscription -SubscriptionId $subscriptionId2
    $gwlocation = $gw.Location    
    $connection = New-AzureRmVirtualNetworkGatewayConnection -Name $connectionsName -ResourceGroupName $gwrg -Location $gwlocation -VirtualNetworkGateway1 $gw -PeerId $id -ConnectionType ExpressRoute -AuthorizationKey $AuthKey
