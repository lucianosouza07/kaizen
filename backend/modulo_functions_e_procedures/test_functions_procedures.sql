-- =============================================================================
-- test_functions_procedures.sql
-- Kaizen BD — Testes Automatizados de Functions e Procedures (BK-DB-06)
-- SGBD: MySQL Server 8.0.46 / Dialeto MySQL 8.0
-- =============================================================================

USE kaizen;

-- =============================================================================
-- SEÇÃO 1: AUDITORIA DE METADADOS NO INFORMATION_SCHEMA
-- =============================================================================

-- 1.1 Conferência das 4 Functions com READS SQL DATA
SELECT routine_name, routine_type, sql_data_access, routine_definition
  FROM information_schema.routines
 WHERE routine_schema = 'kaizen'
   AND routine_type = 'FUNCTION'
   AND routine_name IN ('fn_valor_devido', 'fn_status_mensalidade', 'fn_acesso_elegivel', 'fn_ocupacao_turma')
 ORDER BY routine_name;

-- 1.2 Conferência das 4 Procedures com MODIFIES SQL DATA
SELECT routine_name, routine_type, sql_data_access
  FROM information_schema.routines
 WHERE routine_schema = 'kaizen'
   AND routine_type = 'PROCEDURE'
   AND routine_name IN ('sp_proximo_numero', 'sp_gerar_mensalidades', 'sp_registrar_pagamento', 'sp_anonimizar_aluno')
 ORDER BY routine_name;

-- 1.3 Verificação de Presença das Tabelas Base Requeridas
SELECT table_name, engine, table_rows
  FROM information_schema.tables
 WHERE table_schema = 'kaizen'
   AND table_name IN (
     'UNIDADE', 'CONTADOR_DOCUMENTO', 'ALUNO', 'COLABORADOR',
     'PLANO', 'TURMA', 'CONTRATO', 'MENSALIDADE', 'PAGAMENTO',
     'RESERVA_TURMA', 'AUDITORIA_LOG'
   )
 ORDER BY table_name;

-- =============================================================================
-- SEÇÃO 2: MASSA DE DADOS PARA TESTES ISOLADOS (FIXTURES)
-- =============================================================================

-- Garante Unidades de Teste
INSERT INTO UNIDADE (id_unidade, nome, cnpj, cidade, ativa)
VALUES 
  (901, 'Unidade Teste Alpha', '11222333000191', 'São Paulo', 1),
  (902, 'Unidade Teste Beta',  '11222333000272', 'Campinas',  1)
ON DUPLICATE KEY UPDATE nome = VALUES(nome);

-- Garante Contadores de Documento
INSERT INTO CONTADOR_DOCUMENTO (tipo, id_unidade, ultimo)
VALUES 
  ('CONTRATO', 901, 100),
  ('NFSE',     901, 50),
  ('CONTRATO', 902, 200)
ON DUPLICATE KEY UPDATE ultimo = VALUES(ultimo);

-- Garante Alunos de Teste
INSERT INTO ALUNO (id_aluno, id_unidade, nome, cpf, email, data_nascimento, consentimento_lgpd_em, ativo)
VALUES 
  (9001, 901, 'Carlos Silva Teste',    '90100000101', 'carlos.teste@kaizen.com',    '1990-05-10', NOW(), 1),
  (9002, 901, 'Mariana Souza Teste',   '90100000202', 'mariana.teste@kaizen.com',   '1994-08-20', NOW(), 1),
  (9003, 901, 'Roberto Ferreira Teste','90100000303', 'roberto.teste@kaizen.com',   '1985-12-15', NOW(), 1),
  (9004, 901, 'Ana Clara Teste',       '90100000404', 'anaclara.teste@kaizen.com',  '2000-01-30', NOW(), 1),
  (9005, 902, 'Lucas Mendes Teste',    '90200000505', 'lucas.teste@kaizen.com',     '1992-07-22', NOW(), 1)
ON DUPLICATE KEY UPDATE nome = VALUES(nome), ativo = VALUES(ativo);

-- Garante Colaborador Instrutor e Turma
INSERT INTO COLABORADOR (id_colaborador, id_unidade, nome, cpf, email, cargo, ativo)
VALUES (9101, 901, 'Instrutor Treinador', '91000000101', 'instrutor.teste@kaizen.com', 'INSTRUTOR', 1)
ON DUPLICATE KEY UPDATE nome = VALUES(nome);

