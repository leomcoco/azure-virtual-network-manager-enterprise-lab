#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_base_lab

SUBSCRIPTION_ID=$(get_subscription_id)
CONNECTIVITY_CONFIG_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/networkManagers/$NETWORK_MANAGER_NAME/connectivityConfigurations/$CONNECTIVITY_CONFIG_NAME"
SECURITY_CONFIG_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/networkManagers/$NETWORK_MANAGER_NAME/securityAdminConfigurations/$SECURITY_CONFIG_NAME"

echo
echo "==> Criando VNet dinâmica com tags esperadas pela política"

az network vnet create \
  --name "$VNET_DYNAMIC_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --location "$LOCATION" \
  --address-prefixes "$VNET_DYNAMIC_PREFIX" \
  --subnet-name "$SUBNET_DYNAMIC_NAME" \
  --subnet-prefixes "$SUBNET_DYNAMIC_PREFIX" \
  --tags \
    environment=lab \
    workload=avnm-demo \
    role=spoke \
    scenario="$SCENARIO_TAG" \
    managedBy=azure-cli \
  --output table

echo
echo "==> Criando VNet fora do padrão, sem role=spoke"

az network vnet create \
  --name "$VNET_OUTOFPOLICY_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --location "$LOCATION" \
  --address-prefixes "$VNET_OUTOFPOLICY_PREFIX" \
  --subnet-name "$SUBNET_OUTOFPOLICY_NAME" \
  --subnet-prefixes "$SUBNET_OUTOFPOLICY_PREFIX" \
  --tags \
    environment=lab \
    workload=outofpolicy \
    role=not-governed \
    scenario="$SCENARIO_TAG" \
    managedBy=azure-cli \
  --output table

echo
echo "==> Solicitando reavaliação de Azure Policy, quando disponível"

az policy state trigger-scan \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --no-wait \
  --only-show-errors || true

echo
echo "==> Aguardando alguns minutos para propagação de associação dinâmica"
sleep 90

echo
echo "==> Publicando novamente as configurações existentes do AVNM para a região $LOCATION"
echo "Esta etapa não altera o desenho do laboratório anterior; apenas reaplica as configurações existentes para incluir novos membros dinâmicos."

az network manager post-commit \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --commit-type "Connectivity" \
  --configuration-ids "$CONNECTIVITY_CONFIG_ID" \
  --target-locations "$LOCATION" \
  --output table

az network manager post-commit \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --commit-type "SecurityAdmin" \
  --configuration-ids "$SECURITY_CONFIG_ID" \
  --target-locations "$LOCATION" \
  --output table

echo
echo "VNets de teste criadas. Próximo passo: ./scripts/02-create-test-vms.sh"
