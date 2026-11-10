-- ============================================================================
-- Kaizen ERP - Testes de Integridade e Validação do Núcleo de Cadastro
-- Dialeto: MySQL 8.0.46
-- ============================================================================

SET NAMES utf8mb4;

-- ----------------------------------------------------------------------------
-- 1. Verificação das tabelas criadas no catálogo
-- ----------------------------------------------------------------------------
SELECT table_name, engine, table_collation 
FROM information_schema.tables 
WHERE table_schema = DATABASE()
  AND table_name IN ('UNIDADE', 'CONTADOR_DOCUMENTO', 'PAPEL', 'USUARIO', 'USUARIO_PAPEL', 'ALUNO', 'COLABORADOR');

-- ----------------------------------------------------------------------------
-- 2. Verificação de constraints de unicidade e integridade
-- ----------------------------------------------------------------------------
SELECT table_name, constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_schema = DATABASE()
  AND constraint_name IN (
    'uq_unidade_cnpj', 'ck_unidade_cnpj',
    'fk_contador_unidade',
    'uq_papel_nome',
    'uq_usuario_login', 'uq_usuario_cpf', 'uq_usuario_email', 'fk_usuario_unidade',
    'fk_usuario_papel_usuario', 'fk_usuario_papel_papel',
    'uq_aluno_cpf', 'uq_aluno_email', 'uq_aluno_unidade', 'ck_aluno_cpf', 'fk_aluno_unidade',
    'uq_colaborador_cpf', 'uq_colaborador_unidade', 'ck_colaborador_cpf', 'fk_colaborador_unidade'
  );

-- ----------------------------------------------------------------------------
-- 3. Carga básica e validação funcional de inserção
-- ----------------------------------------------------------------------------
-- US1: UNIDADE, CONTADOR_DOCUMENTO e PAPEL
INSERT INTO UNIDADE (id_unidade, nome, cnpj, cidade, ativa) 
VALUES (1, 'Unidade Central', '12345678000199', 'São Paulo', 1);

INSERT INTO CONTADOR_DOCUMENTO (tipo, id_unidade, ultimo)
VALUES ('CONTRATO', 1, 0), ('NFSE', 1, 0);

INSERT INTO PAPEL (id_papel, nome)
VALUES (1, 'ADMINISTRADOR'), (2, 'RECEPCAO');

-- US2: USUARIO e USUARIO_PAPEL
INSERT INTO USUARIO (id_usuario, login, nome, cpf, email, id_unidade, ativo)
VALUES (1, 'admin', 'Administrador do Sistema', '11122233344', 'admin@kaizen.com', 1, 1);

INSERT INTO USUARIO_PAPEL (id_usuario, id_papel)
VALUES (1, 1);

-- US3: ALUNO e COLABORADOR
INSERT INTO ALUNO (id_aluno, id_unidade, nome, cpf, email, data_nascimento, consentimento_lgpd_em, ativo)
VALUES (1, 1, 'Aluno Teste', '55566677788', 'aluno@teste.com', '2000-01-01', CURRENT_TIMESTAMP, 1);

INSERT INTO COLABORADOR (id_colaborador, id_unidade, nome, cpf, cargo, ativo)
VALUES (1, 1, 'Instrutor Teste', '99988877766', 'Instrutor', 1);

-- ----------------------------------------------------------------------------
-- 4. Cenários de Testes Negativos e Restrições (Execuções comentadas para teste interativo)
-- ----------------------------------------------------------------------------
-- Cenário A (US1): Violação de formato regex CNPJ em UNIDADE (Esperado: CHECK constraint ck_unidade_cnpj is violated)
-- INSERT INTO UNIDADE (nome, cnpj, cidade) VALUES ('Unidade Invalida', '1234567800019A', 'Rio de Janeiro');

-- Cenário B (US1): Duplicidade de CNPJ em UNIDADE (Esperado: Duplicate entry '12345678000199' for key 'uq_unidade_cnpj')
-- INSERT INTO UNIDADE (nome, cnpj, cidade) VALUES ('Unidade Filial', '12345678000199', 'Campinas');

-- Cenário C (US2): Duplicidade de CPF em USUARIO (Esperado: Duplicate entry for key 'uq_usuario_cpf')
-- INSERT INTO USUARIO (login, nome, cpf, email) VALUES ('outro_login', 'Outro Nome', '11122233344', 'outro@kaizen.com');

-- Cenário D (US2): Teste de ON DELETE CASCADE em USUARIO_PAPEL
-- DELETE FROM USUARIO WHERE id_usuario = 1;
-- SELECT COUNT(*) AS deve_ser_zero FROM USUARIO_PAPEL WHERE id_usuario = 1;

-- Cenário E (US3): Duplicidade de CPF em ALUNO (Esperado: Duplicate entry for key 'uq_aluno_cpf')
-- INSERT INTO ALUNO (id_unidade, nome, cpf, email, data_nascimento) VALUES (1, 'Aluno Duplicado', '55566677788', 'novo@teste.com', '2001-02-02');

-- Cenário F (US3): Violação de formato de CPF com letras em ALUNO (Esperado: CHECK constraint ck_aluno_cpf is violated)
-- INSERT INTO ALUNO (id_unidade, nome, cpf, email, data_nascimento) VALUES (1, 'Aluno Letra', '1112223334A', 'letra@teste.com', '2001-02-02');

-- Cenário G (US3): Violação de formato de CPF em COLABORADOR (Esperado: CHECK constraint ck_colaborador_cpf is violated)
-- INSERT INTO COLABORADOR (id_unidade, nome, cpf, cargo) VALUES (1, 'Colab Letra', '9998887776A', 'Recepcionista');
