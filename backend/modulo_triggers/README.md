# Módulo: Triggers (6 Regras / 7 Objetos)

**Identificador**: `modulo_triggers`
**Escopo**: Núcleo Transacional de Banco de Dados — Kaizen ERP (Rede de Academias)
**Stack Alvo**: MySQL Server 8.0.46 / MySQL Workbench 8.0.47 CE
**Tarefa de Referência**: **BK-DB-07**
**Status**: Implementado e Testado

---

## 1. Visão Geral do Módulo

O módulo de Triggers encapsula a **integridade ativa de dados** do Kaizen BD. Ele assegura que regras operacionais críticas, automações financeiras, controle de acesso físico e trilhas de auditoria sejam aplicados e defendidos diretamente pelo motor de banco de dados (`InnoDB`), rejeitando violações independentemente da aplicação cliente ou do usuário que submeta a instrução DML.

O conjunto contempla **6 regras de negócio fundamentais** materializadas em **7 objetos de gatilho**:

| # | Regra de Negócio | Objeto de Gatilho | Evento | Tabela | Mecanismo |
|---|---|---|---|---|---|
| **1** | Numeração automática de contratos | `trg_contrato_numero` | `BEFORE INSERT` | `contrato` | Invocação atômica de `sp_proximo_numero` gerando formato `CTR-AAAA-000001`. |
| **2** | Recálculo de status após pagamento | `trg_pagamento_status` | `AFTER INSERT` | `pagamento` | Agregação direta de recebimentos e estornos atualizando `mensalidade.status` (`PAGA`, `PARCIAL`, `ABERTA`). |
| **3** | Validação de acesso na catraca | `trg_acesso_validacao` | `BEFORE INSERT` | `acesso` | Chamada à função `fn_acesso_elegivel` persistindo `liberado` (1 ou 0) e `motivo`. |
| **4** | Anti-overlap temporal de turmas (Insert) | `trg_turma_sem_overlap_i` | `BEFORE INSERT` | `turma` | `SIGNAL SQLSTATE '45000'` em caso de colisão de horário para mesma sala ou instrutor na mesma unidade. |
| **4** | Anti-overlap temporal de turmas (Update) | `trg_turma_sem_overlap_u` | `BEFORE UPDATE` | `turma` | `SIGNAL SQLSTATE '45000'` em colisão de horário, excluindo a própria linha (`t.id_turma <> NEW.id_turma`). |
| **5** | Controle de capacidade de turma | `trg_reserva_capacidade` | `BEFORE INSERT` | `reserva_turma` | `SIGNAL SQLSTATE '45000'` ('Turma lotada: use ESPERA') se reservas `CONFIRMADA` \(\ge\) capacidade. |
| **6** | Auditoria de atualização de alunos | `trg_auditoria_aluno` | `AFTER UPDATE` | `aluno` | Inserção em `auditoria_log` com JSON de estados `antes` e `depois` e conta real via `USER()`. |

---

## 2. Estrutura de Arquivos

| Arquivo | Descrição |
|---|---|
| [`triggers.sql`](triggers.sql) | Script DDL completo dos 7 gatilhos com delimitadores (`DELIMITER $$`), remoção prévia idempotente e tratamento de exceções. |
| [`testes_triggers.sql`](testes_triggers.sql) | Suíte completa de testes automatizados com procedure de execução (`sp_executar_testes_triggers`), asserções funcionais e testes negativos de `SQLSTATE '45000'`. |
| [`README.md`](README.md) | Documentação técnica, especificações de regras e mapeamento dos critérios de aceite. |

---

## 3. Instruções de Execução

### No MySQL Workbench 8.0.47 CE:
1. Abra e execute o script [`triggers.sql`](triggers.sql) (*File → Open SQL Script → Execute*).
2. Abra e execute o script [`testes_triggers.sql`](testes_triggers.sql).
3. Execute a chamada de testes no SQL Editor:
   ```sql
   CALL sp_executar_testes_triggers();
   ```

---

## 4. Conformidade com os Critérios de Aceite (BK-DB-07)

| Critério de Aceite | Status | Evidência de Implementação |
|---|---|---|
| **Numeração de contrato** | **Atendido** | `trg_contrato_numero` formata `CTR-AAAA-000001` via `sp_proximo_numero` em inserção sem número. |
| **Recálculo de status após pagamento** | **Atendido** | `trg_pagamento_status` agrega recebimentos e estornos, atualizando para `PAGA`, `PARCIAL` ou `ABERTA`. |
| **Validação de acesso** | **Atendido** | `trg_acesso_validacao` avalia adimplência via `fn_acesso_elegivel` e preenche `liberado` e `motivo`. |
| **Anti-overlap em INSERT e UPDATE** | **Atendido** | `trg_turma_sem_overlap_i` e `trg_turma_sem_overlap_u` impedem colisões de sala/instrutor com `SQLSTATE '45000'`. |
| **Capacidade de turma** | **Atendido** | `trg_reserva_capacidade` bloqueia reservas confirmadas além da lotação física máxima. |
| **Auditoria de UPDATE em aluno com antes/depois** | **Atendido** | `trg_auditoria_aluno` grava em `auditoria_log` JSON completo com dados anteriores e novos e usuário de conexão `USER()`. |

---

## 5. Rastreabilidade com a Especificação

- **Feature Directory**: `specs/002-triggers-regras-negocio/`
- **Especificação**: `specs/002-triggers-regras-negocio/spec.md`
- **Plano**: `specs/002-triggers-regras-negocio/plan.md`
- **Tarefas**: `specs/002-triggers-regras-negocio/tasks.md`
- **Contratos de Trigger**: `specs/002-triggers-regras-negocio/contracts/trigger-contracts.md`
- **Guia de Validação Rápida**: `specs/002-triggers-regras-negocio/quickstart.md`
