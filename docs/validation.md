# Validação do laboratório

## Validar VNets

```bash
az network vnet list \
  --resource-group rg-avnm-lab \
  --output table
```

Resultado esperado:

- `vnet-hub-shared-001`
- `vnet-spoke-app-001`
- `vnet-spoke-data-001`

## Validar Azure Virtual Network Manager

```bash
az network manager show \
  --resource-group rg-avnm-lab \
  --name avnm-lab-001 \
  --output table
```

## Validar Network Group

```bash
az network manager group show \
  --resource-group rg-avnm-lab \
  --network-manager-name avnm-lab-001 \
  --name ng-spokes-lab \
  --output table
```

## Validar membros estáticos

```bash
az network manager group static-member list \
  --resource-group rg-avnm-lab \
  --network-manager avnm-lab-001 \
  --network-group ng-spokes-lab \
  --output table
```

## Validar conectividade efetiva

```bash
az network manager list-effective-connectivity-config \
  --resource-group rg-avnm-lab \
  --virtual-network-name vnet-spoke-app-001 \
  --output json
```

## Validar security admin rule efetiva

```bash
az network manager list-effective-security-admin-rule \
  --resource-group rg-avnm-lab \
  --virtual-network-name vnet-spoke-app-001 \
  --output json
```
