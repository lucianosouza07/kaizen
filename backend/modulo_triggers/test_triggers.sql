-- =============================================================================
-- test_triggers.sql
-- Kaizen BD — Testes Automatizados de Triggers (6 Regras / 7 Objetos) (BK-DB-07)
-- SGBD: MySQL Server 8.0.46 / Dialeto MySQL 8.0 (InnoDB, utf8mb4_0900_ai_ci)
-- =============================================================================

USE kaizen;

SET NAMES utf8mb4;
SET character_set_client = utf8mb4;

-- =============================================================================
-- SEÇÃO 1: AUDITORIA DE METADADOS NO INFORMATION_SCHEMA
-- =============================================================================

SELECT 'AUDITORIA DE METADADOS: TRIGGERS' AS status;

SELECT trigger_name,
       event_manipulation,
       event_object_table,
       action_timing,
       action_orientation
  FROM information_schema.triggers
 WHERE trigger_schema = 'kaizen'
   AND trigger_name IN (
     'trg_contrato_numero',
     'trg_pagamento_status',
     'trg_acesso_validacao',
     'trg_turma_sem_overlap_i',
     'trg_turma_sem_overlap_u',
     'trg_reserva_capacidade',
     'trg_auditoria_aluno'
   )
 ORDER BY event_object_table, trigger_name;

-- =============================================================================
-- SEÇÃO 2: INFRAESTRUTURA DE TESTES AUTOMATIZADOS (HARNESS)
-- =============================================================================

DROP TABLE IF EXISTS _resultado_teste_trigger;
CREATE TEMPORARY TABLE _resultado_teste_trigger (
  id_teste   INT AUTO_INCREMENT PRIMARY KEY,
  regra      VARCHAR(50),
  objeto     VARCHAR(50),
  descricao  VARCHAR(150),
  resultado  VARCHAR(10),
  detalhes   VARCHAR(255)
);

DROP PROCEDURE IF EXISTS _sp_assert_trigger;
DELIMITER $$
CREATE PROCEDURE _sp_assert_trigger(
  IN p_regra     VARCHAR(50),
  IN p_objeto    VARCHAR(50),
  IN p_descricao VARCHAR(150),
  IN p_condicao  BOOLEAN,
  IN p_detalhes  VARCHAR(255)
)
BEGIN
  INSERT INTO _resultado_teste_trigger (regra, objeto, descricao, resultado, detalhes)
  VALUES (
    p_regra,
    p_objeto,
    p_descricao,
    IF(p_condicao, 'PASS', 'FAIL'),
    IF(p_condicao, 'OK', p_detalhes)
  );
END$$
DELIMITER ;

-- =============================================================================
-- SEÇÃO 3: MASSA DE DADOS PARA TESTES ISOLADOS (FIXTURES)
-- =============================================================================

-- Unidade de Teste
INSERT INTO UNIDADE (id_unidade, nome, cnpj, cidade, ativa)
VALUES (961, 'Unidade Teste Triggers', '99888777000199', 'Salvador', 1)
ON DUPLICATE KEY UPDATE nome = VALUES(nome);

-- Contador inicial para a série CONTRATO da unidade 961
INSERT INTO CONTADOR_DOCUMENTO (tipo, id_unidade, ultimo)
VALUES ('CONTRATO', 961, 50)
ON DUPLICATE KEY UPDATE ultimo = VALUES(ultimo);

-- Plano de Teste
INSERT INTO PLANO (id_plano, nome, periodicidade_meses, valor_mensal, carencia_dias, multa_percentual, ativo)
VALUES (961, 'Plano Teste Triggers', 1, 100.00, 5, 2.00, 1)
ON DUPLICATE KEY UPDATE nome = VALUES(nome);

-- Colaborador (Instrutor) de Teste
INSERT INTO COLABORADOR (id_colaborador, id_unidade, nome, cpf, email, cargo, ativo)
VALUES 
  (961, 961, 'Instrutor Carlos', '77788899901', 'carlos.inst@kaizen.local', 'INSTRUTOR', 1),
  (962, 961, 'Instrutora Ana',   '77788899902', 'ana.inst@kaizen.local',    'INSTRUTOR', 1)
ON DUPLICATE KEY UPDATE nome = VALUES(nome);

