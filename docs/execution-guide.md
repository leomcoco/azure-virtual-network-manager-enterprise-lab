# Guia de execução

Este guia descreve como executar o laboratório do Azure Virtual Network Manager.

A forma recomendada é usar o Azure Cloud Shell em modo Bash. Também é possível executar no Git Bash no Windows, desde que o Azure CLI esteja autenticado na subscription correta.

## 1. Validar a subscription ativa

```bash
az account show --output table
```

Se necessário, selecione a subscription correta:

```bash
az account set --subscription "<SUBSCRIPTION_ID>"
```

## 2. Clonar o repositório

```bash
git clone https://github.com/leomcoco/azure-virtual-network-manager-enterprise-lab.git
cd azure-virtual-network-manager-enterprise-lab
```

## 3. Permitir execução dos scripts

```bash
chmod +x scripts/*.sh
```

## 4. Validar pré-requisitos

```bash
./scripts/00-prereqs.sh
```

## 5. Criar o laboratório

```bash
./scripts/01-deploy-avnm-lab.sh
```

## 6. Criar policy de associação dinâmica

```bash
./scripts/02-create-policy-add-to-network-group.sh
```

## 7. Criar baseline de Security Admin Rule

```bash
./scripts/03-create-security-admin-baseline.sh
```

## 8. Validar o laboratório

```bash
./scripts/04-validate-avnm-lab.sh
```

## 9. Remover os recursos

```bash
./scripts/99-cleanup.sh
```

## Observação para Git Bash no Windows

Os scripts definem as variáveis `MSYS_NO_PATHCONV=1` e `MSYS2_ARG_CONV_EXCL="*"` para evitar que resource IDs do Azure iniciados por `/subscriptions/...` sejam convertidos automaticamente para caminhos locais do Windows.

Exemplo de resource ID esperado:

```text
/subscriptions/<subscription-id>
```

Exemplo do problema quando a conversão acontece:

```text
C:/Program Files/Git/subscriptions/<subscription-id>
```

Se o Azure CLI retornar `No subscriptions found`, o login foi feito no tenant ou conta incorreta. Nesse caso, use o Cloud Shell ou refaça o login informando explicitamente o tenant da subscription.
