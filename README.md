# Azure Virtual Network Manager Enterprise Lab

Laboratório prático para demonstrar o uso do Azure Virtual Network Manager na governança de conectividade e segurança de redes Azure em escala enterprise.

Este repositório acompanha o artigo:

**Azure Virtual Network Manager na prática: conectividade e segurança de redes em escala enterprise**

Artigo publicado:  
https://leonardococo.com.br/azure-virtual-network-manager-governanca-redes-enterprise/

## Objetivo

Criar um laboratório controlado com Azure Virtual Network Manager para demonstrar:

- criação de VNets no padrão hub-spoke;
- criação de um Azure Virtual Network Manager;
- organização de VNets em network group;
- aplicação de connectivity configuration no padrão hub-spoke;
- exemplo de associação dinâmica com Azure Policy;
- criação de uma Security Admin Rule de laboratório;
- validação das configurações efetivas;
- limpeza dos recursos criados.

## Arquitetura do laboratório

```text
Azure Virtual Network Manager
├── Network Group: ng-spokes-lab
│   ├── vnet-spoke-app-001
│   └── vnet-spoke-data-001
│
├── Connectivity Configuration
│   └── Hub-Spoke
│
└── Security Admin Configuration
    └── Baseline de bloqueio administrativo para laboratório

Hub:
└── vnet-hub-shared-001
```

## Abordagem técnica

A criação dos recursos base é feita com Azure CLI.

As configurações do Azure Virtual Network Manager, como connectivity configuration, Azure Policy e security admin configuration, são aplicadas com ARM REST API via `az rest`.

Essa abordagem reduz problemas de parsing da extensão `virtual-network-manager` em ambientes locais com Git Bash no Windows e deixa o laboratório mais previsível para reprodução.

## Recursos criados

- Resource Group
- Azure Virtual Network Manager
- VNet Hub
- 2 VNets Spoke
- Network Group
- Static Members
- Connectivity Configuration
- Azure Policy customizada para associação dinâmica
- Security Admin Configuration de laboratório
- Security Admin Rule de laboratório

## Versões utilizadas no laboratório

Laboratório validado com:

- Azure CLI: 2.67.0
- Ambiente de execução: Git Bash no Windows / VS Code
- Data de execução do laboratório: 27/05/2026

Para validar a versão da extensão `virtual-network-manager`, execute:

```bash
az extension show --name virtual-network-manager --output table
```

## Pré-requisitos

- Subscription Azure para laboratório
- Azure Cloud Shell com Bash ou Git Bash com Azure CLI autenticada
- Permissão para criar recursos de rede
- Permissão para criar Azure Policy definition e assignment
- Permissão para criar recursos no escopo da subscription

## Observação para Git Bash no Windows

Este laboratório pode ser executado no Azure Cloud Shell em modo Bash, que é a opção recomendada.

Também é possível executar no Git Bash no Windows. Nesse caso, os scripts definem as variáveis `MSYS_NO_PATHCONV=1` e `MSYS2_ARG_CONV_EXCL="*"` para evitar que resource IDs do Azure iniciados por `/subscriptions/...` sejam convertidos automaticamente para caminhos locais do Windows.

Exemplo de resource ID esperado:

```text
/subscriptions/<subscription-id>
```

Exemplo do problema no Git Bash quando a conversão acontece:

```text
C:/Program Files/Git/subscriptions/<subscription-id>
```

Esse comportamento causa erro em comandos do Azure CLI que esperam um resource ID válido do Azure.

## Como executar

Recomendação para maior compatibilidade: execute no Azure Cloud Shell em modo Bash.

Clone o repositório:

```bash
git clone https://github.com/leomcoco/azure-virtual-network-manager-enterprise-lab.git
cd azure-virtual-network-manager-enterprise-lab
chmod +x scripts/*.sh
```

Execute um script por vez.

### 1. Validar pré-requisitos

```bash
./scripts/00-prereqs.sh
```

### 2. Criar o laboratório

```bash
./scripts/01-deploy-avnm-lab.sh
```

### 3. Criar policy de associação dinâmica

```bash
./scripts/02-create-policy-add-to-network-group.sh
```

### 4. Criar baseline de Security Admin Rule

```bash
./scripts/03-create-security-admin-baseline.sh
```

### 5. Validar o laboratório

```bash
./scripts/04-validate-avnm-lab.sh
```

## Como remover os recursos

```bash
./scripts/99-cleanup.sh
```

O script solicita confirmação manual. Digite `DELETE` para iniciar a remoção.

## Evidências esperadas

Ao final da execução, o laboratório deve validar:

- Resource Group criado;
- VNets hub e spokes criadas;
- Azure Virtual Network Manager criado;
- Network Group com as VNets spoke associadas;
- Connectivity Configuration no padrão hub-spoke;
- Azure Policy customizada criada e atribuída;
- Security Admin Configuration criada;
- Security Admin Rule efetiva para bloqueio de RDP inbound nas spokes.

Consulte também:

- `docs/validation.md`
- `docs/screenshots.md`
- `evidence/expected-outputs.md`

## Segurança

Este laboratório não usa dados reais, workloads produtivos, IPs públicos ou credenciais.

Não publique no repositório:

- subscription ID real em arquivos;
- tenant ID;
- e-mails;
- credenciais;
- chaves;
- secrets;
- prints com dados sensíveis;
- nomes de ambientes corporativos.

## Observações

Este laboratório foi criado para estudo e demonstração.

Antes de adaptar para produção, revise:

- escopo do Azure Virtual Network Manager;
- permissões;
- naming convention;
- tagging;
- Azure Policy;
- security admin rules;
- conectividade;
- processo de mudança;
- rollback.

## Licença

Este projeto está licenciado sob a MIT License.
