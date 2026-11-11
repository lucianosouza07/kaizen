-- =============================================================================
-- 05_triggers.sql
-- Kaizen BD — Módulo de Triggers (6 Regras / 7 Objetos) (BK-DB-07)
-- SGBD: MySQL Server 8.0.46 / Dialeto MySQL 8.0 (InnoDB, utf8mb4_0900_ai_ci)
-- =============================================================================

USE kaizen;

SET NAMES utf8mb4;
SET character_set_client = utf8mb4;

-- =============================================================================
-- REGRA 1 (OBJETO 1/7): NUMERAÇÃO AUTOMÁTICA DE CONTRATO
-- Evento: BEFORE INSERT ON contrato
-- Descrição: Gera número sequencial formatado CTR-AAAA-000001 por unidade quando
--            o número vier omitido ou em branco, integrando com sp_proximo_numero.
-- =============================================================================

DROP TRIGGER IF EXISTS trg_contrato_numero;

DELIMITER $$

CREATE TRIGGER trg_contrato_numero
BEFORE INSERT ON contrato
FOR EACH ROW
BEGIN
  DECLARE v_num INT UNSIGNED;
  IF NEW.numero IS NULL OR NEW.numero = '' THEN
    CALL sp_proximo_numero('CONTRATO', NEW.id_unidade, v_num);
    SET NEW.numero = CONCAT('CTR-', YEAR(NEW.data_inicio), '-', LPAD(v_num, 6, '0'));
  END IF;
END$$

DELIMITER ;

-- =============================================================================
-- REGRA 2 (OBJETO 2/7): RECÁLCULO REATIVO DE STATUS DE MENSALIDADE
-- Evento: AFTER INSERT ON pagamento
-- Descrição: Recalcula o status da mensalidade associada via agregação direta
--            de recebimentos e estornos compensatórios em relação ao valor nominal.
--            Transita para 'PAGA', 'PARCIAL' ou 'ABERTA', preservando 'CANCELADA'.
-- =============================================================================

DROP TRIGGER IF EXISTS trg_pagamento_status;

DELIMITER $$

CREATE TRIGGER trg_pagamento_status
AFTER INSERT ON pagamento
FOR EACH ROW
BEGIN
  DECLARE v_nominal DECIMAL(12,2);
  DECLARE v_pago    DECIMAL(12,2);
  DECLARE v_atual   VARCHAR(20);

  SELECT valor + juros + multa - desconto, status
    INTO v_nominal, v_atual
    FROM mensalidade
   WHERE id_mensalidade = NEW.id_mensalidade;

  SELECT COALESCE(SUM(CASE WHEN tipo = 'RECEBIMENTO' THEN valor ELSE -valor END), 0)
    INTO v_pago
    FROM pagamento
   WHERE id_mensalidade = NEW.id_mensalidade;

  IF v_atual <> 'CANCELADA' THEN
    UPDATE mensalidade
       SET status = CASE WHEN v_nominal - v_pago <= 0 THEN 'PAGA'
                         WHEN v_pago > 0 THEN 'PARCIAL'
                         ELSE 'ABERTA' END
     WHERE id_mensalidade = NEW.id_mensalidade;
  END IF;
END$$

DELIMITER ;

-- =============================================================================
-- REGRA 3 (OBJETO 3/7): VALIDAÇÃO DINÂMICA DE CATRACA E REGISTRO DE ACESSO
-- Evento: BEFORE INSERT ON acesso
-- Descrição: Avalia elegibilidade de acesso físico via fn_acesso_elegivel.
--            Preenche liberado e motivo padronizado sem emitir erro, garantindo
--            a persistência das tentativas negadas para auditoria de portaria.
-- =============================================================================

DROP TRIGGER IF EXISTS trg_acesso_validacao;

DELIMITER $$

CREATE TRIGGER trg_acesso_validacao
BEFORE INSERT ON acesso
FOR EACH ROW
BEGIN
  IF fn_acesso_elegivel(NEW.id_aluno) = 1 THEN
    SET NEW.liberado = 1, NEW.motivo = 'LIBERADO';
  ELSE
    SET NEW.liberado = 0, NEW.motivo = 'CONTRATO_INATIVO_OU_INADIMPLENTE';
  END IF;
END$$

DELIMITER ;

-- =============================================================================
-- REGRA 4 (OBJETO 4/7): ANTI-OVERLAP NA INSERÇÃO DE TURMAS
-- Evento: BEFORE INSERT ON turma
-- Descrição: Impede conflito de horários para a mesma sala ou para o mesmo
--            instrutor na mesma unidade, disparando SIGNAL SQLSTATE '45000'.
-- =============================================================================

