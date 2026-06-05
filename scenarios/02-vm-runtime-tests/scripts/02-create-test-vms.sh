#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_base_lab

echo "==> Validando VNet dinâmica"
az network vnet show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$VNET_DYNAMIC_NAME" >/dev/null

echo
echo "==> Criando NSGs do cenário"

create_nsg_if_missing "$NSG_HUB_NAME"
create_nsg_if_missing "$NSG_SPOKE_APP_NAME"
create_nsg_if_missing "$NSG_SPOKE_DYNAMIC_NAME"

echo
echo "==> Criando regras locais de NSG para permitir testes internos"

create_or_update_nsg_rule "$NSG_SPOKE_DYNAMIC_NAME" "Allow-8080-From-VirtualNetwork" 100 8080
create_or_update_nsg_rule "$NSG_SPOKE_DYNAMIC_NAME" "Allow-3389-From-VirtualNetwork" 110 3389
create_or_update_nsg_rule "$NSG_SPOKE_APP_NAME" "Allow-8080-From-VirtualNetwork" 100 8080

echo
echo "==> Criando VMs Linux sem IP público"

create_vm_if_missing "$VM_HUB_NAME" "$VNET_HUB_NAME" "$SUBNET_HUB_NAME" "$NSG_HUB_NAME"
create_vm_if_missing "$VM_SPOKE_APP_NAME" "$VNET_SPOKE_APP_NAME" "$SUBNET_SPOKE_APP_NAME" "$NSG_SPOKE_APP_NAME"
create_vm_if_missing "$VM_SPOKE_DYNAMIC_NAME" "$VNET_DYNAMIC_NAME" "$SUBNET_DYNAMIC_NAME" "$NSG_SPOKE_DYNAMIC_NAME"

echo
echo "==> IPs privados das VMs"
echo "$VM_HUB_NAME: $(get_vm_private_ip "$VM_HUB_NAME")"
echo "$VM_SPOKE_APP_NAME: $(get_vm_private_ip "$VM_SPOKE_APP_NAME")"
echo "$VM_SPOKE_DYNAMIC_NAME: $(get_vm_private_ip "$VM_SPOKE_DYNAMIC_NAME")"

echo
echo "VMs criadas. Próximo passo: ./scripts/03-start-test-services.sh"
