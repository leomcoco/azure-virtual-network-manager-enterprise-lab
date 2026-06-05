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

echo "==> Validando peering AVNM antes do teste de tráfego"
require_hub_to_dynamic_peering

echo
echo "==> Teste esperado: SUCESSO"
echo "Origem: $VM_HUB_NAME"
echo "Destino: $VM_SPOKE_DYNAMIC_NAME ($TARGET_IP:8080)"

TEST_SCRIPT=$(cat <<PY
python3 - <<'PYTHON'
import socket
host = "$TARGET_IP"
port = 8080
try:
    socket.create_connection((host, port), timeout=5).close()
    print(f"PASS: {host}:{port} reachable from hub VM")
except Exception as e:
    print(f"FAIL: {host}:{port} not reachable from hub VM: {e}")
    raise SystemExit(1)
PYTHON
PY
)

OUTPUT=$(run_command_message "$VM_HUB_NAME" "$TEST_SCRIPT")
echo "$OUTPUT"

if ! grep -q "PASS: $TARGET_IP:8080 reachable from hub VM" <<< "$OUTPUT"; then
  echo
  echo "FAIL: o teste Hub -> Spoke na porta 8080 não retornou PASS."
  echo "Não use esta execução como evidência positiva no artigo."
  exit 1
fi

echo
echo "Teste Hub -> Spoke na porta 8080 validado com sucesso."
echo "Próximo passo: ./scripts/05-test-spoke-to-spoke.sh"
