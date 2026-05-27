#!/usr/bin/env bash

set -euo pipefail

# Evita que o Git Bash no Windows converta resource IDs do Azure
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

LOCATION="eastus"
RESOURCE_GROUP_NAME="rg-avnm-lab"

NETWORK_MANAGER_NAME="avnm-lab-001"
NETWORK_GROUP_NAME="ng-spokes-lab"

SECURITY_CONFIG_NAME="sac-baseline-lab"
RULE_COLLECTION_NAME="arc-spokes-baseline"
RULE_NAME="deny-rdp-inbound-to-spokes"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "Não foi possível obter a subscription ativa."
  exit 1
fi

NETWORK_GROUP_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/networkManagers/$NETWORK_MANAGER_NAME/networkGroups/$NETWORK_GROUP_NAME"

echo "==> Criando Security Admin Configuration"

az network manager security-admin-config create \
  --configuration-name "$SECURITY_CONFIG_NAME" \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --description "Security admin baseline for AVNM lab" \
  --apply-on None \
  --output table

echo
echo "==> Criando Rule Collection aplicada ao Network Group"

az network manager security-admin-config rule-collection create \
  --configuration-name "$SECURITY_CONFIG_NAME" \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --rule-collection-name "$RULE_COLLECTION_NAME" \
  --description "Baseline rules for lab spokes" \
  --applies-to-groups network-group-id="$NETWORK_GROUP_ID" \
  --output table

echo
echo "==> Criando Security Admin Rule para bloquear RDP inbound"

az network manager security-admin-config rule-collection rule create \
  --configuration-name "$SECURITY_CONFIG_NAME" \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --rule-collection-name "$RULE_COLLECTION_NAME" \
  --rule-name "$RULE_NAME" \
  --kind "Custom" \
  --protocol "Tcp" \
  --access "Deny" \
  --priority 100 \
  --direction "Inbound" \
  --sources address-prefix="*" address-prefix-type="IPPrefix" \
  --destinations address-prefix="*" address-prefix-type="IPPrefix" \
  --source-port-ranges 0-65535 \
  --dest-port-ranges 3389 \
  --description "Deny inbound RDP to lab spokes" \
  --output table

SECURITY_CONFIG_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/networkManagers/$NETWORK_MANAGER_NAME/securityAdminConfigurations/$SECURITY_CONFIG_NAME"

echo
echo "==> Publicando Security Admin Configuration na região $LOCATION"

az network manager post-commit \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --commit-type "SecurityAdmin" \
  --configuration-ids "$SECURITY_CONFIG_ID" \
  --target-locations "$LOCATION" \
  --output table

echo
echo "Security Admin baseline criada."
echo "Próximo passo: ./scripts/04-validate-avnm-lab.sh"
