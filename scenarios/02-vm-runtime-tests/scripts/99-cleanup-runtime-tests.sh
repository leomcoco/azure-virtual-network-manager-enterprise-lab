#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_az_login

echo "Este script remove apenas os recursos do cenário 02-vm-runtime-tests."
echo "Ele NÃO remove o AVNM, as VNets base, as policies, o network group ou os scripts do laboratório anterior."
echo

echo "Recursos que serão removidos:"
echo "- $VM_HUB_NAME"
echo "- $VM_SPOKE_APP_NAME"
echo "- $VM_SPOKE_DYNAMIC_NAME"
echo "- $NSG_HUB_NAME"
echo "- $NSG_SPOKE_APP_NAME"
echo "- $NSG_SPOKE_DYNAMIC_NAME"
echo "- $VNET_DYNAMIC_NAME"
echo "- $VNET_OUTOFPOLICY_NAME"
echo

read -r -p "Digite DELETE para confirmar: " CONFIRMATION

if [[ "$CONFIRMATION" != "DELETE" ]]; then
  echo "Operação cancelada."
  exit 0
fi

echo
echo "==> Removendo VMs"
for vm in "$VM_HUB_NAME" "$VM_SPOKE_APP_NAME" "$VM_SPOKE_DYNAMIC_NAME"; do
  if az vm show --resource-group "$RESOURCE_GROUP_NAME" --name "$vm" >/dev/null 2>&1; then
    az vm delete --resource-group "$RESOURCE_GROUP_NAME" --name "$vm" --yes --output none
    echo "VM removida: $vm"
  else
    echo "VM não encontrada: $vm"
  fi
done

echo
echo "==> Removendo NICs residuais do cenário, se existirem"
for pattern in "$VM_HUB_NAME" "$VM_SPOKE_APP_NAME" "$VM_SPOKE_DYNAMIC_NAME"; do
  mapfile -t nic_ids < <(az network nic list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "[?contains(name, '$pattern')].id" \
    -o tsv)

  for nic_id in "${nic_ids[@]:-}"; do
    if [[ -n "$nic_id" ]]; then
      az network nic delete --ids "$nic_id" --output none || true
      echo "NIC removida: $nic_id"
    fi
  done
done

echo
echo "==> Removendo discos residuais do cenário, se existirem"
for pattern in "$VM_HUB_NAME" "$VM_SPOKE_APP_NAME" "$VM_SPOKE_DYNAMIC_NAME"; do
  mapfile -t disk_ids < <(az disk list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "[?contains(name, '$pattern')].id" \
    -o tsv)

  for disk_id in "${disk_ids[@]:-}"; do
    if [[ -n "$disk_id" ]]; then
      az disk delete --ids "$disk_id" --yes --output none || true
      echo "Disco removido: $disk_id"
    fi
  done
done

echo
echo "==> Removendo NSGs do cenário"
for nsg in "$NSG_HUB_NAME" "$NSG_SPOKE_APP_NAME" "$NSG_SPOKE_DYNAMIC_NAME"; do
  if az network nsg show --resource-group "$RESOURCE_GROUP_NAME" --name "$nsg" >/dev/null 2>&1; then
    az network nsg delete --resource-group "$RESOURCE_GROUP_NAME" --name "$nsg" --output none || true
    echo "NSG removido: $nsg"
  else
    echo "NSG não encontrado: $nsg"
  fi
done

echo
echo "==> Removendo VNets do cenário"
for vnet in "$VNET_DYNAMIC_NAME" "$VNET_OUTOFPOLICY_NAME"; do
  if az network vnet show --resource-group "$RESOURCE_GROUP_NAME" --name "$vnet" >/dev/null 2>&1; then
    az network vnet delete --resource-group "$RESOURCE_GROUP_NAME" --name "$vnet" --output none || true
    echo "VNet removida: $vnet"
  else
    echo "VNet não encontrada: $vnet"
  fi
done

echo
echo "Cleanup do cenário concluído. O laboratório base permanece preservado."
