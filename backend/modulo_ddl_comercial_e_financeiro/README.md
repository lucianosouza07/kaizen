# Módulo DDL Comercial e Financeiro (GL4BD-4 / BK-DB-04)

| Metadado | Detalhe |
|---|---|
| **Tarefa** | GL4BD-4 (`BK-DB-04`: DDL comercial e financeiro) |
| **Etapa** | 3 (Modelo Físico e Integridade Declarativa) |
| **SGBD** | MySQL Server 8.0.46 / InnoDB / `utf8mb4_0900_ai_ci` |
| **Dependência** | `BK-DB-03` (DDL do núcleo de cadastro: `UNIDADE`, `ALUNO`) |

---

## 1. Visão Geral

Este módulo implementa o DDL das quatro tabelas do núcleo comercial e financeiro do Kaizen ERP:
* `PLANO`: Catálogo global de planos e precificação.
* `CONTRATO`: Contratos de alunos, com restrição estrita de 1 contrato ativo por aluno e chave estrangeira composta multiunidade.
* `MENSALIDADE`: Parcelas e faturamentos com competência mensal (`AAAA-MM`) idempotente por contrato.
* `PAGAMENTO`: Registro transacional de recebimentos e estornos compensatórios com idempotência de baixa externa.

---

## 2. Dicionário das Tabelas e Decisões de Design

### 2.1 `PLANO`
* **Finalidade:** Catálogo de planos disponíveis na rede de academias.
* **PK:** `id_plano` (`SMALLINT UNSIGNED AUTO_INCREMENT`).
* **Integridade:**
  * `uq_plano_nome`: Unicidade do nome do plano.
  * `ck_plano_periodo`: `periodicidade_meses > 0`.
  * `ck_plano_valor`: `valor_mensal > 0` (`DECIMAL(10,2)`).
  * `ck_plano_multa`: `multa_percentual >= 0` (`DECIMAL(5,2)`).

### 2.2 `CONTRATO`
* **Finalidade:** Vínculo formal do aluno com um plano em uma unidade específica.
* **PK:** `id_contrato` (`INT UNSIGNED AUTO_INCREMENT`).
* **Coluna Gerada (`ativo_unico`):**
  * Expressão: `TINYINT UNSIGNED GENERATED ALWAYS AS (IF(status = 'ATIVO', 1, NULL)) STORED`.
  * Restrição: `UNIQUE KEY uq_contrato_ativo_por_aluno (id_aluno, ativo_unico)`.
  * *Efeito:* Garante no máximo 1 contrato com status `ATIVO` por aluno. Como `NULL` não colide em índices únicos no MySQL InnoDB, o aluno pode ter múltiplos contratos com status `CANCELADO` ou `SUSPENSO` (histórico preservado sem violação).
* **FK Composta:**
  * `(id_aluno, id_unidade)` referencia `ALUNO(id_aluno, id_unidade)` garantindo que o contrato não seja assinado em unidade divergente do cadastro do aluno.
* **Constraints de Negócio:**
  * `ck_contrato_dia`: `dia_vencimento BETWEEN 1 AND 28` (dias válidos em todos os meses do ano).
  * `ck_contrato_datas`: `data_fim IS NULL OR data_fim >= data_inicio`.
  * `ck_contrato_valor`: `valor_mensal > 0` (`DECIMAL(10,2)`).

### 2.3 `MENSALIDADE`
* **Finalidade:** Obrigações financeiras periódicas geradas para um contrato.
* **PK:** `id_mensalidade` (`INT UNSIGNED AUTO_INCREMENT`).
* **Idempotência Declarativa:**
  * `UNIQUE KEY uq_mensalidade_competencia (id_contrato, competencia)`.
  * Impede faturamento duplicado para o mesmo mês/ano de um contrato.
* **Constraints:**
  * `ck_mensalidade_competencia`: `competencia REGEXP '^[0-9]{4}-(0[1-9]|1[0-2])$'` (validação estrita do padrão ISO AAAA-MM).
  * `ck_mensalidade_valor`: `valor > 0` (`DECIMAL(10,2)`).
  * `ck_mensalidade_encargos`: `juros >= 0 AND multa >= 0 AND desconto >= 0 AND desconto <= valor`.

### 2.4 `PAGAMENTO`
* **Finalidade:** Transações financeiras recebidas e estornos compensatórios.
* **PK:** `id_pagamento` (`BIGINT UNSIGNED AUTO_INCREMENT`).
* **Idempotência:**
  * `UNIQUE KEY uq_pagamento_id_externo (id_externo)`: Garante que retornos de gateways/webhooks (ex: PIX/Boleto) não sejam processados repetidamente.
* **Estorno Compensatório:**
  * O estorno nunca sobrescreve o pagamento original; cria um registro compensatório com `tipo = 'ESTORNO'` e referencia `id_pagamento_original`.
* **Precisão:**
  * `pago_em TIMESTAMP(3)` com precisão de milissegundos para auditoria financeira precisa.

---

## 3. Critérios de Aceite Atendidos

| Critério do Backlog (`BK-DB-04`) | Implementação Técnica | Status |
|---|---|---|
| `DECIMAL(10,2)` em todos os valores | Utilizado em `PLANO`, `CONTRATO`, `MENSALIDADE` e `PAGAMENTO` | ✅ Atendido |
| `uq_contrato_ativo_por_aluno` | Coluna gerada `ativo_unico` + índice único no MySQL InnoDB | ✅ Atendido |
| `uq_mensalidade_competencia` | Chave única em `(id_contrato, competencia)` | ✅ Atendido |
| `uq_pagamento_id_externo` | Chave única em `id_externo` (`VARCHAR(64)`) | ✅ Atendido |
| `CHECK`s de dia, data, competência e encargos | Constraints `ck_contrato_dia`, `ck_contrato_datas`, `ck_mensalidade_competencia`, `ck_mensalidade_encargos` | ✅ Atendido |
| Integridade multiunidade por FK composta | `fk_contrato_aluno_unidade` referenciando `ALUNO(id_aluno, id_unidade)` | ✅ Atendido |

---

## 4. Instruções de Execução e Teste

### Pré-requisito
Certifique-se de que o container MySQL está ativo e que o DDL do núcleo de cadastro foi executado:

```bash
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modulo_ddl_do_nucleo_de_cadastro/01_ddl_nucleo_cadastro.sql
```

### 1. Aplicação do DDL Comercial e Financeiro
```bash
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modulo_ddl_comercial_e_financeiro/02_ddl_comercial_financeiro.sql
```

### 2. Execução da Suíte de Testes
```bash
docker exec -i kaizen-mysql-test mysql -u root -proot kaizen < backend/modulo_ddl_comercial_e_financeiro/test_ddl_comercial_financeiro.sql
```

