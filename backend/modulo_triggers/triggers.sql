-- ============================================================================
-- Kaizen BD — Módulo de Triggers (6 Regras de Negócio / 7 Objetos de Gatilho)
-- RDBMS: MySQL Server 8.0.46
-- Dialeto: MySQL 8.0 (InnoDB, utf8mb4, utf8mb4_0900_ai_ci)
-- Tarefa: BK-DB-07
-- ============================================================================

USE kaizen;

-- Remove triggers pré-existentes para garantir idempotência de execução
DROP TRIGGER IF EXISTS trg_contrato_numero;
DROP TRIGGER IF EXISTS trg_pagamento_status;
DROP TRIGGER IF EXISTS trg_acesso_validacao;
DROP TRIGGER IF EXISTS trg_turma_sem_overlap_i;
DROP TRIGGER IF EXISTS trg_turma_sem_overlap_u;
DROP TRIGGER IF EXISTS trg_reserva_capacidade;
DROP TRIGGER IF EXISTS trg_auditoria_aluno;

DELIMITER $$

-- ============================================================================
-- REGRA 1: Numeração Formal Automática de Contrato
-- Objeto: trg_contrato_numero
-- Disparo: BEFORE INSERT ON contrato FOR EACH ROW
-- Descrição: Se o número for omitido ou vazio, invoca o sequenciador documental
--            sp_proximo_numero para a filial e formata como CTR-AAAA-000001.
-- ============================================================================
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

-- ============================================================================
-- REGRA 2: Recálculo Atômico do Status da Mensalidade após Pagamento
-- Objeto: trg_pagamento_status
-- Disparo: AFTER INSERT ON pagamento FOR EACH ROW
-- Descrição: Agrega diretamente os recebimentos e estornos vinculados à
--            mensalidade e atualiza seu status para PAGA, PARCIAL ou ABERTA.
-- ============================================================================
CREATE TRIGGER trg_pagamento_status
AFTER INSERT ON pagamento
FOR EACH ROW
BEGIN
  DECLARE v_nominal DECIMAL(12,2);
  DECLARE v_pago    DECIMAL(12,2);
  DECLARE v_atual   VARCHAR(20);

  -- Obtém o valor nominal líquido devido e o status atual da mensalidade
  SELECT valor + juros + multa - desconto, status
    INTO v_nominal, v_atual
    FROM mensalidade
   WHERE id_mensalidade = NEW.id_mensalidade;

  -- Agregação direta de recebimentos e estornos para evitar locks ou funções aninhadas
  SELECT COALESCE(SUM(CASE WHEN tipo = 'RECEBIMENTO' THEN valor ELSE -valor END), 0)
    INTO v_pago
    FROM pagamento
   WHERE id_mensalidade = NEW.id_mensalidade;

  -- Se a fatura não estiver cancelada, atualiza o status de acordo com o saldo
  IF v_atual <> 'CANCELADA' THEN
    UPDATE mensalidade
       SET status = CASE WHEN v_nominal - v_pago <= 0 THEN 'PAGA'
                         WHEN v_pago > 0 THEN 'PARCIAL'
                         ELSE 'ABERTA' END
     WHERE id_mensalidade = NEW.id_mensalidade;
  END IF;
END$$

-- ============================================================================
-- REGRA 3: Validação Automática de Elegibilidade de Acesso na Catraca
-- Objeto: trg_acesso_validacao
-- Disparo: BEFORE INSERT ON acesso FOR EACH ROW
-- Descrição: Avalia elegibilidade via fn_acesso_elegivel (contrato ativo e
--            inadimplência máxima de 5 dias). Sempre grava o registro para auditoria.
-- ============================================================================
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

