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
    s = socket.create_connection((host, port), timeout=5)
    s.close()
    print(f"UNEXPECTED: {host}:{port} reachable. Review Security Admin Rule deployment.")
    raise SystemExit(1)
except Exception as e:
    print(f"PASS: {host}:{port} blocked or timed out, as expected: {e}")
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
echo "Teste de bloqueio 3389 concluído. Próximo passo: ./scripts/07-validate-effective-configs.sh"
