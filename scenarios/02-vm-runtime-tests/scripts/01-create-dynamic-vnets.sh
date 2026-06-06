#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_base_lab

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
echo "==> Aguardando propagação inicial de associação dinâmica"
sleep 90

echo
echo "VNets de teste criadas."
echo "Próximo passo obrigatório: ./scripts/08-redeploy-connectivity-and-wait.sh"
