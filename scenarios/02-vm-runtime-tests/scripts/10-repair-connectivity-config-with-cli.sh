#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_az_login

API_VERSION="${API_VERSION:-2024-10-01}"
SUBSCRIPTION_ID=$(get_subscription_id)

NETWORK_GROUP_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Network/networkManagers/${NETWORK_MANAGER_NAME}/networkGroups/${NETWORK_GROUP_NAME}"
VNET_HUB_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Network/virtualNetworks/${VNET_HUB_NAME}"
CONNECTIVITY_CONFIG_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Network/networkManagers/${NETWORK_MANAGER_NAME}/connectivityConfigurations/${CONNECTIVITY_CONFIG_NAME}"
CONNECTIVITY_CONFIG_URI="https://management.azure.com${CONNECTIVITY_CONFIG_ID}?api-version=${API_VERSION}"

TMP_BODY="$(mktemp)"
trap 'rm -f "$TMP_BODY"' EXIT

cat > "$TMP_BODY" <<JSON
{
  "properties": {
    "description": "Hub-spoke connectivity configuration for AVNM lab",
    "connectivityTopology": "HubAndSpoke",
    "deleteExistingPeering": false,
    "isGlobal": false,
    "appliesToGroups": [
      {
        "networkGroupId": "$NETWORK_GROUP_ID",
        "groupConnectivity": "None",
        "isGlobal": false,
        "useHubGateway": false
      }
    ],
    "hubs": [
      {
        "resourceId": "$VNET_HUB_ID",
        "resourceType": "Microsoft.Network/virtualNetworks"
      }
    ]
  }
}
JSON

echo "==> Regravando Connectivity Configuration com JSON tipado via ARM REST"
echo "Motivo: eliminar risco de campos booleanos gravados como string ou divergência de schema."
echo "URI: $CONNECTIVITY_CONFIG_URI"
echo

cat "$TMP_BODY"
echo

BODY_CONTENT="$(cat "$TMP_BODY")"

az rest \
  --method put \
  --uri "$CONNECTIVITY_CONFIG_URI" \
  --headers "Content-Type=application/json" \
  --body "$BODY_CONTENT" \
  --output jsonc

echo
echo "==> Validando configuração após regravação"

az network manager connect-config show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --configuration-name "$CONNECTIVITY_CONFIG_NAME" \
  --output jsonc

echo
echo "==> Reimplantando Connectivity Configuration na região $LOCATION"

az network manager post-commit \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --commit-type Connectivity \
  --configuration-ids "$CONNECTIVITY_CONFIG_ID" \
  --target-locations "$LOCATION" \
  --output table

echo
echo "==> Aguardando peering Hub <-> Spoke dinâmica"

HUB_VNET_ID=$(get_vnet_id "$VNET_HUB_NAME")
DYNAMIC_VNET_ID=$(get_vnet_id "$VNET_DYNAMIC_NAME")

MAX_ATTEMPTS="${MAX_ATTEMPTS:-30}"
SLEEP_SECONDS="${SLEEP_SECONDS:-30}"

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  echo "Tentativa $attempt/$MAX_ATTEMPTS"

  HUB_TO_DYNAMIC_COUNT=$(az network vnet peering list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_HUB_NAME" \
    --query "[?remoteVirtualNetwork.id=='$DYNAMIC_VNET_ID' && peeringState=='Connected'] | length(@)" \
    -o tsv)

  DYNAMIC_TO_HUB_COUNT=$(az network vnet peering list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_DYNAMIC_NAME" \
    --query "[?remoteVirtualNetwork.id=='$HUB_VNET_ID' && peeringState=='Connected'] | length(@)" \
    -o tsv)

  if [[ "$HUB_TO_DYNAMIC_COUNT" == "1" && "$DYNAMIC_TO_HUB_COUNT" == "1" ]]; then
    echo
    echo "PASS: peering AVNM Hub <-> Spoke dinâmica encontrado em estado Connected."
    echo
    echo "Peerings no Hub:"
    az network vnet peering list \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --vnet-name "$VNET_HUB_NAME" \
      --query "[].{name:name,state:peeringState,remote:remoteVirtualNetwork.id,allowVnetAccess:allowVirtualNetworkAccess}" \
      --output table

    echo
    echo "Peerings na Spoke dinâmica:"
    az network vnet peering list \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --vnet-name "$VNET_DYNAMIC_NAME" \
      --query "[].{name:name,state:peeringState,remote:remoteVirtualNetwork.id,allowVnetAccess:allowVirtualNetworkAccess}" \
      --output table

    echo
    echo "Próximo passo: ./scripts/04-test-hub-to-spoke.sh"
    exit 0
  fi

  echo "Peering ainda não encontrado. Aguardando ${SLEEP_SECONDS}s..."
  sleep "$SLEEP_SECONDS"
done

echo
echo "FAIL: o AVNM ainda não materializou o peering Hub <-> Spoke dinâmica."
echo
echo "O deployment geral pode aparecer como Succeeded mesmo com falha por VNet."
echo "No Portal, valide:"
echo "AVNM > Deployments > Connectivity > View deployment details and resource status"
echo
echo "Se o Resource status continuar Failed para as VNets, colete o erro detalhado via Activity Log ou suporte Microsoft."
exit 1
