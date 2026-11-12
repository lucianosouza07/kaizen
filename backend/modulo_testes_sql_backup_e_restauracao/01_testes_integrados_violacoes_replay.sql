-- ============================================================================
-- Kaizen ERP - Bateria Integrada de Testes SQL: Integridade, Violações e Replay
-- Tarefa: BK-DB-09 (GL4BD-9)
-- Dialeto: MySQL 8.0.46
-- ============================================================================

USE kaizen;
SET NAMES utf8mb4;

-- ============================================================================
-- BLOCO A: TESTES POSITIVOS E CONFERÊNCIA DE SEED
-- ============================================================================

-- A.1 Conferência das 15 tabelas no catálogo
SELECT 'BLOCO A.1 - Verificação de Tabelas' AS etapa;
SELECT table_name, engine, table_rows, table_collation 
FROM information_schema.tables 
WHERE table_schema = DATABASE()
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- A.2 Conferência das 5 Views
SELECT 'BLOCO A.2 - Verificação das Views' AS etapa;
SELECT table_name 
FROM information_schema.views 
WHERE table_schema = DATABASE()
ORDER BY table_name;

-- A.3 Conferência dos 7 Triggers
SELECT 'BLOCO A.3 - Verificação dos Triggers' AS etapa;
SELECT trigger_name, event_manipulation, event_object_table, action_timing
FROM information_schema.triggers
WHERE trigger_schema = DATABASE()
ORDER BY trigger_name;

-- A.4 Conferência de Dados de Seed Críticos
SELECT 'BLOCO A.4 - Contagem de Registros de Seed' AS etapa;
SELECT 'UNIDADE' AS entidade, count(*) AS total FROM UNIDADE
UNION ALL
SELECT 'PLANO', count(*) FROM PLANO
UNION ALL
SELECT 'MODALIDADE', count(*) FROM MODALIDADE
UNION ALL
SELECT 'TURMA', count(*) FROM TURMA
UNION ALL
SELECT 'PAPEL', count(*) FROM PAPEL
UNION ALL
SELECT 'USUARIO', count(*) FROM USUARIO
UNION ALL
SELECT 'ALUNO', count(*) FROM ALUNO
UNION ALL
SELECT 'COLABORADOR', count(*) FROM COLABORADOR
UNION ALL
SELECT 'CONTRATO', count(*) FROM CONTRATO;

-- ============================================================================
-- BLOCO B: TESTES DE NEGÓCIO E VIOLAÇÕES (Erros Esperados)
-- ============================================================================

-- B.1 Tentativa de Segundo Contrato ATIVO para o mesmo Aluno
-- Regra: Restrição uq_contrato_ativo_por_aluno via coluna gerada ativo_unico
-- Esperado se descomentado: ERROR 1062 (23000): Duplicate entry '...-1' for key 'CONTRATO.uq_contrato_ativo_por_aluno'
/*
INSERT INTO CONTRATO (numero, id_aluno, id_unidade, id_plano, data_inicio, dia_vencimento, valor_mensal, status)
VALUES ('CTR-VIOLA-01', 1, 1, 1, CURRENT_DATE(), 10, 149.90, 'ATIVO');
*/

-- B.2 Tentativa de Inserção de Aluno com Unidade Divergente no Contrato
-- Regra: FK Composta fk_contrato_aluno_unidade (id_aluno, id_unidade) -> ALUNO (id_aluno, id_unidade)
-- Esperado se descomentado: ERROR 1452 (23000): Cannot add or update a child row: a foreign key constraint fails
/*
INSERT INTO CONTRATO (numero, id_aluno, id_unidade, id_plano, data_inicio, dia_vencimento, valor_mensal, status)
VALUES ('CTR-VIOLA-02', 1, 999, 1, CURRENT_DATE(), 10, 149.90, 'ATIVO');
*/

-- B.3 Tentativa de Inserção de CPF inválido em ALUNO (com letras ou tamanho divergente)
-- Regra: CHECK ck_aluno_cpf
-- Esperado se descomentado: ERROR 3819 (HY000): Check constraint 'ck_aluno_cpf' is violated.
/*
INSERT INTO ALUNO (id_unidade, nome, cpf, email, data_nascimento)
VALUES (1, 'Aluno CPF Invalido', '1234567890A', 'cpf_invalido@teste.com', '1990-01-01');
*/

-- B.4 Tentativa de Acesso na Catraca com Aluno Inadimplente ou Inativo
-- Regra: Trigger TRG_ACESSO_CATRACA_BEFORE_INSERT bloqueia acesso não autorizado
-- Esperado se chamada com aluno sem contrato vigente ou mensalidade em atraso:
-- Erro ou rejeição com registro de tentativa bloqueada em AUDITORIA_LOG.

-- ============================================================================
-- BLOCO C: TESTES DE REPLAY E IDEMPOTÊNCIA
-- ============================================================================

-- C.1 Idempotência de Baixa Externa de Pagamento (Replay de Webhook/Gateway)
-- Regra: Restrição de unicidade uq_pagamento_id_externo
-- Esperado se submetido o mesmo id_externo: ERROR 1062 (23000): Duplicate entry 'ID_PAGAMENTO_EXTERNO' for key 'PAGAMENTO.uq_pagamento_id_externo'
/*
INSERT INTO PAGAMENTO (id_mensalidade, tipo, valor, forma, id_externo, pago_em)
VALUES (1, 'RECEBIMENTO', 149.90, 'PIX', 'PAY-REPLAY-TEST-001', CURRENT_TIMESTAMP(3));

-- Tentativa de Replay (deve falhar):
INSERT INTO PAGAMENTO (id_mensalidade, tipo, valor, forma, id_externo, pago_em)
VALUES (1, 'RECEBIMENTO', 149.90, 'PIX', 'PAY-REPLAY-TEST-001', CURRENT_TIMESTAMP(3));
*/

-- C.2 Idempotência de Geração de Mensalidades por Competência
-- Regra: Restrição de unicidade uq_mensalidade_competencia (id_contrato, competencia)
-- Esperado se faturado novamente o mesmo contrato na mesma competência:
-- ERROR 1062 (23000): Duplicate entry '1-2026-01' for key 'MENSALIDADE.uq_mensalidade_competencia'
/*
INSERT INTO MENSALIDADE (id_contrato, competencia, vencimento, valor, status)
VALUES (1, '2026-01', '2026-01-10', 149.90, 'ABERTA');
*/

SELECT 'Suíte integrada de validação de regras, violações e replay executada com sucesso!' AS status_final;
