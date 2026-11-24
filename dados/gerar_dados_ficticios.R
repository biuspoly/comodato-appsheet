# Gera os Parquet FICTICIOS que substituem as tabelas do MariaDB (bd_comodato)
# lidas pelo comodato_sheet.R. Mesmas colunas usadas no SELECT original.
# Empresas, clientes, CNPJs e caminhos de anexos sao inventados.
#
# Uso (na raiz do repositorio):  Rscript dados/gerar_dados_ficticios.R

library(nanoparquet)

arq_script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
dir_dados  <- if (length(arq_script) == 1) dirname(normalizePath(arq_script)) else "dados"

# TB_EMPRESAS --------------------------------------------------------------
TB_EMPRESAS <- data.frame(
  CNPJ_EMP = c("90000002000173", "90000001000129", "90000001000200",
               "90000003000118", "90000003000207", "90000004000162"),
  EMPRESA  = c("AURORA DISTRIBUIDORA DE BEBIDAS LTDA", "BOREAL NORTE COMERCIO DE BEBIDAS",
               "BOREAL SERTAO COMERCIO DE BEBIDAS", "CASCATA MA DISTRIBUICAO",
               "CASCATA FL DISTRIBUICAO", "DELTA BEBIDAS E LOGISTICA LTDA"),
  stringsAsFactors = FALSE
)

# TB_COMODATO --------------------------------------------------------------
TB_COMODATO <- data.frame(
  CEV      = c(7001L, 7002L, 8001L, 8002L, 8101L, 9001L, 9501L, 9502L, 6990L),
  NF       = as.character(500001:500009),
  MOT      = c("201", "201", "305", "305", "310", "401", "501", "502", "201"),
  CODCLI   = c("10001", "10002", "20001", "20002", "21001", "30001", "40001", "40002", "10003"),
  FANTASIA = c("BAR DO PORTO", "MERCADINHO BOA VISTA", "RESTAURANTE SABOR FICTICIO",
               "CONDOMINIO JARDIM EXEMPLO", "LANCHONETE ESQUINA", "BARRACA DA PRAIA",
               "ESPETINHO DO CENTRO", "QUIOSQUE BEIRA MAR", "BAR ANTIGO"),
  NOME     = c("ANA PAULA EXEMPLO", "MERCADINHO BOA VISTA LTDA", "RESTAURANTE SABOR FICTICIO LTDA",
               "CONDOMINIO RESIDENCIAL JARDIM EXEMPLO", "PEDRO DEMONSTRACAO", "LUCIA AMOSTRA",
               "RAFAEL FICTICIO", "BEATRIZ EXEMPLO LIMA", "MARIA ANTIGA"),
  DTE      = c("20260325", "20260325", "20260326", "20260326", "20260327", "20260327",
               "20260328", "20260328", "20260301"),
  DTV      = c("20270325", "20270325", "20270326", "20270326", "20270327", "20260426",
               "20270328", "20270328", "20270301"),
  CNPJ_REV = c("90000002000173", "90000002000173", "90000001000129", "90000001000129",
               "90000001000200", "90000003000118", "90000004000162", "90000004000162",
               "90000002000173"),
  stringsAsFactors = FALSE
)
TB_COMODATO$PRE_PED <- as.numeric(paste0(TB_COMODATO$DTE, sprintf("%04d", seq_len(nrow(TB_COMODATO)))))

# TB_COMOD_SOLICITADO (so o PRE_PED entra na consulta) ---------------------
TB_COMOD_SOLICITADO <- data.frame(PRE_PED = TB_COMODATO$PRE_PED)

# tb_anexos_cev: PDFs assinados que voltaram ---------------------------------
#   7001 assinado; 8001 assinado so no anexo2; 8002 tinha anexo cancelado (situacao X)
tb_anexos_cev <- data.frame(
  CNPJ_REV = c("90000002000173", "90000001000129", "90000001000129"),
  ncev     = c(7001L, 8001L, 8002L),
  anexo1   = c("Anexos/90000002000173_00010001_7001.PDF", NA, "Anexos/90000001000129_00020002_8002.PDF"),
  anexo2   = c(NA, "Anexos/90000001000129_00020001_8001_v2.PDF", NA),
  anexo3   = c(NA_character_, NA_character_, NA_character_),
  situacao = c("A", "A", "X"),
  stringsAsFactors = FALSE
)

tabelas <- list(TB_EMPRESAS = TB_EMPRESAS, TB_COMODATO = TB_COMODATO,
                TB_COMOD_SOLICITADO = TB_COMOD_SOLICITADO, tb_anexos_cev = tb_anexos_cev)
for (nm in names(tabelas)) {
  write_parquet(tabelas[[nm]], file.path(dir_dados, paste0(nm, ".parquet")))
  cat(sprintf("%-22s %3d linhas\n", nm, nrow(tabelas[[nm]])))
}
