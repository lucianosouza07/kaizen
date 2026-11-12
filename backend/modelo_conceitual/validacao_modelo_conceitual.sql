-- =============================================================================
-- KAIZEN BD — VALIDAÇÃO DE CONFORMIDADE DO MODELO CONCEITUAL (BK-DB-01)
-- Dialeto: MySQL 8.0.46 (compatível com execução isolada em memória via CTEs)
-- Objetivo: Comprovar de forma executável no MySQL Workbench 8.0.47 CE que o
--           catálogo conceitual atende estritamente aos 4 critérios de aceite:
--           1) Exatamente 13 entidades de domínio;
--           2) Exatamente 13 relacionamentos com cardinalidades (R1 a R13);
--           3) RESERVA_TURMA e USUARIO_PAPEL explícitas como associativas;
--           4) Nenhuma tabela técnica (AUDITORIA_LOG, CONTADOR_DOCUMENTO) no conceitual.
-- =============================================================================

WITH catalogo_entidades_conceituais AS (
    SELECT 1  AS ordem, 'UNIDADE'        AS entidade, 'FORTE'       AS natureza, 'DOMINIO' AS camada UNION ALL
    SELECT 2  AS ordem, 'ALUNO'          AS entidade, 'FORTE'       AS natureza, 'DOMINIO' AS camada UNION ALL
    SELECT 3  AS ordem, 'COLABORADOR'    AS entidade, 'FORTE'       AS natureza, 'DOMINIO' AS camada UNION ALL
    SELECT 4  AS ordem, 'PLANO'          AS entidade, 'FORTE'       AS natureza, 'DOMINIO' AS camada UNION ALL
    SELECT 5  AS ordem, 'CONTRATO'       AS entidade, 'FORTE'       AS natureza, 'DOMINIO' AS camada UNION ALL
    SELECT 6  AS ordem, 'MENSALIDADE'    AS entidade, 'FORTE'       AS natureza, 'DOMINIO' AS camada UNION ALL
    SELECT 7  AS ordem, 'PAGAMENTO'      AS entidade, 'FORTE'       AS natureza, 'DOMINIO' AS camada UNION ALL
    SELECT 8  AS ordem, 'ACESSO'         AS entidade, 'EVENTO'      AS natureza, 'DOMINIO' AS camada UNION ALL
    SELECT 9  AS ordem, 'TURMA'          AS entidade, 'FORTE'       AS natureza, 'DOMINIO' AS camada UNION ALL
    SELECT 10 AS ordem, 'RESERVA_TURMA'  AS entidade, 'ASSOCIATIVA' AS natureza, 'DOMINIO' AS camada UNION ALL
    SELECT 11 AS ordem, 'USUARIO'        AS entidade, 'FORTE'       AS natureza, 'DOMINIO' AS camada UNION ALL
    SELECT 12 AS ordem, 'PAPEL'          AS entidade, 'FORTE'       AS natureza, 'DOMINIO' AS camada UNION ALL
    SELECT 13 AS ordem, 'USUARIO_PAPEL'  AS entidade, 'ASSOCIATIVA' AS natureza, 'DOMINIO' AS camada
),
catalogo_relacionamentos_conceituais AS (
    SELECT 'R1'  AS codigo, 'UNIDADE'     AS origem, 'ALUNO'       AS destino, '1 : 0..N' AS cardinalidade, NULL            AS entidade_associativa UNION ALL
    SELECT 'R2'  AS codigo, 'UNIDADE'     AS origem, 'COLABORADOR' AS destino, '1 : 0..N' AS cardinalidade, NULL            AS entidade_associativa UNION ALL
    SELECT 'R3'  AS codigo, 'UNIDADE'     AS origem, 'CONTRATO'    AS destino, '1 : 0..N' AS cardinalidade, NULL            AS entidade_associativa UNION ALL
    SELECT 'R4'  AS codigo, 'PLANO'       AS origem, 'CONTRATO'    AS destino, '1 : 0..N' AS cardinalidade, NULL            AS entidade_associativa UNION ALL
    SELECT 'R5'  AS codigo, 'ALUNO'       AS origem, 'CONTRATO'    AS destino, '1 : 0..N' AS cardinalidade, NULL            AS entidade_associativa UNION ALL
    SELECT 'R6'  AS codigo, 'CONTRATO'    AS origem, 'MENSALIDADE' AS destino, '1 : 0..N' AS cardinalidade, NULL            AS entidade_associativa UNION ALL
    SELECT 'R7'  AS codigo, 'MENSALIDADE' AS origem, 'PAGAMENTO'   AS destino, '1 : 0..N' AS cardinalidade, NULL            AS entidade_associativa UNION ALL
    SELECT 'R8'  AS codigo, 'ALUNO'       AS origem, 'ACESSO'      AS destino, '1 : 0..N' AS cardinalidade, NULL            AS entidade_associativa UNION ALL
    SELECT 'R9'  AS codigo, 'COLABORADOR' AS origem, 'TURMA'       AS destino, '1 : 0..N' AS cardinalidade, NULL            AS entidade_associativa UNION ALL
    SELECT 'R10' AS codigo, 'UNIDADE'     AS origem, 'TURMA'       AS destino, '1 : 0..N' AS cardinalidade, NULL            AS entidade_associativa UNION ALL
    SELECT 'R11' AS codigo, 'ALUNO'       AS origem, 'TURMA'       AS destino, 'N : N'    AS cardinalidade, 'RESERVA_TURMA' AS entidade_associativa UNION ALL
    SELECT 'R12' AS codigo, 'USUARIO'     AS origem, 'PAPEL'       AS destino, 'N : N'    AS cardinalidade, 'USUARIO_PAPEL' AS entidade_associativa UNION ALL
    SELECT 'R13' AS codigo, 'UNIDADE'     AS origem, 'USUARIO'     AS destino, '1 : 0..N' AS cardinalidade, NULL            AS entidade_associativa
)
SELECT
    'INV-MC-01: 13 entidades de dominio' AS criterio_aceite,
    COUNT(*) AS valor_encontrado,
    13 AS valor_esperado,
    CASE WHEN COUNT(*) = 13 THEN 'PASS' ELSE 'FAIL' END AS resultado
