# Cenário 02 — Testes reais com VMs para Azure Virtual Network Manager

Este cenário complementa o laboratório base de Azure Virtual Network Manager.

Ele não altera os scripts principais do laboratório anterior e não remove recursos base como AVNM, network group, connectivity configuration, security admin configuration ou policies.

## Objetivo

Validar o comportamento real do AVNM usando VNets e VMs:

- criar uma nova spoke com tags de governança;
- criar uma VNet fora do padrão;
- criar VMs Linux sem IP público;
- iniciar serviços TCP de teste nas portas 8080 e 3389;
- validar conectividade hub-spoke;
- validar ausência de comunicação direta entre spokes;
- validar bloqueio da porta 3389 por Security Admin Rule;
- validar configurações efetivas do AVNM.

## Pré-requisito

Antes de executar este cenário, o laboratório base precisa estar criado.

Execute os scripts principais na raiz do repositório, se ainda não tiver feito isso:

```bash
./scripts/00-prereqs.sh
./scripts/01-deploy-avnm-lab.sh
./scripts/02-create-policy-add-to-network-group.sh
./scripts/03-create-security-admin-baseline.sh
./scripts/04-validate-avnm-lab.sh
```

## Como executar

A partir desta pasta:

```bash
cd scenarios/02-vm-runtime-tests
chmod +x scripts/*.sh
```

Execute um script por vez:

```bash
./scripts/00-validate-base-lab.sh
./scripts/01-create-dynamic-vnets.sh
./scripts/02-create-test-vms.sh
./scripts/03-start-test-services.sh
./scripts/04-test-hub-to-spoke.sh
./scripts/05-test-spoke-to-spoke.sh
./scripts/06-test-security-admin-deny.sh
./scripts/07-validate-effective-configs.sh
```

## Validações importantes

O script `04-test-hub-to-spoke.sh` valida se existe peering AVNM em estado `Connected` entre o hub e a spoke dinâmica antes de testar a porta 8080.

O script `06-test-security-admin-deny.sh` valida a conectividade base na porta 8080 antes de testar o bloqueio da porta 3389.

Essa validação é importante porque um timeout na porta 3389 só é uma boa evidência de bloqueio da Security Admin Rule se houver conectividade base funcionando entre hub e spoke.

## Como coletar evidências

Capture prints dos seguintes pontos:

1. Nova VNet `vnet-spoke-dynamic-001` com tags corretas.
2. VNet `vnet-outofpolicy-001` sem as tags de entrada no modelo.
3. VMs sem IP público.
4. Run Command iniciando serviços nas portas 8080 e 3389.
5. Peering AVNM Hub <-> Spoke dinâmica em estado `Connected`.
6. Teste Hub -> Spoke na porta 8080 com resultado `PASS`.
7. Teste Spoke -> Spoke na porta 8080 com resultado `PASS: not reachable`.
8. NSG permitindo porta 3389.
9. Teste Hub -> Spoke na porta 3389 com resultado `PASS: blocked or timed out`.
10. Effective connectivity configuration.
11. Effective security admin rule.
12. Estrutura deste cenário no GitHub.

Não use como evidência positiva prints com `FAIL`, `timed out` em testes esperados como sucesso ou erro de placeholder.

## Cleanup

Depois de capturar as evidências:

```bash
./scripts/99-cleanup-runtime-tests.sh
```

Digite `DELETE` para confirmar.

Esse cleanup remove apenas os recursos criados neste cenário. O laboratório base permanece preservado.
