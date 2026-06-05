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

echo "==> Garantindo que o NSG local permite 3389 a partir de VirtualNetwork"
create_or_update_nsg_rule "$NSG_SPOKE_DYNAMIC_NAME" "Allow-3389-From-VirtualNetwork" 110 3389

echo
echo "==> Validando conectividade base na porta 8080 antes de testar o bloqueio da 3389"
BASELINE_SCRIPT=$(cat <<PY
python3 - <<'PYTHON'
import socket
host = "$TARGET_IP"
port = 8080
try:
    socket.create_connection((host, port), timeout=5).close()
    print(f"PASS-BASELINE: {host}:{port} reachable from hub VM")
except Exception as e:
    print(f"FAIL-BASELINE: {host}:{port} not reachable from hub VM: {e}")
    raise SystemExit(1)
PYTHON
PY
)

BASELINE_OUTPUT=$(run_command_message "$VM_HUB_NAME" "$BASELINE_SCRIPT")
echo "$BASELINE_OUTPUT"

if ! grep -q "PASS-BASELINE: $TARGET_IP:8080 reachable from hub VM" <<< "$BASELINE_OUTPUT"; then
  echo
  echo "FAIL: a porta 8080 não está acessível a partir do hub."
  echo "Sem essa conectividade base, timeout na porta 3389 não prova bloqueio da Security Admin Rule."
  exit 1
fi

echo
echo "==> Teste esperado: FALHA/TIMEOUT"
echo "Origem: $VM_HUB_NAME"
echo "Destino: $VM_SPOKE_DYNAMIC_NAME ($TARGET_IP:3389)"
echo "Motivo esperado: Security Admin Rule do AVNM bloqueia 3389 antes da avaliação do NSG."

TEST_SCRIPT=$(cat <<PY
python3 - <<'PYTHON'
import socket
host = "$TARGET_IP"
port = 3389
try:
    socket.create_connection((host, port), timeout=5).close()
    print(f"UNEXPECTED: {host}:{port} reachable. Review Security Admin Rule deployment.")
    raise SystemExit(1)
except Exception as e:
    print(f"PASS: {host}:{port} blocked or timed out, as expected: {e}")
PYTHON
PY
)

OUTPUT=$(run_command_message "$VM_HUB_NAME" "$TEST_SCRIPT")
echo "$OUTPUT"

if ! grep -q "PASS: $TARGET_IP:3389 blocked or timed out" <<< "$OUTPUT"; then
  echo
  echo "FAIL: o teste de bloqueio da porta 3389 não retornou PASS."
  exit 1
fi

echo
echo "Teste de bloqueio 3389 validado com sucesso."
echo "Próximo passo: ./scripts/07-validate-effective-configs.sh"
