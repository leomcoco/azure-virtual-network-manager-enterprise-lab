#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

require_az_login

RUN_ID="${RUN_ID:-$(date -u +"%Y%m%dT%H%M%SZ")}"
OUT_DIR="${OUT_DIR:-evidence/troubleshooting/redeploy-${RUN_ID}}"
mkdir -p "$OUT_DIR/json" "$OUT_DIR/table" "$OUT_DIR/logs" "$OUT_DIR/cmd"

SUBSCRIPTION_ID="$(get_subscription_id)"
CONNECTIVITY_CONFIG_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Network/networkManagers/${NETWORK_MANAGER_NAME}/connectivityConfigurations/${CONNECTIVITY_CONFIG_NAME}"

START_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

exec > >(tee "$OUT_DIR/summary.log") 2>&1

run_cmd() {
  local file="$1"
  local description="$2"
  local cmd="$3"

  echo
  echo "================================================================================"
  echo "==> $description"
  echo "Arquivo: $OUT_DIR/$file"
  echo "Comando: $cmd"
  echo "================================================================================"

  printf '%s\n' "$cmd" > "$OUT_DIR/cmd/$(basename "$file").cmd"

  set +e
  bash -lc "$cmd" > "$OUT_DIR/$file" 2>&1
  local rc=$?
  set -u

  echo "Exit code: $rc"
  if [[ $rc -ne 0 ]]; then
    echo "ATENÇÃO: comando falhou. Verifique o arquivo $OUT_DIR/$file"
  fi
}

echo "AVNM redeploy with debug"
echo "Run ID: $RUN_ID"
echo "Output directory: $OUT_DIR"
echo "Start time: $START_TIME"
echo "Connectivity config ID: $CONNECTIVITY_CONFIG_ID"

run_cmd "json/00-deploy-status-before.jsonc" \
  "Deployment status antes do post-commit" \
  "az network manager list-deploy-status --network-manager-name '$NETWORK_MANAGER_NAME' --resource-group '$RESOURCE_GROUP_NAME' --deployment-types Connectivity SecurityAdmin --regions '$LOCATION' --output jsonc"

run_cmd "logs/01-post-commit-debug.log" \
  "Post-commit Connectivity com --debug" \
  "az network manager post-commit --network-manager-name '$NETWORK_MANAGER_NAME' --resource-group '$RESOURCE_GROUP_NAME' --commit-type Connectivity --configuration-ids '$CONNECTIVITY_CONFIG_ID' --target-locations '$LOCATION' --debug"

HUB_VNET_ID="$(get_vnet_id "$VNET_HUB_NAME")"
DYNAMIC_VNET_ID="$(get_vnet_id "$VNET_DYNAMIC_NAME")"

MAX_ATTEMPTS="${MAX_ATTEMPTS:-30}"
SLEEP_SECONDS="${SLEEP_SECONDS:-30}"

