#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_az_login

echo "==> Iniciando serviços de teste na VM da spoke dinâmica"
echo "VM: $VM_SPOKE_DYNAMIC_NAME"
echo "Portas: 8080 e 3389"

az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$VM_SPOKE_DYNAMIC_NAME" \
  --command-id RunShellScript \
  --scripts '
set -e
pkill -f "python3 -m http.server 8080" || true
pkill -f "python3 -m http.server 3389" || true
nohup python3 -m http.server 8080 --bind 0.0.0.0 >/tmp/http-8080.log 2>&1 &
nohup python3 -m http.server 3389 --bind 0.0.0.0 >/tmp/http-3389.log 2>&1 &
sleep 3
ss -ltn | grep -E ":8080|:3389" || true
' \
  --output table

echo
echo "Serviços iniciados. Próximo passo: ./scripts/04-test-hub-to-spoke.sh"
