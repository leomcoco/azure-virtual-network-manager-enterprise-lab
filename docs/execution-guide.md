# Guia de execução

Este guia descreve como executar o laboratório do Azure Virtual Network Manager.

A forma recomendada é usar o Azure Cloud Shell em modo Bash. Isso reduz problemas de autenticação local, múltiplos tenants, MFA e versões diferentes de ferramentas.

## 1. Abrir o Azure Cloud Shell

No Azure Portal, abra o Cloud Shell e selecione **Bash**.

Confirme a subscription ativa:

```bash
az account show --output table