INSERT INTO TURMA (id_turma, id_unidade, id_instrutor, modalidade, sala, capacidade, inicio, fim)
VALUES (9201, 901, 9101, 'CrossFit Teste', 'Sala 01', 20, '2026-11-15 10:00:00', '2026-11-15 11:00:00')
ON DUPLICATE KEY UPDATE modalidade = VALUES(modalidade);

-- Reservas de Turma com diferentes status
INSERT INTO RESERVA_TURMA (id_reserva, id_turma, id_aluno, id_unidade, status)
VALUES 
  (9301, 9201, 9001, 901, 'CONFIRMADA'),
  (9302, 9201, 9002, 901, 'CONFIRMADA'),
  (9303, 9201, 9003, 901, 'CANCELADA'),
  (9304, 9201, 9004, 901, 'ESPERA')
ON DUPLICATE KEY UPDATE status = VALUES(status);

-- Plano de Teste
INSERT INTO PLANO (id_plano, nome, periodicidade_meses, valor_mensal, carencia_dias, multa_percentual, ativo)
VALUES (91, 'Plano Teste Rotinas', 1, 100.00, 5, 2.00, 1)
ON DUPLICATE KEY UPDATE valor_mensal = VALUES(valor_mensal);

-- Contratos
INSERT INTO CONTRATO (id_contrato, numero, id_aluno, id_unidade, id_plano, data_inicio, data_fim, dia_vencimento, valor_mensal, status)
VALUES 
  (9401, 'CTR-2026-009401', 9001, 901, 91, '2026-01-01', NULL, 10, 100.00, 'ATIVO'),
  (9402, 'CTR-2026-009402', 9002, 901, 91, '2026-01-01', NULL, 15, 100.00, 'ATIVO'),
  (9403, 'CTR-2026-009403', 9003, 901, 91, '2026-01-01', NULL, 5,  100.00, 'ATIVO'),
  (9404, 'CTR-2026-009404', 9004, 901, 91, '2026-01-01', NULL, 10, 100.00, 'CANCELADO'),
  (9405, 'CTR-2026-009405', 9005, 902, 91, '2026-01-01', NULL, 10, 100.00, 'ATIVO')
ON DUPLICATE KEY UPDATE status = VALUES(status);

-- Mensalidades para Teste de Cálculos
-- 9501: Mensalidade Aberta (sem pagamentos)
-- 9502: Mensalidade Parcial (pago 40 de 100)
-- 9503: Mensalidade Paga (pago 100 de 100)
-- 9504: Mensalidade Cancelada
-- 9505: Mensalidade Vencida há mais de 5 dias sem pagamento (para aluno 9003)
INSERT INTO MENSALIDADE (id_mensalidade, id_contrato, competencia, vencimento, valor, juros, multa, desconto, status)
VALUES 
  (9501, 9401, '2026-09', '2026-09-10', 100.00, 0.00, 0.00, 0.00, 'ABERTA'),
  (9502, 9401, '2026-10', '2026-10-10', 100.00, 0.00, 0.00, 0.00, 'ABERTA'),
  (9503, 9402, '2026-10', '2026-10-15', 100.00, 0.00, 0.00, 0.00, 'PAGA'),
  (9504, 9404, '2026-10', '2026-10-10', 100.00, 0.00, 0.00, 0.00, 'CANCELADA'),
  (9505, 9403, '2026-10', '2026-10-05', 100.00, 10.00, 2.00, 0.00, 'ABERTA')
ON DUPLICATE KEY UPDATE valor = VALUES(valor);

-- Pagamentos existentes
INSERT INTO PAGAMENTO (id_pagamento, id_mensalidade, tipo, valor, forma, id_externo, pago_em)
VALUES 
  (9601, 9502, 'RECEBIMENTO', 40.00,  'PIX',    'PAY-TEST-0001', NOW()),
  (9602, 9503, 'RECEBIMENTO', 100.00, 'CARTAO', 'PAY-TEST-0002', NOW())
ON DUPLICATE KEY UPDATE valor = VALUES(valor);

-- =============================================================================
-- SEÇÃO 3: EXECUÇÃO DOS TESTES DE HISTÓRIAS DE USUÁRIO
-- =============================================================================

