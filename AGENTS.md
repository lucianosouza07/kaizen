# Instructions for AI Agents (Kaizen)

Relational database project for Kaizen (gym/club network management). Focused strictly on database tier: conceptual, logical, and physical models, DDL, objects, seed data, and SQL test scripts for MySQL 8.0.46.

## Stack & Target Environment
- **RDBMS:** MySQL Server 8.0.46 / MySQL Workbench 8.0.47 CE
- **Dialect / Engine:** MySQL 8.0 (`InnoDB`, `utf8mb4`, `utf8mb4_0900_ai_ci`)
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
│   └── modelo_fisico/                                # Physical SQL scripts (DDL, routines, triggers, views)
│       ├── modulo_ddl_do_nucleo_de_cadastro/         # 01_ddl_nucleo_cadastro.sql & test
│       ├── modulo_ddl_comercial_e_financeiro/        # 02_ddl_comercial_financeiro.sql & test
│       ├── modulo_ddl_de_operacao_tabela_tecnica_e_seed/ # 03_ddl_operacao_seed.sql & test
│       ├── modulo_functions_e_procedures/            # 04_functions_procedures.sql & test
│       ├── modulo_triggers/                          # 05_triggers.sql & test
│       └── modulo_views_roles_e_privilegios_minimos/ # 06_views_roles.sql & test
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

## Testing Instructions

Every database module includes a self-contained test script (`test_*.sql`) with assertions verifying schema constraints, routine behavior, trigger firings, and RBAC privileges.

### Run All Test Suites (CLI):
```bash
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_conceitual/validacao_modelo_conceitual.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_do_nucleo_de_cadastro/test_ddl_nucleo_cadastro.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_comercial_e_financeiro/test_ddl_comercial_financeiro.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_functions_e_procedures/test_functions_procedures.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_triggers/test_triggers.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_views_roles_e_privilegios_minimos/test_views_roles.sql
```

## Code Style & Architectural Conventions

1. **Scope Boundary:** Relational database tier only (DDL, triggers, stored procedures, functions, views, seed data, and verification SQL). Do not add application or ORM code unless explicitly requested.
2. **Object Naming Convention:**
   - Tables and database objects: Snake_case uppercase (`UNIDADE`, `MENSALIDADE`, `VW_ACESSO_DIARIO`, `TRG_...`, `SP_...`, `FN_...`).
   - Columns: Snake_case lowercase (`id_unidade`, `dt_criacao`, `nr_matricula`).
   - Indexes and constraints: `PK_<table>`, `FK_<origem>_<destino>`, `UK_<origem>_<campos>`, `CK_<table>_<campo>`.
3. **Multi-unit Isolation:** Every operational entity referencing tenant data must maintain relational integrity with `UNIDADE`.
4. **Git & Commit Standards:**
   - Follow Conventional Commits: `tipo(escopo opcional): descrição` in lowercase, imperative mood, without emojis.
5. **Git Workflow:** Feature branches branch off and merge back into `develop` via pull requests.
