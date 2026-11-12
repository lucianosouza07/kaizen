-- =============================================================================
-- test_views_roles.sql
-- Kaizen BD — Testes Automatizados de Views, Roles e Privilégios Mínimos (BK-DB-08)
-- SGBD: MySQL Server 8.0.46 / Dialeto MySQL 8.0 (InnoDB, utf8mb4_0900_ai_ci)
-- =============================================================================

USE kaizen;

SET NAMES utf8mb4;
SET character_set_client = utf8mb4;
SET SESSION sql_mode = 'ONLY_FULL_GROUP_BY,STRICT_ALL_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- =============================================================================
-- SEÇÃO 1: AUDITORIA DE METADADOS NO INFORMATION_SCHEMA
-- =============================================================================

SELECT 'AUDITORIA DE METADADOS: VISÕES' AS status;

SELECT table_name AS nome_visao,
       is_updatable,
       check_option
  FROM information_schema.views
 WHERE table_schema = 'kaizen'
   AND table_name IN (
     'vw_inadimplentes',
     'vw_fluxo_caixa',
     'vw_ocupacao_turma',
     'vw_aluno_financeiro',
     'vw_auditoria_resumo'
   )
 ORDER BY table_name;

-- =============================================================================
-- SEÇÃO 2: INFRAESTRUTURA DE TESTES AUTOMATIZADOS (HARNESS)
-- =============================================================================

DROP TABLE IF EXISTS _resultado_teste_views_roles;
CREATE TEMPORARY TABLE _resultado_teste_views_roles (
  id_teste   INT AUTO_INCREMENT PRIMARY KEY,
  historia   VARCHAR(50),
  objeto     VARCHAR(50),
  descricao  VARCHAR(150),
  resultado  VARCHAR(10),
  detalhes   VARCHAR(255)
);

DROP PROCEDURE IF EXISTS _sp_assert_vr;
DELIMITER $$
CREATE PROCEDURE _sp_assert_vr(
  IN p_historia  VARCHAR(50),
  IN p_objeto    VARCHAR(50),
  IN p_descricao VARCHAR(150),
  IN p_condicao  BOOLEAN,
  IN p_detalhes  VARCHAR(255)
)
BEGIN
  INSERT INTO _resultado_teste_views_roles (historia, objeto, descricao, resultado, detalhes)
  VALUES (
    p_historia,
    p_objeto,
    p_descricao,
    IF(p_condicao, 'PASS', 'FAIL'),
    IF(p_condicao, 'OK', p_detalhes)
  );
END$$
DELIMITER ;

-- =============================================================================
-- SEÇÃO 3: PRÉ-REQUISITOS BLOQUEANTES (FOUNDATIONAL)
-- =============================================================================

-- Validação de existência das 15 tabelas-base
SELECT COUNT(*) INTO @v_total_tabelas
  FROM information_schema.tables
 WHERE table_schema = 'kaizen'
   AND table_type = 'BASE TABLE'
   AND table_name IN (
     'UNIDADE', 'PAPEL', 'USUARIO', 'USUARIO_PAPEL', 'ALUNO', 'COLABORADOR',
     'PLANO', 'CONTRATO', 'MENSALIDADE', 'PAGAMENTO', 'TURMA', 'RESERVA_TURMA',
     'AUDITORIA_LOG', 'CONTADOR_DOCUMENTO'
   );

CALL _sp_assert_vr(
  'FOUNDATIONAL',
  'TABELAS_BASE',
  'Existência das tabelas relacionais do núcleo Kaizen',
  @v_total_tabelas >= 14,
  CONCAT('Encontradas ', @v_total_tabelas, ' tabelas')
);

-- Validação de existência das 5 rotinas dependentes
SELECT COUNT(*) INTO @v_total_rotinas
  FROM information_schema.routines
 WHERE routine_schema = 'kaizen'
   AND routine_name IN (
     'fn_valor_devido', 'fn_ocupacao_turma',
     'sp_gerar_mensalidades', 'sp_registrar_pagamento', 'sp_anonimizar_aluno'
   );

CALL _sp_assert_vr(
  'FOUNDATIONAL',
  'ROTINAS',
  'Existência das rotinas procedurais de apoio',
  @v_total_rotinas >= 5,
  CONCAT('Encontradas ', @v_total_rotinas, ' rotinas')
);