-- -----------------------------------------------------------------------------
-- US1: Validação das Functions (fn_valor_devido, fn_status_mensalidade, fn_acesso_elegivel, fn_ocupacao_turma)
-- -----------------------------------------------------------------------------

-- Teste T1.1: fn_valor_devido em mensalidade aberta (esperado: 100.00)
SET @devido_9501 = fn_valor_devido(9501);

-- Teste T1.2: fn_valor_devido em mensalidade parcial (esperado: 60.00)
SET @devido_9502 = fn_valor_devido(9502);

-- Teste T1.3: fn_valor_devido em mensalidade quitada (esperado: 0.00)
SET @devido_9503 = fn_valor_devido(9503);

-- Teste T1.4: fn_status_mensalidade dinâmica
SET @status_calc_9501 = fn_status_mensalidade(9501); -- Esperado: 'ABERTA'
SET @status_calc_9502 = fn_status_mensalidade(9502); -- Esperado: 'PARCIAL'
SET @status_calc_9503 = fn_status_mensalidade(9503); -- Esperado: 'PAGA'
SET @status_calc_9504 = fn_status_mensalidade(9504); -- Esperado: 'CANCELADA'

-- Teste T1.5: fn_acesso_elegivel
-- Aluno 9002 (em dia, mensalidade paga) -> Esperado: 1
SET @elegivel_9002 = fn_acesso_elegivel(9002);
-- Aluno 9003 (atraso > 5 dias na mensalidade 9505) -> Esperado: 0
SET @elegivel_9003 = fn_acesso_elegivel(9003);
-- Aluno 9004 (contrato cancelado) -> Esperado: 0
SET @elegivel_9004 = fn_acesso_elegivel(9004);

-- Teste T1.6: fn_ocupacao_turma (Turma 9201 tem 2 reservas CONFIRMADAS) -> Esperado: 2
SET @ocupacao_9201 = fn_ocupacao_turma(9201);

-- -----------------------------------------------------------------------------
-- US2: Validação de Idempotência em Procedures
-- -----------------------------------------------------------------------------

-- Teste T2.1: sp_gerar_mensalidades 1ª execução para competência '2026-11', unidade 901
CALL sp_gerar_mensalidades('2026-11', 901);

-- Teste T2.2: sp_gerar_mensalidades 2ª execução com os mesmos parâmetros (esperado: geradas = 0)
CALL sp_gerar_mensalidades('2026-11', 901);

-- Teste T2.3: sp_registrar_pagamento 1ª execução com id_externo novo
CALL sp_registrar_pagamento(9501, 100.00, 'PIX', 'EXT-PAY-IDEMP-001');

-- Teste T2.4: sp_registrar_pagamento 2ª execução com mesmo id_externo (esperado: inseridos = 0, status_atual = 'PAGA')
CALL sp_registrar_pagamento(9501, 100.00, 'PIX', 'EXT-PAY-IDEMP-001');

-- -----------------------------------------------------------------------------
-- US3: Validação da Emulação de Sequences (sp_proximo_numero)
-- -----------------------------------------------------------------------------

-- Teste T3.1: Incremento atômico consecutivo para 'CONTRATO', unidade 901 (base era 100)
CALL sp_proximo_numero('CONTRATO', 901, @seq1_u901); -- Esperado: 101
CALL sp_proximo_numero('CONTRATO', 901, @seq2_u901); -- Esperado: 102

-- Teste T3.2: Isolamento da série na unidade 902 (base era 200)
CALL sp_proximo_numero('CONTRATO', 902, @seq1_u902); -- Esperado: 201

-- -----------------------------------------------------------------------------
-- US4: Validação de Anonimização LGPD (sp_anonimizar_aluno)
-- -----------------------------------------------------------------------------

-- Executa anonimização sobre o aluno 9005
CALL sp_anonimizar_aluno(9005);

-- =============================================================================
-- SEÇÃO 4: CONSOLIDAÇÃO DOS RESULTADOS E ASSERÇÕES (PASS/FAIL)
-- =============================================================================

