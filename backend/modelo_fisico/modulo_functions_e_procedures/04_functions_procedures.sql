-- =============================================================================
-- 04_functions_procedures.sql
-- Kaizen BD — Functions e Procedures (inclui contadores)
-- Tarefa: BK-DB-06 (Etapa 4: Objetos e Segurança)
-- SGBD: MySQL Server 8.0.46 / Dialeto MySQL 8.0
-- Engine / Collation: InnoDB / utf8mb4_0900_ai_ci
-- =============================================================================

USE kaizen;

-- =============================================================================
-- SEÇÃO 1: FUNCTIONS (4 rotinas, todas READS SQL DATA)
-- =============================================================================

DROP FUNCTION IF EXISTS fn_valor_devido;
DROP FUNCTION IF EXISTS fn_status_mensalidade;
DROP FUNCTION IF EXISTS fn_acesso_elegivel;
DROP FUNCTION IF EXISTS fn_ocupacao_turma;

DELIMITER $$

-- -----------------------------------------------------------------------------
-- 1.1 fn_valor_devido
-- Finalidade: Calcula o saldo devedor líquido de uma mensalidade.
-- Fórmula: GREATEST((valor + juros + multa - desconto) - (recebimentos - estornos), 0)
-- -----------------------------------------------------------------------------
CREATE FUNCTION fn_valor_devido(p_mensalidade INT UNSIGNED)
RETURNS DECIMAL(12,2) READS SQL DATA
BEGIN
  DECLARE v_nominal DECIMAL(12,2) DEFAULT 0.00;
  DECLARE v_pago    DECIMAL(12,2) DEFAULT 0.00;

  SELECT (valor + juros + multa - desconto) INTO v_nominal
    FROM MENSALIDADE
   WHERE id_mensalidade = p_mensalidade;

  SELECT COALESCE(SUM(CASE WHEN tipo = 'RECEBIMENTO' THEN valor ELSE -valor END), 0.00)
    INTO v_pago
    FROM PAGAMENTO
   WHERE id_mensalidade = p_mensalidade;

  RETURN GREATEST(COALESCE(v_nominal, 0.00) - v_pago, 0.00);
END$$

-- -----------------------------------------------------------------------------
-- 1.2 fn_status_mensalidade
-- Finalidade: Determina dinamicamente o status de faturamento da mensalidade.
-- Retornos: 'CANCELADA', 'PAGA', 'PARCIAL', 'ABERTA'
-- -----------------------------------------------------------------------------
CREATE FUNCTION fn_status_mensalidade(p_mensalidade INT UNSIGNED)
RETURNS VARCHAR(10) READS SQL DATA
BEGIN
  DECLARE v_devido DECIMAL(12,2);
  DECLARE v_pago   DECIMAL(12,2);
  DECLARE v_atual  VARCHAR(20);

  SELECT status INTO v_atual
    FROM MENSALIDADE
   WHERE id_mensalidade = p_mensalidade;

  SET v_devido = fn_valor_devido(p_mensalidade);

  SELECT COALESCE(SUM(CASE WHEN tipo = 'RECEBIMENTO' THEN valor ELSE -valor END), 0.00)
    INTO v_pago
    FROM PAGAMENTO
   WHERE id_mensalidade = p_mensalidade;

  IF v_atual = 'CANCELADA' THEN
    RETURN 'CANCELADA';
  END IF;

  IF v_devido <= 0.00 THEN
    RETURN 'PAGA';
  END IF;

  IF v_pago > 0.00 THEN
    RETURN 'PARCIAL';
  END IF;

  RETURN 'ABERTA';
END$$

-- -----------------------------------------------------------------------------
-- 1.3 fn_acesso_elegivel
-- Finalidade: Avalia se o aluno está apto para liberação na catraca.
-- Regra: Contrato ATIVO em vigência E atraso máximo de 5 dias nas mensalidades.
-- Retorno: 1 (elegível) ou 0 (não elegível)
-- -----------------------------------------------------------------------------
CREATE FUNCTION fn_acesso_elegivel(p_aluno INT UNSIGNED)
RETURNS TINYINT(1) READS SQL DATA
BEGIN
  DECLARE v_ativo  INT DEFAULT 0;
  DECLARE v_atraso INT DEFAULT 0;

  SELECT COUNT(*) INTO v_ativo
    FROM CONTRATO
   WHERE id_aluno = p_aluno
     AND status = 'ATIVO'
     AND data_inicio <= CURDATE()
     AND (data_fim IS NULL OR data_fim >= CURDATE());

  IF v_ativo = 0 THEN
    RETURN 0;
  END IF;

  SELECT COALESCE(MAX(DATEDIFF(CURDATE(), m.vencimento)), 0) INTO v_atraso
    FROM MENSALIDADE m
    JOIN CONTRATO c ON c.id_contrato = m.id_contrato
   WHERE c.id_aluno = p_aluno
     AND c.status = 'ATIVO'
     AND m.status IN ('ABERTA', 'PARCIAL')
     AND m.vencimento < CURDATE()
     AND fn_valor_devido(m.id_mensalidade) > 0.00;

  RETURN IF(v_atraso <= 5, 1, 0);
END$$