-- ============================================================================
-- REGRA 4A: Anti-Overlap Temporal de Turmas em Inserção
-- Objeto: trg_turma_sem_overlap_i
-- Disparo: BEFORE INSERT ON turma FOR EACH ROW
-- Descrição: Rejeita a inserção via SIGNAL SQLSTATE '45000' se houver colisão
--            temporal para mesma sala ou mesmo instrutor na mesma unidade.
-- ============================================================================
CREATE TRIGGER trg_turma_sem_overlap_i
BEFORE INSERT ON turma
FOR EACH ROW
BEGIN
  IF EXISTS (SELECT 1 FROM turma t
              WHERE t.id_unidade = NEW.id_unidade
                AND (t.id_instrutor = NEW.id_instrutor OR t.sala = NEW.sala)
                AND t.inicio < NEW.fim AND t.fim > NEW.inicio) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflito de sala ou instrutor';
  END IF;
END$$

-- ============================================================================
-- REGRA 4B: Anti-Overlap Temporal de Turmas em Atualização
-- Objeto: trg_turma_sem_overlap_u
-- Disparo: BEFORE UPDATE ON turma FOR EACH ROW
-- Descrição: Rejeita a atualização via SIGNAL SQLSTATE '45000' se houver colisão
--            temporal, excluindo a própria linha sendo editada (t.id_turma <> NEW.id_turma).
-- ============================================================================
CREATE TRIGGER trg_turma_sem_overlap_u
BEFORE UPDATE ON turma
FOR EACH ROW
BEGIN
  IF EXISTS (SELECT 1 FROM turma t
              WHERE t.id_turma <> NEW.id_turma
                AND t.id_unidade = NEW.id_unidade
                AND (t.id_instrutor = NEW.id_instrutor OR t.sala = NEW.sala)
                AND t.inicio < NEW.fim AND t.fim > NEW.inicio) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflito de sala ou instrutor';
  END IF;
END$$

-- ============================================================================
-- REGRA 5: Controle Estrito de Capacidade Máxima de Turma
-- Objeto: trg_reserva_capacidade
-- Disparo: BEFORE INSERT ON reserva_turma FOR EACH ROW
-- Descrição: Impede reservas CONFIRMADA quando a contagem atingir a capacidade
--            da sala, orientando o direcionamento para o status ESPERA.
-- ============================================================================
CREATE TRIGGER trg_reserva_capacidade
BEFORE INSERT ON reserva_turma
FOR EACH ROW
BEGIN
  DECLARE v_cap SMALLINT UNSIGNED;
  DECLARE v_qtd SMALLINT UNSIGNED DEFAULT 0;

  IF NEW.status = 'CONFIRMADA' THEN
    SELECT capacidade INTO v_cap FROM turma WHERE id_turma = NEW.id_turma;
    SELECT COUNT(*) INTO v_qtd FROM reserva_turma
     WHERE id_turma = NEW.id_turma AND status = 'CONFIRMADA';

    IF v_qtd >= v_cap THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Turma lotada: use ESPERA';
    END IF;
  END IF;
END$$

-- ============================================================================
-- REGRA 6: Trilha Estruturada de Auditoria em Atualização Cadastral de Aluno
-- Objeto: trg_auditoria_aluno
-- Disparo: AFTER UPDATE ON aluno FOR EACH ROW
-- Descrição: Serializa em JSON os estados anterior (OLD) e novo (NEW) dos
--            campos cadastrais de aluno e registra o ator conectado via USER().
-- ============================================================================
CREATE TRIGGER trg_auditoria_aluno
AFTER UPDATE ON aluno
FOR EACH ROW
BEGIN
  INSERT INTO auditoria_log (tabela, operacao, chave_pk, antes, depois, conta_mysql)
  VALUES ('aluno', 'UPDATE', CAST(NEW.id_aluno AS CHAR),
          JSON_OBJECT('nome', OLD.nome, 'cpf', OLD.cpf, 'email', OLD.email,
                      'data_nascimento', OLD.data_nascimento, 'ativo', OLD.ativo),
          JSON_OBJECT('nome', NEW.nome, 'cpf', NEW.cpf, 'email', NEW.email,
                      'data_nascimento', NEW.data_nascimento, 'ativo', NEW.ativo),
          USER());
END$$

DELIMITER ;
