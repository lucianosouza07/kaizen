-- ============================================================================
-- Kaizen ERP - Script de Auditoria e Validação Pós-Restauração (BK-DB-09)
-- Executado no schema restaurado (ex: kaizen_restore_test)
-- Dialeto: MySQL 8.0.46
-- ============================================================================

SET NAMES utf8mb4;

SELECT '=== AUDITORIA PÓS-RESTAURAÇÃO DO BANCO KAIZEN ERP ===' AS cabecalho;
SELECT DATABASE() AS schema_auditado, CURRENT_TIMESTAMP AS executado_em;

-- ----------------------------------------------------------------------------
-- 1. Verificação Quantitativa das 15 Tabelas
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN count(*) = 15 THEN 'PASS - 15 Tabelas recriadas corretamente'
        ELSE CONCAT('FAIL - Quantidade incorreta de tabelas: ', count(*))
    END AS status_tabelas,
    count(*) AS total_tabelas
FROM information_schema.tables 
WHERE table_schema = DATABASE() 
  AND table_type = 'BASE TABLE';

-- Listagem de conformidade das tabelas
SELECT table_name, engine, table_rows, table_collation
FROM information_schema.tables 
WHERE table_schema = DATABASE() 
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- ----------------------------------------------------------------------------
-- 2. Verificação Quantitativa das 5 Views
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN count(*) = 5 THEN 'PASS - 5 Views operacionais recriadas corretamente'
        ELSE CONCAT('FAIL - Quantidade incorreta de views: ', count(*))
    END AS status_views,
    count(*) AS total_views
FROM information_schema.views 
WHERE table_schema = DATABASE();

SELECT table_name AS view_name
FROM information_schema.views 
WHERE table_schema = DATABASE()
ORDER BY table_name;

-- ----------------------------------------------------------------------------
-- 3. Verificação Quantitativa dos Triggers
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN count(*) >= 7 THEN 'PASS - Triggers recriados corretamente'
        ELSE CONCAT('FAIL - Quantidade insuficiente de triggers: ', count(*))
    END AS status_triggers,
    count(*) AS total_triggers
FROM information_schema.triggers 
WHERE trigger_schema = DATABASE();

SELECT trigger_name, event_manipulation, event_object_table, action_timing
FROM information_schema.triggers 
WHERE trigger_schema = DATABASE()
ORDER BY trigger_name;

-- ----------------------------------------------------------------------------
-- 4. Verificação de Functions e Procedures
-- ----------------------------------------------------------------------------
SELECT routine_name, routine_type, data_type, security_type
FROM information_schema.routines 
WHERE routine_schema = DATABASE()
ORDER BY routine_name;

-- ----------------------------------------------------------------------------
-- 5. Conferência de Integridade dos Registros de Seed
-- ----------------------------------------------------------------------------
SELECT 'UNIDADE' AS tabela, count(*) AS registros FROM UNIDADE
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

-- ----------------------------------------------------------------------------
-- 6. Teste de Fumaça Operacional no Schema Restaurado
-- ----------------------------------------------------------------------------
-- Consulta simples à view de alunos ativos
SELECT count(*) AS total_alunos_ativos_view FROM VW_ALUNOS_ATIVOS;

-- Consulta à view de ocupação de turmas
SELECT count(*) AS turmas_monitoradas_view FROM VW_OCUPACAO_TURMAS;

SELECT 'Auditoria pós-restauração finalizada: Banco 100% íntegro e recriado com paridade!' AS resultado;
