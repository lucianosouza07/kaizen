# Kaizen ERP — Banco de Dados Relacional (MySQL 8.0)

Camada de banco de dados relacional para a rede de academias e clubes **Kaizen ERP**. O projeto abrange desde os modelos conceituais e lógicos (3FN) até scripts físicos DDL, rotinas armazenadas (functions e procedures), triggers de auditoria/integridade, visões e segurança RBAC com privilégios mínimos.

---

## 1. Ambiente e Tecnologias
- **SGBD:** MySQL Server 8.0.46 / MySQL Workbench 8.0.47 CE
- **Engine de Armazenamento:** `InnoDB`
- **Charset & Collation:** `utf8mb4` / `utf8mb4_0900_ai_ci`
- **Container Oficial:** imagem `mysql:8.0` via Docker Compose

---

## 2. Estrutura do Repositório

```text
kaizen/
├── docker-compose.yaml                               # Subida de instância local MySQL 8.0
├── README.md                                         # Documentação central do banco de dados
└── backend/
    ├── modelo_conceitual/                            # Etapa 1: Modelo Conceitual ER/EER
    │   ├── catalogo_entidades_relacionamentos.md     # 13 entidades e 13 relacionamentos R1-R13
    │   ├── diagrama_er_conceitual.mmd                # Diagrama conceitual em sintaxe Mermaid
    │   └── validacao_modelo_conceitual.sql           # Teste automatizado de validação conceitual
    │
    ├── modelo_logico/                                # Etapa 2: Modelo Lógico e 3FN
    │   ├── dicionario_dados.md                       # Dicionário semântico e tipos lógicos
    │   ├── justificativa_3fn.md                      # Demonstração matemática de 1FN, 2FN e 3FN
    │   ├── matriz_integridade.md                     # Matriz de PKs, FKs, UKs e CKs
    │   └── regras_multiunidade.md                    # Regras de isolamento multiunidade
    │
    └── modelo_fisico/                                # Etapa 3+: Módulos de Execução do Banco de Dados
        ├── modulo_ddl_do_nucleo_de_cadastro/         # DDL de Cadastro Base
        │   ├── 01_ddl_nucleo_cadastro.sql            # UNIDADE, PAPEL, USUARIO, ALUNO, COLABORADOR, etc.
        │   └── test_ddl_nucleo_cadastro.sql          # Asserções de integridade do cadastro
        ├── modulo_ddl_comercial_e_financeiro/        # DDL Comercial e Financeiro
        │   ├── 02_ddl_comercial_financeiro.sql       # PLANO, CONTRATO, MENSALIDADE, PAGAMENTO
        │   └── test_ddl_comercial_financeiro.sql     # Testes de constraints financeiras e unicidade
        ├── modulo_ddl_de_operacao_tabela_tecnica_e_seed/ # Operação e Carga Inicial
        │   └── 03_ddl_operacao_seed.sql              # TURMA, ACESSO, RESERVA_TURMA, AUDITORIA_LOG, Seeds
        ├── modulo_functions_e_procedures/            # Rotinas Armazenadas
        │   ├── 04_functions_procedures.sql           # 4 Functions + 4 Stored Procedures
        │   └── test_functions_procedures.sql         # Testes unitários das rotinas
        ├── modulo_triggers/                          # Triggers e Automação de Negócio
        │   ├── 05_triggers.sql                       # 7 triggers de integridade, auditoria e status
        │   └── test_triggers.sql                     # Testes automatizados de disparos de triggers
        └── modulo_views_roles_e_privilegios_minimos/ # Visões e Segurança RBAC
            ├── 06_views_roles.sql                    # 5 visões analíticas/operacionais e 6 roles RBAC
            └── test_views_roles.sql                  # Testes de privilégios e consultas das views
```

---

## 3. Ordem de Instalação e Execução

Para montar a base do zero com todas as tabelas, seeds, rotinas, triggers e papéis de segurança, execute os scripts em sequência ordinal:

```bash
# 1. Subir o container de banco de dados
docker compose up -d

# 2. Executar em ordem ordinal sequencial:
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_do_nucleo_de_cadastro/01_ddl_nucleo_cadastro.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_comercial_e_financeiro/02_ddl_comercial_financeiro.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_de_operacao_tabela_tecnica_e_seed/03_ddl_operacao_seed.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_functions_e_procedures/04_functions_procedures.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_triggers/05_triggers.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_views_roles_e_privilegios_minimos/06_views_roles.sql
```

---

## 4. Execução da Suíte de Testes

Cada módulo possui seu respectivo script de testes e asserções automatizadas (`test_*.sql`):

```bash
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_conceitual/validacao_modelo_conceitual.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_do_nucleo_de_cadastro/test_ddl_nucleo_cadastro.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_comercial_e_financeiro/test_ddl_comercial_financeiro.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_functions_e_procedures/test_functions_procedures.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_triggers/test_triggers.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_views_roles_e_privilegios_minimos/test_views_roles.sql
```

---

## 5. Mapeamento das 15 Tabelas do Modelo

| Categoria | Tabela | Finalidade Principal |
|---|---|---|
| **Núcleo de Cadastro** | `UNIDADE` | Cadastro das filiais da rede de academias |
| | `PAPEL` | Perfis de acesso no sistema |
| | `USUARIO` | Credenciais de acesso ao sistema |
| | `USUARIO_PAPEL` | Associação N:N entre usuários e papéis |
| | `ALUNO` | Cadastro dos alunos da rede com isolamento multiunidade |
| | `COLABORADOR` | Funcionários e instrutores vinculados a uma unidade |
| **Comercial / Financeiro** | `PLANO` | Catálogo de planos e preços |
| | `CONTRATO` | Contrato do aluno (regra estrita de 1 ativo por aluno) |
| | `MENSALIDADE` | Parcelas com competência mensal idempotente (`AAAA-MM`) |
| | `PAGAMENTO` | Registro financeiro e suporte a estornos compensatórios |
| **Operação** | `TURMA` | Horários de aulas e atividades com capacidade máxima |
| | `ACESSO` | Registros de catraca / portaria |
| | `RESERVA_TURMA` | Associação N:N entre alunos e turmas |
| **Técnicas** | `CONTADOR_DOCUMENTO` | Controle atômico de sequenciais de documentos/matrículas |
| | `AUDITORIA_LOG` | Trilha de auditoria das operações DML sensíveis |