-- =============================================================================
-- SEÇÃO 4: MASSA DE DADOS PARA TESTES ISOLADOS (FIXTURES)
-- =============================================================================

-- Unidade de Teste (ID: 981)
INSERT INTO UNIDADE (id_unidade, nome, cnpj, cidade, ativa)
VALUES (981, 'Unidade Teste Views Roles', '88999000000199', 'Salvador', 1)
ON DUPLICATE KEY UPDATE nome = VALUES(nome);

-- Papéis de Domínio no Catálogo
INSERT INTO PAPEL (id_papel, nome)
VALUES 
  (981, 'GESTOR_TESTE'),
  (982, 'OPERADOR_TESTE')
ON DUPLICATE KEY UPDATE nome = VALUES(nome);

-- Usuários e Vínculos
INSERT INTO USUARIO (id_usuario, id_unidade, login, senha_hash, nome, email, ativo)
VALUES (981, 981, 'operador.views', 'hash_teste_views', 'Operador da Silva', 'operador.views@kaizen.local', 1)
ON DUPLICATE KEY UPDATE nome = VALUES(nome);

INSERT INTO USUARIO_PAPEL (id_usuario, id_papel)
VALUES (981, 981), (981, 982)
ON DUPLICATE KEY UPDATE atribuido_em = CURRENT_TIMESTAMP;

-- Plano de Teste
INSERT INTO PLANO (id_plano, nome, periodicidade_meses, valor_mensal, carencia_dias, multa_percentual, ativo)
VALUES (981, 'Plano Teste Views', 1, 150.00, 5, 2.00, 1)
ON DUPLICATE KEY UPDATE nome = VALUES(nome);

-- Alunos de Teste (CPFs conhecidos para validação de mascaramento)
INSERT INTO ALUNO (id_aluno, id_unidade, nome, cpf, email, data_nascimento, consentimento_lgpd_em, ativo)
VALUES
  (981, 981, 'Aluno Adimplente',   '12345678901', 'aluno.adimp@kaizen.local',   '1996-05-10', NOW(), 1),
  (982, 981, 'Aluno Inadimplente', '98765432199', 'aluno.inadimp@kaizen.local', '1998-08-20', NOW(), 1)
ON DUPLICATE KEY UPDATE nome = VALUES(nome);

-- Contratos
DELETE FROM CONTRATO WHERE id_unidade = 981;
INSERT INTO CONTRATO (id_contrato, numero, id_aluno, id_unidade, id_plano, data_inicio, data_fim, dia_vencimento, valor_mensal, status)
VALUES
  (98101, 'CTR-2026-981001', 981, 981, 981, '2026-01-01', NULL, 10, 150.00, 'ATIVO'),
  (98102, 'CTR-2026-981002', 982, 981, 981, '2026-01-01', NULL, 10, 150.00, 'ATIVO');

-- Mensalidades (uma vencida para o inadimplente e uma paga para o adimplente)
DELETE FROM PAGAMENTO WHERE id_mensalidade IN (98101, 98102, 98103);
DELETE FROM MENSALIDADE WHERE id_contrato IN (98101, 98102);

INSERT INTO MENSALIDADE (id_mensalidade, id_contrato, competencia, vencimento, valor, juros, multa, desconto, status)
VALUES
  (98101, 98101, '2026-01', '2026-01-10', 150.00, 0.00, 0.00, 0.00, 'PAGA'),
  (98102, 98102, '2026-01', '2026-01-10', 150.00, 10.00, 5.00, 0.00, 'ABERTA');

-- Pagamentos (liquidação de 98101 e um pagamento parcial com estorno em 98102)
INSERT INTO PAGAMENTO (id_pagamento, id_mensalidade, tipo, valor, forma, pago_em, id_externo)
VALUES
  (98101, 98101, 'RECEBIMENTO', 150.00, 'PIX', '2026-01-10 10:00:00', 'EXT-VR-98101'),
  (98102, 98102, 'RECEBIMENTO', 100.00, 'PIX', '2026-01-15 14:00:00', 'EXT-VR-98102-REC'),
  (98103, 98102, 'ESTORNO',      20.00, 'PIX', '2026-01-15 15:30:00', 'EXT-VR-98102-EST');

-- Turma e Reservas
DELETE FROM RESERVA_TURMA WHERE id_turma = 98101;
DELETE FROM TURMA WHERE id_unidade = 981;