-- -----------------------------------------------------------------------------
-- 1.4 fn_ocupacao_turma
-- Finalidade: Retorna a quantidade de reservas CONFIRMADAS para uma turma.
-- Retorno: SMALLINT UNSIGNED com total de ocupantes confirmados.
-- -----------------------------------------------------------------------------
CREATE FUNCTION fn_ocupacao_turma(p_turma INT UNSIGNED)
RETURNS SMALLINT UNSIGNED READS SQL DATA
BEGIN
  DECLARE v_qtd SMALLINT UNSIGNED DEFAULT 0;

  SELECT COUNT(*) INTO v_qtd
    FROM RESERVA_TURMA
   WHERE id_turma = p_turma
     AND status = 'CONFIRMADA';

  RETURN v_qtd;
END$$

-- =============================================================================
-- SEÇÃO 2: PROCEDURES (4 rotinas, todas MODIFIES SQL DATA)
-- =============================================================================

DROP PROCEDURE IF EXISTS sp_proximo_numero;
DROP PROCEDURE IF EXISTS sp_gerar_mensalidades;
DROP PROCEDURE IF EXISTS sp_registrar_pagamento;
DROP PROCEDURE IF EXISTS sp_anonimizar_aluno;

-- -----------------------------------------------------------------------------
-- 2.1 sp_proximo_numero
-- Finalidade: Emula SEQUENCE atômica no MySQL com LAST_INSERT_ID() por unidade.
-- Suporta séries: 'CONTRATO', 'NFSE'
-- -----------------------------------------------------------------------------
CREATE PROCEDURE sp_proximo_numero(
  IN  p_tipo    VARCHAR(16),
  IN  p_unidade INT UNSIGNED,
  OUT p_numero  INT UNSIGNED
) MODIFIES SQL DATA
BEGIN
  INSERT INTO CONTADOR_DOCUMENTO (tipo, id_unidade, ultimo)
  VALUES (p_tipo, p_unidade, LAST_INSERT_ID(1))
  ON DUPLICATE KEY UPDATE ultimo = LAST_INSERT_ID(ultimo + 1);

  SET p_numero = LAST_INSERT_ID();
END$$

-- -----------------------------------------------------------------------------
-- 2.2 sp_gerar_mensalidades
-- Finalidade: Geração em lote idempotente de faturas mensais para contratos ativos.
-- Idempotência: Garantida por INSERT IGNORE com chave uq_mensalidade_competencia.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE sp_gerar_mensalidades(
  IN p_competencia CHAR(7),
  IN p_unidade     INT UNSIGNED
) MODIFIES SQL DATA
BEGIN
  INSERT IGNORE INTO MENSALIDADE (id_contrato, competencia, vencimento, valor, status)
  SELECT c.id_contrato,
         p_competencia,
         STR_TO_DATE(CONCAT(p_competencia, '-', LPAD(c.dia_vencimento, 2, '0')), '%Y-%m-%d'),
         c.valor_mensal,
         'ABERTA'
    FROM CONTRATO c
   WHERE c.id_unidade = p_unidade
     AND c.status = 'ATIVO'
     AND c.data_inicio <= STR_TO_DATE(CONCAT(p_competencia, '-01'), '%Y-%m-%d')
     AND (c.data_fim IS NULL
          OR c.data_fim >= STR_TO_DATE(CONCAT(p_competencia, '-01'), '%Y-%m-%d'));

  SELECT ROW_COUNT() AS geradas;
END$$

-- -----------------------------------------------------------------------------
-- 2.3 sp_registrar_pagamento
-- Finalidade: Baixa de pagamento idempotente por id_externo e retorno do status.
-- Idempotência: Garantida por INSERT IGNORE com chave uq_pagamento_id_externo.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_pagamento(
  IN p_mensalidade INT UNSIGNED,
  IN p_valor       DECIMAL(10,2),
  IN p_forma       VARCHAR(12),
  IN p_id_externo  VARCHAR(64)
) MODIFIES SQL DATA
BEGIN
  IF p_forma NOT IN ('PIX', 'BOLETO', 'CARTAO', 'DINHEIRO') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'forma de pagamento invalida';
  END IF;

  INSERT IGNORE INTO PAGAMENTO (id_mensalidade, tipo, valor, forma, id_externo)
  VALUES (p_mensalidade, 'RECEBIMENTO', p_valor, p_forma, p_id_externo);

  SELECT ROW_COUNT() AS inseridos, fn_status_mensalidade(p_mensalidade) AS status_atual;
END$$

-- -----------------------------------------------------------------------------
-- 2.4 sp_anonimizar_aluno
-- Finalidade: Conformidade com a LGPD via substituição de PII preservando PK e FKs.
-- Integridade: Aluno inativado; contratos, acessos e históricos são preservados.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE sp_anonimizar_aluno(IN p_aluno INT UNSIGNED)
MODIFIES SQL DATA
BEGIN
  UPDATE ALUNO
     SET nome = CONCAT('ALUNO ANONIMIZADO ', id_aluno),
         cpf = CONCAT('9', LPAD(id_aluno, 10, '0')),
         email = CONCAT('anonimo+', id_aluno, '@invalid.local'),
         data_nascimento = '1900-01-01',
         consentimento_lgpd_em = NULL,
         ativo = 0
   WHERE id_aluno = p_aluno;

  SELECT ROW_COUNT() AS linhas_afetadas;
END$$

DELIMITER ;
