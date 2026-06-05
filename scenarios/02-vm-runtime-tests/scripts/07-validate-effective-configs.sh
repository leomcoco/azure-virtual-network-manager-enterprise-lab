#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_az_login

echo "==> Configuração efetiva de conectividade na VNet dinâmica"
az network manager list-effective-connectivity-config \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --virtual-network-name "$VNET_DYNAMIC_NAME" \
  --output json

echo
echo "==> Security Admin Rules efetivas na VNet dinâmica"
az network manager list-effective-security-admin-rule \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --virtual-network-name "$VNET_DYNAMIC_NAME" \
  --output json

echo
echo "==> Configuração efetiva na VNet fora do padrão"
echo "Resultado esperado: sem configuração do AVNM ou sem as mesmas regras do network group governado."
az network manager list-effective-connectivity-config \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --virtual-network-name "$VNET_OUTOFPOLICY_NAME" \
  --output json || true

echo
echo "Validações concluídas. Capture os prints de evidência antes do cleanup."
