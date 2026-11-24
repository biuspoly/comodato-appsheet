# comodato-appsheet

A **primeira automação de comodato** de uma distribuidora de bebidas, em R.
Ela mantém atualizada uma planilha Google que serve de base para um app
**AppSheet** usado pelas revendas para acompanhar quais contratos de comodato
(CEV) já voltaram assinados.

> **Todos os dados deste repositório são fictícios.** Empresas, clientes, CNPJs
> e caminhos de anexos foram inventados. Nenhuma credencial está no código:
> conta Google e URL da planilha são lidas por `obter_credencial(nome)`.

## Como se encaixa no processo de comodato

1. O comodato (empréstimo de chopeira, freezer, mesas etc. a um cliente) é
   registrado no sistema da distribuidora e gera um **CEV** — o termo que o
   cliente precisa assinar.
2. Quando o termo assinado volta, o PDF é anexado ao CEV (tabela de anexos).
3. **Este script** roda em loop (a cada 2 minutos):
   - consulta os comodatos e o status de assinatura (assinado = tem anexo válido);
   - grava a aba `comodatos_geral` na planilha Google que alimenta o AppSheet,
     onde as revendas acompanham o que falta assinar.
4. Depois, essa etapa evoluiu para a automação que gera o PDF e envia direto
   para assinatura eletrônica (repositório `comodato-cev`).

## Estrutura

```
comodato-appsheet/
├── comodato_sheet.R              # loop: banco -> planilha Google
├── aplicacao_cev.bat             # atalho Windows
├── dados/
│   ├── gerar_dados_ficticios.R   # gera os Parquet abaixo
│   ├── TB_COMODATO.parquet
│   ├── TB_EMPRESAS.parquet
│   ├── TB_COMOD_SOLICITADO.parquet
│   └── tb_anexos_cev.parquet
├── .env.example
└── .gitignore
```

No ambiente real as quatro tabelas vinham de um MariaDB (`bd_comodato`). Aqui
são arquivos Parquet fictícios com as mesmas colunas usadas no SELECT original
(que ficou comentado no script, ao lado da versão em `dplyr`).

## Credenciais

Os segredos (conta Google e URL/ID da planilha) são lidos só pela função
`obter_credencial(nome)`, no início do `comodato_sheet.R`. Hoje ela lê variáveis
de ambiente (que podem vir do `.env`); para ligar num cofre de senhas basta trocar
o corpo dessa função. O `.env.example` lista só os nomes.

## Modo demonstração

É o padrão (`CEV_MODO_DEMO` ausente ou diferente de `0`):

- **Google Sheets**: em vez de `write_sheet()`, grava a aba em `saida/comodatos_geral.csv`;
- o loop roda só `MAX_CICLOS` vezes (padrão 2, a cada `INTERVALO_SEGUNDOS`, padrão 5).

Para usar de verdade: copie `.env.example` para `.env`, preencha conta Google e
URL da planilha e use `CEV_MODO_DEMO=0` (o loop volta a ser infinito, a cada 120 s).
Na primeira execução o `googlesheets4` abre o navegador para autorizar a conta e
guarda o token em `.secrets/` (ignorada pelo git).

## Como rodar

Requisitos: R ≥ 4.2 com `dplyr`, `glue`, `nanoparquet` (e, só no modo real,
`googlesheets4`).

```r
install.packages(c("dplyr", "glue", "nanoparquet"))
```

Na pasta do repositório:

```bash
Rscript dados/gerar_dados_ficticios.R   # (opcional) regerar os dados
Rscript comodato_sheet.R
```

## Observações

- O script original também comparava cada ciclo com o anterior (pacote `arsenal`)
  para avisar quando um CEV passava de "Não assinado" para "Assinado". Esse aviso
  era a única finalidade da comparação (e de uma segunda consulta com motorista e
  usuário do app), então tudo isso foi retirado desta versão. O acompanhamento do
  status continua na própria planilha/AppSheet.
