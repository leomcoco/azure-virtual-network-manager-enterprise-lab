#!/usr/bin/env bash

set -euo pipefail

# Evita que o Git Bash no Windows converta resource IDs do Azure.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

LOCATION="eastus"
RESOURCE_GROUP_NAME="rg-avnm-lab"

NETWORK_MANAGER_NAME="avnm-lab-001"
NETWORK_GROUP_NAME="ng-spokes-lab"

SECURITY_CONFIG_NAME="sac-baseline-lab"
RULE_COLLECTION_NAME="arc-spokes-baseline"
RULE_NAME="deny-rdp-inbound-to-spokes"

API_VERSION="2024-10-01"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "Não foi possível obter a subscription ativa."
  exit 1
fi

NETWORK_GROUP_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/networkManagers/$NETWORK_MANAGER_NAME/networkGroups/$NETWORK_GROUP_NAME"

echo "==> Validando Azure Virtual Network Manager"

az network manager show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$NETWORK_MANAGER_NAME" \
  --output table

echo
echo "==> Criando Security Admin Configuration via ARM REST"

SECURITY_CONFIG_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/networkManagers/$NETWORK_MANAGER_NAME/securityAdminConfigurations/$SECURITY_CONFIG_NAME?api-version=$API_VERSION"

SECURITY_CONFIG_BODY=$(cat <<JSON
{
  "properties": {
    "description": "Security admin baseline for AVNM lab",
    "applyOnNetworkIntentPolicyBasedServices": [
      "None"
    ]
  }
}
JSON
)

az rest \
  --method put \
  --uri "$SECURITY_CONFIG_URI" \
  --headers "Content-Type=application/json" \
  --body "$SECURITY_CONFIG_BODY" \
  --output table

echo
echo "==> Criando Rule Collection via ARM REST"

RULE_COLLECTION_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/networkManagers/$NETWORK_MANAGER_NAME/securityAdminConfigurations/$SECURITY_CONFIG_NAME/ruleCollections/$RULE_COLLECTION_NAME?api-version=$API_VERSION"

RULE_COLLECTION_BODY=$(cat <<JSON
{
  "properties": {
    "description": "Baseline rules for lab spokes",
    "appliesToGroups": [
      {
        "networkGroupId": "$NETWORK_GROUP_ID"
      }
    ]
  }
}
JSON
)

az rest \
  --method put \
  --uri "$RULE_COLLECTION_URI" \
  --headers "Content-Type=application/json" \
  --body "$RULE_COLLECTION_BODY" \
  --output table

echo
echo "==> Criando Security Admin Rule para bloquear RDP inbound via ARM REST"

RULE_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/networkManagers/$NETWORK_MANAGER_NAME/securityAdminConfigurations/$SECURITY_CONFIG_NAME/ruleCollections/$RULE_COLLECTION_NAME/rules/$RULE_NAME?api-version=$API_VERSION"

RULE_BODY=$(cat <<JSON
{
  "kind": "Custom",
  "properties": {
    "description": "Deny inbound RDP to lab spokes",
    "protocol": "Tcp",
    "sources": [
      {
        "addressPrefix": "*",
        "addressPrefixType": "IPPrefix"
      }
    ],
    "destinations": [
      {
        "addressPrefix": "*",
        "addressPrefixType": "IPPrefix"
      }
    ],
    "sourcePortRanges": [
      "0-65535"
    ],
    "destinationPortRanges": [
      "3389"
    ],
    "access": "Deny",
    "priority": 100,
    "direction": "Inbound"
  }
}
JSON
)

az rest \
  --method put \
  --uri "$RULE_URI" \
  --headers "Content-Type=application/json" \
  --body "$RULE_BODY" \
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
