# Guia de prints do laboratório

Este arquivo não armazena os prints do laboratório.

Ele serve como guia para indicar quais telas devem ser capturadas durante a execução e usadas no artigo do WordPress.

Os prints principais devem ser inseridos no artigo publicado no WordPress. O GitHub mantém este guia para ajudar outras pessoas a reproduzirem a validação e entenderem quais evidências são relevantes.

## Print 1 — Azure Virtual Network Manager

**Onde capturar:** Azure Portal > Azure Virtual Network Manager > `avnm-lab-001`

**Objetivo:** comprovar que a instância do Azure Virtual Network Manager foi criada.

**Legenda sugerida:** Instância do Azure Virtual Network Manager criada para governar as redes do laboratório.

**ALT text sugerido:** Tela do Azure Virtual Network Manager mostrando a instância criada para governança de redes virtuais.

## Print 2 — Network Group

**Onde capturar:** Azure Virtual Network Manager > Network Groups > `ng-spokes-lab`

**Objetivo:** mostrar o grupo usado para organizar as VNets spoke.

**Legenda sugerida:** Network group usado para organizar as redes spoke do laboratório.

**ALT text sugerido:** Grupo de rede no Azure Virtual Network Manager com VNets spoke associadas.

## Print 3 — Static Members

**Onde capturar:** Network Group `ng-spokes-lab` > Static members

**Objetivo:** comprovar que as VNets `vnet-spoke-app-001` e `vnet-spoke-data-001` foram associadas ao grupo.

**Legenda sugerida:** VNets spoke associadas ao network group do laboratório.

**ALT text sugerido:** VNets spoke associadas como membros estáticos de um network group.

## Print 4 — Connectivity Configuration

**Onde capturar:** Azure Virtual Network Manager > Configurations > Connectivity configuration `cc-hub-spoke-lab`

**Objetivo:** mostrar a configuração de conectividade hub-spoke.

**Legenda sugerida:** Configuração hub-spoke aplicada pelo Azure Virtual Network Manager.

**ALT text sugerido:** Configuração de conectividade hub-spoke no Azure Virtual Network Manager.

## Print 5 — Security Admin Rule

**Onde capturar:** Azure Virtual Network Manager > Security admin configurations > `sac-baseline-lab`

**Objetivo:** demonstrar a baseline de segurança administrativa criada no laboratório.

**Legenda sugerida:** Security admin rule usada para aplicar uma baseline de segurança no laboratório.

**ALT text sugerido:** Regra administrativa de segurança configurada no Azure Virtual Network Manager.

## Print 6 — Validação no terminal

**Onde capturar:** Terminal com a execução do script `04-validate-avnm-lab.sh`

**Objetivo:** comprovar que os recursos foram criados e que as configurações efetivas foram consultadas.

**Legenda sugerida:** Validação do laboratório executada com Azure CLI.

**ALT text sugerido:** Terminal mostrando validação dos recursos criados no laboratório de Azure Virtual Network Manager.

## Print 7 — Repositório GitHub

**Onde capturar:** Página inicial do repositório no GitHub.

**Objetivo:** evidenciar que os artefatos do laboratório foram publicados para a comunidade.

**Legenda sugerida:** Repositório público com scripts e documentação do laboratório.

**ALT text sugerido:** Repositório GitHub com artefatos técnicos do laboratório de Azure Virtual Network Manager.

## Cuidados antes de publicar prints

Antes de publicar qualquer imagem no WordPress ou GitHub, oculte:

- subscription ID;
- tenant ID;
- e-mails;
- nomes de ambientes reais;
- dados corporativos;
- identificadores internos;
- qualquer informação sensível.

## Armazenamento dos prints

Para este laboratório, a recomendação é inserir os prints principais diretamente no artigo do WordPress.

Não é obrigatório armazenar os arquivos de imagem no GitHub.

Se quiser publicar evidências adicionais no GitHub no futuro, crie uma pasta separada, por exemplo:

```text
evidence/screenshots/
```

Nesse caso, publique apenas imagens revisadas e sem dados sensíveis.
