#!/usr/bin/env bash

set -euo pipefail

LOCATION="eastus"
RESOURCE_GROUP_NAME="rg-avnm-lab"

NETWORK_MANAGER_NAME="avnm-lab-001"
NETWORK_GROUP_NAME="ng-spokes-lab"
CONNECTIVITY_CONFIG_NAME="cc-hub-spoke-lab"

VNET_HUB_NAME="vnet-hub-shared-001"
VNET_SPOKE_APP_NAME="vnet-spoke-app-001"
VNET_SPOKE_DATA_NAME="vnet-spoke-data-001"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "Não foi possível obter a subscription ativa."
  echo "Execute az login e tente novamente."
  exit 1
fi

echo "==> Subscription em uso"
echo "$SUBSCRIPTION_ID"

echo
echo "==> Criando Resource Group"

az group create \
  --name "$RESOURCE_GROUP_NAME" \
  --location "$LOCATION" \
  --tags \
    environment=lab \
    workload=avnm-demo \
    owner=community \
    costCenter=mct-lab \
    managedBy=azure-cli \
    article=azure-virtual-network-manager \
  --output table

echo
echo "==> Criando VNet Hub"

az network vnet create \
  --name "$VNET_HUB_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --location "$LOCATION" \
  --address-prefixes "10.10.0.0/16" \
  --subnet-name "snet-shared" \
  --subnet-prefixes "10.10.1.0/24" \
  --tags \
    environment=lab \
    workload=avnm-demo \
    role=hub \
    owner=community \
    costCenter=mct-lab \
    managedBy=azure-cli \
    article=azure-virtual-network-manager \
  --output table

echo
echo "==> Criando VNet Spoke App"

az network vnet create \
  --name "$VNET_SPOKE_APP_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --location "$LOCATION" \
  --address-prefixes "10.20.0.0/16" \
  --subnet-name "snet-app" \
  --subnet-prefixes "10.20.1.0/24" \
  --tags \
    environment=lab \
    workload=avnm-demo \
    role=spoke \
    owner=community \
    costCenter=mct-lab \
    managedBy=azure-cli \
    article=azure-virtual-network-manager \
  --output table

echo
echo "==> Criando VNet Spoke Data"

az network vnet create \
  --name "$VNET_SPOKE_DATA_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --location "$LOCATION" \
  --address-prefixes "10.30.0.0/16" \
  --subnet-name "snet-data" \
  --subnet-prefixes "10.30.1.0/24" \
  --tags \
    environment=lab \
    workload=avnm-demo \
    role=spoke \
    owner=community \
    costCenter=mct-lab \
    managedBy=azure-cli \
    article=azure-virtual-network-manager \
  --output table

echo
echo "==> Criando Azure Virtual Network Manager"

az network manager create \
  --name "$NETWORK_MANAGER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --location "$LOCATION" \
  --scope-accesses "Connectivity" "SecurityAdmin" \
  --network-manager-scopes subscriptions="/subscriptions/$SUBSCRIPTION_ID" \
  --description "AVNM lab for enterprise network governance" \
  --tags \
    environment=lab \
    workload=avnm-demo \
    owner=community \
    costCenter=mct-lab \
    managedBy=azure-cli \
    article=azure-virtual-network-manager \
  --output table

echo
echo "==> Criando Network Group"

az network manager group create \
  --name "$NETWORK_GROUP_NAME" \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --description "Network group for lab spoke virtual networks" \
  --output table

VNET_HUB_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/virtualNetworks/$VNET_HUB_NAME"
VNET_SPOKE_APP_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/virtualNetworks/$VNET_SPOKE_APP_NAME"
VNET_SPOKE_DATA_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/virtualNetworks/$VNET_SPOKE_DATA_NAME"
NETWORK_GROUP_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/networkManagers/$NETWORK_MANAGER_NAME/networkGroups/$NETWORK_GROUP_NAME"

echo
echo "==> Associando VNet Spoke App ao Network Group"

az network manager group static-member create \
  --name "$VNET_SPOKE_APP_NAME" \
  --network-group "$NETWORK_GROUP_NAME" \
  --network-manager "$NETWORK_MANAGER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --resource-id "$VNET_SPOKE_APP_ID" \
  --output table

echo
echo "==> Associando VNet Spoke Data ao Network Group"

az network manager group static-member create \
  --name "$VNET_SPOKE_DATA_NAME" \
  --network-group "$NETWORK_GROUP_NAME" \
  --network-manager "$NETWORK_MANAGER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --resource-id "$VNET_SPOKE_DATA_ID" \
  --output table

echo
echo "==> Criando Connectivity Configuration Hub-Spoke"

APPLIES_TO_GROUPS="[{\"networkGroupId\":\"$NETWORK_GROUP_ID\",\"groupConnectivity\":\"None\",\"isGlobal\":false,\"useHubGateway\":false}]"
HUBS="[{\"resourceId\":\"$VNET_HUB_ID\",\"resourceType\":\"Microsoft.Network/virtualNetworks\"}]"

az network manager connect-config create \
  --configuration-name "$CONNECTIVITY_CONFIG_NAME" \
  --description "Hub-spoke connectivity configuration for AVNM lab" \
  --applies-to-groups "$APPLIES_TO_GROUPS" \
  --connectivity-topology "HubAndSpoke" \
  --delete-existing-peering "False" \
  --hubs "$HUBS" \
  --is-global "False" \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --output table

CONNECTIVITY_CONFIG_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/networkManagers/$NETWORK_MANAGER_NAME/connectivityConfigurations/$CONNECTIVITY_CONFIG_NAME"

echo
echo "==> Publicando configuração de conectividade na região $LOCATION"

az network manager post-commit \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --commit-type "Connectivity" \
  --configuration-ids "$CONNECTIVITY_CONFIG_ID" \
  --target-locations "$LOCATION" \
  --output table

echo
echo "Deploy principal concluído."
echo "Próximo passo: ./scripts/02-create-policy-add-to-network-group.sh"
