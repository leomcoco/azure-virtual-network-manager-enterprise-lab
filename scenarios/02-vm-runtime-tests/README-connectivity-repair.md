# Correção incremental — diagnóstico e reparo de conectividade

Arquivos adicionados:

- `scripts/09-diagnose-avnm-connectivity.sh`
- `scripts/10-repair-connectivity-config-with-cli.sh`

Use o diagnóstico antes de continuar os testes com VMs:

```bash
./scripts/09-diagnose-avnm-connectivity.sh
```

Se a configuração efetiva aparecer, mas os peerings continuarem ausentes, execute o reparo:

```bash
./scripts/10-repair-connectivity-config-with-cli.sh
```

Esse reparo atualiza a connectivity configuration usando `az network manager connect-config update`, em vez de recriar o JSON diretamente via ARM REST. A intenção é eliminar divergência de schema ou propriedades aceitas pela API, mas que não estejam sendo materializadas como peering.

Só continue para os testes de VMs se aparecer:

```text
PASS: peering AVNM Hub <-> Spoke dinâmica encontrado em estado Connected.
```