-- Alunos de Teste
INSERT INTO ALUNO (id_aluno, id_unidade, nome, cpf, email, data_nascimento, consentimento_lgpd_em, ativo)
VALUES
  (961, 961, 'Aluno Trg Um',     '88899900011', 'aluno1.trg@kaizen.local', '1995-03-10', NOW(), 1),
  (962, 961, 'Aluno Trg Dois',   '88899900022', 'aluno2.trg@kaizen.local', '1997-07-20', NOW(), 1),
  (963, 961, 'Aluno Trg Tres',   '88899900033', 'aluno3.trg@kaizen.local', '1992-11-15', NOW(), 1),
  (964, 961, 'Aluno Inadimplente','88899900044', 'aluno4.inad@kaizen.local', '1990-01-01', NOW(), 1)
ON DUPLICATE KEY UPDATE nome = VALUES(nome);

-- =============================================================================
-- SEÇÃO 4: EXECUÇÃO DOS TESTES POR REGRA DE NEGÓCIO
-- =============================================================================

-- -----------------------------------------------------------------------------
-- REGRA 1: NUMERAÇÃO AUTOMÁTICA DE CONTRATOS (trg_contrato_numero)
-- -----------------------------------------------------------------------------

-- Teste 1.1: Inserção de contrato com número NULL -> deve gerar CTR-2026-000051
DELETE FROM CONTRATO WHERE id_unidade = 961;

INSERT INTO CONTRATO (id_contrato, numero, id_aluno, id_unidade, id_plano, data_inicio, data_fim, dia_vencimento, valor_mensal, status)
VALUES (96101, NULL, 961, 961, 961, '2026-01-01', NULL, 10, 100.00, 'ATIVO');

SELECT numero INTO @v_num_gerado FROM CONTRATO WHERE id_contrato = 96101;
CALL _sp_assert_trigger(
  'Regra 1',
  'trg_contrato_numero',
  'Contrato com numero NULL recebe geracao automatica CTR-2026-000051',
  @v_num_gerado = 'CTR-2026-000051',
  CONCAT('Esperado: CTR-2026-000051 | Obtido: ', COALESCE(@v_num_gerado, 'NULL'))
);

-- Teste 1.2: Inserção de contrato com número pré-definido -> deve preservar
INSERT INTO CONTRATO (id_contrato, numero, id_aluno, id_unidade, id_plano, data_inicio, data_fim, dia_vencimento, valor_mensal, status)
VALUES (96102, 'CTR-MIGRADO-777', 962, 961, 961, '2026-01-01', NULL, 10, 100.00, 'ATIVO');

SELECT numero INTO @v_num_preservado FROM CONTRATO WHERE id_contrato = 96102;
CALL _sp_assert_trigger(
  'Regra 1',
  'trg_contrato_numero',
  'Contrato com numero preenchido preserva valor informado',
  @v_num_preservado = 'CTR-MIGRADO-777',
  CONCAT('Esperado: CTR-MIGRADO-777 | Obtido: ', COALESCE(@v_num_preservado, 'NULL'))
);

-- -----------------------------------------------------------------------------
-- REGRA 2: RECÁLCULO REATIVO DE STATUS FINANCEIRO (trg_pagamento_status)
-- -----------------------------------------------------------------------------

-- Cria mensalidade de teste no valor de 100.00
DELETE FROM PAGAMENTO WHERE id_mensalidade IN (96101, 96102);
DELETE FROM MENSALIDADE WHERE id_contrato IN (96101, 96102);

INSERT INTO MENSALIDADE (id_mensalidade, id_contrato, competencia, vencimento, valor, juros, multa, desconto, status)
VALUES (96101, 96101, '2026-01', '2026-01-10', 100.00, 0.00, 0.00, 0.00, 'ABERTA');

-- Teste 2.1: Pagamento parcial de 40.00 -> status deve transitar para 'PARCIAL'
INSERT INTO PAGAMENTO (id_pagamento, id_mensalidade, tipo, valor, forma, id_externo)
VALUES (96101, 96101, 'RECEBIMENTO', 40.00, 'PIX', 'PAY-EXT-96101-A');

