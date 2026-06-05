#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_az_login

SUBSCRIPTION_ID=$(get_subscription_id)
CONNECTIVITY_CONFIG_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Network/networkManagers/${NETWORK_MANAGER_NAME}/connectivityConfigurations/${CONNECTIVITY_CONFIG_NAME}"

echo "==> Reimplantando Connectivity Configuration do AVNM"
echo "Network Manager: $NETWORK_MANAGER_NAME"
echo "Configuration: $CONNECTIVITY_CONFIG_NAME"
echo "Target location: $LOCATION"
echo "Configuration ID: $CONNECTIVITY_CONFIG_ID"
echo

az network manager post-commit \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --commit-type Connectivity \
  --configuration-ids "$CONNECTIVITY_CONFIG_ID" \
  --target-locations "$LOCATION" \
  --output table

echo
echo "==> Aguardando materialização dos peerings Hub <-> Spoke dinâmica"
echo "Este passo valida o pré-requisito para os testes de tráfego com VMs."
echo

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
echo "FAIL: o peering AVNM Hub <-> Spoke dinâmica não foi materializado dentro do tempo esperado."
echo
echo "O post-commit foi enviado, mas os peerings não apareceram como Connected."
echo "Antes de usar testes de tráfego no artigo, verifique no Portal:"
echo "AVNM > Deployments > Connectivity > View deployment details and resource status"
echo
echo "Validações úteis:"
echo "az network vnet peering list --resource-group $RESOURCE_GROUP_NAME --vnet-name $VNET_HUB_NAME --output table"
echo "az network vnet peering list --resource-group $RESOURCE_GROUP_NAME --vnet-name $VNET_DYNAMIC_NAME --output table"
exit 1
