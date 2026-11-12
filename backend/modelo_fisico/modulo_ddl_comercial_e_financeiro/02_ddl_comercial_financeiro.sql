-- ============================================================================
-- Kaizen ERP - DDL Comercial e Financeiro
-- Dialeto / Engine: MySQL 8.0.46 (InnoDB, utf8mb4, utf8mb4_0900_ai_ci)
-- Tabelas: PLANO, CONTRATO, MENSALIDADE, PAGAMENTO
-- Tarefa: GL4BD-4 (BK-DB-04)
-- Dependência: Núcleo de Cadastro (UNIDADE, ALUNO)
-- ============================================================================

USE kaizen;

SET NAMES utf8mb4;
SET character_set_client = utf8mb4;

-- ----------------------------------------------------------------------------
-- 1. PLANO (Catálogo de Planos)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PLANO (
  id_plano            SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome                VARCHAR(50)   NOT NULL,
  periodicidade_meses TINYINT UNSIGNED NOT NULL,
  valor_mensal        DECIMAL(10,2) NOT NULL,
  carencia_dias       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  multa_percentual    DECIMAL(5,2)  NOT NULL DEFAULT 0,
  ativo               TINYINT(1)    NOT NULL DEFAULT 1,
  PRIMARY KEY (id_plano),
  UNIQUE KEY uq_plano_nome (nome),
  CONSTRAINT ck_plano_periodo CHECK (periodicidade_meses > 0),
  CONSTRAINT ck_plano_valor   CHECK (valor_mensal > 0),
  CONSTRAINT ck_plano_multa   CHECK (multa_percentual >= 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ----------------------------------------------------------------------------
-- 2. CONTRATO
-- Nota de Integridade:
--  - Coluna gerada ativo_unico garante no máximo 1 contrato com status 'ATIVO' por aluno.
--  - FK composta (id_aluno, id_unidade) assegura isolamento e integridade multiunidade.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CONTRATO (
  id_contrato    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  numero         VARCHAR(24)  NULL,
  id_aluno       INT UNSIGNED NOT NULL,
  id_unidade     INT UNSIGNED NOT NULL,
  id_plano       SMALLINT UNSIGNED NOT NULL,
  data_inicio    DATE NOT NULL,
  data_fim       DATE NULL,
  dia_vencimento TINYINT UNSIGNED NOT NULL,
  valor_mensal   DECIMAL(10,2) NOT NULL,
  status         ENUM('ATIVO','SUSPENSO','CANCELADO') NOT NULL DEFAULT 'ATIVO',
  assinado_em    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ativo_unico    TINYINT UNSIGNED GENERATED ALWAYS AS (IF(status = 'ATIVO', 1, NULL)) STORED,
  PRIMARY KEY (id_contrato),
  UNIQUE KEY uq_contrato_numero (numero),
  UNIQUE KEY uq_contrato_ativo_por_aluno (id_aluno, ativo_unico),
  KEY ix_contrato_aluno_unidade (id_aluno, id_unidade),
  KEY ix_contrato_unidade (id_unidade),
  KEY ix_contrato_plano (id_plano),
  KEY ix_contrato_status (status, data_inicio),
  CONSTRAINT fk_contrato_aluno_unidade FOREIGN KEY (id_aluno, id_unidade)
    REFERENCES ALUNO (id_aluno, id_unidade) ON DELETE RESTRICT,
  CONSTRAINT fk_contrato_unidade FOREIGN KEY (id_unidade)
    REFERENCES UNIDADE (id_unidade) ON DELETE RESTRICT,
  CONSTRAINT fk_contrato_plano FOREIGN KEY (id_plano)
    REFERENCES PLANO (id_plano) ON DELETE RESTRICT,
  CONSTRAINT ck_contrato_dia CHECK (dia_vencimento BETWEEN 1 AND 28),
  CONSTRAINT ck_contrato_datas CHECK (data_fim IS NULL OR data_fim >= data_inicio),
  CONSTRAINT ck_contrato_valor CHECK (valor_mensal > 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ----------------------------------------------------------------------------
-- 3. MENSALIDADE
-- Nota de Integridade:
--  - uq_mensalidade_competencia garante idempotência de geração (1 competência por contrato).
--  - CHECKs validam formato AAAA-MM e regras de encargos e descontos.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS MENSALIDADE (
  id_mensalidade INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_contrato    INT UNSIGNED NOT NULL,
  competencia    CHAR(7) NOT NULL,
  vencimento     DATE NOT NULL,
  valor          DECIMAL(10,2) NOT NULL,
  juros          DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  multa          DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  desconto       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  status         ENUM('ABERTA','PARCIAL','PAGA','CANCELADA') NOT NULL DEFAULT 'ABERTA',
  criado_em      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id_mensalidade),
  UNIQUE KEY uq_mensalidade_competencia (id_contrato, competencia),
  KEY ix_mensalidade_status_vencimento (status, vencimento),
  CONSTRAINT fk_mensalidade_contrato FOREIGN KEY (id_contrato)
    REFERENCES CONTRATO (id_contrato) ON DELETE RESTRICT,
  CONSTRAINT ck_mensalidade_competencia CHECK (competencia REGEXP '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  CONSTRAINT ck_mensalidade_valor CHECK (valor > 0),
  CONSTRAINT ck_mensalidade_encargos CHECK (juros >= 0 AND multa >= 0 AND desconto >= 0 AND desconto <= valor)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ----------------------------------------------------------------------------
-- 4. PAGAMENTO
-- Nota de Integridade:
--  - uq_pagamento_id_externo garante idempotência no processamento de pagamentos/webhooks.
--  - Estorno é sempre um lançamento compensatório referenciando id_pagamento_original.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PAGAMENTO (
  id_pagamento          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_mensalidade        INT UNSIGNED NOT NULL,
  tipo                  ENUM('RECEBIMENTO','ESTORNO') NOT NULL DEFAULT 'RECEBIMENTO',
  valor                 DECIMAL(10,2) NOT NULL,
  forma                 ENUM('PIX','BOLETO','CARTAO','DINHEIRO') NOT NULL,
  id_externo            VARCHAR(64) NULL,
  id_pagamento_original BIGINT UNSIGNED NULL,
  pago_em               TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id_pagamento),
  UNIQUE KEY uq_pagamento_id_externo (id_externo),
  KEY ix_pagamento_mensalidade (id_mensalidade, tipo),
  KEY ix_pagamento_original (id_pagamento_original),
  CONSTRAINT fk_pagamento_mensalidade FOREIGN KEY (id_mensalidade)
    REFERENCES MENSALIDADE (id_mensalidade) ON DELETE RESTRICT,
  CONSTRAINT fk_pagamento_estorno FOREIGN KEY (id_pagamento_original)
    REFERENCES PAGAMENTO (id_pagamento) ON DELETE RESTRICT,
  CONSTRAINT ck_pagamento_valor CHECK (valor > 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
