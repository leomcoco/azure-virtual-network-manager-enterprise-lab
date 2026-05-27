#!/usr/bin/env bash

set -euo pipefail

# Evita que o Git Bash no Windows converta resource IDs do Azure.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

RESOURCE_GROUP_NAME="rg-avnm-lab"

POLICY_DEFINITION_NAME="avnm-add-lab-spokes-to-network-group"
POLICY_ASSIGNMENT_NAME="avnm-add-lab-spokes-to-network-group-assignment"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "Não foi possível obter a subscription ativa."
  exit 1
fi

echo "Este script removerá os recursos do laboratório."
echo
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Policy Assignment: $POLICY_ASSIGNMENT_NAME"
echo "Policy Definition: $POLICY_DEFINITION_NAME"
echo

read -r -p "Digite DELETE para confirmar: " CONFIRMATION

if [[ "$CONFIRMATION" != "DELETE" ]]; then
  echo "Operação cancelada."
  exit 0
fi

echo
echo "==> Removendo Policy Assignment, se existir"

if az policy assignment show \
  --name "$POLICY_ASSIGNMENT_NAME" \
  --scope "/subscriptions/$SUBSCRIPTION_ID" >/dev/null 2>&1; then

  az policy assignment delete \
    --name "$POLICY_ASSIGNMENT_NAME" \
    --scope "/subscriptions/$SUBSCRIPTION_ID"

  echo "Policy Assignment removida."
else
  echo "Policy Assignment não encontrada."
fi

echo
echo "==> Removendo Policy Definition, se existir"

if az policy definition show \
  --name "$POLICY_DEFINITION_NAME" \
  --subscription "$SUBSCRIPTION_ID" >/dev/null 2>&1; then

  az policy definition delete \
    --name "$POLICY_DEFINITION_NAME" \
    --subscription "$SUBSCRIPTION_ID"

  echo "Policy Definition removida."
else
  echo "Policy Definition não encontrada."
fi

echo
echo "==> Removendo Resource Group"

if az group show --name "$RESOURCE_GROUP_NAME" >/dev/null 2>&1; then
  az group delete \
    --name "$RESOURCE_GROUP_NAME" \
    --yes \
    --no-wait

  echo "Remoção do Resource Group iniciada."
else
  echo "Resource Group não encontrado."
fi

echo
echo "Cleanup iniciado. A exclusão dos recursos pode levar alguns minutos."
