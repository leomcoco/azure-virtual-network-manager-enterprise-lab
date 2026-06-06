#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_az_login

echo "==> Subscription"
az account show --query "{name:name,id:id,tenantId:tenantId}" --output table

echo
echo "==> Network Manager"
az network manager show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$NETWORK_MANAGER_NAME" \
  --query "{name:name,location:location,scopeAccesses:networkManagerScopeAccesses,scopes:networkManagerScopes,provisioningState:provisioningState}" \
  --output jsonc

echo
echo "==> Connectivity Configuration"
az network manager connect-config show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --configuration-name "$CONNECTIVITY_CONFIG_NAME" \
  --output jsonc

echo
echo "==> Deployment Status"
az network manager list-deploy-status \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --deployment-types Connectivity SecurityAdmin \
  --regions "$LOCATION" \
  --output jsonc || true

echo
echo "==> Static members"
az network manager group static-member list \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --network-group-name "$NETWORK_GROUP_NAME" \
  --output table || true

echo
echo "==> Effective connectivity - Spoke dinâmica"
az network manager list-effective-connectivity-config \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --virtual-network-name "$VNET_DYNAMIC_NAME" \
  --output jsonc || true

echo
echo "==> Peerings no Hub"
az network vnet peering list \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --vnet-name "$VNET_HUB_NAME" \
  --query "[].{name:name,state:peeringState,remote:remoteVirtualNetwork.id,allowVnetAccess:allowVirtualNetworkAccess}" \
  --output table || true

echo
echo "==> Peerings na Spoke dinâmica"
az network vnet peering list \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --vnet-name "$VNET_DYNAMIC_NAME" \
  --query "[].{name:name,state:peeringState,remote:remoteVirtualNetwork.id,allowVnetAccess:allowVirtualNetworkAccess}" \
  --output table || true
