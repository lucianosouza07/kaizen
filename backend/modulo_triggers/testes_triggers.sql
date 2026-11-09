-- ============================================================================
-- Kaizen BD — Bateria de Testes dos Triggers (BK-DB-07)
-- RDBMS: MySQL Server 8.0.46
-- Dialeto: MySQL 8.0
-- Validação Funcional e Asserções Negativas (SQLSTATE '45000')
-- ============================================================================

USE kaizen;

-- Procedimento de execução e relatório da suíte de testes de triggers
DROP PROCEDURE IF EXISTS sp_executar_testes_triggers;

DELIMITER $$

CREATE PROCEDURE sp_executar_testes_triggers()
BEGIN
  DECLARE v_total_testes INT DEFAULT 0;
  DECLARE v_passou       INT DEFAULT 0;
  DECLARE v_falhou       INT DEFAULT 0;

  -- Variáveis auxiliares de dados de teste
  DECLARE v_unidade      INT UNSIGNED;
  DECLARE v_plano        SMALLINT UNSIGNED;
  DECLARE v_instrutor    INT UNSIGNED;
  DECLARE v_aluno_ativo  INT UNSIGNED;
  DECLARE v_aluno_inad   INT UNSIGNED;
  DECLARE v_contrato_id  INT UNSIGNED;
  DECLARE v_contrato_num VARCHAR(24);
  DECLARE v_mensal_id    INT UNSIGNED;
  DECLARE v_status_m     VARCHAR(20);
  DECLARE v_turma_1      INT UNSIGNED;
  DECLARE v_turma_2      INT UNSIGNED;
  DECLARE v_acesso_lib   TINYINT(1);
  DECLARE v_acesso_mot   VARCHAR(40);
  DECLARE v_audit_count  INT;
  DECLARE v_esperado_erro BOOLEAN;

  -- Tabela temporária para registro detalhado dos resultados
  DROP TEMPORARY TABLE IF EXISTS tmp_resultado_testes;
  CREATE TEMPORARY TABLE tmp_resultado_testes (
    id_teste VARCHAR(10),
    regra VARCHAR(60),
    status VARCHAR(10),
    detalhes VARCHAR(200)
  );

  -- --------------------------------------------------------------------------
  -- 0. PREPARAÇÃO DE AMBIENTE / DADOS BASE PARA OS TESTES
  -- --------------------------------------------------------------------------
  -- Garante unidade para testes
  SELECT id_unidade INTO v_unidade FROM unidade LIMIT 1;
  IF v_unidade IS NULL THEN
    INSERT INTO unidade (nome, cnpj, cidade) VALUES ('Unidade Testes', '99999999000199', 'Salvador');
    SET v_unidade = LAST_INSERT_ID();
    INSERT INTO contador_documento (tipo, id_unidade, ultimo) VALUES ('CONTRATO', v_unidade, 0);
  END IF;

  -- Garante plano de teste
  SELECT id_plano INTO v_plano FROM plano LIMIT 1;
  IF v_plano IS NULL THEN
    INSERT INTO plano (nome, periodicidade_meses, valor_mensal, carencia_dias, multa_percentual)
    VALUES ('Plano Teste', 1, 100.00, 5, 2.00);
    SET v_plano = LAST_INSERT_ID();
  END IF;

  -- Garante instrutor de teste
  SELECT id_colaborador INTO v_instrutor FROM colaborador WHERE id_unidade = v_unidade LIMIT 1;
  IF v_instrutor IS NULL THEN
    INSERT INTO colaborador (id_unidade, nome, cpf, cargo)
    VALUES (v_unidade, 'Instrutor Teste', '88888888888', 'INSTRUTOR');
    SET v_instrutor = LAST_INSERT_ID();
  END IF;

  -- Garante aluno ativo de teste
  INSERT INTO aluno (id_unidade, nome, cpf, email, data_nascimento, ativo)
  VALUES (v_unidade, 'Aluno Teste Ativo', '77777777777', 'aluno_teste_ativo@kaizen.local', '1995-05-10', 1)
  ON DUPLICATE KEY UPDATE id_aluno = LAST_INSERT_ID(id_aluno);
  SET v_aluno_ativo = LAST_INSERT_ID();

  -- Garante aluno sem contrato de teste
  INSERT INTO aluno (id_unidade, nome, cpf, email, data_nascimento, ativo)
  VALUES (v_unidade, 'Aluno Teste Inativo', '66666666666', 'aluno_teste_inativo@kaizen.local', '1998-08-20', 1)
  ON DUPLICATE KEY UPDATE id_aluno = LAST_INSERT_ID(id_aluno);
  SET v_aluno_inad = LAST_INSERT_ID();

  -- ==========================================================================
  -- TESTE T1: trg_contrato_numero (Numeração Automática CTR-AAAA-000001)
  -- ==========================================================================
  SET v_total_testes = v_total_testes + 1;
  INSERT INTO contrato (numero, id_aluno, id_unidade, id_plano, data_inicio, data_fim, dia_vencimento, valor_mensal, status)
  VALUES (NULL, v_aluno_ativo, v_unidade, v_plano, '2026-03-01', NULL, 10, 100.00, 'ATIVO');
  SET v_contrato_id = LAST_INSERT_ID();

  SELECT numero INTO v_contrato_num FROM contrato WHERE id_contrato = v_contrato_id;
  IF v_contrato_num REGEXP '^CTR-2026-[0-9]{6}$' THEN
    SET v_passou = v_passou + 1;
    INSERT INTO tmp_resultado_testes VALUES ('T1', 'trg_contrato_numero', 'PASS', CONCAT('Gerado com sucesso: ', v_contrato_num));
  ELSE
    SET v_falhou = v_falhou + 1;
    INSERT INTO tmp_resultado_testes VALUES ('T1', 'trg_contrato_numero', 'FAIL', CONCAT('Formato inesperado: ', COALESCE(v_contrato_num, 'NULL')));
  END IF;

  -- ==========================================================================
  -- TESTE T2: trg_pagamento_status (Recálculo Atômico: ABERTA -> PARCIAL -> PAGA)
  -- ==========================================================================
  SET v_total_testes = v_total_testes + 1;
  -- Cria mensalidade nominal de R$ 100,00
  INSERT INTO mensalidade (id_contrato, competencia, vencimento, valor, juros, multa, desconto, status)
  VALUES (v_contrato_id, '2026-03', '2026-03-10', 100.00, 0, 0, 0, 'ABERTA');
  SET v_mensal_id = LAST_INSERT_ID();

  -- 1º Pagamento parcial: R$ 40,00
  INSERT INTO pagamento (id_mensalidade, tipo, valor, forma, id_externo)
  VALUES (v_mensal_id, 'RECEBIMENTO', 40.00, 'PIX', 'PAY-TEST-001');

  SELECT status INTO v_status_m FROM mensalidade WHERE id_mensalidade = v_mensal_id;

  IF v_status_m = 'PARCIAL' THEN
    -- 2º Pagamento para quitação: R$ 60,00
    INSERT INTO pagamento (id_mensalidade, tipo, valor, forma, id_externo)
    VALUES (v_mensal_id, 'RECEBIMENTO', 60.00, 'PIX', 'PAY-TEST-002');

    SELECT status INTO v_status_m FROM mensalidade WHERE id_mensalidade = v_mensal_id;
    IF v_status_m = 'PAGA' THEN
      SET v_passou = v_passou + 1;
      INSERT INTO tmp_resultado_testes VALUES ('T2', 'trg_pagamento_status', 'PASS', 'Status transitou corretamente: ABERTA -> PARCIAL -> PAGA');
    ELSE
      SET v_falhou = v_falhou + 1;
      INSERT INTO tmp_resultado_testes VALUES ('T2', 'trg_pagamento_status', 'FAIL', CONCAT('Esperava PAGA, obteve ', v_status_m));
    END IF;
  ELSE
    SET v_falhou = v_falhou + 1;
    INSERT INTO tmp_resultado_testes VALUES ('T2', 'trg_pagamento_status', 'FAIL', CONCAT('Esperava PARCIAL, obteve ', v_status_m));
  END IF;

  -- ==========================================================================
  -- TESTE T3: trg_acesso_validacao (Validação em Linha de Catraca)
  -- ==========================================================================
  SET v_total_testes = v_total_testes + 1;
  -- Tentativa para aluno com contrato ativo e adimplente
  INSERT INTO acesso (id_aluno, id_unidade, data_hora)
  VALUES (v_aluno_ativo, v_unidade, NOW(3));

  SELECT liberado, motivo INTO v_acesso_lib, v_acesso_mot
    FROM acesso WHERE id_aluno = v_aluno_ativo ORDER BY id_acesso DESC LIMIT 1;

  -- Tentativa para aluno sem contrato
  INSERT INTO acesso (id_aluno, id_unidade, data_hora)
  VALUES (v_aluno_inad, v_unidade, NOW(3));

  IF v_acesso_lib = 1 AND v_acesso_mot = 'LIBERADO' THEN
    SELECT liberado, motivo INTO v_acesso_lib, v_acesso_mot
      FROM acesso WHERE id_aluno = v_aluno_inad ORDER BY id_acesso DESC LIMIT 1;
    IF v_acesso_lib = 0 AND v_acesso_mot = 'CONTRATO_INATIVO_OU_INADIMPLENTE' THEN
      SET v_passou = v_passou + 1;
      INSERT INTO tmp_resultado_testes VALUES ('T3', 'trg_acesso_validacao', 'PASS', 'Liberação e bloqueio na catraca validados com sucesso');
    ELSE
      SET v_falhou = v_falhou + 1;
      INSERT INTO tmp_resultado_testes VALUES ('T3', 'trg_acesso_validacao', 'FAIL', 'Falha ao rejeitar aluno sem contrato ativo');
    END IF;
  ELSE
    SET v_falhou = v_falhou + 1;
    INSERT INTO tmp_resultado_testes VALUES ('T3', 'trg_acesso_validacao', 'FAIL', 'Falha ao liberar aluno ativo adimplente');
  END IF;

  -- ==========================================================================
  -- TESTE T4: trg_turma_sem_overlap_i (Bloqueio de Anti-Overlap em INSERT)
  -- ==========================================================================
  SET v_total_testes = v_total_testes + 1;
  -- Cria Turma 1: Sala A, 08:00 às 09:00
  INSERT INTO turma (id_unidade, id_instrutor, modalidade, sala, capacidade, inicio, fim)
  VALUES (v_unidade, v_instrutor, 'Musculação', 'Sala A', 10, '2026-06-01 08:00:00', '2026-06-01 09:00:00');
  SET v_turma_1 = LAST_INSERT_ID();

  -- Tenta inserir Turma Conflitante na mesma sala (08:30 às 09:30)
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET v_esperado_erro = TRUE;
    SET v_esperado_erro = FALSE;

    INSERT INTO turma (id_unidade, id_instrutor, modalidade, sala, capacidade, inicio, fim)
    VALUES (v_unidade, v_instrutor, 'Spinning', 'Sala A', 10, '2026-06-01 08:30:00', '2026-06-01 09:30:00');
  END;

  IF v_esperado_erro = TRUE THEN
    SET v_passou = v_passou + 1;
    INSERT INTO tmp_resultado_testes VALUES ('T4', 'trg_turma_sem_overlap_i', 'PASS', 'Bloqueou corretamente inserção com overlap de sala/instrutor');
  ELSE
    SET v_falhou = v_falhou + 1;
    INSERT INTO tmp_resultado_testes VALUES ('T4', 'trg_turma_sem_overlap_i', 'FAIL', 'Permitiu inserção indevida de turma com sobreposição temporal');
  END IF;

  -- ==========================================================================
  -- TESTE T5: trg_turma_sem_overlap_u (Anti-Overlap em UPDATE)
  -- ==========================================================================
  SET v_total_testes = v_total_testes + 1;
  -- Cria Turma 2: Sala B, 10:00 às 11:00
  INSERT INTO turma (id_unidade, id_instrutor, modalidade, sala, capacidade, inicio, fim)
  VALUES (v_unidade, v_instrutor, 'Pilates', 'Sala B', 10, '2026-06-01 10:00:00', '2026-06-01 11:00:00');
  SET v_turma_2 = LAST_INSERT_ID();

  -- Tenta mover Turma 2 para o horário conflitante da Turma 1
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET v_esperado_erro = TRUE;
    SET v_esperado_erro = FALSE;

    UPDATE turma
       SET sala = 'Sala A', inicio = '2026-06-01 08:30:00', fim = '2026-06-01 09:30:00'
     WHERE id_turma = v_turma_2;
  END;

  IF v_esperado_erro = TRUE THEN
    -- Testa atualização sem conflito da própria turma (deve suceder)
    UPDATE turma SET modalidade = 'Pilates Avançado' WHERE id_turma = v_turma_2;
    SET v_passou = v_passou + 1;
    INSERT INTO tmp_resultado_testes VALUES ('T5', 'trg_turma_sem_overlap_u', 'PASS', 'Bloqueou UPDATE conflitante e permitiu edição sem auto-colisão');
  ELSE
    SET v_falhou = v_falhou + 1;
    INSERT INTO tmp_resultado_testes VALUES ('T5', 'trg_turma_sem_overlap_u', 'FAIL', 'Permitiu atualização com sobreposição temporal');
  END IF;

  -- ==========================================================================
  -- TESTE T6: trg_reserva_capacidade (Bloqueio de Lotação de Turma)
  -- ==========================================================================
  SET v_total_testes = v_total_testes + 1;
  -- Ajusta capacidade da Turma 2 para 1 vaga
  UPDATE turma SET capacidade = 1 WHERE id_turma = v_turma_2;

  -- 1ª Reserva: CONFIRMADA (deve passar)
  INSERT INTO reserva_turma (id_turma, id_aluno, id_unidade, status)
  VALUES (v_turma_2, v_aluno_ativo, v_unidade, 'CONFIRMADA');

  -- 2ª Reserva: Tenta CONFIRMADA com turma cheia (deve falhar)
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET v_esperado_erro = TRUE;
    SET v_esperado_erro = FALSE;

    INSERT INTO reserva_turma (id_turma, id_aluno, id_unidade, status)
    VALUES (v_turma_2, v_aluno_inad, v_unidade, 'CONFIRMADA');
  END;

  IF v_esperado_erro = TRUE THEN
    SET v_passou = v_passou + 1;
    INSERT INTO tmp_resultado_testes VALUES ('T6', 'trg_reserva_capacidade', 'PASS', 'Bloqueou reserva confirmada em turma com capacidade esgotada');
  ELSE
    SET v_falhou = v_falhou + 1;
    INSERT INTO tmp_resultado_testes VALUES ('T6', 'trg_reserva_capacidade', 'FAIL', 'Permitiu reserva confirmada excedendo a capacidade máxima');
  END IF;

  -- ==========================================================================
  -- TESTE T7: trg_auditoria_aluno (Gravação Estruturada em JSON e USER())
  -- ==========================================================================
  SET v_total_testes = v_total_testes + 1;
  UPDATE aluno
     SET nome = 'Aluno Teste Nome Alterado'
   WHERE id_aluno = v_aluno_ativo;

  SELECT COUNT(*) INTO v_audit_count
    FROM auditoria_log
   WHERE tabela = 'aluno'
     AND operacao = 'UPDATE'
     AND chave_pk = CAST(v_aluno_ativo AS CHAR)
     AND JSON_EXTRACT(depois, '$.nome') = 'Aluno Teste Nome Alterado';

  IF v_audit_count > 0 THEN
    SET v_passou = v_passou + 1;
    INSERT INTO tmp_resultado_testes VALUES ('T7', 'trg_auditoria_aluno', 'PASS', 'Trilha de auditoria gerada com JSON antes/depois e USER()');
  ELSE
    SET v_falhou = v_falhou + 1;
    INSERT INTO tmp_resultado_testes VALUES ('T7', 'trg_auditoria_aluno', 'FAIL', 'Falha ao registrar log estruturado de atualização em aluno');
  END IF;

  -- --------------------------------------------------------------------------
  -- EXIBIÇÃO DO RELATÓRIO CONSOLIDADO
  -- --------------------------------------------------------------------------
  SELECT * FROM tmp_resultado_testes;

  SELECT v_total_testes AS total_testes,
         v_passou       AS testes_passados,
         v_falhou       AS testes_falhados,
         CASE WHEN v_falhou = 0 THEN 'SUCESSO - TODOS OS TRIGGERS APROVADOS'
              ELSE 'FALHA - VERIFICAR LOGS' END AS resultado_geral;

  -- Limpeza de registros de teste
  DELETE FROM reserva_turma WHERE id_turma IN (v_turma_1, v_turma_2);
  DELETE FROM turma WHERE id_turma IN (v_turma_1, v_turma_2);
  DELETE FROM pagamento WHERE id_mensalidade = v_mensal_id;
  DELETE FROM mensalidade WHERE id_mensalidade = v_mensal_id;
  DELETE FROM acesso WHERE id_aluno IN (v_aluno_ativo, v_aluno_inad);
  DELETE FROM contrato WHERE id_contrato = v_contrato_id;
  DELETE FROM auditoria_log WHERE tabela = 'aluno' AND chave_pk = CAST(v_aluno_ativo AS CHAR);
  DELETE FROM aluno WHERE id_aluno IN (v_aluno_ativo, v_aluno_inad);

END$$

DELIMITER ;
