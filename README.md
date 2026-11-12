<p align="center">
  <img src="LOGO.png" alt="Kaizen Logo" width="280">
</p>

<h1 align="center" style="font-size: 8.6rem;">Kaizen</h1>

> **Estágio Atual do Projeto:** A camada de banco de dados relacional encontra-se totalmente modelada, normalizada (3FN) e operacional no MySQL 8.0. Com as 15 tabelas (13 de domínio e 2 técnicas), rotinas de negócio (procedures e functions), triggers de auditoria/integridade e controle RBAC implementados e cobertos por suítes de testes, o projeto está pronto em ambiente conteinerizado (Docker Compose + phpMyAdmin) para a integração com as próximas fases de aplicação e interfaces.

[![MySQL](https://img.shields.io/badge/MySQL-8.0.46-00758F?logo=mysql&logoColor=white)](#ambiente-e-stack)
[![InnoDB](https://img.shields.io/badge/Engine-InnoDB-orange)](#ambiente-e-stack)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](#execução-via-docker-recomendado)
[![Status](https://img.shields.io/badge/Status-Database%20Ready-brightgreen)](#suíte-de-testes)

---

## Visão Geral

O **Kaizen** centraliza a gestão multiunidade da rede de academias e clubes, provendo isolamento lógico de filiais, controle contratual estrito (regra de 1 contrato ativo por aluno), idempotência financeira de mensalidades e trilha de auditoria completa para operações críticas.

### Recursos Entregues
- **Conformidade Relacional Rigorosa:** Modelagem normalizada em Terceira Forma Normal (3FN).
- **Isolamento Multiunidade:** Suporte nativo a filiais com integridade referencial.
- **Automação no Banco de Dados:** Triggers para auditoria DML e manutenção de status; procedures atômicas para fluxos operacionais.
- **Segurança RBAC:** Matriz de privilégios mínimos segmentada por papéis operacionais.
- **Pronto para Desenvolvimento:** Ambiente containerizado via Docker com interface phpMyAdmin inclusa.

---

## Ambiente e Stack

| Componente | Especificação |
|---|---|
| **SGBD** | MySQL Server 8.0.46 / MySQL Workbench 8.0.47 CE |
| **Engine** | `InnoDB` |
| **Charset / Collation** | `utf8mb4` / `utf8mb4_0900_ai_ci` |
| **Configuração de Tabelas** | `lower_case_table_names = 1` |
| **Containers** | Docker Compose (`database` MySQL 8.0 + `phpmyadmin`) |

---

## Arquitetura do Repositório

```text
kaizen/
├── docker-compose.yaml                               # Serviços MySQL 8.0 e phpMyAdmin
├── LOGO.png                                          # Identidade visual do projeto
├── README.md                                         # Documentação central do banco de dados
└── backend/
    ├── modelo_conceitual/                            # Modelo Conceitual ER/EER
    │   ├── catalogo_entidades_relacionamentos.md     # 13 entidades e relacionamentos R1-R13
    │   ├── diagrama_er_conceitual.mmd                # Diagrama conceitual (Mermaid)
    │   ├── modelo_conceitual.pdf                     # Documento consolidado
    │   └── validacao_modelo_conceitual.sql           # Asserções conceituais
    │
    ├── modelo_logico/                                # Modelo Lógico e Regras Relacionais
    │   ├── dicionario_dados.md                       # Dicionário semântico e tipos lógicos
    │   ├── justificativa_3fn.md                      # Demonstração formal de 1FN, 2FN e 3FN
    │   ├── matriz_integridade.md                     # Mapeamento de PKs, FKs, UKs e CKs
    │   ├── modelo_logico.pdf                         # Documento consolidado
    │   └── regras_multiunidade.md                    # Diretrizes de isolamento por unidade
    │
    ├── modelo_fisico/                                # Scripts SQL Executáveis
    │   ├── modulo_ddl_do_nucleo_de_cadastro/         # DDL: UNIDADE, USUARIO, ALUNO, COLABORADOR...
    │   ├── modulo_ddl_comercial_e_financeiro/        # DDL: PLANO, CONTRATO, MENSALIDADE, PAGAMENTO...
    │   ├── modulo_ddl_de_operacao_tabela_tecnica_e_seed/ # DDL: TURMA, ACESSO, AUDITORIA_LOG + Carga Inicial
    │   ├── modulo_functions_e_procedures/            # 4 Stored Procedures + 4 Functions
    │   ├── modulo_triggers/                          # 7 Triggers de negócio e auditoria
    │   └── modulo_views_roles_e_privilegios_minimos/ # 5 Views analíticas e 6 Roles RBAC
    │
    └── modulo_testes_sql_backup_e_restauracao/       # Validação Integrada e Resiliência (BK-DB-09)
        ├── 01_testes_integrados_violacoes_replay.sql # Bateria de estresse, violações e idempotência
        ├── 02_validacao_restauracao.sql              # Auditoria de paridade no catálogo (information_schema)
        ├── executar_backup_e_restauracao.sh          # Automação de dump e restore a frio (Linux/macOS)
        └── executar_backup_e_restauracao.ps1         # Automação de dump e restore a frio (Windows/PowerShell)
```

---

## Início Rápido

### Execução via Docker (Recomendado)

> [!TIP]
> A execução via Docker já inicializa o banco de dados configurado com timezone UTC, collation correta e a ferramenta web phpMyAdmin.

1. **Subir os containers:**
   ```bash
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

3. **Acesso visual via phpMyAdmin:**
   - URL: [http://localhost:8080](http://localhost:8080)
   - Servidor: `database`
   - Usuário / Senha: `root` / `root`

4. **Parar os containers:**
   ```bash
   docker compose down       # Mantém o volume de dados
   docker compose down -v    # Limpa dados para reinicialização limpa
   ```

---

### Execução via MySQL Workbench / Instância Local

> [!IMPORTANT]
> Caso utilize uma instância local fora do Docker, certifique-se de que a variável de sistema `lower_case_table_names` esteja definida como `1`.

1. **Conectar à instância:** Host `127.0.0.1`, Porta `3306`, Usuário `root`.
2. **Criar o schema Kaizen:**
   ```sql
   CREATE SCHEMA IF NOT EXISTS kaizen 
     DEFAULT CHARACTER SET utf8mb4 
     DEFAULT COLLATE utf8mb4_0900_ai_ci;
   USE kaizen;
   ```
3. **Executar os scripts na ordem obrigatória:**
   - `01_ddl_nucleo_cadastro.sql`
   - `02_ddl_comercial_financeiro.sql`
   - `03_ddl_operacao_seed.sql`
   - `04_functions_procedures.sql`
   - `05_triggers.sql`
   - `06_views_roles.sql`
4. Atualize o painel *Navigator* (*Refresh All*) para inspecionar tabelas, rotinas e visões criadas.

---

## Suíte de Testes

Cada módulo contém testes unitários e asserções automatizadas (`test_*.sql`).

### Opção 1: Via Linha de Comando (Docker)

```bash
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_conceitual/validacao_modelo_conceitual.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_do_nucleo_de_cadastro/test_ddl_nucleo_cadastro.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_ddl_comercial_e_financeiro/test_ddl_comercial_financeiro.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_functions_e_procedures/test_functions_procedures.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_triggers/test_triggers.sql
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modelo_fisico/modulo_views_roles_e_privilegios_minimos/test_views_roles.sql
```

### Opção 2: Via MySQL Workbench

Para executar e inspecionar os testes interativamente na interface gráfica:

1. Conecte-se à sua instância e garanta que o schema ativo seja o `kaizen` (`USE kaizen;`).
2. Abra o arquivo de teste correspondente ao módulo desejado via menu **File** > **Open SQL Script...** (ou `Ctrl + Shift + O`):
   - `backend/modelo_conceitual/validacao_modelo_conceitual.sql`
   - `backend/modelo_fisico/modulo_ddl_do_nucleo_de_cadastro/test_ddl_nucleo_cadastro.sql`
   - `backend/modelo_fisico/modulo_ddl_comercial_e_financeiro/test_ddl_comercial_financeiro.sql`
   - `backend/modelo_fisico/modulo_functions_e_procedures/test_functions_procedures.sql`
   - `backend/modelo_fisico/modulo_triggers/test_triggers.sql`
   - `backend/modelo_fisico/modulo_views_roles_e_privilegios_minimos/test_views_roles.sql`
3. Execute o script clicando no ícone do **Raio** (*Execute the selected portion of the script or everything*).
4. Acompanhe os resultados no painel **Action Output** na parte inferior:
   - Consultas de asserção retornam mensagens de validação com status `OK` / `PASSOU`.
   - Testes de integridade (como violação intencional de constraints ou triggers) reportam os erros esperados capturados pelo script.

---

## Catálogo de Tabelas

O modelo físico é composto por 15 tabelas (13 de domínio e 2 técnicas):

| Categoria | Tabela | Finalidade Principal |
|---|---|---|
| **Núcleo de Cadastro** | `UNIDADE` | Cadastro das filiais e academias da rede |
| | `PAPEL` | Perfis e níveis de acesso ao sistema |
| | `USUARIO` | Credenciais e status de autenticação |
| | `USUARIO_PAPEL` | Relação N:N entre usuários e papéis |
| | `ALUNO` | Cadastro dos membros e isolamento por unidade |
| | `COLABORADOR` | Instrutores e colaboradores operacionais |
| **Comercial / Financeiro** | `PLANO` | Catálogo de produtos, planos e precificação |
| | `CONTRATO` | Vínculo contratual do aluno (regra: 1 ativo por aluno) |
| | `MENSALIDADE` | Parcelas e competências financeiras mensais (`AAAA-MM`) |
| | `PAGAMENTO` | Liquidação financeira e registro de estornos |
| **Operação** | `TURMA` | Horários de aulas, atividades e capacidade máxima |
| | `ACESSO` | Registros de catraca / portaria |
| | `RESERVA_TURMA` | Inscrições e reservas de alunos por turma |
| **Técnicas** | `CONTADOR_DOCUMENTO` | Geração atômica de identificadores e matrículas |
| | `AUDITORIA_LOG` | Trilha de auditoria para operações DML sensíveis |

---

## Testes Integrados, Backup e Restauração

Para comprovar a resiliência e a recuperabilidade da base de dados relacional, o projeto conta com rotinas de testes integrados ponta a ponta e automação de Disaster Recovery (BK-DB-09), que podem ser executadas tanto via terminal (Docker / scripts) quanto interativamente via interface gráfica (MySQL Workbench).

### Opção 1: Via Linha de Comando (Docker e Scripts Automatizados)

1. **Bateria Integrada de Violações e Idempotência (Replay):**
   Executa testes cobrindo dados de seed, tentativas intencionais de violação (lotação de turmas, múltiplos contratos ativos, quebra de isolamento multiunidade) e proteção contra replays de webhook/faturamento:
   ```bash
   docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modulo_testes_sql_backup_e_restauracao/01_testes_integrados_violacoes_replay.sql
   ```

2. **Ciclo Automatizado de Backup Lógico e Restauração a Frio:**
   A rotina extrai um dump lógico consistente (`mysqldump` com `--single-transaction --routines --triggers --events`), cria uma base vazia (`kaizen_restore_test`), restaura integralmente o dump e executa auditoria no catálogo (`information_schema`) via `02_validacao_restauracao.sql` para atestar a recriação exata de tabelas, views, rotinas, triggers e seeds.

   - **No Linux / macOS (Bash):**
     ```bash
     chmod +x backend/modulo_testes_sql_backup_e_restauracao/executar_backup_e_restauracao.sh
     ./backend/modulo_testes_sql_backup_e_restauracao/executar_backup_e_restauracao.sh
     ```

   - **No Windows (PowerShell):**
     ```powershell
     powershell -ExecutionPolicy Bypass -File backend/modulo_testes_sql_backup_e_restauracao/executar_backup_e_restauracao.ps1
     ```

---

### Opção 2: Via MySQL Workbench (Interface Gráfica)

1. **Executar a Bateria Integrada de Testes:**
   - Conecte-se à instância MySQL e certifique-se de selecionar o schema principal (`USE kaizen;`).
   - Abra o script via menu **File** > **Open SQL Script...** (`Ctrl + Shift + O`) selecionando `backend/modulo_testes_sql_backup_e_restauracao/01_testes_integrados_violacoes_replay.sql`.
   - Clique no ícone do **Raio** para executar.
   - Acompanhe no painel **Action Output** e na grade de resultados as asserções de validação e os blocos de teste de integridade.

2. **Realizar Backup e Restauração Visual:**
   - **Exportação (Backup):**
     1. No menu lateral esquerdo (**Navigator**), acesse a aba **Administration** e clique em **Data Export**.
     2. Selecione o schema `kaizen`.
     3. Marque as opções **Dump Stored Procedures and Functions**, **Dump Events** e **Dump Triggers**.
     4. Selecione **Export to Self-Contained File** e defina o destino do arquivo `.sql`.
     5. Clique em **Start Export**.
   - **Importação (Restauração em base vazia para teste de recuperação):**
     1. Crie um schema vazio executando `CREATE SCHEMA kaizen_restore_test;`.
     2. Em **Administration**, clique em **Data Import/Restore**.
     3. Selecione **Import from Self-Contained File** e aponte para o backup exportado.
     4. Em **Default Target Schema**, selecione `kaizen_restore_test`.
     5. Clique em **Start Import**.
   - **Validação pós-Restauração:**
     1. Selecione o schema restaurado: `USE kaizen_restore_test;`.
     2. Abra e execute o script `backend/modulo_testes_sql_backup_e_restauracao/02_validacao_restauracao.sql`.
     3. Verifique se todas as verificações retornam `PASS` para a integridade de tabelas, visões, triggers e seeds.
