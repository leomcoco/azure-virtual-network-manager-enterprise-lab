#!/usr/bin/env bash

set -euo pipefail

RESOURCE_GROUP_NAME="rg-avnm-lab"

NETWORK_MANAGER_NAME="avnm-lab-001"
NETWORK_GROUP_NAME="ng-spokes-lab"

VNET_SPOKE_APP_NAME="vnet-spoke-app-001"
VNET_SPOKE_DATA_NAME="vnet-spoke-data-001"

SECURITY_CONFIG_NAME="sac-baseline-lab"
RULE_COLLECTION_NAME="arc-spokes-baseline"

echo "==> Validando Resource Group"

az group show \
  --name "$RESOURCE_GROUP_NAME" \
  --query "{name:name, location:location, provisioningState:properties.provisioningState}" \
  --output table

echo
echo "==> Validando VNets"

az network vnet list \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --query "[].{name:name, location:location, addressSpace:addressSpace.addressPrefixes[0]}" \
  --output table

echo
echo "==> Validando Azure Virtual Network Manager"

az network manager show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$NETWORK_MANAGER_NAME" \
  --query "{name:name, location:location, provisioningState:provisioningState}" \
  --output table

echo
echo "==> Validando Network Group"

az network manager group show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --name "$NETWORK_GROUP_NAME" \
  --query "{name:name, description:description}" \
  --output table

echo
echo "==> Listando membros estáticos do Network Group"

az network manager group static-member list \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --network-manager "$NETWORK_MANAGER_NAME" \
  --network-group "$NETWORK_GROUP_NAME" \
  --output table

echo
echo "==> Validando conectividade efetiva na VNet Spoke App"

az network manager list-effective-connectivity-config \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --virtual-network-name "$VNET_SPOKE_APP_NAME" \
  --output json

echo
echo "==> Validando conectividade efetiva na VNet Spoke Data"

az network manager list-effective-connectivity-config \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --virtual-network-name "$VNET_SPOKE_DATA_NAME" \
  --output json

echo
echo "==> Validando Security Admin Configuration"

az network manager security-admin-config show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --configuration-name "$SECURITY_CONFIG_NAME" \
  --output table

echo
echo "==> Validando Rule Collection"

az network manager security-admin-config rule-collection show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --configuration-name "$SECURITY_CONFIG_NAME" \
  --rule-collection-name "$RULE_COLLECTION_NAME" \
  --output table

echo
echo "==> Validando regras efetivas na VNet Spoke App"

az network manager list-effective-security-admin-rule \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --virtual-network-name "$VNET_SPOKE_APP_NAME" \
  --output json

echo
echo "Validação concluída."
