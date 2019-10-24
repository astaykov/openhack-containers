#!/bin/bash
# Admin Consent does not work in Cloud shell! So make sure you either run this sceript locally and login properly using az cli
# or implement a user input to wait untill you grant admin consent manually to the server app

aksname="team9sec"

echo Create server app ...
# Create the Azure AD application
serverApplicationId=$(az ad app create \
    --display-name "${aksname}Server" \
    --identifier-uris "https://${aksname}Server" \
    --query appId -o tsv)

# Update the application group memebership claims
sleep 20

echo Update server app to get group membership claims ...
az ad app update --id $serverApplicationId --set groupMembershipClaims=All

# Create a service principal for the Azure AD application
echo Create SP for server app ...
az ad sp create --id $serverApplicationId

sleep 20

# Get the service principal secret
echo Create server app secret ...
serverApplicationSecret=$(az ad sp credential reset \
    --name $serverApplicationId \
    --credential-description "AKSPassword" \
    --query password -o tsv)

echo Require permissions to the server app
az ad app permission add \
    --id $serverApplicationId \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope 06da0dbc-49e2-44d2-8312-53f166ab848a=Scope 7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role

sleep 20

echo grant permissions to the server app
az ad app permission grant --id $serverApplicationId --api 00000003-0000-0000-c000-000000000000

echo try admin consent server app... when you see a red errors, go and to admin consent manually
# Admin Consent does not work in Cloud Shell !!
az ad app permission admin-consent --id  $serverApplicationId

read -p 'Go to Azure Portal, grand admin consent to the server app and hit enter here ...' uservarS

echo Create client app ...
clientApplicationId=$(az ad app create \
    --display-name "${aksname}Client" \
    --native-app \
    --reply-urls "https://${aksname}Client" \
    --query appId -o tsv)

echo Create SP client app
az ad sp create --id $clientApplicationId
sleep 20

oAuthPermissionId=$(az ad app show --id $serverApplicationId --query "oauth2Permissions[0].id" -o tsv)

echo add permissions grant to the client app
az ad app permission add --id $clientApplicationId --api $serverApplicationId --api-permissions $oAuthPermissionId=Scope

sleep 20
echo add permission grant to the client app
az ad app permission grant --id $clientApplicationId --api $serverApplicationId
export aksname=team9sec
export serverApplicationId=37764a51-54e7-43ec-8fed-77d88feed907
export serverApplicationSecret='@?1nA?kUQ[7gTXN8D2A?zOKsyba94nm/'
export clientApplicationId=cb1626f5-5b6b-40bb-903c-0b708e50a9d0

az aks create \
    --resource-group teamResources \
    --name $aksname \
    --network-plugin azure \
    --vnet-subnet-id /subscriptions/87bf97a9-e035-4c77-b8a5-c6697ef853e2/resourceGroups/teamResources/providers/Microsoft.Network/virtualNetworks/vnet/subnets/aks-subnet \
    --docker-bridge-address 172.17.0.1/16 \
    --dns-service-ip 192.168.0.10 \
    --service-cidr 192.168.0.0/24 \
    --generate-ssh-keys \
    --node-count 3 \
    --attach-acr registryuGf9246 \
    --enable-rbac \
    --aad-server-app-id $serverApplicationId \
    --aad-server-app-secret $serverApplicationSecret \
    --aad-client-app-id $clientApplicationId \
    --aad-tenant-id 2319eb5c-74f4-4d16-b289-50003acf58fb \
    --enable-addons monitoring \
    --network-policy azure


echo Do not forget to install flexvol to the cluster: kubectl create -f https://raw.githubusercontent.com/Azure/kubernetes-keyvault-flexvol/master/deployment/kv-flexvol-installer.yaml