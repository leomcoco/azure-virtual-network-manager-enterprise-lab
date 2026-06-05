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
    socket.create_connection((host, port), timeout=5).close()
    print(f"UNEXPECTED: {host}:{port} reachable from spoke VM")
    raise SystemExit(1)
except Exception as e:
    print(f"PASS: {host}:{port} not reachable from spoke VM, as expected: {e}")
PYTHON
PY
)

OUTPUT=$(run_command_message "$VM_SPOKE_APP_NAME" "$TEST_SCRIPT")
echo "$OUTPUT"

if ! grep -q "PASS: $TARGET_IP:8080 not reachable from spoke VM" <<< "$OUTPUT"; then
  echo
  echo "FAIL: o teste Spoke -> Spoke não retornou o bloqueio esperado."
  exit 1
fi

echo
echo "Teste Spoke -> Spoke validado com sucesso."
echo "Próximo passo: ./scripts/06-test-security-admin-deny.sh"