SELECT status INTO @v_status_parcial FROM MENSALIDADE WHERE id_mensalidade = 96101;
CALL _sp_assert_trigger(
  'Regra 2',
  'trg_pagamento_status',
  'Pagamento parcial transita mensalidade para PARCIAL',
  @v_status_parcial = 'PARCIAL',
  CONCAT('Esperado: PARCIAL | Obtido: ', COALESCE(@v_status_parcial, 'NULL'))
);

-- Teste 2.2: Pagamento complementar de 60.00 -> status deve transitar para 'PAGA'
INSERT INTO PAGAMENTO (id_pagamento, id_mensalidade, tipo, valor, forma, id_externo)
VALUES (96102, 96101, 'RECEBIMENTO', 60.00, 'PIX', 'PAY-EXT-96101-B');

SELECT status INTO @v_status_paga FROM MENSALIDADE WHERE id_mensalidade = 96101;
CALL _sp_assert_trigger(
  'Regra 2',
  'trg_pagamento_status',
  'Pagamento total transita mensalidade para PAGA',
  @v_status_paga = 'PAGA',
  CONCAT('Esperado: PAGA | Obtido: ', COALESCE(@v_status_paga, 'NULL'))
);

-- Teste 2.3: Estorno de 30.00 -> status deve retornar para 'PARCIAL'
INSERT INTO PAGAMENTO (id_pagamento, id_mensalidade, tipo, valor, forma, id_externo, id_pagamento_original)
VALUES (96103, 96101, 'ESTORNO', 30.00, 'PIX', 'PAY-EXT-96101-C', 96102);

SELECT status INTO @v_status_estornado FROM MENSALIDADE WHERE id_mensalidade = 96101;
CALL _sp_assert_trigger(
  'Regra 2',
  'trg_pagamento_status',
  'Estorno reduzindo liquidacao retorna status para PARCIAL',
  @v_status_estornado = 'PARCIAL',
  CONCAT('Esperado: PARCIAL | Obtido: ', COALESCE(@v_status_estornado, 'NULL'))
);

-- Teste 2.4: Mensalidade CANCELADA permanece CANCELADA mesmo com lancamento
INSERT INTO MENSALIDADE (id_mensalidade, id_contrato, competencia, vencimento, valor, juros, multa, desconto, status)
VALUES (96102, 96102, '2026-01', '2026-01-10', 100.00, 0.00, 0.00, 0.00, 'CANCELADA');

INSERT INTO PAGAMENTO (id_pagamento, id_mensalidade, tipo, valor, forma, id_externo)
VALUES (96104, 96102, 'RECEBIMENTO', 100.00, 'PIX', 'PAY-EXT-96102-A');

SELECT status INTO @v_status_cancelada FROM MENSALIDADE WHERE id_mensalidade = 96102;
CALL _sp_assert_trigger(
  'Regra 2',
  'trg_pagamento_status',
  'Mensalidade CANCELADA permanece CANCELADA apos pagamento',
  @v_status_cancelada = 'CANCELADA',
  CONCAT('Esperado: CANCELADA | Obtido: ', COALESCE(@v_status_cancelada, 'NULL'))
);

-- -----------------------------------------------------------------------------
-- REGRA 3: VALIDAÇÃO DINÂMICA DE CATRACA (trg_acesso_validacao)
-- -----------------------------------------------------------------------------

-- Aluno 961 tem contrato ativo e mensalidade parcial/paga -> elegível
DELETE FROM ACESSO WHERE id_unidade = 961;

INSERT INTO ACESSO (id_acesso, id_aluno, id_unidade)
VALUES (96101, 961, 961);

SELECT liberado, motivo INTO @v_liberado_ok, @v_motivo_ok FROM ACESSO WHERE id_acesso = 96101;
CALL _sp_assert_trigger(
  'Regra 3',
  'trg_acesso_validacao',
  'Aluno adimplente e ativo recebe liberado = 1 e motivo LIBERADO',
  @v_liberado_ok = 1 AND @v_motivo_ok = 'LIBERADO',
  CONCAT('Liberado: ', COALESCE(@v_liberado_ok, -1), ' | Motivo: ', COALESCE(@v_motivo_ok, 'NULL'))
);

