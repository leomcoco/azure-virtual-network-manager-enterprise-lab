#!/usr/bin/env bash

set -euo pipefail

# Evita que o Git Bash no Windows converta resource IDs do Azure.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

LOCATION="${LOCATION:-eastus}"
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-rg-avnm-lab}"

NETWORK_MANAGER_NAME="${NETWORK_MANAGER_NAME:-avnm-lab-001}"
NETWORK_GROUP_NAME="${NETWORK_GROUP_NAME:-ng-spokes-lab}"
CONNECTIVITY_CONFIG_NAME="${CONNECTIVITY_CONFIG_NAME:-cc-hub-spoke-lab}"
SECURITY_CONFIG_NAME="${SECURITY_CONFIG_NAME:-sac-baseline-lab}"

VNET_HUB_NAME="${VNET_HUB_NAME:-vnet-hub-shared-001}"
VNET_SPOKE_APP_NAME="${VNET_SPOKE_APP_NAME:-vnet-spoke-app-001}"
VNET_DYNAMIC_NAME="${VNET_DYNAMIC_NAME:-vnet-spoke-dynamic-001}"
VNET_OUTOFPOLICY_NAME="${VNET_OUTOFPOLICY_NAME:-vnet-outofpolicy-001}"

SUBNET_HUB_NAME="${SUBNET_HUB_NAME:-snet-shared}"
SUBNET_SPOKE_APP_NAME="${SUBNET_SPOKE_APP_NAME:-snet-app}"
SUBNET_DYNAMIC_NAME="${SUBNET_DYNAMIC_NAME:-snet-dynamic}"
SUBNET_OUTOFPOLICY_NAME="${SUBNET_OUTOFPOLICY_NAME:-snet-outofpolicy}"

VNET_DYNAMIC_PREFIX="${VNET_DYNAMIC_PREFIX:-10.40.0.0/16}"
SUBNET_DYNAMIC_PREFIX="${SUBNET_DYNAMIC_PREFIX:-10.40.1.0/24}"
VNET_OUTOFPOLICY_PREFIX="${VNET_OUTOFPOLICY_PREFIX:-10.50.0.0/16}"
SUBNET_OUTOFPOLICY_PREFIX="${SUBNET_OUTOFPOLICY_PREFIX:-10.50.1.0/24}"

VM_HUB_NAME="${VM_HUB_NAME:-vm-hub-test-001}"
VM_SPOKE_APP_NAME="${VM_SPOKE_APP_NAME:-vm-spoke-app-test-001}"
VM_SPOKE_DYNAMIC_NAME="${VM_SPOKE_DYNAMIC_NAME:-vm-spoke-dynamic-test-001}"

NSG_HUB_NAME="${NSG_HUB_NAME:-nsg-hub-test-001}"
NSG_SPOKE_APP_NAME="${NSG_SPOKE_APP_NAME:-nsg-spoke-app-test-001}"
NSG_SPOKE_DYNAMIC_NAME="${NSG_SPOKE_DYNAMIC_NAME:-nsg-spoke-dynamic-test-001}"

VM_IMAGE="${VM_IMAGE:-Ubuntu2204}"
VM_SIZE="${VM_SIZE:-Standard_B1s}"
ADMIN_USERNAME="${ADMIN_USERNAME:-azureuser}"
SCENARIO_TAG="02-vm-runtime-tests"

get_subscription_id() {
  az account show --query id -o tsv
}

require_az_login() {
  if ! az account show >/dev/null 2>&1; then
    echo "Nenhuma sessão Azure ativa foi encontrada. Execute az login ou use o Azure Cloud Shell."
    exit 1
  fi
}

resource_exists() {
  local id="$1"
  az resource show --ids "$id" >/dev/null 2>&1
}

require_base_lab() {
  require_az_login

  echo "==> Validando base do laboratório anterior"

  az group show --name "$RESOURCE_GROUP_NAME" >/dev/null

  az network vnet show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VNET_HUB_NAME" >/dev/null

  az network vnet show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VNET_SPOKE_APP_NAME" >/dev/null

  az network manager show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$NETWORK_MANAGER_NAME" >/dev/null

  az network manager group show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --network-manager-name "$NETWORK_MANAGER_NAME" \
    --name "$NETWORK_GROUP_NAME" >/dev/null

  echo "Base encontrada: Resource Group, VNets, AVNM e Network Group."
}

get_vm_private_ip() {
  local vm_name="$1"
  az vm list-ip-addresses \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$vm_name" \
    --query "[0].virtualMachine.network.privateIpAddresses[0]" \
    -o tsv
}

create_nsg_if_missing() {
  local nsg_name="$1"

  if az network nsg show --resource-group "$RESOURCE_GROUP_NAME" --name "$nsg_name" >/dev/null 2>&1; then
    echo "NSG já existe: $nsg_name"
  else
    echo "Criando NSG: $nsg_name"
    az network nsg create \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --name "$nsg_name" \
      --location "$LOCATION" \
      --tags scenario="$SCENARIO_TAG" managedBy=azure-cli \
      --output none
  fi
}

create_or_update_nsg_rule() {
  local nsg_name="$1"
  local rule_name="$2"
  local priority="$3"
  local port="$4"

  if az network nsg rule show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --nsg-name "$nsg_name" \
    --name "$rule_name" >/dev/null 2>&1; then

    az network nsg rule update \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --nsg-name "$nsg_name" \
      --name "$rule_name" \
      --priority "$priority" \
      --access Allow \
      --direction Inbound \
      --protocol Tcp \
      --source-address-prefixes VirtualNetwork \
      --source-port-ranges '*' \
      --destination-address-prefixes '*' \
      --destination-port-ranges "$port" \
      --output none
  else
    az network nsg rule create \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --nsg-name "$nsg_name" \
      --name "$rule_name" \
      --priority "$priority" \
      --access Allow \
      --direction Inbound \
      --protocol Tcp \
      --source-address-prefixes VirtualNetwork \
      --source-port-ranges '*' \
      --destination-address-prefixes '*' \
      --destination-port-ranges "$port" \
      --output none
  fi
}

create_vm_if_missing() {
  local vm_name="$1"
  local vnet_name="$2"
  local subnet_name="$3"
  local nsg_name="$4"

  if az vm show --resource-group "$RESOURCE_GROUP_NAME" --name "$vm_name" >/dev/null 2>&1; then
    echo "VM já existe: $vm_name"
    return 0
  fi

  echo "Criando VM sem IP público: $vm_name"

  az vm create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$vm_name" \
    --location "$LOCATION" \
    --image "$VM_IMAGE" \
    --size "$VM_SIZE" \
    --admin-username "$ADMIN_USERNAME" \
    --generate-ssh-keys \
    --vnet-name "$vnet_name" \
    --subnet "$subnet_name" \
    --nsg "$nsg_name" \
    --public-ip-address "" \
    --os-disk-delete-option Delete \
    --nic-delete-option Delete \
    --tags scenario="$SCENARIO_TAG" managedBy=azure-cli \
    --output none
}
