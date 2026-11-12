# Kaizen ERP — Banco de Dados Relacional (MySQL 8.0)

Camada de banco de dados relacional para a rede de academias e clubes **Kaizen ERP**. O projeto abrange desde os modelos conceituais e lógicos (3FN) até scripts físicos DDL, rotinas armazenadas (functions e procedures), triggers de auditoria/integridade, visões e segurança RBAC com privilégios mínimos.

---

## 1. Ambiente e Tecnologias
- **SGBD:** MySQL Server 8.0.46 / MySQL Workbench 8.0.47 CE
- **Engine de Armazenamento:** `InnoDB`
- **Charset & Collation:** `utf8mb4` / `utf8mb4_0900_ai_ci`
- **Configuração de Tabelas:** `lower_case_table_names = 1`
- **Ambiente Containerizado:** Docker Compose com serviços `database` (MySQL 8.0) e `phpmyadmin` (interface web)

---

## 2. Estrutura do Repositório

```text
kaizen/
├── docker-compose.yaml                               # Subida dos containers MySQL 8.0 e phpMyAdmin
├── README.md                                         # Documentação central do banco de dados
└── backend/
    ├── modelo_conceitual/                            # Etapa 1: Modelo Conceitual ER/EER
    │   ├── catalogo_entidades_relacionamentos.md     # 13 entidades e 13 relacionamentos R1-R13
    │   ├── diagrama_er_conceitual.mmd                # Diagrama conceitual em sintaxe Mermaid
    │   ├── modelo_conceitual.pdf                     # Versão consolidada em PDF
    │   └── validacao_modelo_conceitual.sql           # Teste automatizado de validação conceitual
    │
    ├── modelo_logico/                                # Etapa 2: Modelo Lógico e 3FN
    │   ├── dicionario_dados.md                       # Dicionário semântico e tipos lógicos
    │   ├── justificativa_3fn.md                      # Demonstração matemática de 1FN, 2FN e 3FN
    │   ├── matriz_integridade.md                     # Matriz de PKs, FKs, UKs e CKs
    │   ├── modelo_logico.pdf                         # Versão consolidada em PDF
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

## 3. Como Executar o Projeto

Você pode subir e executar o banco de dados de duas formas: **via Docker** (linha de comando ou navegador) ou **via MySQL Workbench**.

### Forma 1: Execução via Docker (Recomendado)

O Docker Compose sobe automaticamente a instância do MySQL 8.0 e a interface web do phpMyAdmin.

1. **Subir os containers:**
   ```bash
   cd src
   docker compose up -d
   ```

2. **Aplicar os scripts em ordem sequencial ordinal:**
   ```bash
   docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_do_nucleo_de_cadastro/01_ddl_nucleo_cadastro.sql
   docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_comercial_e_financeiro/02_ddl_comercial_financeiro.sql
   docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_de_operacao_tabela_tecnica_e_seed/03_ddl_operacao_seed.sql
   docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_functions_e_procedures/04_functions_procedures.sql
   docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_triggers/05_triggers.sql
   docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_views_roles_e_privilegios_minimos/06_views_roles.sql
   ```

3. **Acesso visual via Navegador (phpMyAdmin):**
   - Acesse no navegador: **`http://localhost:8080`**
   - **Servidor:** `database`
   - **Usuário:** `root`
   - **Senha:** `root`

4. **Encerrar os serviços:**
   ```bash
   docker compose down       # Encerra os containers mantendo os dados
   docker compose down -v    # Encerra e limpa todos os volumes para reiniciar do zero
   ```

---

### Forma 2: Execução via MySQL Workbench (ou Instância Local)

Se preferir utilizar o **MySQL Workbench 8.0.47 CE** conectado ao MySQL local ou ao container Docker:

1. **Conectar à Instância:**
   - Crie uma conexão (*MySQL Connection*) no Workbench com:
     - **Hostname:** `127.0.0.1` (ou `localhost`)
     - **Port:** `3306`
     - **Username:** `root`
     - **Password:** `root` (ou a senha configurada no seu MySQL local)

2. **Garantir a existência do banco de dados:**
   - Execute no editor SQL:
     ```sql
     CREATE SCHEMA IF NOT EXISTS kaizen 
       DEFAULT CHARACTER SET utf8mb4 
       DEFAULT COLLATE utf8mb4_0900_ai_ci;
     USE kaizen;
     ```

3. **Executar os scripts em ordem:**
   No menu **File** > **Open SQL Script...** (ou `Ctrl + Shift + O`), abra e execute clicando no ícone do **Raio (Execute)** na seguinte ordem estrita:
   - `backend/modelo_fisico/modulo_ddl_do_nucleo_de_cadastro/01_ddl_nucleo_cadastro.sql`
   - `backend/modelo_fisico/modulo_ddl_comercial_e_financeiro/02_ddl_comercial_financeiro.sql`
   - `backend/modelo_fisico/modulo_ddl_de_operacao_tabela_tecnica_e_seed/03_ddl_operacao_seed.sql`
   - `backend/modelo_fisico/modulo_functions_e_procedures/04_functions_procedures.sql`
   - `backend/modelo_fisico/modulo_triggers/05_triggers.sql`
   - `backend/modelo_fisico/modulo_views_roles_e_privilegios_minimos/06_views_roles.sql`

4. **Atualizar o catálogo (Schemas):**
   - No painel lateral esquerdo (*Navigator*), clique com o botão direito no schema `kaizen` e selecione **Refresh All**. Todas as 15 tabelas, rotinas, triggers e visões estarão disponíveis.

---

## 4. Execução da Suíte de Testes

Cada módulo possui seu respectivo script de testes e asserções automatizadas (`test_*.sql`).

**Via Docker CLI:**
```bash
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_conceitual/validacao_modelo_conceitual.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_do_nucleo_de_cadastro/test_ddl_nucleo_cadastro.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_comercial_e_financeiro/test_ddl_comercial_financeiro.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_functions_e_procedures/test_functions_procedures.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_triggers/test_triggers.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_views_roles_e_privilegios_minimos/test_views_roles.sql
```

*(No MySQL Workbench, basta abrir qualquer arquivo `test_*.sql` e clicar em Execute).*

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