-- Aluno 964 sem contrato ativo -> bloqueado mas gravado
INSERT INTO ACESSO (id_acesso, id_aluno, id_unidade)
VALUES (96102, 964, 961);

SELECT liberado, motivo INTO @v_liberado_bloq, @v_motivo_bloq FROM ACESSO WHERE id_acesso = 96102;
CALL _sp_assert_trigger(
  'Regra 3',
  'trg_acesso_validacao',
  'Aluno inativo/inadimplente recebe liberado = 0 e motivo de bloqueio gravado',
  @v_liberado_bloq = 0 AND @v_motivo_bloq = 'CONTRATO_INATIVO_OU_INADIMPLENTE',
  CONCAT('Liberado: ', COALESCE(@v_liberado_bloq, -1), ' | Motivo: ', COALESCE(@v_motivo_bloq, 'NULL'))
);

-- -----------------------------------------------------------------------------
-- REGRA 4: ANTI-OVERLAP EM TURMAS (trg_turma_sem_overlap_i / trg_turma_sem_overlap_u)
-- -----------------------------------------------------------------------------

DELETE FROM RESERVA_TURMA WHERE id_unidade = 961;
DELETE FROM TURMA WHERE id_unidade = 961;

-- Turma base: Sala 101, Instrutor 961, 10:00 as 11:00
INSERT INTO TURMA (id_turma, id_unidade, id_instrutor, modalidade, sala, capacidade, inicio, fim)
VALUES (96101, 961, 961, 'Musculação', 'Sala 101', 20, '2026-02-01 10:00:00', '2026-02-01 11:00:00');

-- Teste 4.1: Conflito de mesma sala no INSERT (10:30 as 11:30) -> deve disparar SIGNAL 45000
DROP PROCEDURE IF EXISTS _sp_test_overlap_i_sala;
DELIMITER $$
CREATE PROCEDURE _sp_test_overlap_i_sala(OUT p_erro BOOLEAN)
BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET p_erro = TRUE;
  SET p_erro = FALSE;
  INSERT INTO TURMA (id_turma, id_unidade, id_instrutor, modalidade, sala, capacidade, inicio, fim)
  VALUES (96102, 961, 962, 'Pilates', 'Sala 101', 15, '2026-02-01 10:30:00', '2026-02-01 11:30:00');
END$$
DELIMITER ;

CALL _sp_test_overlap_i_sala(@v_erro_overlap_sala);
CALL _sp_assert_trigger(
  'Regra 4',
  'trg_turma_sem_overlap_i',
  'Insercao de turma com sobreposicao de sala lanca SIGNAL 45000',
  @v_erro_overlap_sala = TRUE,
  CONCAT('Erro capturado: ', IF(@v_erro_overlap_sala, 'SIM', 'NAO'))
);

-- Teste 4.2: Conflito de mesmo instrutor no INSERT (10:30 as 11:30 em outra sala) -> deve disparar SIGNAL 45000
DROP PROCEDURE IF EXISTS _sp_test_overlap_i_inst;
DELIMITER $$
CREATE PROCEDURE _sp_test_overlap_i_inst(OUT p_erro BOOLEAN)
BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET p_erro = TRUE;
  SET p_erro = FALSE;
  INSERT INTO TURMA (id_turma, id_unidade, id_instrutor, modalidade, sala, capacidade, inicio, fim)
  VALUES (96103, 961, 961, 'Crossfit', 'Sala 202', 15, '2026-02-01 10:30:00', '2026-02-01 11:30:00');
END$$
DELIMITER ;

CALL _sp_test_overlap_i_inst(@v_erro_overlap_inst);
CALL _sp_assert_trigger(
  'Regra 4',
  'trg_turma_sem_overlap_i',
  'Insercao de turma com sobreposicao de instrutor lanca SIGNAL 45000',
  @v_erro_overlap_inst = TRUE,
  CONCAT('Erro capturado: ', IF(@v_erro_overlap_inst, 'SIM', 'NAO'))
);

-- Teste 4.3: Atualização de turma sem conflito (apenas mudando capacidade) -> deve permitir (ignora propria linha)
DROP PROCEDURE IF EXISTS _sp_test_overlap_u_propria;
DELIMITER $$
CREATE PROCEDURE _sp_test_overlap_u_propria(OUT p_ok BOOLEAN)
BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET p_ok = FALSE;
  SET p_ok = TRUE;
  UPDATE TURMA SET capacidade = 25 WHERE id_turma = 96101;
