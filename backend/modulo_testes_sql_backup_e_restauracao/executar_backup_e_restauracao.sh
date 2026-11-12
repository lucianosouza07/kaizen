#!/usr/bin/env bash
# ==============================================================================
# Kaizen ERP - Automação de Backup e Restauração Lógica (BK-DB-09)
# Requisitos: mysqldump e mysql client instalados ou via Docker
# ==============================================================================
set -euo pipefail

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-root}"
DB_NAME="${DB_NAME:-kaizen}"
RESTORE_DB_NAME="${RESTORE_DB_NAME:-kaizen_restore_test}"
BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_FILE="${BACKUP_DIR}/backup_kaizen.sql"

echo "=== [1/4] Iniciando Backup Lógico com mysqldump ==="
if command -v docker &> /dev/null && docker ps --format '{{.Names}}' | grep -q 'kaizen-mysql-test'; then
  echo "Utilizando container Docker kaizen-mysql-test..."
  docker exec kaizen-mysql-test mysqldump \
    -u"${DB_USER}" \
    -p"${DB_PASS}" \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --default-character-set=utf8mb4 \
    --set-gtid-purged=OFF \
    "${DB_NAME}" > "${BACKUP_FILE}"
else
  echo "Utilizando mysqldump local..."
  mysqldump \
    --host="${DB_HOST}" \
    --port="${DB_PORT}" \
    --user="${DB_USER}" \
    --password="${DB_PASS}" \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --default-character-set=utf8mb4 \
    --set-gtid-purged=OFF \
    "${DB_NAME}" > "${BACKUP_FILE}"
fi

echo "Backup gerado com sucesso: ${BACKUP_FILE} ($(du -h "${BACKUP_FILE}" | cut -f1))"

echo "=== [2/4] Criando esquema limpo para restauração: ${RESTORE_DB_NAME} ==="
DROP_CREATE_SQL="DROP DATABASE IF EXISTS \`${RESTORE_DB_NAME}\`; CREATE DATABASE \`${RESTORE_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"
if command -v docker &> /dev/null && docker ps --format '{{.Names}}' | grep -q 'kaizen-mysql-test'; then
  docker exec -i kaizen-mysql-test mysql -u"${DB_USER}" -p"${DB_PASS}" -e "${DROP_CREATE_SQL}"
  echo "=== [3/4] Restaurando dump no container Docker... ==="
  docker exec -i kaizen-mysql-test mysql -u"${DB_USER}" -p"${DB_PASS}" "${RESTORE_DB_NAME}" < "${BACKUP_FILE}"
  echo "=== [4/4] Executando validação pós-restauração... ==="
  docker exec -i kaizen-mysql-test mysql -u"${DB_USER}" -p"${DB_PASS}" "${RESTORE_DB_NAME}" < "${BACKUP_DIR}/02_validacao_restauracao.sql"
else
  mysql --host="${DB_HOST}" --port="${DB_PORT}" --user="${DB_USER}" --password="${DB_PASS}" -e "${DROP_CREATE_SQL}"
  echo "=== [3/4] Restaurando dump via cliente local... ==="
  mysql --host="${DB_HOST}" --port="${DB_PORT}" --user="${DB_USER}" --password="${DB_PASS}" "${RESTORE_DB_NAME}" < "${BACKUP_FILE}"
  echo "=== [4/4] Executando validação pós-restauração... ==="
  mysql --host="${DB_HOST}" --port="${DB_PORT}" --user="${DB_USER}" --password="${DB_PASS}" "${RESTORE_DB_NAME}" < "${BACKUP_DIR}/02_validacao_restauracao.sql"
fi

echo "=== Ciclo de Backup e Restauração Concluído com Sucesso! ==="
