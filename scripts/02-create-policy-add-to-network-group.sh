#!/usr/bin/env bash

set -euo pipefail

# Evita que o Git Bash no Windows converta resource IDs do Azure.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

RESOURCE_GROUP_NAME="rg-avnm-lab"
NETWORK_MANAGER_NAME="avnm-lab-001"
NETWORK_GROUP_NAME="ng-spokes-lab"

POLICY_DEFINITION_NAME="avnm-add-lab-spokes-to-network-group"
POLICY_ASSIGNMENT_NAME="avnm-add-lab-spokes-to-network-group-assignment"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "Não foi possível obter a subscription ativa."
  exit 1
fi

NETWORK_GROUP_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/networkManagers/$NETWORK_MANAGER_NAME/networkGroups/$NETWORK_GROUP_NAME"
POLICY_DEFINITION_ID="/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/policyDefinitions/$POLICY_DEFINITION_NAME"

echo "==> Validando existência do Network Group"

az network manager group show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --name "$NETWORK_GROUP_NAME" \
  --output table

echo
echo "==> Criando ou atualizando policy definition via ARM REST"

POLICY_DEFINITION_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/policyDefinitions/$POLICY_DEFINITION_NAME?api-version=2021-06-01"

POLICY_DEFINITION_BODY=$(cat <<JSON
{
  "properties": {
    "displayName": "AVNM - Add lab spoke VNets to network group",
    "description": "Adds lab spoke VNets to an Azure Virtual Network Manager network group based on tags.",
    "policyType": "Custom",
    "mode": "Microsoft.Network.Data",
    "policyRule": {
      "if": {
        "allOf": [
          {
            "field": "type",
            "equals": "Microsoft.Network/virtualNetworks"
          },
          {
            "field": "tags['environment']",
            "equals": "lab"
          },
          {
            "field": "tags['workload']",
            "equals": "avnm-demo"
          },
          {
            "field": "tags['role']",
            "equals": "spoke"
          }
        ]
      },
      "then": {
        "effect": "addToNetworkGroup",
        "details": {
          "networkGroupId": "$NETWORK_GROUP_ID"
        }
      }
    }
  }
}
JSON
)

az rest \
  --method put \
  --uri "$POLICY_DEFINITION_URI" \
  --headers "Content-Type=application/json" \
  --body "$POLICY_DEFINITION_BODY" \
  --output table

echo
echo "==> Criando ou atualizando policy assignment via ARM REST"

POLICY_ASSIGNMENT_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/policyAssignments/$POLICY_ASSIGNMENT_NAME?api-version=2022-06-01"

POLICY_ASSIGNMENT_BODY=$(cat <<JSON
{
  "properties": {
    "displayName": "AVNM - Add lab spoke VNets to network group",
    "description": "Assigns lab spoke VNets to AVNM network group based on tags.",
    "policyDefinitionId": "$POLICY_DEFINITION_ID",
    "enforcementMode": "Default"
  }
}
JSON
)

az rest \
  --method put \
  --uri "$POLICY_ASSIGNMENT_URI" \
  --headers "Content-Type=application/json" \
  --body "$POLICY_ASSIGNMENT_BODY" \
  --output table

echo
echo "Policy criada e atribuída."
echo "A associação dinâmica pode levar alguns minutos para aparecer no Azure Virtual Network Manager."