echo
echo "==> Aguardando materialização dos peerings Hub <-> Spoke dinâmica"
echo "Hub VNet ID: $HUB_VNET_ID"
echo "Dynamic VNet ID: $DYNAMIC_VNET_ID"

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  echo
  echo "Tentativa $attempt/$MAX_ATTEMPTS"

  hub_count=$(az network vnet peering list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_HUB_NAME" \
    --query "[?remoteVirtualNetwork.id=='$DYNAMIC_VNET_ID' && peeringState=='Connected'] | length(@)" \
    -o tsv 2>> "$OUT_DIR/logs/peering-check-errors.log")

  dynamic_count=$(az network vnet peering list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_DYNAMIC_NAME" \
    --query "[?remoteVirtualNetwork.id=='$HUB_VNET_ID' && peeringState=='Connected'] | length(@)" \
    -o tsv 2>> "$OUT_DIR/logs/peering-check-errors.log")

  echo "Hub -> Dynamic connected count: ${hub_count:-0}"
  echo "Dynamic -> Hub connected count: ${dynamic_count:-0}"

  az network vnet peering list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_HUB_NAME" \
    --query "[].{name:name,state:peeringState,sync:peeringSyncLevel,remote:remoteVirtualNetwork.id}" \
    --output table > "$OUT_DIR/table/peerings-hub-attempt-${attempt}.table" 2>&1

  az network vnet peering list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_DYNAMIC_NAME" \
    --query "[].{name:name,state:peeringState,sync:peeringSyncLevel,remote:remoteVirtualNetwork.id}" \
    --output table > "$OUT_DIR/table/peerings-dynamic-attempt-${attempt}.table" 2>&1

  if [[ "$hub_count" == "1" && "$dynamic_count" == "1" ]]; then
    echo
    echo "PASS: peering AVNM Hub <-> Spoke dinâmica encontrado em estado Connected."
    cp "$OUT_DIR/table/peerings-hub-attempt-${attempt}.table" "$OUT_DIR/table/peerings-hub-final.table"
    cp "$OUT_DIR/table/peerings-dynamic-attempt-${attempt}.table" "$OUT_DIR/table/peerings-dynamic-final.table"

    run_cmd "json/99-activity-log-after-success.jsonc" \
      "Activity Log após sucesso" \
      "az monitor activity-log list --start-time '$START_TIME' --query \"[?contains(to_string(properties), 'ANM_') || contains(to_string(operationName.value), 'virtualNetworkPeerings') || contains(to_string(operationName.value), 'networkManagers') || contains(to_string(resourceId), 'networkManagers') || contains(to_string(resourceId), 'virtualNetworkPeerings')].{time:eventTimestamp,operation:operationName.value,status:status.value,subStatus:subStatus.value,resource:resourceId,properties:properties}\" --output jsonc"

    exit 0
  fi

  if (( attempt % 5 == 0 )); then
    run_cmd "json/deploy-status-attempt-${attempt}.jsonc" \
      "Deployment status na tentativa ${attempt}" \
      "az network manager list-deploy-status --network-manager-name '$NETWORK_MANAGER_NAME' --resource-group '$RESOURCE_GROUP_NAME' --deployment-types Connectivity SecurityAdmin --regions '$LOCATION' --output jsonc"
  fi

  echo "Peering ainda não encontrado. Aguardando ${SLEEP_SECONDS}s..."
  sleep "$SLEEP_SECONDS"
done

echo
echo "FAIL: peering AVNM Hub <-> Spoke dinâmica não materializado."

run_cmd "json/90-deploy-status-after-failure.jsonc" \
  "Deployment status após falha" \
  "az network manager list-deploy-status --network-manager-name '$NETWORK_MANAGER_NAME' --resource-group '$RESOURCE_GROUP_NAME' --deployment-types Connectivity SecurityAdmin --regions '$LOCATION' --output jsonc"

run_cmd "json/91-activity-log-after-failure.jsonc" \
  "Activity Log filtrado após falha" \
  "az monitor activity-log list --start-time '$START_TIME' --query \"[?contains(to_string(properties), 'RequestDisallowedByPolicy') || contains(to_string(properties), 'HubAndSpokeFailure') || contains(to_string(properties), 'ANM_') || contains(to_string(operationName.value), 'virtualNetworkPeerings') || contains(to_string(operationName.value), 'networkManagers') || contains(to_string(resourceId), 'networkManagers') || contains(to_string(resourceId), 'virtualNetworkPeerings')].{time:eventTimestamp,operation:operationName.value,status:status.value,subStatus:subStatus.value,resource:resourceId,caller:caller,properties:properties}\" --output jsonc"

run_cmd "json/92-policy-assignments-after-failure.jsonc" \
  "Policy assignments após falha" \
  "az policy assignment list --disable-scope-strict-match --output jsonc || az policy assignment list --output jsonc"

echo
echo "Pasta de diagnóstico: $OUT_DIR"
exit 1
