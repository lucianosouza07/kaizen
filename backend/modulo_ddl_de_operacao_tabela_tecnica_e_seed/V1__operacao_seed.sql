-- =============================================================================
-- V1__operacao_seed.sql
-- Kaizen BD — DDL de Operação, Tabela Técnica e Seed (BK-DB-05)
-- MySQL 8.0.46 | InnoDB | utf8mb4_0900_ai_ci
-- Ordem de criação: TURMA → ACESSO → RESERVA_TURMA → AUDITORIA_LOG → SEED
-- Dependências: unidade, aluno, colaborador, plano, contrato, mensalidade, pagamento
-- =============================================================================

USE kaizen;

-- =============================================================================
-- SEÇÃO 1: TURMA
-- =============================================================================

CREATE TABLE turma (
  id_turma     INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  id_unidade   INT UNSIGNED     NOT NULL,
  id_instrutor INT UNSIGNED     NOT NULL,
  modalidade   VARCHAR(50)      NOT NULL,
  sala         VARCHAR(30)      NOT NULL,
  capacidade   SMALLINT UNSIGNED NOT NULL,
  inicio       DATETIME         NOT NULL,
  fim          DATETIME         NOT NULL,
  PRIMARY KEY (id_turma),
  -- Suporte à FK composta em RESERVA_TURMA (id_turma, id_unidade)
  UNIQUE KEY uq_turma_unidade (id_turma, id_unidade),
  -- Anti-overlap: busca por instrutor + período
  KEY ix_turma_instrutor_periodo (id_instrutor, id_unidade, inicio, fim),
  -- Anti-overlap: busca por sala + período
  KEY ix_turma_sala_periodo (id_unidade, sala, inicio, fim),
  -- FK composta: instrutor deve pertencer à mesma unidade da turma
  CONSTRAINT fk_turma_instrutor_unidade
    FOREIGN KEY (id_instrutor, id_unidade)
    REFERENCES colaborador (id_colaborador, id_unidade),
  CONSTRAINT fk_turma_unidade
    FOREIGN KEY (id_unidade)
    REFERENCES unidade (id_unidade),
  CONSTRAINT ck_turma_capacidade CHECK (capacidade > 0),
  CONSTRAINT ck_turma_periodo    CHECK (fim > inicio)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

-- =============================================================================
-- SEÇÃO 2: ACESSO
-- =============================================================================

CREATE TABLE acesso (
  id_acesso  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_aluno   INT UNSIGNED    NOT NULL,
  id_unidade INT UNSIGNED    NOT NULL,
  -- TIMESTAMP(3): instante de alta precisão em UTC
  data_hora  TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  liberado   TINYINT(1)      NOT NULL DEFAULT 0,
  motivo     VARCHAR(40)     NOT NULL DEFAULT '',
  PRIMARY KEY (id_acesso),
  -- Histórico por aluno (trg_acesso_validacao, fn_acesso_elegivel)
  KEY ix_acesso_aluno_unidade (id_aluno, id_unidade),
  -- Histórico por unidade/período (vw_acesso_diario)
  KEY ix_acesso_unidade_data (id_unidade, data_hora),
  -- FK composta: aluno deve pertencer à unidade registrada
  CONSTRAINT fk_acesso_aluno_unidade
    FOREIGN KEY (id_aluno, id_unidade)
    REFERENCES aluno (id_aluno, id_unidade),
  CONSTRAINT fk_acesso_unidade
    FOREIGN KEY (id_unidade)
    REFERENCES unidade (id_unidade)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

-- =============================================================================
-- SEÇÃO 3: RESERVA_TURMA
-- =============================================================================

CREATE TABLE reserva_turma (
  id_reserva   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_turma     INT UNSIGNED    NOT NULL,
  id_aluno     INT UNSIGNED    NOT NULL,
  id_unidade   INT UNSIGNED    NOT NULL,
  status       ENUM('CONFIRMADA','ESPERA','CANCELADA') NOT NULL DEFAULT 'CONFIRMADA',
  reservada_em TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_reserva),
  -- Sem inscrições duplicadas do mesmo aluno na mesma turma
  UNIQUE KEY uq_reserva_turma_aluno (id_turma, id_aluno),
  -- fn_ocupacao_turma: contagem de CONFIRMADAS por turma
  KEY ix_reserva_turma_status (id_turma, status),
  -- Suporte à FK composta (id_turma, id_unidade)
  KEY ix_reserva_turma_unidade (id_turma, id_unidade),
  -- Suporte à FK composta (id_aluno, id_unidade)
  KEY ix_reserva_aluno_unidade (id_aluno, id_unidade),
  -- FK composta: turma deve pertencer à unidade da reserva
  CONSTRAINT fk_reserva_turma_unidade
    FOREIGN KEY (id_turma, id_unidade)
    REFERENCES turma (id_turma, id_unidade),
  -- FK composta: aluno deve pertencer à unidade da reserva
  CONSTRAINT fk_reserva_aluno_unidade
    FOREIGN KEY (id_aluno, id_unidade)
    REFERENCES aluno (id_aluno, id_unidade)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

-- =============================================================================
-- SEÇÃO 4: AUDITORIA_LOG (tabela técnica, sem FK)
-- =============================================================================

CREATE TABLE auditoria_log (
  id_log      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  tabela      VARCHAR(64)     NOT NULL,
  operacao    ENUM('INSERT','UPDATE','DELETE') NOT NULL,
  chave_pk    VARCHAR(64)     NOT NULL,
  -- Snapshots JSON: NULL em INSERT (antes) ou DELETE (depois)
  antes       JSON            NULL,
  depois      JSON            NULL,
  -- USER() captura a conta conectada real, não o DEFINER do trigger
  conta_mysql VARCHAR(100)    NOT NULL,
  -- TIMESTAMP(3): instante de alta precisão em UTC
  ocorrido_em TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id_log),
  -- Consulta de trilha por período
  KEY ix_auditoria_data (ocorrido_em),
  -- Consulta de trilha por entidade auditada
  KEY ix_auditoria_tabela (tabela, chave_pk)
  -- Sem FOREIGN KEY: tabela técnica independente; sobrevive a anonimizações e deleções lógicas
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

-- =============================================================================
-- SEÇÃO 5: SEED
-- (usuario / usuario_papel são populados pelo DBA após CREATE USER — TRD §7, TR-DB-13)
-- =============================================================================

-- 2 unidades operacionais
INSERT INTO unidade (nome, cnpj, cidade, ativa) VALUES
  ('Matriz',            '00000000000191', 'Salvador',   1),
  ('Filial Alagoinhas', '00000000000272', 'Alagoinhas', 1);

-- 6 papéis de segurança (RBAC)
INSERT INTO papel (nome) VALUES
  ('DBA'),
  ('GERENTE'),
  ('RECEPCAO'),
  ('FINANCEIRO'),
  ('INSTRUTOR'),
  ('ALUNO');

-- 2 planos de assinatura
INSERT INTO plano (nome, periodicidade_meses, valor_mensal, carencia_dias, multa_percentual) VALUES
  ('Mensal',  1,  129.90, 0, 2.00),
  ('Anual',   12,  99.90, 0, 2.00);

-- 2 contadores por unidade (CONTRATO + NFSE) = 4 linhas total; ultimo = 0
INSERT INTO contador_documento (tipo, id_unidade, ultimo)
  SELECT 'CONTRATO', id_unidade, 0 FROM unidade;
INSERT INTO contador_documento (tipo, id_unidade, ultimo)
  SELECT 'NFSE', id_unidade, 0 FROM unidade;
