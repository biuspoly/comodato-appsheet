library(glue)
library(dplyr)
library(nanoparquet)

# Pasta do repositorio (funciona com Rscript e com source)
arq_script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
if (length(arq_script) == 1) setwd(dirname(normalizePath(arq_script)))

# ===============================
# CREDENCIAIS
# ===============================
# Ponto UNICO de leitura de segredos (conta Google, ID/URL da planilha).
# Hoje le variaveis de ambiente (que podem vir do .env); para usar um cofre de
# senhas (Vault, Azure Key Vault, AWS Secrets Manager, keyring...) basta trocar
# o corpo desta funcao. Devolve "" quando a credencial nao existe.
obter_credencial <- function(nome) {
  Sys.getenv(nome, "")
}

# Carrega o .env (CHAVE=valor); chaves sem valor sao ignoradas
if (file.exists(".env")) {
  for (linha in trimws(readLines(".env", warn = FALSE, encoding = "UTF-8"))) {
    if (linha == "" || startsWith(linha, "#") || !grepl("=", linha, fixed = TRUE)) next
    valor <- gsub('^"|"$', "", trimws(sub("^[^=]*=", "", linha)))
    if (nzchar(valor)) do.call(Sys.setenv, setNames(list(valor), trimws(sub("=.*$", "", linha))))
  }
}

# Modo demonstracao (padrao): nao fala com o Google Sheets; grava a aba em saida/*.csv
modo_demo <- function() Sys.getenv("CEV_MODO_DEMO", "1") != "0"

max_ciclos <- as.numeric(Sys.getenv("MAX_CICLOS", if (modo_demo()) "2" else "Inf"))
intervalo  <- as.numeric(Sys.getenv("INTERVALO_SEGUNDOS", if (modo_demo()) "5" else "120"))

# ===============================
# GOOGLE SHEETS
# ===============================
url_planilha <- obter_credencial("PLANILHA_URL")

if (!modo_demo()) {
  googlesheets4::gs4_auth(
    email = obter_credencial("GOOGLE_SHEETS_EMAIL"),
    cache = ".secrets/"
  )
}

gravar_planilha <- function(dados, aba) {
  if (modo_demo() || url_planilha == "") {
    dir.create("saida", showWarnings = FALSE)
    arq <- file.path("saida", paste0(aba, ".csv"))
    write.csv(dados, arq, row.names = FALSE, fileEncoding = "UTF-8")
    cat(glue("[DEMO] aba '{aba}' gravada em {arq} ({nrow(dados)} linhas)"), "\n")
  } else {
    googlesheets4::write_sheet(
      data = dados,
      ss = url_planilha,
      sheet = aba
    )
  }
}

# ===============================
# BANCO (antes MariaDB bd_comodato; agora Parquet ficticio em dados/)
# ===============================
ler_tabela <- function(nome) as.data.frame(read_parquet(file.path("dados", paste0(nome, ".parquet"))))

# Equivale ao SELECT original:
#   SELECT DISTINCT E.EMPRESA, C.CEV, C.NF, c.CODCLI AS Cliente, c.FANTASIA AS Fantasia,
#          c.NOME AS 'Razão Social', c.DTE AS 'Data Emissão', c.DTV AS 'Data Vencimento',
#          REPLACE(REPLACE(a.anexoN, 'Anexos/', 'Anexos_Comodato/'), '.PDF', '.pdf') as anexoN,
#          c.CNPJ_REV AS cnpj,
#          CASE WHEN a.anexo1 IS NULL AND a.anexo2 IS NULL AND a.anexo3 IS NULL
#               THEN 'Não assinado' ELSE 'Assinado' END AS status_assinatura,
#          c.PRE_PED
#   FROM TB_COMODATO C
#   LEFT JOIN TB_EMPRESAS E ON E.CNPJ_EMP = C.CNPJ_REV
#   LEFT JOIN TB_COMOD_SOLICITADO S ON C.PRE_PED = S.PRE_PED
#   LEFT JOIN tb_anexos_cev A ON A.CNPJ_REV = C.CNPJ_REV AND A.ncev = C.CEV AND A.situacao <> 'X'
#   WHERE S.PRE_PED IS NOT NULL AND S.PRE_PED >= 202603240000
consultar_comodatos <- function() {
  C <- ler_tabela("TB_COMODATO")
  E <- ler_tabela("TB_EMPRESAS")
  S <- ler_tabela("TB_COMOD_SOLICITADO")
  A <- ler_tabela("tb_anexos_cev") %>% filter(situacao != "X")

  ajusta <- function(x) gsub(".PDF", ".pdf", gsub("Anexos/", "Anexos_Comodato/", x, fixed = TRUE), fixed = TRUE)

  C %>%
    left_join(E, by = c("CNPJ_REV" = "CNPJ_EMP")) %>%
    left_join(S %>% distinct(PRE_PED) %>% mutate(.s = TRUE), by = "PRE_PED") %>%
    left_join(A, by = c("CNPJ_REV" = "CNPJ_REV", "CEV" = "ncev")) %>%
    filter(!is.na(.s), PRE_PED >= 202603240000) %>%
    transmute(EMPRESA, CEV, NF,
              Cliente = CODCLI, Fantasia = FANTASIA, `Razão Social` = NOME,
              `Data Emissão` = DTE, `Data Vencimento` = DTV,
              anexo1 = ajusta(anexo1), anexo2 = ajusta(anexo2), anexo3 = ajusta(anexo3),
              cnpj = CNPJ_REV,
              status_assinatura = if_else(is.na(anexo1) & is.na(anexo2) & is.na(anexo3),
                                          "Não assinado", "Assinado"),
              PRE_PED) %>%
    distinct()
}

ciclo <- 0

# ===============================
# LOOP
# ===============================
while (ciclo < max_ciclos) {

  ciclo <- ciclo + 1
  cat(glue("\n---- ciclo {ciclo} ({format(Sys.time(), '%H:%M:%S')}) ----"), "\n")

  tryCatch({

    # ===============================
    # COMODATOS GERAL (PLANILHA)
    # ===============================
    comodatos_geral <- consultar_comodatos()

    gravar_planilha(comodatos_geral, "comodatos_geral")

    cat(glue("  {sum(comodatos_geral$status_assinatura == 'Assinado')} assinado(s), ",
             "{sum(comodatos_geral$status_assinatura == 'Não assinado')} pendente(s)"), "\n")

  }, error = function(e) {
    cat("\nERRO:", e$message, "\n")
  })

  if (ciclo < max_ciclos) Sys.sleep(intervalo)
}
