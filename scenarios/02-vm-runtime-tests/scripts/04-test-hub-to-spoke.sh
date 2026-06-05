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

echo "==> Teste esperado: SUCESSO"
echo "Origem: $VM_HUB_NAME"
echo "Destino: $VM_SPOKE_DYNAMIC_NAME ($TARGET_IP:8080)"

TEST_SCRIPT=$(cat <<PY
python3 - <<'PYTHON'
import socket
host = "$TARGET_IP"
port = 8080
try:
    s = socket.create_connection((host, port), timeout=5)
    s.close()
    print(f"PASS: {host}:{port} reachable from hub VM")
except Exception as e:
    print(f"FAIL: {host}:{port} not reachable from hub VM: {e}")
    raise SystemExit(1)
PYTHON
PY
)

az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$VM_HUB_NAME" \
  --command-id RunShellScript \
  --scripts "$TEST_SCRIPT" \
  --output table

echo
echo "Teste Hub -> Spoke na porta 8080 concluído. Próximo passo: ./scripts/05-test-spoke-to-spoke.sh"
