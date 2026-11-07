-- ============================================================================
-- Kaizen ERP - Testes de Integridade e Validação do Núcleo de Cadastro
-- ============================================================================

-- 1. Verificação das tabelas criadas no catálogo
SELECT table_name, engine, table_collation 
FROM information_schema.tables 
WHERE table_name IN ('UNIDADE', 'CONTADOR_DOCUMENTO', 'PAPEL', 'USUARIO', 'USUARIO_PAPEL', 'ALUNO', 'COLABORADOR');

-- 2. Verificação de constraints de unicidade compostas
SELECT table_name, constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE constraint_name IN ('uq_aluno_unidade', 'uq_colaborador_unidade', 'uq_aluno_cpf', 'uq_usuario_email');

-- 3. Carga básica de testes
INSERT INTO UNIDADE (id_unidade, nome, cnpj, cidade, ativa) 
VALUES (1, 'Unidade Central', '12345678000199', 'São Paulo', 1);

INSERT INTO CONTADOR_DOCUMENTO (tipo, id_unidade, ultimo)
VALUES ('CONTRATO', 1, 0), ('NFSE', 1, 0);

INSERT INTO PAPEL (id_papel, nome)
VALUES (1, 'ADMINISTRADOR'), (2, 'RECEPCAO');

INSERT INTO USUARIO (id_usuario, login, nome, cpf, email, id_unidade, ativo)
VALUES (1, 'admin', 'Administrador do Sistema', '11122233344', 'admin@kaizen.com', 1, 1);

INSERT INTO USUARIO_PAPEL (id_usuario, id_papel)
VALUES (1, 1);

INSERT INTO ALUNO (id_aluno, id_unidade, nome, cpf, email, data_nascimento, ativo)
VALUES (1, 1, 'Aluno Teste', '55566677788', 'aluno@teste.com', '2000-01-01', 1);

INSERT INTO COLABORADOR (id_colaborador, id_unidade, nome, cpf, cargo, ativo)
VALUES (1, 1, 'Instrutor Teste', '99988877766', 'Instrutor', 1);

-- 4. Teste de Violação de Unicidade de CPF em ALUNO (Esperado: Duplicate entry)
-- INSERT INTO ALUNO (id_unidade, nome, cpf, email, data_nascimento)
-- VALUES (1, 'Aluno Duplicado', '55566677788', 'outro@teste.com', '2001-02-02');
