# Módulo de Triggers (6 Regras / 7 Objetos) (BK-DB-07)

| Metadado | Detalhe |
|---|---|
| **Tarefa** | `BK-DB-07`: Triggers (6 regras / 7 objetos) |
| **Etapa do Plano** | Etapa 4 (Objetos e Segurança) |
| **SGBD** | MySQL Server 8.0.46 / MySQL Workbench 8.0.47 CE |
| **Engine / Collation** | InnoDB / `utf8mb4` / `utf8mb4_0900_ai_ci` |
| **Dependências** | Núcleo de Cadastro (`BK-DB-03`), DDL Comercial/Financeiro (`BK-DB-04`), DDL Operação e Tabela Técnica (`BK-DB-05`), Functions e Procedures (`BK-DB-06`) |

---

## 1. Visão Geral

Este módulo implementa os gatilhos declarativos de banco de dados responsáveis pela imposição ativa e automatizada de regras críticas de negócio diretamente no motor relacional MySQL. Ele garante a integridade dos dados e a rejeição imediata de violações operacionais, independentemente da aplicação, usuário ou ferramenta que execute os comandos de manipulação de dados (`INSERT` ou `UPDATE`).

---

## 2. Estrutura de Artefatos do Módulo

```text
src/backend/modulo_triggers/
├── 05_triggers.sql         # DDL de criação dos 7 objetos de triggers
├── test_triggers.sql       # Script de testes automatizados e asserções de aceite
└── README.md               # Este documento de especificação e guia de execução
```

---

## 3. Catálogo de Objetos e Regras de Negócio

| Regra | Objeto de Gatilho | Tabela Alvo | Evento | Comportamento e Regra de Negócio |
|---|---|---|---|---|
| **Regra 1** | `trg_contrato_numero` | `CONTRATO` | `BEFORE INSERT` | Gera automaticamente a numeração sequencial padronizada de contratos no formato `CTR-AAAA-000001` por unidade e ano caso o campo venha nulo ou em branco, integrando com `sp_proximo_numero('CONTRATO', ...)`. |
| **Regra 2** | `trg_pagamento_status` | `PAGAMENTO` | `AFTER INSERT` | Recalcula de forma reativa o status da mensalidade associada (`PAGA`, `PARCIAL`, `ABERTA`) por agregação direta da soma compensatória de pagamentos e estornos em relação ao valor nominal e encargos. Preserva o status `CANCELADA`. |
| **Regra 3** | `trg_acesso_validacao` | `ACESSO` | `BEFORE INSERT` | Avalia dinamicamente a elegibilidade de acesso físico via `fn_acesso_elegivel(NEW.id_aluno)`. Preenche `liberado = 1` e `motivo = 'LIBERADO'` ou `liberado = 0` e `motivo = 'CONTRATO_INATIVO_OU_INADIMPLENTE'`, garantindo persistência da tentativa sem disparar erro na catraca. |
| **Regra 4** | `trg_turma_sem_overlap_i` | `TURMA` | `BEFORE INSERT` | Bloqueia ativamente com `SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflito de sala ou instrutor'` qualquer inserção de turma com sobreposição de horário para a mesma sala ou para o mesmo instrutor na mesma unidade. |
| **Regra 4** | `trg_turma_sem_overlap_u` | `TURMA` | `BEFORE UPDATE` | Impõe a mesma restrição temporal anti-overlap para atualizações de turmas existentes na unidade, desconsiderando explicitamente a própria linha sob edição (`t.id_turma <> NEW.id_turma`). |
| **Regra 5** | `trg_reserva_capacidade` | `RESERVA_TURMA` | `BEFORE INSERT` | Valida se a quantidade de vagas confirmadas atingiu a capacidade máxima da turma. Se `NEW.status = 'CONFIRMADA'` e a turma estiver lotada, rejeita a inserção com `SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Turma lotada: use ESPERA'`. Aceita reservas em `ESPERA`. |
| **Regra 6** | `trg_auditoria_aluno` | `ALUNO` | `AFTER UPDATE` | Captura transparentemente fotos em JSON dos dados cadastrais sensíveis de antes (`OLD`) e depois (`NEW`) (`nome`, `cpf`, `email`, `data_nascimento`, `ativo`), gravando o log histórico em `AUDITORIA_LOG` com a conta conectada obtida via `USER()`. |

---

## 4. Guia de Instalação e Execução

### 4.1 Criação dos Triggers no MySQL 8.0 / MySQL Workbench

Execute o script `05_triggers.sql` conectado à instância com usuário detentor de privilégios de administração (`SUPER` / `TRIGGER`):

```sql
USE kaizen;
SOURCE src/backend/modulo_triggers/05_triggers.sql;
```

*Nota para execução manual no Workbench*: O script inclui controle explícito de delimitadores (`DELIMITER $$ ... DELIMITER ;`). Execute o arquivo completo como script (*Execute the entire script*, `Ctrl+Shift+Enter`).

### 4.2 Execução dos Testes Automatizados

Após a criação dos triggers, execute o script de validação automatizada:

```sql
USE kaizen;
SOURCE src/backend/modulo_triggers/test_triggers.sql;
```

O script executa asserções cobrindo todos os cenários positivos e negativos (incluindo tratamento de erros esperados `45000`) e exibe o consolidado final com a contagem de testes aprovados e reprovados.

---

## 5. Matriz de Conformidade com os Critérios de Aceite (`BK-DB-07`)

| # | Critério de Aceite do Backlog | Evidência de Implementação | Status |
|---|---|---|:---:|
| **AC-1** | Numeração automática de contrato | `trg_contrato_numero` implementado em `BEFORE INSERT ON contrato`, gerando padrão `CTR-AAAA-000001` via `sp_proximo_numero` quando omitido. | **PASS** |
| **AC-2** | Recálculo de status após pagamento | `trg_pagamento_status` implementado em `AFTER INSERT ON pagamento` com agregação direta em SQL, atualizando `mensalidade.status` (`PAGA`, `PARCIAL`, `ABERTA`) e preservando `CANCELADA`. | **PASS** |
| **AC-3** | Validação de acesso em catraca | `trg_acesso_validacao` implementado em `BEFORE INSERT ON acesso` consultando `fn_acesso_elegivel`, persistindo acessos negados com `liberado = 0` e motivo padronizado. | **PASS** |
| **AC-4** | Anti-overlap em `INSERT` e `UPDATE` de turmas | `trg_turma_sem_overlap_i` e `trg_turma_sem_overlap_u` implementados em `turma`, disparando `SIGNAL 45000` em caso de colisão de sala ou instrutor no intervalo. | **PASS** |
| **AC-5** | Capacidade de turma | `trg_reserva_capacidade` implementado em `BEFORE INSERT ON reserva_turma`, bloqueando reservas `CONFIRMADA` quando lotada e permitindo `ESPERA`. | **PASS** |
| **AC-6** | Auditoria de `UPDATE` em aluno com antes/depois | `trg_auditoria_aluno` implementado em `AFTER UPDATE ON aluno`, serializando snapshots JSON em `AUDITORIA_LOG` com o ator retornado por `USER()`. | **PASS** |
