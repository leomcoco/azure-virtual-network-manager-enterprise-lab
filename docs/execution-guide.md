# Guia de execução

Este guia descreve como executar o laboratório no Azure Cloud Shell usando Bash.

## 1. Abrir Azure Cloud Shell

Acesse o Azure Portal e abra o Cloud Shell em modo Bash.

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

## 7. Criar security admin baseline

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
