-- ============================================================================
-- Kaizen ERP - DDL do Núcleo de Cadastro
-- Dialeto / Engine: MySQL 8.0.46 (InnoDB, utf8mb4, utf8mb4_0900_ai_ci)
-- Tabelas: UNIDADE, CONTADOR_DOCUMENTO, PAPEL, USUARIO, USUARIO_PAPEL,
--          ALUNO, COLABORADOR
-- ============================================================================

SET NAMES utf8mb4;
SET character_set_client = utf8mb4;

-- ----------------------------------------------------------------------------
-- 1. UNIDADE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS UNIDADE (
    id_unidade INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    cnpj CHAR(14) NOT NULL,
    cidade VARCHAR(60) NOT NULL,
    ativa TINYINT(1) NOT NULL DEFAULT 1,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_unidade_cnpj UNIQUE (cnpj),
    CONSTRAINT ck_unidade_cnpj CHECK (cnpj REGEXP '^[0-9]{14}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------------------------------------------------------
-- 2. CONTADOR_DOCUMENTO (Técnica)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CONTADOR_DOCUMENTO (
    tipo VARCHAR(20) NOT NULL,
    id_unidade INT UNSIGNED NOT NULL,
    ultimo INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (tipo, id_unidade),
    CONSTRAINT fk_contador_unidade FOREIGN KEY (id_unidade) REFERENCES UNIDADE(id_unidade) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------------------------------------------------------
-- 3. PAPEL
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PAPEL (
    id_papel INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(30) NOT NULL,
    CONSTRAINT uq_papel_nome UNIQUE (nome)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------------------------------------------------------
-- 4. USUARIO
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS USUARIO (
    id_usuario INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    login VARCHAR(50) NOT NULL,
    nome VARCHAR(100) NOT NULL,
    cpf CHAR(11) NOT NULL,
    email VARCHAR(120) NOT NULL,
    id_unidade INT UNSIGNED NULL,
    ativo TINYINT(1) NOT NULL DEFAULT 1,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_usuario_login UNIQUE (login),
    CONSTRAINT uq_usuario_cpf UNIQUE (cpf),
    CONSTRAINT uq_usuario_email UNIQUE (email),
    CONSTRAINT fk_usuario_unidade FOREIGN KEY (id_unidade) REFERENCES UNIDADE(id_unidade) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------------------------------------------------------
-- 5. USUARIO_PAPEL
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS USUARIO_PAPEL (
    id_usuario INT UNSIGNED NOT NULL,
    id_papel INT UNSIGNED NOT NULL,
    PRIMARY KEY (id_usuario, id_papel),
    CONSTRAINT fk_usuario_papel_usuario FOREIGN KEY (id_usuario) REFERENCES USUARIO(id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_usuario_papel_papel FOREIGN KEY (id_papel) REFERENCES PAPEL(id_papel) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------------------------------------------------------
-- 6. ALUNO
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ALUNO (
    id_aluno INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_unidade INT UNSIGNED NOT NULL,
    nome VARCHAR(100) NOT NULL,
    cpf CHAR(11) NOT NULL,
    email VARCHAR(120) NOT NULL,
    data_nascimento DATE NOT NULL,
    consentimento_lgpd_em TIMESTAMP NULL,
    ativo TINYINT(1) NOT NULL DEFAULT 1,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_aluno_cpf UNIQUE (cpf),
    CONSTRAINT uq_aluno_email UNIQUE (email),
    CONSTRAINT uq_aluno_unidade UNIQUE (id_aluno, id_unidade),
    CONSTRAINT fk_aluno_unidade FOREIGN KEY (id_unidade) REFERENCES UNIDADE(id_unidade) ON DELETE RESTRICT,
    CONSTRAINT ck_aluno_cpf CHECK (cpf REGEXP '^[0-9]{11}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------------------------------------------------------
-- 7. COLABORADOR
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS COLABORADOR (
    id_colaborador INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_unidade INT UNSIGNED NOT NULL,
    nome VARCHAR(100) NOT NULL,
    cpf CHAR(11) NOT NULL,
    cargo VARCHAR(50) NOT NULL,
    ativo TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT uq_colaborador_cpf UNIQUE (cpf),
    CONSTRAINT uq_colaborador_unidade UNIQUE (id_colaborador, id_unidade),
    CONSTRAINT fk_colaborador_unidade FOREIGN KEY (id_unidade) REFERENCES UNIDADE(id_unidade) ON DELETE RESTRICT,
    CONSTRAINT ck_colaborador_cpf CHECK (cpf REGEXP '^[0-9]{11}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
