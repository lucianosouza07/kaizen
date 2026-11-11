-- =============================================================================
-- 06_views_roles.sql
-- Kaizen BD — Módulo de Views, Roles e Privilégios Mínimos (BK-DB-08)
-- SGBD: MySQL Server 8.0.46 / Dialeto MySQL 8.0 (InnoDB, utf8mb4_0900_ai_ci)
-- =============================================================================

USE kaizen;

SET NAMES utf8mb4;
SET character_set_client = utf8mb4;
SET SESSION sql_mode = 'ONLY_FULL_GROUP_BY,STRICT_ALL_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- =============================================================================
-- PARTE 1: VISÕES DE NEGÓCIO (5 VIEWS)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1.1 VISÃO: vw_inadimplentes
-- Finalidade: Consulta de cobrança por unidade, listando mensalidades abertas
--             ou parciais vencidas, saldo devido e CPF mascarado (LGPD).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_inadimplentes AS
SELECT c.id_unidade,
       a.id_aluno,
       a.nome,
       CONCAT('***.', RIGHT(a.cpf, 3)) AS cpf_mascarado,
       m.competencia,
       m.vencimento,
       m.valor + m.juros + m.multa - m.desconto AS valor_nominal,
       fn_valor_devido(m.id_mensalidade) AS saldo_devido,
       DATEDIFF(CURDATE(), m.vencimento) AS dias_atraso
  FROM mensalidade m
  JOIN contrato c ON c.id_contrato = m.id_contrato
  JOIN aluno a ON a.id_aluno = c.id_aluno AND a.id_unidade = c.id_unidade
 WHERE m.status IN ('ABERTA','PARCIAL')
   AND m.vencimento < CURDATE();

-- -----------------------------------------------------------------------------
-- 1.2 VISÃO: vw_fluxo_caixa
-- Finalidade: Balanço financeiro diário por unidade e competência, apurando
--             o valor líquido monetário (recebimentos - estornos).
--             Em conformidade estrita com ONLY_FULL_GROUP_BY.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_fluxo_caixa AS
SELECT c.id_unidade,
       DATE(p.pago_em) AS dia,
       m.competencia,
       SUM(CASE WHEN p.tipo = 'RECEBIMENTO' THEN p.valor ELSE -p.valor END) AS valor_liquido,
       COUNT(*) AS qtd_lancamentos
  FROM pagamento p
  JOIN mensalidade m ON m.id_mensalidade = p.id_mensalidade
  JOIN contrato c ON c.id_contrato = m.id_contrato
 GROUP BY c.id_unidade, DATE(p.pago_em), m.competencia;

-- -----------------------------------------------------------------------------
-- 1.3 VISÃO: vw_ocupacao_turma
-- Finalidade: Ocupação operacional de turmas em tempo real, calculando vagas
--             confirmadas (via fn_ocupacao_turma) e saldo de vagas livres.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_ocupacao_turma AS
SELECT t.id_unidade,
       t.id_turma,
       t.modalidade,
       t.sala,
       t.inicio,
       t.fim,
       t.capacidade,
       fn_ocupacao_turma(t.id_turma) AS confirmados,
       GREATEST(t.capacidade - fn_ocupacao_turma(t.id_turma), 0) AS vagas_livres
  FROM turma t;

-- -----------------------------------------------------------------------------
-- 1.4 VISÃO: vw_aluno_financeiro
-- Finalidade: Ficha cadastral e financeira agregada do aluno com proteção de
--             dados (CPF mascarado), total de títulos e saldo devedor acumulado.
--             Em conformidade estrita com ONLY_FULL_GROUP_BY.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_aluno_financeiro AS
SELECT a.id_unidade,
       a.id_aluno,
       a.nome,
       CONCAT('***.', RIGHT(a.cpf, 3)) AS cpf_mascarado,
       c.numero AS numero_contrato,
       c.status AS status_contrato,
       COUNT(m.id_mensalidade) AS qtd_mensalidades,
       COALESCE(SUM(fn_valor_devido(m.id_mensalidade)), 0) AS saldo_devido
  FROM aluno a
  LEFT JOIN contrato c ON c.id_aluno = a.id_aluno
                      AND c.id_unidade = a.id_unidade
                      AND c.status = 'ATIVO'
  LEFT JOIN mensalidade m ON m.id_contrato = c.id_contrato
 GROUP BY a.id_unidade, a.id_aluno, a.nome, a.cpf, c.numero, c.status;

