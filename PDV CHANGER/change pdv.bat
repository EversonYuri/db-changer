@echo off
echo [INFO] Iniciando processo de troca de banco...
cd /d C:\HERA\BANCO\bin
if errorlevel 1 (
  powershell -NoLogo -NoProfile -Command "Write-Host '[ERRO] Nao foi possivel acessar C:\HERA\BANCO\bin.' -ForegroundColor Red"
)

set "BACKUP_DIR=%~dp0backup"
if not exist "%BACKUP_DIR%" (
  echo [INFO] Criando pasta de backup...
  mkdir "%BACKUP_DIR%"
  if errorlevel 1 (
    powershell -NoLogo -NoProfile -Command "Write-Host '[ERRO] Nao foi possivel criar a pasta de backup.' -ForegroundColor Red"
  )
) else (
  echo [INFO] Pasta de backup ja existe.
)

echo [INFO] Gerando backup do banco atual...
mariadb-dump -u root -p240190 pdv > "%BACKUP_DIR%\backup_pdv_%DATE:~0,2%-%DATE:~3,2%-%DATE:~6,4%_%time:~0,2%-%time:~3,2%.sql"
if errorlevel 1 (
  powershell -NoLogo -NoProfile -Command "Write-Host '[ERRO] Falha ao gerar o backup do banco.' -ForegroundColor Red"
)

echo [INFO] Recriando o banco de dados.
mariadb -u root -p240190 --default-character-set=utf8 -e "DROP DATABASE IF EXISTS `pdv`; CREATE DATABASE `pdv` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
if errorlevel 1 (
  powershell -NoLogo -NoProfile -Command "Write-Host '[ERRO] Falha ao recriar o banco de dados.' -ForegroundColor Red"
)

setlocal

set "BASE_DIR=%~dp0"
set "TEMP_SELECTION=%TEMP%\selected_sql.txt"
if exist "%TEMP_SELECTION%" del "%TEMP_SELECTION%" >nul 2>&1

powershell -NoLogo -NoProfile -Command ^
  "$base = '%~dp0';" ^
  "$files = Get-ChildItem -Path $base -File | Where-Object { $_.Name -match '\.sql(\.gz)?$' } | Sort-Object Name;" ^
  "if(-not $files){Write-Host 'Nenhum arquivo SQL encontrado.'; exit 1};" ^
  "$index = 0;" ^
  "function Draw {" ^
    "Clear-Host;" ^
    "Write-Host 'Selecione o arquivo (*.sql / *.sql.gz) com as setas e Enter:';" ^
    "for($i = 0; $i -lt $files.Count; $i++){" ^
      "if($i -eq $index){Write-Host ('> ' + $files[$i].Name)}" ^
      "else{Write-Host ('  ' + $files[$i].Name)}" ^
    "}" ^
  "};" ^
  "Draw;" ^
  "while($true){" ^
    "$key = [Console]::ReadKey($true);" ^
    "if($key.Key -eq 'DownArrow' -and $index -lt $files.Count - 1){$index++; Draw}" ^
    "elseif($key.Key -eq 'UpArrow' -and $index -gt 0){$index--; Draw}" ^
    "elseif($key.Key -eq 'Enter'){Set-Content -Path '%TEMP_SELECTION%' -Value $files[$index].FullName; break}" ^
  "}" 

if not exist "%TEMP_SELECTION%" (
  echo Nenhum arquivo foi selecionado.
  exit /b 1
)

set /p "SELECTED_FILE="<"%TEMP_SELECTION%"
del "%TEMP_SELECTION%" >nul 2>&1

set "SQL_TO_IMPORT=%SELECTED_FILE%"
for %%F in ("%SELECTED_FILE%") do (
  if /I "%%~xF"==".gz" (
    echo [INFO] Descompactando arquivo gzip...
    "%~dp0gz\bin\gzip.exe" -dk "%%~fF"
    if errorlevel 1 (
      powershell -NoLogo -NoProfile -Command "Write-Host '[ERRO] Falha ao descompactar o arquivo selecionado.' -ForegroundColor Red"
    )
    set "SQL_TO_IMPORT=%%~dpnF"
  )
)

echo [INFO] Importando o arquivo selecionado...
mariadb -u root -p240190 -D pdv --default-character-set=utf8 < "%SQL_TO_IMPORT%"

endlocal

echo [INFO] Parando servico Tomcat7...
net stop Tomcat7 >nul 2>&1
if errorlevel 1 (
  powershell -NoLogo -NoProfile -Command "Write-Host '[ERRO] Falha ao parar o Tomcat7.' -ForegroundColor Red"
)

echo [INFO] Removendo pasta gestaofacil antiga...
if exist C:\HERA\tomcat\webapps\gestaofacil (
  rmdir /s /q C:\HERA\tomcat\webapps\gestaofacil
  if errorlevel 1 (
    powershell -NoLogo -NoProfile -Command "Write-Host '[ERRO] Falha ao remover a aplicacao antiga.' -ForegroundColor Red"
  )
) else (
  echo [INFO] Nenhuma pasta gestaofacil anterior encontrada.
)

echo [INFO] Iniciando Tomcat7...
net start Tomcat7 >nul 2>&1
if errorlevel 1 (
  powershell -NoLogo -NoProfile -Command "Write-Host '[ERRO] Falha ao iniciar o Tomcat7.' -ForegroundColor Red"
)

echo [SUCESSO] Processo concluido.
pause
exit /b 0