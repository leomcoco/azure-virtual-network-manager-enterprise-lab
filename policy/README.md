# Azure Policy para associação dinâmica

Este laboratório cria a policy dinamicamente pelo script:

```bash
scripts/02-create-policy-add-to-network-group.sh
```

A policy usa o efeito `addToNetworkGroup`, específico do Azure Virtual Network Manager.

O `networkGroupId` é inserido como resource ID completo dentro da policy rule durante a execução do script. Isso evita deixar subscription ID fixo no repositório.
