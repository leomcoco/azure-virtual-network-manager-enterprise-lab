# Azure Virtual Network Manager Enterprise Lab

Laboratório prático para demonstrar o uso do Azure Virtual Network Manager na governança de conectividade e segurança de redes Azure em escala enterprise.

Este repositório acompanha o artigo:

**Azure Virtual Network Manager na prática: conectividade e segurança de redes em escala enterprise**

## Objetivo

Criar um laboratório controlado com Azure Virtual Network Manager para demonstrar:

- criação de VNets hub e spoke;
- criação de um Azure Virtual Network Manager;
- organização de VNets em network group;
- configuração de conectividade hub-spoke;
- exemplo de associação dinâmica com Azure Policy;
- exemplo de security admin rule de laboratório;
- validação da configuração aplicada;
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

## Pré-requisitos

- Subscription Azure para laboratório
- Azure Cloud Shell com Bash ou Git Bash com Azure CLI autenticada
- Permissão para criar recursos de rede
- Permissão para criar Azure Policy definition e assignment
- Permissão para criar recursos no escopo da subscription

## Como executar

Recomendação para maior compatibilidade: execute no Azure Cloud Shell em modo Bash.

```bash
git clone https://github.com/leomcoco/azure-virtual-network-manager-enterprise-lab.git
cd azure-virtual-network-manager-enterprise-lab
chmod +x scripts/*.sh

./scripts/00-prereqs.sh
./scripts/01-deploy-avnm-lab.sh
./scripts/02-create-policy-add-to-network-group.sh
./scripts/03-create-security-admin-baseline.sh
./scripts/04-validate-avnm-lab.sh
```

## Como remover os recursos

```bash
./scripts/99-cleanup.sh
```

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

Este laboratório foi criado para estudo e demonstração. Antes de adaptar para produção, revise escopo, permissões, naming convention, tagging, security admin rules, conectividade, processo de mudança e rollback.

## Licença

Este projeto está licenciado sob a MIT License.
