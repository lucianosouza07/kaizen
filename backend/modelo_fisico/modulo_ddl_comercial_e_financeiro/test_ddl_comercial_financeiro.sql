-- ============================================================================
-- Kaizen ERP - Testes de Integridade Comercial e Financeira (GL4BD-4 / BK-DB-04)
-- Validação dos Critérios de Aceite, Constraints, Idempotência e Tipagem
-- ============================================================================

USE kaizen;

-- ----------------------------------------------------------------------------
-- 1. Verificação de Metadados e Chaves no Information Schema
-- ----------------------------------------------------------------------------
SELECT table_name, engine, table_collation 
FROM information_schema.tables 
WHERE table_schema = 'kaizen'
  AND table_name IN ('PLANO', 'CONTRATO', 'MENSALIDADE', 'PAGAMENTO');

SELECT table_name, column_name, data_type, numeric_precision, numeric_scale, is_nullable
FROM information_schema.columns
WHERE table_schema = 'kaizen'
  AND table_name IN ('PLANO', 'CONTRATO', 'MENSALIDADE', 'PAGAMENTO')
  AND data_type = 'decimal';

SELECT table_name, constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'kaizen'
  AND constraint_name IN (
    'uq_plano_nome',
    'uq_contrato_numero',
    'uq_contrato_ativo_por_aluno',
    'uq_mensalidade_competencia',
    'uq_pagamento_id_externo'
  );

-- ----------------------------------------------------------------------------
-- 2. Carga Base de Dados Válidos (Testes Positivos)
-- ----------------------------------------------------------------------------
-- Garante unidade e alunos do núcleo de cadastro para os testes
INSERT INTO UNIDADE (id_unidade, nome, cnpj, cidade, ativa)
VALUES (10, 'Unidade Teste Financeiro', '98765432000188', 'Salvador', 1)
ON DUPLICATE KEY UPDATE nome = VALUES(nome);

INSERT INTO ALUNO (id_aluno, id_unidade, nome, cpf, email, data_nascimento, ativo)
VALUES (100, 10, 'Aluno Financiado 1', '12312312344', 'aluno100@kaizen.com', '1995-05-15', 1)
ON DUPLICATE KEY UPDATE nome = VALUES(nome);

INSERT INTO ALUNO (id_aluno, id_unidade, nome, cpf, email, data_nascimento, ativo)
VALUES (101, 10, 'Aluno Financiado 2', '32132132155', 'aluno101@kaizen.com', '1998-08-20', 1)
ON DUPLICATE KEY UPDATE nome = VALUES(nome);

-- Insere Plano
INSERT INTO PLANO (id_plano, nome, periodicidade_meses, valor_mensal, carencia_dias, multa_percentual, ativo)
VALUES (1, 'Plano Mensal Pro', 1, 149.90, 0, 2.00, 1);

-- Insere Contrato Ativo para o aluno 100
INSERT INTO CONTRATO (id_contrato, numero, id_aluno, id_unidade, id_plano, data_inicio, data_fim, dia_vencimento, valor_mensal, status)
VALUES (1, 'CTR-2026-000001', 100, 10, 1, '2026-01-01', NULL, 10, 149.90, 'ATIVO');

-- Insere Mensalidade Válida
INSERT INTO MENSALIDADE (id_mensalidade, id_contrato, competencia, vencimento, valor, juros, multa, desconto, status)
VALUES (1, 1, '2026-01', '2026-01-10', 149.90, 0.00, 0.00, 0.00, 'ABERTA');

-- Insere Pagamento de Recebimento
INSERT INTO PAGAMENTO (id_pagamento, id_mensalidade, tipo, valor, forma, id_externo, pago_em)
VALUES (1, 1, 'RECEBIMENTO', 149.90, 'PIX', 'PAY-EXT-00001', '2026-01-09 14:30:00.000');

-- Insere Estorno Compensatório referenciando id_pagamento_original
INSERT INTO PAGAMENTO (id_pagamento, id_mensalidade, tipo, valor, forma, id_externo, id_pagamento_original, pago_em)
VALUES (2, 1, 'ESTORNO', 149.90, 'PIX', 'PAY-EXT-00001-EST', 1, '2026-01-10 10:00:00.000');

-- ----------------------------------------------------------------------------
-- 3. Validação de Histórico e Ativo Único
-- ----------------------------------------------------------------------------
-- Aluno 100 pode ter contratos históricos com status 'CANCELADO' ou 'SUSPENSO' (ativo_unico = NULL)
INSERT INTO CONTRATO (id_contrato, numero, id_aluno, id_unidade, id_plano, data_inicio, data_fim, dia_vencimento, valor_mensal, status)
VALUES (2, 'CTR-2025-000050', 100, 10, 1, '2025-01-01', '2025-12-31', 10, 129.90, 'CANCELADO');

SELECT id_contrato, id_aluno, numero, status, ativo_unico 
FROM CONTRATO 
WHERE id_aluno = 100;

-- ----------------------------------------------------------------------------
-- 4. CONSULTA DOS TESTES DE SUCESSO
-- ----------------------------------------------------------------------------
SELECT 'Carga e integridade de chave estrangeira executada com sucesso!' AS resultado;

-- ----------------------------------------------------------------------------
-- 5. CENÁRIOS DE TESTES NEGATIVOS (Devem falhar se descomentados)
-- ----------------------------------------------------------------------------
-- T1: Tentativa de segundo contrato ATIVO para o mesmo aluno (esperado: ERROR 1062 uq_contrato_ativo_por_aluno)
-- INSERT INTO CONTRATO (numero, id_aluno, id_unidade, id_plano, data_inicio, dia_vencimento, valor_mensal, status)
-- VALUES ('CTR-2026-999999', 100, 10, 1, '2026-02-01', 10, 149.90, 'ATIVO');

-- T2: Tentativa de duplicar competência para o mesmo contrato (esperado: ERROR 1062 uq_mensalidade_competencia)
-- INSERT INTO MENSALIDADE (id_contrato, competencia, vencimento, valor)
-- VALUES (1, '2026-01', '2026-01-10', 149.90);

-- T3: Tentativa de duplicar id_externo de pagamento (esperado: ERROR 1062 uq_pagamento_id_externo)
-- INSERT INTO PAGAMENTO (id_mensalidade, valor, forma, id_externo)
-- VALUES (1, 10.00, 'PIX', 'PAY-EXT-00001');

-- T4: Violação de CHECK de dia de vencimento (dia 30) (esperado: ERROR 3819 ck_contrato_dia)
-- INSERT INTO CONTRATO (numero, id_aluno, id_unidade, id_plano, data_inicio, dia_vencimento, valor_mensal, status)
-- VALUES ('CTR-CK-01', 101, 10, 1, '2026-01-01', 30, 149.90, 'ATIVO');

-- T5: Violação de CHECK de competência (formato inválido '2026-13') (esperado: ERROR 3819 ck_mensalidade_competencia)
-- INSERT INTO MENSALIDADE (id_contrato, competencia, vencimento, valor)
-- VALUES (1, '2026-13', '2026-01-10', 149.90);

-- T6: Violação de FK composta (aluno da unidade 10 tentando contrato na unidade 999) (esperado: ERROR 1452 fk_contrato_aluno_unidade)
-- INSERT INTO CONTRATO (numero, id_aluno, id_unidade, id_plano, data_inicio, dia_vencimento, valor_mensal, status)
-- VALUES ('CTR-FK-ERR', 101, 999, 1, '2026-01-01', 10, 149.90, 'ATIVO');
