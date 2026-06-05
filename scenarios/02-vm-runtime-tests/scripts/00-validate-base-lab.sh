#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_base_lab

SUBSCRIPTION_ID=$(get_subscription_id)

echo
echo "==> Subscription ativa"
az account show --query "{name:name, id:id, tenantId:tenantId}" --output table

echo
echo "==> Validando configurações base do AVNM"

az network manager connect-config show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --configuration-name "$CONNECTIVITY_CONFIG_NAME" \
  --output table

az network manager security-admin-config show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --configuration-name "$SECURITY_CONFIG_NAME" \
  --output table

echo
echo "Base validada. Próximo passo: ./scripts/01-create-dynamic-vnets.sh"
