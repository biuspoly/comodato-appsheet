@echo off
cd /d "%~dp0"
:: Usa o Rscript do PATH (ou defina a variavel RSCRIPT com o caminho completo)
if "%RSCRIPT%"=="" set RSCRIPT=Rscript
"%RSCRIPT%" comodato_sheet.R
pause
