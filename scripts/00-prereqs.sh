#!/usr/bin/env bash

set -euo pipefail

# Evita conversão automática de resource IDs no Git Bash do Windows.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

echo "==> Validando Azure CLI"

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI não encontrada."
  echo "Execute este laboratório no Azure Cloud Shell ou instale a Azure CLI."
  exit 1
fi

az version --output table

echo
echo "==> Validando login no Azure"

if ! az account show >/dev/null 2>&1; then
  echo "Nenhuma sessão Azure ativa foi encontrada."
  echo "Execute: az login"
  exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "Não foi possível obter a subscription ativa."
  exit 1
fi

echo "Subscription ativa: $SUBSCRIPTION_NAME"
echo "Subscription ID: $SUBSCRIPTION_ID"
echo "Tenant ID: $TENANT_ID"

echo
echo "==> Instalando ou atualizando extensão virtual-network-manager"

az extension add \
  --name virtual-network-manager \
  --upgrade \
  --only-show-errors

echo
echo "==> Registrando resource provider Microsoft.Network, se necessário"

az provider register \
  --namespace Microsoft.Network \
  --only-show-errors

echo "Estado atual do provider Microsoft.Network:"
az provider show \
  --namespace Microsoft.Network \
  --query "registrationState" \
  --output tsv

echo
echo "Pré-requisitos validados."