SELECT 
  'AC1: 4 Functions READS SQL DATA' AS criterio,
  IF(
    (SELECT COUNT(*) FROM information_schema.routines 
      WHERE routine_schema = 'kaizen' AND routine_type = 'FUNCTION' 
        AND sql_data_access = 'READS SQL DATA'
        AND routine_name IN ('fn_valor_devido', 'fn_status_mensalidade', 'fn_acesso_elegivel', 'fn_ocupacao_turma')) = 4,
    'PASS', 'FAIL'
  ) AS resultado,
  'Todas as 4 funções declaradas estritamente com READS SQL DATA' AS detalhe

UNION ALL

SELECT 
  'AC2: 4 Procedures MODIFIES SQL DATA' AS criterio,
  IF(
    (SELECT COUNT(*) FROM information_schema.routines 
      WHERE routine_schema = 'kaizen' AND routine_type = 'PROCEDURE' 
        AND sql_data_access = 'MODIFIES SQL DATA'
        AND routine_name IN ('sp_proximo_numero', 'sp_gerar_mensalidades', 'sp_registrar_pagamento', 'sp_anonimizar_aluno')) = 4,
    'PASS', 'FAIL'
  ) AS resultado,
  'Todas as 4 procedures declaradas com MODIFIES SQL DATA' AS detalhe

UNION ALL

SELECT 
  'AC3: Cálculo fn_valor_devido e fn_status_mensalidade' AS criterio,
  IF(
    @devido_9501 = 100.00 AND @devido_9502 = 60.00 AND @devido_9503 = 0.00
    AND @status_calc_9501 = 'ABERTA' AND @status_calc_9502 = 'PARCIAL' 
    AND @status_calc_9503 = 'PAGA' AND @status_calc_9504 = 'CANCELADA',
    'PASS', 'FAIL'
  ) AS resultado,
  CONCAT('devido=(9501:', @devido_9501, ', 9502:', @devido_9502, ', 9503:', @devido_9503, ')') AS detalhe

UNION ALL

SELECT 
  'AC4: Validação de Catraca fn_acesso_elegivel' AS criterio,
  IF(@elegivel_9002 = 1 AND @elegivel_9003 = 0 AND @elegivel_9004 = 0, 'PASS', 'FAIL') AS resultado,
  CONCAT('elegivel=(adimplente:', @elegivel_9002, ', atrasado>5d:', @elegivel_9003, ', cancelado:', @elegivel_9004, ')') AS detalhe

UNION ALL

SELECT 
  'AC5: Ocupação de Turma fn_ocupacao_turma' AS criterio,
  IF(@ocupacao_9201 = 2, 'PASS', 'FAIL') AS resultado,
  CONCAT('ocupacao_calculada=', @ocupacao_9201, ' (esperado=2 apenas CONFIRMADA)') AS detalhe

UNION ALL

SELECT 
  'AC6: sp_proximo_numero emula 2 séries e isolamento por unidade' AS criterio,
  IF(@seq1_u901 = 101 AND @seq2_u901 = 102 AND @seq1_u902 = 201, 'PASS', 'FAIL') AS resultado,
  CONCAT('seq_u901=(', @seq1_u901, ',', @seq2_u901, '), seq_u902=', @seq1_u902) AS detalhe

UNION ALL

SELECT 
  'AC7: Idempotência de Pagamento por id_externo' AS criterio,
  IF((SELECT COUNT(*) FROM PAGAMENTO WHERE id_externo = 'EXT-PAY-IDEMP-001') = 1, 'PASS', 'FAIL') AS resultado,
  'Inserção duplicada ignorada sem lançar erro nem duplicar pagamento' AS detalhe

UNION ALL

SELECT 
  'AC8: Anonimização LGPD sp_anonimizar_aluno preserva integridade' AS criterio,
  IF(
    (SELECT nome FROM ALUNO WHERE id_aluno = 9005) = 'ALUNO ANONIMIZADO 9005'
    AND (SELECT cpf FROM ALUNO WHERE id_aluno = 9005) = '90000009005'
    AND (SELECT email FROM ALUNO WHERE id_aluno = 9005) = 'anonimo+9005@invalid.local'
    AND (SELECT ativo FROM ALUNO WHERE id_aluno = 9005) = 0
    AND (SELECT COUNT(*) FROM CONTRATO WHERE id_aluno = 9005) = 1,
    'PASS', 'FAIL'
  ) AS resultado,
  'PII descaracterizada, aluno desativado e chaves estrangeiras preservadas' AS detalhe;
