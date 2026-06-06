#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_az_login

SUBSCRIPTION_ID=$(get_subscription_id)

NETWORK_GROUP_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Network/networkManagers/${NETWORK_MANAGER_NAME}/networkGroups/${NETWORK_GROUP_NAME}"
VNET_HUB_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Network/virtualNetworks/${VNET_HUB_NAME}"
CONNECTIVITY_CONFIG_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Network/networkManagers/${NETWORK_MANAGER_NAME}/connectivityConfigurations/${CONNECTIVITY_CONFIG_NAME}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

APPLIES_FILE="$TMP_DIR/applies-to-groups.json"
HUBS_FILE="$TMP_DIR/hubs.json"

cat > "$APPLIES_FILE" <<JSON
[
  {
    "networkGroupId": "$NETWORK_GROUP_ID",
    "groupConnectivity": "None",
    "isGlobal": "False",
    "useHubGateway": "False"
  }
]
JSON

cat > "$HUBS_FILE" <<JSON
[
  {
    "resourceId": "$VNET_HUB_ID",
    "resourceType": "Microsoft.Network/virtualNetworks"
  }
]
JSON

echo "==> Atualizando Connectivity Configuration com az network manager connect-config update"
echo "Motivo: evitar divergência de schema ao criar/atualizar a configuração via ARM REST diretamente."
echo

az network manager connect-config update \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --configuration-name "$CONNECTIVITY_CONFIG_NAME" \
  --description "Hub-spoke connectivity configuration for AVNM lab" \
  --connectivity-topology HubAndSpoke \
  --delete-existing-peering False \
  --is-global False \
  --applies-to-groups @"$APPLIES_FILE" \
  --hubs @"$HUBS_FILE" \
  --output table

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
echo "==> Status do deployment de conectividade"
az network manager list-deploy-status \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --deployment-types Connectivity \
  --regions "$LOCATION" \
  --output table || true

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
    echo "Próximo passo: ./scripts/02-create-test-vms.sh"
    exit 0
  fi

  echo "Peering ainda não encontrado. Aguardando ${SLEEP_SECONDS}s..."
  sleep "$SLEEP_SECONDS"
done

echo
echo "FAIL: o AVNM ainda não materializou o peering Hub <-> Spoke dinâmica."
echo
echo "Próximas evidências obrigatórias:"
echo "1) AVNM > Deployments > Connectivity > View deployment details and resource status"
echo "2) Activity Log do recurso avnm-lab-001 filtrando operações Commit e Write VirtualNetworkPeering"
echo "3) Saída do comando abaixo:"
echo
echo "az network manager list-deploy-status --network-manager-name $NETWORK_MANAGER_NAME --resource-group $RESOURCE_GROUP_NAME --deployment-types Connectivity --regions $LOCATION --output jsonc"
exit 1