-- -----------------------------------------------------------------------------
-- 1.5 VISÃO: vw_auditoria_resumo
-- Finalidade: Resumo analítico de trilha forense para governança e auditoria,
--             com resolução do login para nome de usuário e agregação de papéis.
--             Em conformidade estrita com ONLY_FULL_GROUP_BY.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_auditoria_resumo AS
SELECT l.id_log,
       l.tabela,
       l.operacao,
       l.chave_pk,
       l.conta_mysql,
       l.ocorrido_em,
       u.nome AS usuario,
       GROUP_CONCAT(p.nome ORDER BY p.nome SEPARATOR ',') AS papeis
  FROM auditoria_log l
  LEFT JOIN usuario u ON u.login = REPLACE(SUBSTRING_INDEX(l.conta_mysql, '@', 1), CHAR(39), '')
  LEFT JOIN usuario_papel up ON up.id_usuario = u.id_usuario
  LEFT JOIN papel p ON p.id_papel = up.id_papel
 GROUP BY l.id_log, l.tabela, l.operacao, l.chave_pk, l.conta_mysql,
          l.ocorrido_em, u.nome;

-- =============================================================================
-- PARTE 2: DEFINIÇÃO DE PAPÉIS (ROLES) E POLÍTICA DE PRIVILÉGIO MÍNIMO
-- =============================================================================

-- Criação dos 6 papéis de segurança padronizados
CREATE ROLE IF NOT EXISTS 'rl_dba';
CREATE ROLE IF NOT EXISTS 'rl_gerente';
CREATE ROLE IF NOT EXISTS 'rl_recepcao';
CREATE ROLE IF NOT EXISTS 'rl_financeiro';
CREATE ROLE IF NOT EXISTS 'rl_instrutor';
CREATE ROLE IF NOT EXISTS 'rl_leitura';

-- -----------------------------------------------------------------------------
-- 2.1 CONCESSÕES: rl_dba (Administração, Auditoria e Governança Técnica)
-- -----------------------------------------------------------------------------
GRANT ALL PRIVILEGES ON kaizen.* TO 'rl_dba';
GRANT ALL PRIVILEGES ON kaizen.auditoria_log TO 'rl_dba';
GRANT SELECT ON kaizen.vw_auditoria_resumo TO 'rl_dba';
GRANT EXECUTE ON PROCEDURE kaizen.sp_anonimizar_aluno TO 'rl_dba';

-- -----------------------------------------------------------------------------
-- 2.2 CONCESSÕES: rl_gerente (Gestão Operacional e Tática de Unidade)
-- -----------------------------------------------------------------------------
GRANT SELECT ON kaizen.vw_aluno_financeiro TO 'rl_gerente';
GRANT SELECT ON kaizen.vw_inadimplentes   TO 'rl_gerente';
GRANT SELECT ON kaizen.vw_fluxo_caixa     TO 'rl_gerente';
GRANT SELECT ON kaizen.vw_ocupacao_turma  TO 'rl_gerente';

-- -----------------------------------------------------------------------------
-- 2.3 CONCESSÕES: rl_recepcao (Atendimento Balcão e Lotação de Salas)
-- -----------------------------------------------------------------------------
GRANT SELECT ON kaizen.vw_ocupacao_turma  TO 'rl_recepcao';

-- -----------------------------------------------------------------------------
-- 2.4 CONCESSÕES: rl_financeiro (Faturamento, Liquidação e Conciliação Caixa)
-- -----------------------------------------------------------------------------
GRANT SELECT ON kaizen.vw_aluno_financeiro TO 'rl_financeiro';
GRANT SELECT ON kaizen.vw_inadimplentes   TO 'rl_financeiro';
GRANT SELECT ON kaizen.vw_fluxo_caixa     TO 'rl_financeiro';
GRANT EXECUTE ON PROCEDURE kaizen.sp_gerar_mensalidades  TO 'rl_financeiro';
GRANT EXECUTE ON PROCEDURE kaizen.sp_registrar_pagamento TO 'rl_financeiro';
GRANT EXECUTE ON FUNCTION  kaizen.fn_valor_devido        TO 'rl_financeiro';

-- -----------------------------------------------------------------------------
-- 2.5 CONCESSÕES: rl_instrutor (Acompanhamento Pedagógico e Grade de Turmas)
-- -----------------------------------------------------------------------------
GRANT SELECT ON kaizen.vw_ocupacao_turma  TO 'rl_instrutor';

-- -----------------------------------------------------------------------------
-- 2.6 CONCESSÕES: rl_leitura (Auditoria Externa e Consulta Restrita de Cobrança)
-- -----------------------------------------------------------------------------
GRANT SELECT ON kaizen.vw_inadimplentes   TO 'rl_leitura';

-- -----------------------------------------------------------------------------
-- NOTA DE SEGURANÇA E IMUTABILIDADE:
-- Nenhum privilégio direto (SELECT, INSERT, UPDATE, DELETE) é concedido sobre
-- as 13 tabelas-base de domínio para os perfis operacionais (rl_gerente, rl_recepcao,
-- rl_financeiro, rl_instrutor, rl_leitura).
-- Da mesma forma, nenhum perfil operacional recebe UPDATE ou DELETE sobre a
-- tabela técnica AUDITORIA_LOG, garantindo integridade forense indelével.
-- =============================================================================
