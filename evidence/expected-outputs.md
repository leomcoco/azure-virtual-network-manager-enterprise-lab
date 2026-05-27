# Saídas esperadas

## Resource Group

`rg-avnm-lab` criado com sucesso.

## VNets

Devem existir três VNets:

- `vnet-hub-shared-001`
- `vnet-spoke-app-001`
- `vnet-spoke-data-001`

## Azure Virtual Network Manager

Deve existir a instância:

- `avnm-lab-001`

## Network Group

Deve existir o grupo:

- `ng-spokes-lab`

## Connectivity Configuration

Deve existir a configuração:

- `cc-hub-spoke-lab`

## Security Admin Configuration

Deve existir a configuração:

- `sac-baseline-lab`

## Security Admin Rule

Deve existir a regra:

- `deny-rdp-inbound-to-spokes`

## Validação final

As VNets spoke devem apresentar configuração efetiva de conectividade e regra administrativa de segurança após o commit das configurações.