INSERT INTO COLABORADOR (id_colaborador, id_unidade, nome, cpf, email, cargo, ativo)
VALUES (981, 981, 'Instrutor Views', '66655544433', 'inst.views@kaizen.local', 'INSTRUTOR', 1)
ON DUPLICATE KEY UPDATE nome = VALUES(nome);

INSERT INTO TURMA (id_turma, id_unidade, id_instrutor, modalidade, sala, capacidade, inicio, fim, dias_semana, ativa)
VALUES (98101, 981, 981, 'CrossFit', 'Sala Principal', 10, '08:00:00', '09:00:00', 'SEG,QUA,SEX', 1);

INSERT INTO RESERVA_TURMA (id_turma, id_unidade, id_aluno, status)
VALUES
  (98101, 981, 981, 'CONFIRMADA'),
  (98101, 981, 982, 'CONFIRMADA');

-- Registro Técnico de Auditoria
DELETE FROM AUDITORIA_LOG WHERE tabela = 'aluno' AND chave_pk = '981';
INSERT INTO AUDITORIA_LOG (id_log, tabela, operacao, chave_pk, antes, depois, conta_mysql, ocorrido_em)
VALUES (
  98101,
  'aluno',
  'UPDATE',
  '981',
  JSON_OBJECT('nome', 'Aluno Adimplente', 'ativo', 1),
  JSON_OBJECT('nome', 'Aluno Adimplente Alterado', 'ativo', 1),
  'operador.views@localhost',
  CURRENT_TIMESTAMP(3)
);

-- =============================================================================
-- SEÇÃO 5: EXECUÇÃO DOS TESTES POR HISTÓRIA DE USUÁRIO
-- =============================================================================

-- -----------------------------------------------------------------------------
-- USER STORY 1: DADOS FINANCEIROS, INADIMPLÊNCIA E MASCARAMENTO LGPD (P1 - MVP)
-- -----------------------------------------------------------------------------

-- Teste 1.1: vw_inadimplentes retorna o aluno 982 com status em aberto vencido
SELECT COUNT(*) INTO @v_qtd_inad
  FROM vw_inadimplentes
 WHERE id_unidade = 981 AND id_aluno = 982;

CALL _sp_assert_vr(
  'US1',
  'vw_inadimplentes',
  'Identificação de aluno com título vencido em aberto',
  @v_qtd_inad = 1,
  CONCAT('Esperado 1 inadimplente, encontrado ', @v_qtd_inad)
);

-- Teste 1.2: vw_inadimplentes projeta CPF mascarado no formato ***.199
SELECT cpf_mascarado INTO @v_cpf_masc_inad
  FROM vw_inadimplentes
 WHERE id_unidade = 981 AND id_aluno = 982;

CALL _sp_assert_vr(
  'US1',
  'vw_inadimplentes',
  'Mascaramento regulatório LGPD de CPF (***.XXX)',
  @v_cpf_masc_inad = '***.199',
  CONCAT('CPF retornado: ', IFNULL(@v_cpf_masc_inad, 'NULL'))
);

-- Teste 1.3: vw_inadimplentes apura dias de atraso superiores a zero
SELECT dias_atraso INTO @v_dias_atraso
  FROM vw_inadimplentes
 WHERE id_unidade = 981 AND id_aluno = 982;

CALL _sp_assert_vr(
  'US1',
  'vw_inadimplentes',
  'Cálculo dinâmico de dias em atraso',
  @v_dias_atraso > 0,
  CONCAT('Dias apurados: ', @v_dias_atraso)
);

-- Teste 1.4: vw_aluno_financeiro totaliza faturas e mascaramento sob ONLY_FULL_GROUP_BY
SELECT cpf_mascarado, qtd_mensalidades, saldo_devido
  INTO @v_cpf_masc_af, @v_qtd_mens_af, @v_saldo_af
  FROM vw_aluno_financeiro
 WHERE id_unidade = 981 AND id_aluno = 982;

CALL _sp_assert_vr(
  'US1',
  'vw_aluno_financeiro',
  'Consolidação cadastral/financeira e mascaramento sob ONLY_FULL_GROUP_BY',
  @v_cpf_masc_af = '***.199' AND @v_qtd_mens_af >= 1,
  CONCAT('CPF: ', @v_cpf_masc_af, ', Faturas: ', @v_qtd_mens_af, ', Saldo: ', @v_saldo_af)
);

