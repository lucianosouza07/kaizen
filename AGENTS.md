# Instructions for AI Agents (Kaizen)

Relational database project for Kaizen ERP (gym and sports club network management). Focused strictly on the relational database tier: conceptual, logical, and physical models, DDL, routines, triggers, views, seed data, and deterministic SQL test scripts for MySQL 8.0.46.

## Stack & Target Environment
- **RDBMS:** MySQL Server 8.0.46 / MySQL Workbench 8.0.47 CE
- **Engine / Collation:** `InnoDB`, `utf8mb4`, `utf8mb4_0900_ai_ci`
- **System Variables:** `lower_case_table_names = 1`, `default-time-zone = '+00:00'`
- **Local Environment:** Docker Compose (`database` MySQL 8.0 + `phpmyadmin` on port 8080)

## Repository Structure & File Organization
```text
kaizen/
├── docker-compose.yaml                               # MySQL 8.0 & phpMyAdmin containers
├── LOGO.png                                          # Project visual identity
├── README.md                                         # Main human-facing documentation
├── AGENTS.md                                         # Context & operational instructions for AI agents
├── backend/
│   ├── modelo_conceitual/                            # Conceptual EER model & Mermaid diagram
│   ├── modelo_logico/                                # Logical dictionary, 3NF proof & integrity matrix
│   ├── modelo_fisico/                                # Physical SQL scripts (DDL, routines, triggers, views)
│   │   ├── modulo_ddl_do_nucleo_de_cadastro/         # 01_ddl_nucleo_cadastro.sql & test
│   │   ├── modulo_ddl_comercial_e_financeiro/        # 02_ddl_comercial_financeiro.sql & test
│   │   ├── modulo_ddl_de_operacao_tabela_tecnica_e_seed/ # 03_ddl_operacao_seed.sql & test
│   │   ├── modulo_functions_e_procedures/            # 04_functions_procedures.sql & test
│   │   ├── modulo_triggers/                          # 05_triggers.sql & test
│   │   └── modulo_views_roles_e_privilegios_minimos/ # 06_views_roles.sql & test
│   └── modulo_testes_sql_backup_e_restauracao/       # End-to-end tests, dump & cold restore audit (BK-DB-09)
│       ├── 01_testes_integrados_violacoes_replay.sql # Integrated stress, violation & replay assertions
│       ├── 02_validacao_restauracao.sql              # Catalog metadata audit (information_schema)
│       ├── executar_backup_e_restauracao.sh          # Automated backup/restore cycle (Linux/macOS)
│       └── executar_backup_e_restauracao.ps1         # Automated backup/restore cycle (Windows/PowerShell)
└── frontend/                                         # Reserved for upcoming interface modules
```

## Setup & Execution Commands

### 1. Start Database Containers
```bash
docker compose up -d
```
- phpMyAdmin is accessible at `http://localhost:8080` (Server: `database`, User: `root`, Password: `root`).

### 2. Apply Physical Schema (Strict Ordinal Order)
```bash
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_do_nucleo_de_cadastro/01_ddl_nucleo_cadastro.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_comercial_e_financeiro/02_ddl_comercial_financeiro.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_de_operacao_tabela_tecnica_e_seed/03_ddl_operacao_seed.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_functions_e_procedures/04_functions_procedures.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_triggers/05_triggers.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_views_roles_e_privilegios_minimos/06_views_roles.sql
```

## Testing & Verification Instructions

### 1. Unit Test Suites (Per Module)
Each database module includes an isolated test script (`test_*.sql`):
```bash
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_conceitual/validacao_modelo_conceitual.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_do_nucleo_de_cadastro/test_ddl_nucleo_cadastro.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_comercial_e_financeiro/test_ddl_comercial_financeiro.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_functions_e_procedures/test_functions_procedures.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_triggers/test_triggers.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_views_roles_e_privilegios_minimos/test_views_roles.sql
```

### 2. End-to-End Integrated Tests & Idempotency
Validates business violations (class capacity, 1 active contract per member, multi-unit isolation) and webhook replay protection:
```bash
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modulo_testes_sql_backup_e_restauracao/01_testes_integrados_violacoes_replay.sql
```

### 3. Disaster Recovery & Restoration Audit
Runs a consistent logical dump (`mysqldump` with `--single-transaction --routines --triggers --events`), restores into an empty schema (`kaizen_restore_test`), and checks `information_schema` parity:
- **Windows (PowerShell):**
  ```powershell
  powershell -ExecutionPolicy Bypass -File backend/modulo_testes_sql_backup_e_restauracao/executar_backup_e_restauracao.ps1
  ```
- **Linux / macOS (Bash):**
  ```bash
  chmod +x backend/modulo_testes_sql_backup_e_restauracao/executar_backup_e_restauracao.sh
  ./backend/modulo_testes_sql_backup_e_restauracao/executar_backup_e_restauracao.sh
  ```

## Code Style & Architectural Conventions

1. **Scope Boundary:** Relational database tier only (DDL, triggers, stored procedures, functions, views, seed data, and verification SQL). Do not create backend application services or ORM models unless explicitly instructed.
2. **Naming Conventions:**
   - Database tables and objects: Snake_case uppercase (`UNIDADE`, `MENSALIDADE`, `VW_ACESSO_DIARIO`, `TRG_...`, `SP_...`, `FN_...`).
   - Columns: Snake_case lowercase (`id_unidade`, `dt_criacao`, `nr_matricula`).
   - Constraints & Keys: `PK_<table>`, `FK_<origem>_<destino>`, `UK_<origem>_<campos>`, `CK_<table>_<campo>`.
3. **Multi-unit Isolation:** Every operational entity referencing tenant data must maintain relational integrity with `UNIDADE`.
4. **Git & Commit Standards:**
   - Follow Conventional Commits: `tipo(escopo opcional): descrição` in lowercase, imperative mood, without emojis.
5. **Git Workflow:** Feature branches branch off and merge back into `develop` via pull requests.
