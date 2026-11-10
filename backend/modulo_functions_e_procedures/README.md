# Módulo de Functions e Procedures (BK-DB-06)

| Metadado | Detalhe |
|---|---|
| **Tarefa** | `BK-DB-06`: Functions e procedures (inclui contadores) |
| **Etapa do Plano** | Etapa 4 (Objetos e Segurança) |
| **SGBD** | MySQL Server 8.0.46 / MySQL Workbench 8.0.47 CE |
| **Engine / Collation** | InnoDB / `utf8mb4` / `utf8mb4_0900_ai_ci` |
| **Dependências** | Núcleo de Cadastro (`BK-DB-03`), DDL Comercial/Financeiro (`BK-DB-04`), DDL Operação e Tabela Técnica (`BK-DB-05`) |

---

## 1. Visão Geral

Este módulo encapsula as regras de cálculo, verificação analítica e procedimentos transacionais críticos do sistema **Kaizen ERP**, garantindo que operações fundamentais de faturamento, liquidação de mensalidades, liberação de acesso e expurgo de dados pessoais (LGPD) sejam executadas com atomicidade e idempotência diretamente na camada relacional do banco de dados.

---

## 2. Estrutura de Artefatos do Módulo

```text
src/backend/modulo_functions_e_procedures/
├── 01_functions_procedures.sql   # DDL de criação das 4 functions e 4 procedures
├── test_functions_procedures.sql # Script de testes automatizados e asserções de aceite
└── README.md                     # Este documento de especificação e guia de execução
```

---

## 3. Catálogo de Objetos

### 3.1 Funções Armazenadas (4 rotinas `READS SQL DATA`)

| Função | Retorno | Finalidade e Regra |
|---|---|---|
| `fn_valor_devido(p_mensalidade)` | `DECIMAL(12,2)` | Calcula o saldo devedor líquido atual: `GREATEST((valor + juros + multa - desconto) - (recebimentos - estornos), 0.00)`. Retorna `0.00` se a mensalidade foi integralmente liquidada ou sobrepaga. |
| `fn_status_mensalidade(p_mensalidade)` | `VARCHAR(10)` | Determina dinamicamente o status do faturamento: `'CANCELADA'` se a mensalidade estiver cancelada; `'PAGA'` se o saldo devedor for $\le 0$; `'PARCIAL'` se houver pagamentos positivos mas saldo remanescente; ou `'ABERTA'`. |
| `fn_acesso_elegivel(p_aluno)` | `TINYINT(1)` | Retorna `1` se o aluno possuir contrato `ATIVO` vigente e o atraso na mensalidade pendente mais antiga for de no máximo 5 dias corridos; caso contrário, retorna `0` (bloqueado na catraca). |
| `fn_ocupacao_turma(p_turma)` | `SMALLINT UNSIGNED` | Retorna a quantidade inteira de reservas com status `'CONFIRMADA'` para a turma informada. |

### 3.2 Procedimentos Armazenados (4 rotinas `MODIFIES SQL DATA`)

| Procedimento | Assinatura | Mecanismo de Idempotência e Efeito |
|---|---|---|
| `sp_proximo_numero` | `(IN p_tipo, IN p_unidade, OUT p_numero)` | Emula gerador atômico de sequências por unidade no MySQL via `INSERT ... ON DUPLICATE KEY UPDATE ultimo = LAST_INSERT_ID(ultimo + 1)`. Suporta as séries `'CONTRATO'` e `'NFSE'`. |
| `sp_gerar_mensalidades` | `(IN p_competencia, IN p_unidade)` | Emite mensalidades em lote para contratos ativos da competência (`AAAA-MM`). A idempotência é assegurada pelo `INSERT IGNORE` indexado por `uq_mensalidade_competencia(id_contrato, competencia)`. Retorna `geradas` (`ROW_COUNT()`). |
| `sp_registrar_pagamento` | `(IN p_mensalidade, IN p_valor, IN p_forma, IN p_id_externo)` | Registra quitação financeira com validação de forma (`PIX`, `BOLETO`, `CARTAO`, `DINHEIRO`) e `INSERT IGNORE` indexado por `uq_pagamento_id_externo(id_externo)`. Retorna `inseridos` e o `status_atual` via `fn_status_mensalidade`. |
| `sp_anonimizar_aluno` | `(IN p_aluno)` | Substitui dados pessoais (PII) por valores genéricos mascarados (`nome`, `cpf`, `email`, `data_nascimento`), revoga `consentimento_lgpd_em` e seta `ativo = 0`. Preserva a chave primária `id_aluno` e todas as FKs intactas. |

---

## 4. Guia de Instalação e Execução

### 4.1 Criação das Rotinas no MySQL 8.0 / MySQL Workbench

Execute o script `01_functions_procedures.sql` conectado à instância com usuário detentor de privilégios `CREATE ROUTINE`:

```sql
USE kaizen;
SOURCE src/backend/modulo_functions_e_procedures/01_functions_procedures.sql;
```

*Nota para execução manual no Workbench*: O script inclui controle explícito de delimitadores (`DELIMITER $$ ... DELIMITER ;`). Certifique-se de executar o arquivo completo como script (*Execute the entire script*, `Ctrl+Shift+Enter`).

### 4.2 Execução dos Testes Automatizados

Após a criação das rotinas, execute o script de validação:

```sql
USE kaizen;
SOURCE src/backend/modulo_functions_e_procedures/test_functions_procedures.sql;
```

---

## 5. Matriz de Conformidade com os Critérios de Aceite (`BK-DB-06`)

| # | Critério de Aceite do Backlog | Evidência de Implementação | Status |
|---|---|---|:---:|
| **AC-1** | 4 functions com cláusula `READS SQL DATA` | `fn_valor_devido`, `fn_status_mensalidade`, `fn_acesso_elegivel`, `fn_ocupacao_turma` declaradas e registradas no `information_schema.routines` com `sql_data_access = 'READS SQL DATA'`. | **PASS** |
| **AC-2** | 4 procedures armazenadas | `sp_proximo_numero`, `sp_gerar_mensalidades`, `sp_registrar_pagamento`, `sp_anonimizar_aluno` implementadas com `MODIFIES SQL DATA`. | **PASS** |
| **AC-3** | `sp_proximo_numero` emula 2 séries com `LAST_INSERT_ID()` | Atomicidade assegurada por `LAST_INSERT_ID(ultimo + 1)` sobre `CONTADOR_DOCUMENTO`, com suporte a séries `'CONTRATO'` e `'NFSE'` particionadas por `id_unidade`. | **PASS** |
| **AC-4** | `sp_gerar_mensalidades` e `sp_registrar_pagamento` idempotentes | Execuções consecutivas para os mesmos parâmetros produzem `geradas = 0` e `inseridos = 0`, protegidas por chaves únicas e `INSERT IGNORE`. | **PASS** |
| **AC-5** | `sp_anonimizar_aluno` preserva FKs | Descaracterização de PII em `ALUNO` mantendo `id_aluno` inalterado, preservando contratos, acessos e integridade referencial. | **PASS** |