DROP TRIGGER IF EXISTS trg_turma_sem_overlap_i;

DELIMITER $$

CREATE TRIGGER trg_turma_sem_overlap_i
BEFORE INSERT ON turma
FOR EACH ROW
BEGIN
  IF EXISTS (
    SELECT 1
      FROM turma t
     WHERE t.id_unidade = NEW.id_unidade
       AND (t.id_instrutor = NEW.id_instrutor OR t.sala = NEW.sala)
       AND t.inicio < NEW.fim
       AND t.fim > NEW.inicio
  ) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Conflito de sala ou instrutor';
  END IF;
END$$

DELIMITER ;

-- =============================================================================
-- REGRA 4 (OBJETO 5/7): ANTI-OVERLAP NA ATUALIZAÇÃO DE TURMAS
-- Evento: BEFORE UPDATE ON turma
-- Descrição: Impede conflito de horários em reprogramações de turmas na mesma
--            unidade, ignorando a própria linha que está sendo modificada.
-- =============================================================================

DROP TRIGGER IF EXISTS trg_turma_sem_overlap_u;

DELIMITER $$

CREATE TRIGGER trg_turma_sem_overlap_u
BEFORE UPDATE ON turma
FOR EACH ROW
BEGIN
  IF EXISTS (
    SELECT 1
      FROM turma t
     WHERE t.id_turma <> NEW.id_turma
       AND t.id_unidade = NEW.id_unidade
       AND (t.id_instrutor = NEW.id_instrutor OR t.sala = NEW.sala)
       AND t.inicio < NEW.fim
       AND t.fim > NEW.inicio
  ) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Conflito de sala ou instrutor';
  END IF;
END$$

DELIMITER ;

-- =============================================================================
-- REGRA 5 (OBJETO 6/7): CONTROLE DE CAPACIDADE E LOTAÇÃO DE TURMAS
-- Evento: BEFORE INSERT ON reserva_turma
-- Descrição: Rejeita reservas com status CONFIRMADA quando a capacidade máxima
--            for atingida (SIGNAL 45000), permitindo inclusão em fila de ESPERA.
-- =============================================================================

DROP TRIGGER IF EXISTS trg_reserva_capacidade;

DELIMITER $$

CREATE TRIGGER trg_reserva_capacidade
BEFORE INSERT ON reserva_turma
FOR EACH ROW
BEGIN
  DECLARE v_cap SMALLINT UNSIGNED;
  DECLARE v_qtd SMALLINT UNSIGNED DEFAULT 0;

  IF NEW.status = 'CONFIRMADA' THEN
    SELECT capacidade
      INTO v_cap
      FROM turma
     WHERE id_turma = NEW.id_turma;

    SELECT COUNT(*)
      INTO v_qtd
      FROM reserva_turma
     WHERE id_turma = NEW.id_turma
       AND status = 'CONFIRMADA';

    IF v_qtd >= v_cap THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Turma lotada: use ESPERA';
    END IF;
  END IF;
END$$

DELIMITER ;

-- =============================================================================
-- REGRA 6 (OBJETO 7/7): TRILHA DE AUDITORIA DE ALTERAÇÕES EM ALUNO
-- Evento: AFTER UPDATE ON aluno
-- Descrição: Grava snapshot JSON com dados cadastrais de antes e depois na tabela
--            AUDITORIA_LOG, associando a conta do banco conectada via USER().
-- =============================================================================

DROP TRIGGER IF EXISTS trg_auditoria_aluno;

DELIMITER $$

CREATE TRIGGER trg_auditoria_aluno
AFTER UPDATE ON aluno
FOR EACH ROW
BEGIN
  INSERT INTO auditoria_log (
    tabela,
    operacao,
    chave_pk,
    antes,
    depois,
    conta_mysql
  )
  VALUES (
    'aluno',
    'UPDATE',
    CAST(NEW.id_aluno AS CHAR),
    JSON_OBJECT(
      'nome', OLD.nome,
      'cpf', OLD.cpf,
      'email', OLD.email,
      'data_nascimento', OLD.data_nascimento,
      'ativo', OLD.ativo
    ),
    JSON_OBJECT(
      'nome', NEW.nome,
      'cpf', NEW.cpf,
      'email', NEW.email,
      'data_nascimento', NEW.data_nascimento,
      'ativo', NEW.ativo
    ),
    USER()
  );
END$$

DELIMITER ;