-- -----------------------------------------------------------------------------
-- USER STORY 2: SEGREGAÇÃO DE FUNÇÕES E POLÍTICA DE PRIVILÉGIO MÍNIMO (P2)
-- -----------------------------------------------------------------------------

-- Teste 2.1: Validação da existência das 6 roles no banco
SELECT COUNT(*) INTO @v_roles_count
  FROM mysql.user
 WHERE user IN ('rl_dba', 'rl_gerente', 'rl_recepcao', 'rl_financeiro', 'rl_instrutor', 'rl_leitura')
   AND account_locked = 'Y';

CALL _sp_assert_vr(
  'US2',
  'ROLES',
  'Criação das 6 roles de segurança no catálogo',
  @v_roles_count = 6,
  CONCAT('Roles encontradas: ', @v_roles_count)
);

-- Teste 2.2: Concessões de SELECT em visões para rl_financeiro
SELECT COUNT(*) INTO @v_grants_fin_views
  FROM information_schema.table_privileges
 WHERE grantee LIKE "'rl_financeiro'%"
   AND table_schema = 'kaizen'
   AND table_name IN ('vw_aluno_financeiro', 'vw_inadimplentes', 'vw_fluxo_caixa')
   AND privilege_type = 'SELECT';

CALL _sp_assert_vr(
  'US2',
  'GRANTS_ROLES',
  'Concessão de SELECT em visões financeiras para rl_financeiro',
  @v_grants_fin_views = 3,
  CONCAT('Grants de SELECT encontrados: ', @v_grants_fin_views)
);

-- Teste 2.3: Bloqueio de tabelas-base para perfis operacionais
SELECT COUNT(*) INTO @v_grants_indevidos
  FROM information_schema.table_privileges
 WHERE grantee IN ("'rl_gerente'@'%'", "'rl_recepcao'@'%'", "'rl_financeiro'@'%'", "'rl_instrutor'@'%'", "'rl_leitura'@'%'")
   AND table_schema = 'kaizen'
   AND table_name IN (
     'UNIDADE', 'PAPEL', 'USUARIO', 'USUARIO_PAPEL', 'ALUNO', 'COLABORADOR',
     'PLANO', 'CONTRATO', 'MENSALIDADE', 'PAGAMENTO', 'TURMA', 'RESERVA_TURMA',
     'AUDITORIA_LOG', 'CONTADOR_DOCUMENTO'
   );

CALL _sp_assert_vr(
  'US2',
  'PRIVILEGIO_MINIMO',
  'Ausência de concessão direta em tabelas-base para perfis operacionais',
  @v_grants_indevidos = 0,
  CONCAT('Grants diretos encontrados em tabelas-base: ', @v_grants_indevidos)
);

-- Teste 2.4: Execução controlada de procedures/functions para rl_financeiro
SELECT COUNT(*) INTO @v_routines_fin
  FROM information_schema.routine_privileges
 WHERE grantee LIKE "'rl_financeiro'%"
   AND routine_schema = 'kaizen'
   AND routine_name IN ('sp_gerar_mensalidades', 'sp_registrar_pagamento', 'fn_valor_devido')
   AND privilege_type = 'EXECUTE';

CALL _sp_assert_vr(
  'US2',
  'ROUTINE_GRANTS',
  'Concessão de EXECUTE para rl_financeiro em rotinas de faturamento e baixa',
  @v_routines_fin = 3,
  CONCAT('Rotinas autorizadas para rl_financeiro: ', @v_routines_fin)
);

-- -----------------------------------------------------------------------------
-- USER STORY 3: BLINDAGEM E IMUTABILIDADE DA TRILHA DE AUDITORIA (P3)
-- -----------------------------------------------------------------------------

-- Teste 3.1: Consulta a vw_auditoria_resumo com resolução de operador e papéis
SELECT COUNT(*), MAX(usuario), MAX(papeis)
  INTO @v_qtd_audit, @v_usr_audit, @v_pap_audit
  FROM vw_auditoria_resumo
 WHERE id_log = 98101;

