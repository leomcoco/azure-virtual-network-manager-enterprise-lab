#!/usr/bin/env bash

set -euo pipefail

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

echo "==> Validando existência do Network Group"

az network manager group show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --network-manager-name "$NETWORK_MANAGER_NAME" \
  --name "$NETWORK_GROUP_NAME" \
  --output table

echo
echo "==> Gerando policy rule com Network Group ID completo"

POLICY_RULE_FILE="/tmp/avnm-add-to-network-group-policy-rule.json"

cat > "$POLICY_RULE_FILE" <<POLICY_JSON
{
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
POLICY_JSON

echo
echo "==> Criando ou atualizando policy definition"

if az policy definition show \
  --name "$POLICY_DEFINITION_NAME" \
  --subscription "$SUBSCRIPTION_ID" >/dev/null 2>&1; then

  echo "Policy definition já existe. Atualizando..."

  az policy definition update \
    --name "$POLICY_DEFINITION_NAME" \
    --display-name "AVNM - Add lab spoke VNets to network group" \
    --description "Adds lab spoke VNets to an Azure Virtual Network Manager network group based on tags." \
    --mode "Microsoft.Network.Data" \
    --rules "$POLICY_RULE_FILE" \
    --subscription "$SUBSCRIPTION_ID" \
    --output table
else
  echo "Criando nova policy definition..."

  az policy definition create \
    --name "$POLICY_DEFINITION_NAME" \
    --display-name "AVNM - Add lab spoke VNets to network group" \
    --description "Adds lab spoke VNets to an Azure Virtual Network Manager network group based on tags." \
    --mode "Microsoft.Network.Data" \
    --rules "$POLICY_RULE_FILE" \
    --subscription "$SUBSCRIPTION_ID" \
    --output table
fi

POLICY_DEFINITION_ID="/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/policyDefinitions/$POLICY_DEFINITION_NAME"

echo
echo "==> Criando policy assignment"

if az policy assignment show \
  --name "$POLICY_ASSIGNMENT_NAME" \
  --scope "/subscriptions/$SUBSCRIPTION_ID" >/dev/null 2>&1; then

  echo "Policy assignment já existe. Mantendo assignment atual."
else
  az policy assignment create \
    --name "$POLICY_ASSIGNMENT_NAME" \
    --display-name "AVNM - Add lab spoke VNets to network group" \
    --description "Assigns lab spoke VNets to AVNM network group based on tags." \
    --scope "/subscriptions/$SUBSCRIPTION_ID" \
    --policy "$POLICY_DEFINITION_ID" \
    --output table
fi

echo
echo "Policy criada e atribuída."
echo "A associação dinâmica pode levar alguns minutos para aparecer no Azure Virtual Network Manager."