END$$
DELIMITER ;

CALL _sp_test_overlap_u_propria(@v_ok_u_propria);
CALL _sp_assert_trigger(
  'Regra 4',
  'trg_turma_sem_overlap_u',
  'Atualizacao de turma ignorando a propria linha procede com sucesso',
  @v_ok_u_propria = TRUE,
  CONCAT('Sucesso: ', IF(@v_ok_u_propria, 'SIM', 'NAO'))
);

-- Teste 4.4: Inserção de Turma 2 em horário livre (11:00 as 12:00) -> sucesso
INSERT INTO TURMA (id_turma, id_unidade, id_instrutor, modalidade, sala, capacidade, inicio, fim)
VALUES (96104, 961, 961, 'Alongamento', 'Sala 101', 20, '2026-02-01 11:00:00', '2026-02-01 12:00:00');

-- Teste 4.5: Atualização da Turma 2 para horário conflitante com Turma 1 -> deve disparar SIGNAL 45000
DROP PROCEDURE IF EXISTS _sp_test_overlap_u_conflito;
DELIMITER $$
CREATE PROCEDURE _sp_test_overlap_u_conflito(OUT p_erro BOOLEAN)
BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET p_erro = TRUE;
  SET p_erro = FALSE;
  UPDATE TURMA SET inicio = '2026-02-01 10:15:00', fim = '2026-02-01 11:15:00' WHERE id_turma = 96104;
END$$
DELIMITER ;

CALL _sp_test_overlap_u_conflito(@v_erro_u_conflito);
CALL _sp_assert_trigger(
  'Regra 4',
  'trg_turma_sem_overlap_u',
  'Atualizacao de turma para horario colidente com outra turma lanca SIGNAL 45000',
  @v_erro_u_conflito = TRUE,
  CONCAT('Erro capturado: ', IF(@v_erro_u_conflito, 'SIM', 'NAO'))
);

-- -----------------------------------------------------------------------------
-- REGRA 5: CONTROLE DE CAPACIDADE DE TURMAS (trg_reserva_capacidade)
-- -----------------------------------------------------------------------------

-- Cria turma de teste com capacidade 2
INSERT INTO TURMA (id_turma, id_unidade, id_instrutor, modalidade, sala, capacidade, inicio, fim)
VALUES (96105, 961, 962, 'Spinning', 'Sala Bike', 2, '2026-02-01 14:00:00', '2026-02-01 15:00:00');

-- Reserva 1 (Confirmada) -> sucesso
INSERT INTO RESERVA_TURMA (id_reserva, id_turma, id_aluno, id_unidade, status)
VALUES (96101, 96105, 961, 961, 'CONFIRMADA');

-- Reserva 2 (Confirmada) -> sucesso (atingiu capacidade 2/2)
INSERT INTO RESERVA_TURMA (id_reserva, id_turma, id_aluno, id_unidade, status)
VALUES (96102, 96105, 962, 961, 'CONFIRMADA');

-- Teste 5.1: Reserva 3 (Confirmada) em turma lotada -> deve disparar SIGNAL 45000
DROP PROCEDURE IF EXISTS _sp_test_reserva_lotada;
DELIMITER $$
CREATE PROCEDURE _sp_test_reserva_lotada(OUT p_erro BOOLEAN)
BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET p_erro = TRUE;
  SET p_erro = FALSE;
  INSERT INTO RESERVA_TURMA (id_reserva, id_turma, id_aluno, id_unidade, status)
  VALUES (96103, 96105, 963, 961, 'CONFIRMADA');
END$$
DELIMITER ;

CALL _sp_test_reserva_lotada(@v_erro_lotada);
CALL _sp_assert_trigger(
  'Regra 5',
  'trg_reserva_capacidade',
  'Reserva CONFIRMADA em turma lotada lanca SIGNAL 45000',
  @v_erro_lotada = TRUE,
  CONCAT('Erro capturado: ', IF(@v_erro_lotada, 'SIM', 'NAO'))
);