CALL _sp_assert_vr(
  'US3',
  'vw_auditoria_resumo',
  'Resolução analítica de operador e concatenação de papéis sob ONLY_FULL_GROUP_BY',
  @v_qtd_audit = 1 AND @v_usr_audit = 'Operador da Silva' AND @v_pap_audit LIKE '%GESTOR_TESTE%',
  CONCAT('Operador: ', IFNULL(@v_usr_audit,'NULL'), ', Papéis: ', IFNULL(@v_pap_audit,'NULL'))
);

-- Teste 3.2: Imutabilidade de AUDITORIA_LOG: sem UPDATE/DELETE para operacionais
SELECT COUNT(*) INTO @v_audit_operacional_mutavel
  FROM information_schema.table_privileges
 WHERE grantee IN ("'rl_gerente'@'%'", "'rl_recepcao'@'%'", "'rl_financeiro'@'%'", "'rl_instrutor'@'%'", "'rl_leitura'@'%'")
   AND table_schema = 'kaizen'
   AND table_name = 'auditoria_log'
   AND privilege_type IN ('UPDATE', 'DELETE');

CALL _sp_assert_vr(
  'US3',
  'AUDITORIA_LOG',
  'Imutabilidade da trilha forense (sem UPDATE/DELETE para operacionais)',
  @v_audit_operacional_mutavel = 0,
  CONCAT('Grants de alteração em auditoria_log encontrados: ', @v_audit_operacional_mutavel)
);

-- Teste 3.3: Exclusividade de leitura de vw_auditoria_resumo para rl_dba
SELECT COUNT(*) INTO @v_audit_resumo_grants
  FROM information_schema.table_privileges
 WHERE table_schema = 'kaizen'
   AND table_name = 'vw_auditoria_resumo'
   AND grantee NOT LIKE "'rl_dba'%";

CALL _sp_assert_vr(
  'US3',
  'vw_auditoria_resumo',
  'Restrição de acesso a vw_auditoria_resumo exclusivamente para rl_dba',
  @v_audit_resumo_grants = 0,
  CONCAT('Grants não-DBA em vw_auditoria_resumo: ', @v_audit_resumo_grants)
);

-- -----------------------------------------------------------------------------
-- USER STORY 4: VISÕES OPERACIONAIS DE FLUXO DE CAIXA E OCUPAÇÃO (P4)
-- -----------------------------------------------------------------------------

-- Teste 4.1: vw_fluxo_caixa apura valor líquido (recebimento menos estorno)
SELECT valor_liquido, qtd_lancamentos
  INTO @v_liq_caixa, @v_qtd_caixa
  FROM vw_fluxo_caixa
 WHERE id_unidade = 981 AND dia = '2026-01-15' AND competencia = '2026-01';

CALL _sp_assert_vr(
  'US4',
  'vw_fluxo_caixa',
  'Apuração de fluxo líquido (100 recebimento - 20 estorno = 80 líquido)',
  @v_liq_caixa = 80.00 AND @v_qtd_caixa = 2,
  CONCAT('Líquido apurado: ', IFNULL(@v_liq_caixa,'NULL'), ', Lançamentos: ', IFNULL(@v_qtd_caixa,'NULL'))
);

-- Teste 4.2: vw_ocupacao_turma calcula confirmados e vagas livres
SELECT capacidade, confirmados, vagas_livres
  INTO @v_cap_t, @v_conf_t, @v_vagas_t
  FROM vw_ocupacao_turma
 WHERE id_unidade = 981 AND id_turma = 98101;

CALL _sp_assert_vr(
  'US4',
  'vw_ocupacao_turma',
  'Cálculo em tempo real de ocupação confirmada e vagas livres remanescentes',
  @v_cap_t = 10 AND @v_conf_t = 2 AND @v_vagas_t = 8,
  CONCAT('Capacidade: ', @v_cap_t, ', Confirmados: ', @v_conf_t, ', Vagas: ', @v_vagas_t)
);

-- =============================================================================
-- SEÇÃO 6: RELATÓRIO CONSOLIDADO DE EXECUÇÃO DOS TESTES
-- =============================================================================

SELECT 'RELATÓRIO CONSOLIDADO: TESTES DE VIEWS E ROLES' AS painel;

SELECT historia,
       objeto,
       descricao,
       resultado,
       detalhes
  FROM _resultado_teste_views_roles
 ORDER BY id_teste;

SELECT resultado,
       COUNT(*) AS total_testes
  FROM _resultado_teste_views_roles
 GROUP BY resultado;

-- Fim do script de testes
