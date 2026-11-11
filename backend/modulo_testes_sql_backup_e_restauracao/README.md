# Módulo de Testes SQL, Backup e Restauração (BK-DB-09)

| Metadado | Detalhe |
|---|---|
| **Tarefa** | BK-DB-09 (Testes SQL, backup e restauração) |
| **Etapa** | 5 (Validação e Confiabilidade Operacional) |
| **SGBD** | MySQL Server 8.0.46 / InnoDB / `utf8mb4_0900_ai_ci` |
| **Utilitários** | `mysqldump`, `mysql` client, Docker Compose |

---

## 1. Visão Geral

Este módulo comprova a resiliência e a recuperabilidade da base de dados relacional do **Kaizen ERP**:
1. Executa bateria integrada de testes comprovando que regras de negócio rejeitam violações e tentativas de repetição (*replay*).
2. Fornece rotina determinística de extração de backup lógico consistente (`mysqldump`).
3. Automatiza a restauração a frio em base vazia com auditoria rigorosa no catálogo (`information_schema`), provando a recriação exata das **15 tabelas**, **5 visões**, **triggers**, **procedures/functions** e dados de **seed**.

---

## 2. Conteúdo do Módulo

- `01_testes_integrados_violacoes_replay.sql`: Script SQL centralizado dividido em Bloco A (testes positivos e conferência de seed), Bloco B (testes de estresse e violações esperadas) e Bloco C (testes de idempotência contra replay de webhooks e faturamentos).
- `02_validacao_restauracao.sql`: Script de auditoria executado pós-restauração que valida quantitativa e qualitativamente a paridade estrutural no schema restaurado.
- `executar_backup_e_restauracao.sh`: Shell script automatizado para ambientes Linux/macOS ou containers Docker.
- `executar_backup_e_restauracao.ps1`: Script PowerShell nativo para ambientes Windows.

---

## 3. Instruções de Execução

### 3.1 Executar a Bateria Integrada de Testes
No container ou instância MySQL ativa:
```bash
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modulo_testes_sql_backup_e_restauracao/01_testes_integrados_violacoes_replay.sql
```

### 3.2 Executar o Ciclo Automatizado de Backup e Restauração

#### No Linux / macOS / Bash:
```bash
chmod +x backend/modulo_testes_sql_backup_e_restauracao/executar_backup_e_restauracao.sh
./backend/modulo_testes_sql_backup_e_restauracao/executar_backup_e_restauracao.sh
```

#### No Windows / PowerShell:
```powershell
powershell -ExecutionPolicy Bypass -File backend/modulo_testes_sql_backup_e_restauracao/executar_backup_e_restauracao.ps1
```

O comando executará:
1. O dump lógico com `--single-transaction --routines --triggers --events --default-character-set=utf8mb4`.
2. A criação da base vazia `kaizen_restore_test`.
3. A restauração integral do dump.
4. A auditoria via `02_validacao_restauracao.sql`, confirmando `PASS` para todas as 15 tabelas, views, triggers e seeds.
