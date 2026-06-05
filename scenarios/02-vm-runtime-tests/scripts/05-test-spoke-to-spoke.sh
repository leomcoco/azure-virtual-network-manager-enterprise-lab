#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_az_login
TARGET_IP=$(get_vm_private_ip "$VM_SPOKE_DYNAMIC_NAME")

if [[ -z "$TARGET_IP" ]]; then
  echo "Não foi possível obter o IP privado da VM $VM_SPOKE_DYNAMIC_NAME."
  exit 1
fi

echo "==> Teste esperado: FALHA/TIMEOUT"
echo "Origem: $VM_SPOKE_APP_NAME"
echo "Destino: $VM_SPOKE_DYNAMIC_NAME ($TARGET_IP:8080)"
echo "Motivo esperado: hub-spoke sem direct connectivity entre spokes."

TEST_SCRIPT=$(cat <<PY
python3 - <<'PYTHON'
import socket
host = "$TARGET_IP"
port = 8080
try:
    s = socket.create_connection((host, port), timeout=5)
    s.close()
    print(f"UNEXPECTED: {host}:{port} reachable from spoke VM")
    raise SystemExit(1)
except Exception as e:
    print(f"PASS: {host}:{port} not reachable from spoke VM, as expected: {e}")
PYTHON
PY
)

az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$VM_SPOKE_APP_NAME" \
  --command-id RunShellScript \
  --scripts "$TEST_SCRIPT" \
  --output table

echo
echo "Teste Spoke -> Spoke concluído. Próximo passo: ./scripts/06-test-security-admin-deny.sh"