FROM catalogo_entidades_conceituais
UNION ALL
SELECT
    'INV-MC-02: 13 relacionamentos com cardinalidades (R1..R13)' AS criterio_aceite,
    COUNT(*) AS valor_encontrado,
    13 AS valor_esperado,
    CASE WHEN COUNT(*) = 13 AND SUM(CASE WHEN cardinalidade IS NOT NULL THEN 1 ELSE 0 END) = 13 THEN 'PASS' ELSE 'FAIL' END AS resultado
FROM catalogo_relacionamentos_conceituais
UNION ALL
SELECT
    'INV-MC-03: RESERVA_TURMA e USUARIO_PAPEL explicitas como associativas' AS criterio_aceite,
    COUNT(*) AS valor_encontrado,
    2 AS valor_esperado,
    CASE WHEN COUNT(*) = 2 THEN 'PASS' ELSE 'FAIL' END AS resultado
FROM catalogo_entidades_conceituais
WHERE natureza = 'ASSOCIATIVA'
  AND entidade IN ('RESERVA_TURMA', 'USUARIO_PAPEL')
UNION ALL
SELECT
    'INV-MC-04: Nenhuma tabela tecnica (AUDITORIA_LOG, CONTADOR_DOCUMENTO) no conceitual' AS criterio_aceite,
    COUNT(*) AS valor_encontrado,
    0 AS valor_esperado,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS resultado
FROM catalogo_entidades_conceituais
WHERE entidade IN ('AUDITORIA_LOG', 'CONTADOR_DOCUMENTO')
   OR camada <> 'DOMINIO';
