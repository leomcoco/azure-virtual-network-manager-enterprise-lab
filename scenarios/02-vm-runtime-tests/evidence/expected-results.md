# Resultados esperados — Cenário 02

## VNet dinâmica

A VNet `vnet-spoke-dynamic-001` deve ter as tags:

- `environment = lab`
- `workload = avnm-demo`
- `role = spoke`
- `scenario = 02-vm-runtime-tests`

Resultado esperado: associada ao modelo governado pelo AVNM.

## VNet fora do padrão

A VNet `vnet-outofpolicy-001` não deve receber a mesma configuração efetiva do AVNM.

Resultado esperado no `07-validate-effective-configs.sh`:

```json
{
  "skipToken": "",
  "value": []
}
```

## Serviços na VM dinâmica

A VM `vm-spoke-dynamic-test-001` deve escutar nas portas:

- 8080
- 3389

## Conectividade Hub -> Spoke

O teste `04-test-hub-to-spoke.sh` deve retornar:

```text
PASS: 10.40.1.4:8080 reachable from hub VM
```

Se retornar timeout, não use como evidência positiva. Primeiro valide se existe peering AVNM em estado `Connected` entre o hub e a spoke dinâmica.

## Spoke -> Spoke

O teste `05-test-spoke-to-spoke.sh` deve retornar:

```text
PASS: 10.40.1.4:8080 not reachable from spoke VM, as expected
```

## Security Admin Rule

O teste `06-test-security-admin-deny.sh` deve primeiro confirmar a conectividade base na porta 8080:

```text
PASS-BASELINE: 10.40.1.4:8080 reachable from hub VM
```

Depois deve validar o bloqueio da porta 3389:

```text
PASS: 10.40.1.4:3389 blocked or timed out, as expected
```

## Configurações efetivas

O script `07-validate-effective-configs.sh` deve retornar:

- `connectivityTopology: HubAndSpoke`
- `access: Deny`
- `destinationPortRanges: 3389`
- VNet fora do padrão com `value: []`
