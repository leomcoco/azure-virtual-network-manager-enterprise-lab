# Resultados esperados — Cenário 02

## Associação dinâmica

`vnet-spoke-dynamic-001` deve receber as configurações do AVNM por atender às tags esperadas:

- `environment=lab`
- `workload=avnm-demo`
- `role=spoke`

`vnet-outofpolicy-001` não deve receber as mesmas configurações por não atender ao critério de tags.

## Testes com VMs

| Teste | Resultado esperado |
|---|---|
| Hub -> Spoke Dynamic porta 8080 | Sucesso |
| Spoke App -> Spoke Dynamic porta 8080 | Falha ou timeout |
| Hub -> Spoke Dynamic porta 3389 | Falha ou timeout |
| NSG permite 3389, mas AVNM nega | Falha ou timeout |

## Configurações efetivas

A VNet `vnet-spoke-dynamic-001` deve apresentar:

- connectivity configuration efetiva do tipo HubAndSpoke;
- security admin rule efetiva `deny-rdp-inbound-to-spokes`;
- ação Deny para porta 3389.

## Observação

Os testes de falha são intencionais. Eles validam segmentação e guardrail central de segurança.
