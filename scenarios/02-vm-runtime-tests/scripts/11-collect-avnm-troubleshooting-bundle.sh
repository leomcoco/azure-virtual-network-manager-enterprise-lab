#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

require_az_login

RUN_ID="${RUN_ID:-$(date -u +"%Y%m%dT%H%M%SZ")}"
OUT_DIR="${OUT_DIR:-evidence/troubleshooting/${RUN_ID}}"

mkdir -p "$OUT_DIR/json" "$OUT_DIR/table" "$OUT_DIR/logs" "$OUT_DIR/cmd"

SUBSCRIPTION_ID="$(get_subscription_id)"
SCOPE="/subscriptions/${SUBSCRIPTION_ID}"

if [[ -z "${START_TIME:-}" ]]; then
  if date -u -d "-48 hours" +"%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
    START_TIME="$(date -u -d "-48 hours" +"%Y-%m-%dT%H:%M:%SZ")"
  else
    START_TIME="$(date -u +"%Y-%m-%dT00:00:00Z")"
  fi
fi

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

echo "AVNM troubleshooting bundle"
echo "Run ID: $RUN_ID"
echo "Output directory: $OUT_DIR"
echo "Subscription: $SUBSCRIPTION_ID"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Network Manager: $NETWORK_MANAGER_NAME"
echo "Network Group: $NETWORK_GROUP_NAME"
echo "Connectivity Config: $CONNECTIVITY_CONFIG_NAME"
echo "Security Config: $SECURITY_CONFIG_NAME"
echo "Start time for Activity Log: $START_TIME"

run_cmd "json/00-az-version.json" \
  "Azure CLI version" \
  "az version --output json"

run_cmd "json/01-account.jsonc" \
  "Azure account context" \
  "az account show --output jsonc"

run_cmd "json/02-resource-group.jsonc" \
  "Resource Group" \
  "az group show --name '$RESOURCE_GROUP_NAME' --output jsonc"

run_cmd "json/03-network-manager.jsonc" \
  "AVNM resource" \
  "az network manager show --resource-group '$RESOURCE_GROUP_NAME' --name '$NETWORK_MANAGER_NAME' --output jsonc"

run_cmd "json/04-connectivity-config.jsonc" \
  "Connectivity configuration" \
  "az network manager connect-config show --resource-group '$RESOURCE_GROUP_NAME' --network-manager-name '$NETWORK_MANAGER_NAME' --configuration-name '$CONNECTIVITY_CONFIG_NAME' --output jsonc"

run_cmd "json/05-security-admin-config.jsonc" \
  "Security admin configuration" \
  "az network manager security-admin-config show --resource-group '$RESOURCE_GROUP_NAME' --network-manager-name '$NETWORK_MANAGER_NAME' --configuration-name '$SECURITY_CONFIG_NAME' --output jsonc"

run_cmd "json/06-deploy-status.jsonc" \
  "AVNM deployment status" \
  "az network manager list-deploy-status --network-manager-name '$NETWORK_MANAGER_NAME' --resource-group '$RESOURCE_GROUP_NAME' --deployment-types Connectivity SecurityAdmin --regions '$LOCATION' --output jsonc"

run_cmd "table/07-static-members.table" \
  "Static members do Network Group" \
  "az network manager group static-member list --resource-group '$RESOURCE_GROUP_NAME' --network-manager-name '$NETWORK_MANAGER_NAME' --network-group-name '$NETWORK_GROUP_NAME' --output table"

run_cmd "json/08-effective-connectivity-dynamic.jsonc" \
  "Effective connectivity da VNet dinâmica" \
  "az network manager list-effective-connectivity-config --resource-group '$RESOURCE_GROUP_NAME' --virtual-network-name '$VNET_DYNAMIC_NAME' --output jsonc"

run_cmd "json/09-effective-security-dynamic.jsonc" \
  "Effective security admin rules da VNet dinâmica" \
  "az network manager list-effective-security-admin-rule --resource-group '$RESOURCE_GROUP_NAME' --virtual-network-name '$VNET_DYNAMIC_NAME' --output jsonc"

run_cmd "json/10-effective-connectivity-outofpolicy.jsonc" \
  "Effective connectivity da VNet fora do padrão" \
  "az network manager list-effective-connectivity-config --resource-group '$RESOURCE_GROUP_NAME' --virtual-network-name '$VNET_OUTOFPOLICY_NAME' --output jsonc"

