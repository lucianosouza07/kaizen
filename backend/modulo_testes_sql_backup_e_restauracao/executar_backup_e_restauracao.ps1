# ==============================================================================
# Kaizen ERP - Automação de Backup e Restauração Lógica (BK-DB-09)
# PowerShell script para Windows
# ==============================================================================
param (
    [string]$DbHost = "127.0.0.1",
    [int]$DbPort = 3306,
    [string]$DbUser = "root",
    [string]$DbPass = "root",
    [string]$DbName = "kaizen",
    [string]$RestoreDbName = "kaizen_restore_test"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackupFile = Join-Path $ScriptDir "backup_kaizen.sql"
$ValidationFile = Join-Path $ScriptDir "02_validacao_restauracao.sql"

Write-Host "=== [1/4] Iniciando Backup Lógico com mysqldump ===" -ForegroundColor Cyan

$dockerAvailable = $false
try {
    $containers = docker ps --format '{{.Names}}' 2>$null
    if ($containers -match 'kaizen-mysql-test') {
        $dockerAvailable = $true
    }
} catch {}

if ($dockerAvailable) {
    Write-Host "Utilizando container Docker kaizen-mysql-test..." -ForegroundColor Green
    docker exec kaizen-mysql-test mysqldump `
        -u"$DbUser" `
        -p"$DbPass" `
        --single-transaction `
        --routines `
        --triggers `
        --events `
        --default-character-set=utf8mb4 `
        --set-gtid-purged=OFF `
        "$DbName" | Out-File -FilePath $BackupFile -Encoding utf8
} else {
    Write-Host "Utilizando mysqldump local..." -ForegroundColor Green
    & mysqldump `
        --host="$DbHost" `
        --port=$DbPort `
        --user="$DbUser" `
        --password="$DbPass" `
        --single-transaction `
        --routines `
        --triggers `
        --events `
        --default-character-set=utf8mb4 `
        --set-gtid-purged=OFF `
        "$DbName" | Out-File -FilePath $BackupFile -Encoding utf8
}

$fileItem = Get-Item $BackupFile
Write-Host "Backup gerado com sucesso: $BackupFile ($([math]::Round($fileItem.Length / 1KB, 2)) KB)" -ForegroundColor Cyan

Write-Host "=== [2/4] Criando esquema limpo para restauração: $RestoreDbName ===" -ForegroundColor Cyan
$dropCreateSql = "DROP DATABASE IF EXISTS \`$RestoreDbName\`; CREATE DATABASE \`$RestoreDbName\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"

if ($dockerAvailable) {
    docker exec -i kaizen-mysql-test mysql -u"$DbUser" -p"$DbPass" -e "$dropCreateSql"
    Write-Host "=== [3/4] Restaurando dump no container Docker... ===" -ForegroundColor Cyan
    Get-Content $BackupFile | docker exec -i kaizen-mysql-test mysql -u"$DbUser" -p"$DbPass" "$RestoreDbName"
    Write-Host "=== [4/4] Executando validação pós-restauração... ===" -ForegroundColor Cyan
    Get-Content $ValidationFile | docker exec -i kaizen-mysql-test mysql -u"$DbUser" -p"$DbPass" "$RestoreDbName"
} else {
    & mysql --host="$DbHost" --port=$DbPort --user="$DbUser" --password="$DbPass" -e "$dropCreateSql"
    Write-Host "=== [3/4] Restaurando dump via cliente local... ===" -ForegroundColor Cyan
    Get-Content $BackupFile | & mysql --host="$DbHost" --port=$DbPort --user="$DbUser" --password="$DbPass" "$RestoreDbName"
    Write-Host "=== [4/4] Executando validação pós-restauração... ===" -ForegroundColor Cyan
    Get-Content $ValidationFile | & mysql --host="$DbHost" --port=$DbPort --user="$DbUser" --password="$DbPass" "$RestoreDbName"
}

Write-Host "=== Ciclo de Backup e Restauração Concluído com Sucesso! ===" -ForegroundColor Green
