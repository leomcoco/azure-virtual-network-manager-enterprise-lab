# Scripts de diagnóstico AVNM — cenário 02

Estes scripts não substituem os testes do laboratório. Eles servem para coletar evidências detalhadas quando a Connectivity Configuration do Azure Virtual Network Manager aparece como `Succeeded`, mas as VNets ficam com `Resource status = Failed` e os peerings `ANM_*` não são criados.

## Scripts adicionados

- `11-collect-avnm-troubleshooting-bundle.sh`
  - Não altera recursos.
  - Coleta estado do AVNM, VNets, peerings, policy assignments, effective configs e Activity Log.

- `12-redeploy-connectivity-with-debug.sh`
  - Executa novamente o `post-commit` de Connectivity com `--debug`.
  - Aguarda os peerings e coleta logs detalhados do redeploy.

## Como executar

A partir de `scenarios/02-vm-runtime-tests`:

```bash
chmod +x scripts/*.sh

./scripts/11-collect-avnm-troubleshooting-bundle.sh
```

Depois:

```bash
./scripts/12-redeploy-connectivity-with-debug.sh
```

Os arquivos serão gerados em:

```text
evidence/troubleshooting/<timestamp>
```

## Arquivos mais importantes

- `summary.log`
- `json/06-deploy-status.jsonc`
- `json/04-connectivity-config.jsonc`
- `json/activity-log-avnm-policy-peering.jsonc`
- `table/activity-log-avnm-policy-peering.table`
- `logs/01-post-commit-debug.log`
- `json/91-activity-log-after-failure.jsonc`
- `table/peerings-hub-final.table`, se houver sucesso
- `table/peerings-dynamic-final.table`, se houver sucesso

## Interpretação

Se aparecer `RequestDisallowedByPolicy`, ainda existe alguma policy bloqueando `Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write`.

Se não aparecer `virtualNetworkPeerings/write` no Activity Log após o post-commit, o AVNM não chegou a tentar criar os peerings nessa execução.

Se aparecer `Conflict`, pode haver estado residual ou peering manual interferindo.

Só avance para os testes `04`, `05` e `06` quando os peerings Hub <-> Spoke dinâmica estiverem `Connected`.