for vnet in "$VNET_HUB_NAME" "$VNET_SPOKE_APP_NAME" "$VNET_DYNAMIC_NAME" "$VNET_OUTOFPOLICY_NAME"; do
  safe_name="${vnet//[^a-zA-Z0-9_-]/_}"

  run_cmd "json/vnet-${safe_name}.jsonc" \
    "Detalhes da VNet $vnet" \
    "az network vnet show --resource-group '$RESOURCE_GROUP_NAME' --name '$vnet' --output jsonc"

  run_cmd "table/peerings-${safe_name}.table" \
    "Peerings da VNet $vnet" \
    "az network vnet peering list --resource-group '$RESOURCE_GROUP_NAME' --vnet-name '$vnet' --query \"[].{name:name,state:peeringState,sync:peeringSyncLevel,remote:remoteVirtualNetwork.id,allowVnetAccess:allowVirtualNetworkAccess,allowForwardedTraffic:allowForwardedTraffic,useRemoteGateways:useRemoteGateways}\" --output table"

  run_cmd "json/peerings-${safe_name}.jsonc" \
    "Peerings da VNet $vnet em JSON" \
    "az network vnet peering list --resource-group '$RESOURCE_GROUP_NAME' --vnet-name '$vnet' --output jsonc"
done

run_cmd "json/policy-assignments-scope.jsonc" \
  "Policy assignments no escopo da subscription" \
  "az policy assignment list --scope '$SCOPE' --output jsonc"

run_cmd "json/policy-assignments-inherited.jsonc" \
  "Policy assignments incluindo herdadas quando suportado pela CLI" \
  "az policy assignment list --disable-scope-strict-match --output jsonc || az policy assignment list --output jsonc"

run_cmd "table/policy-assignments-peering.table" \
  "Policy assignments com possível relação com peering/network" \
  "az policy assignment list --disable-scope-strict-match --query \"[?contains(to_string(displayName), 'Peering') || contains(to_string(displayName), 'peering') || contains(to_string(name), 'Peering') || contains(to_string(name), 'peering') || contains(to_string(policyDefinitionId), 'Network') || contains(to_string(policyDefinitionId), 'network')].{name:name,displayName:displayName,scope:scope,enforcementMode:enforcementMode,id:id,definition:policyDefinitionId}\" --output table || az policy assignment list --query \"[?contains(to_string(displayName), 'Peering') || contains(to_string(displayName), 'peering') || contains(to_string(name), 'Peering') || contains(to_string(name), 'peering')].{name:name,displayName:displayName,scope:scope,enforcementMode:enforcementMode,id:id,definition:policyDefinitionId}\" --output table"

run_cmd "json/activity-log-full.jsonc" \
  "Activity Log completo desde START_TIME" \
  "az monitor activity-log list --start-time '$START_TIME' --output jsonc"

run_cmd "json/activity-log-avnm-policy-peering.jsonc" \
  "Activity Log filtrado para AVNM, policy e peering" \
  "az monitor activity-log list --start-time '$START_TIME' --query \"[?contains(to_string(properties), 'RequestDisallowedByPolicy') || contains(to_string(properties), 'HubAndSpokeFailure') || contains(to_string(properties), 'ANM_') || contains(to_string(operationName.value), 'virtualNetworkPeerings') || contains(to_string(operationName.value), 'networkManagers') || contains(to_string(resourceId), 'networkManagers') || contains(to_string(resourceId), 'virtualNetworkPeerings')].{time:eventTimestamp,operation:operationName.value,status:status.value,subStatus:subStatus.value,resource:resourceId,caller:caller,properties:properties}\" --output jsonc"

run_cmd "table/activity-log-avnm-policy-peering.table" \
  "Activity Log filtrado em tabela" \
  "az monitor activity-log list --start-time '$START_TIME' --query \"[?contains(to_string(properties), 'RequestDisallowedByPolicy') || contains(to_string(properties), 'HubAndSpokeFailure') || contains(to_string(properties), 'ANM_') || contains(to_string(operationName.value), 'virtualNetworkPeerings') || contains(to_string(operationName.value), 'networkManagers') || contains(to_string(resourceId), 'networkManagers') || contains(to_string(resourceId), 'virtualNetworkPeerings')].{time:eventTimestamp,operation:operationName.value,status:status.value,subStatus:subStatus.value,resource:resourceId}\" --output table"

cat > "$OUT_DIR/README.txt" <<EOF2
AVNM troubleshooting bundle gerado em: $RUN_ID

Arquivos principais:
- summary.log
- json/06-deploy-status.jsonc
- json/04-connectivity-config.jsonc
- json/activity-log-avnm-policy-peering.jsonc
- table/activity-log-avnm-policy-peering.table
- table/peerings-vnet-hub-shared-001.table
- table/peerings-vnet-spoke-dynamic-001.table
- table/policy-assignments-peering.table

Interpretação rápida:
1. Se activity-log-avnm-policy-peering mostrar RequestDisallowedByPolicy, ainda existe policy bloqueando o peering.
2. Se deploy-status mostrar Connectivity como Deployed, mas Resource status no Portal continuar Failed, verifique logs de virtualNetworkPeerings/write.
3. Se os peerings ANM_* não aparecerem no hub e na spoke, não avance para os testes de VM.
EOF2

echo
echo "================================================================================"
echo "Bundle concluído."
echo "Pasta gerada: $OUT_DIR"
echo "Compacte e envie a pasta acima se precisar de análise detalhada."
echo "================================================================================"