-- Teste 5.2: Reserva 3 com status ESPERA na mesma turma lotada -> deve permitir
DROP PROCEDURE IF EXISTS _sp_test_reserva_espera;
DELIMITER $$
CREATE PROCEDURE _sp_test_reserva_espera(OUT p_ok BOOLEAN)
BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET p_ok = FALSE;
  SET p_ok = TRUE;
  INSERT INTO RESERVA_TURMA (id_reserva, id_turma, id_aluno, id_unidade, status)
  VALUES (96104, 96105, 963, 961, 'ESPERA');
END$$
DELIMITER ;

CALL _sp_test_reserva_espera(@v_ok_espera);
CALL _sp_assert_trigger(
  'Regra 5',
  'trg_reserva_capacidade',
  'Reserva com status ESPERA em turma lotada e aceita com sucesso',
  @v_ok_espera = TRUE,
  CONCAT('Sucesso: ', IF(@v_ok_espera, 'SIM', 'NAO'))
);

-- -----------------------------------------------------------------------------
-- REGRA 6: TRILHA DE AUDITORIA DE ALUNO (trg_auditoria_aluno)
-- -----------------------------------------------------------------------------

DELETE FROM AUDITORIA_LOG WHERE tabela = 'aluno' AND chave_pk = '961';

-- Atualiza dados cadastrais do aluno 961
UPDATE ALUNO
   SET nome = 'Aluno Trg Um Modificado',
       email = 'aluno1.modificado@kaizen.local'
 WHERE id_aluno = 961;

-- Verifica se a linha de auditoria foi inserida automaticamente
SELECT COUNT(*),
       JSON_UNQUOTE(JSON_EXTRACT(antes, '$.nome')),
       JSON_UNQUOTE(JSON_EXTRACT(depois, '$.nome')),
       conta_mysql
  INTO @v_count_audit,
       @v_audit_nome_antes,
       @v_audit_nome_depois,
       @v_audit_user
  FROM AUDITORIA_LOG
 WHERE tabela = 'aluno'
   AND chave_pk = '961'
   AND operacao = 'UPDATE'
 ORDER BY id_log DESC
 LIMIT 1;

CALL _sp_assert_trigger(
  'Regra 6',
  'trg_auditoria_aluno',
  'Alteracao em ALUNO gera tupla em AUDITORIA_LOG com JSON de antes e depois',
  @v_count_audit > 0
    AND @v_audit_nome_antes = 'Aluno Trg Um'
    AND @v_audit_nome_depois = 'Aluno Trg Um Modificado'
    AND @v_audit_user IS NOT NULL,
  CONCAT('Antes: ', COALESCE(@v_audit_nome_antes, 'NULL'), ' | Depois: ', COALESCE(@v_audit_nome_depois, 'NULL'))
);

-- =============================================================================
-- SEÇÃO 5: CONSOLIDAÇÃO DOS RESULTADOS DE TESTE
-- =============================================================================

SELECT id_teste,
       regra,
       objeto,
       descricao,
       resultado,
       detalhes
  FROM _resultado_teste_trigger
 ORDER BY id_teste;

SELECT COUNT(*) AS total_testes,
       SUM(CASE WHEN resultado = 'PASS' THEN 1 ELSE 0 END) AS aprovados,
       SUM(CASE WHEN resultado = 'FAIL' THEN 1 ELSE 0 END) AS reprovados,
       IF(SUM(CASE WHEN resultado = 'FAIL' THEN 1 ELSE 0 END) = 0, 'TODOS OS TESTES APROVADOS', 'FALHA NOS TESTES') AS status_final
  FROM _resultado_teste_trigger;

-- Limpeza das procedures auxiliares de teste
DROP PROCEDURE IF EXISTS _sp_assert_trigger;
DROP PROCEDURE IF EXISTS _sp_test_overlap_i_sala;
DROP PROCEDURE IF EXISTS _sp_test_overlap_i_inst;
DROP PROCEDURE IF EXISTS _sp_test_overlap_u_propria;
DROP PROCEDURE IF EXISTS _sp_test_overlap_u_conflito;
DROP PROCEDURE IF EXISTS _sp_test_reserva_lotada;
DROP PROCEDURE IF EXISTS _sp_test_reserva_espera;
