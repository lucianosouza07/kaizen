# Módulo DDL do Núcleo de Cadastro

## Visão Geral
Este módulo contém os scripts de Definição de Dados (DDL) e validações estruturais para as 7 tabelas do núcleo de cadastro do **Kaizen ERP**:
1. `UNIDADE`
2. `CONTADOR_DOCUMENTO` (tabela técnica)
3. `PAPEL`
4. `USUARIO`
5. `USUARIO_PAPEL`
6. `ALUNO`
7. `COLABORADOR`

## Arquivos do Módulo
- `01_ddl_nucleo_cadastro.sql`: Definição de tabelas, tipos de dados, chaves primárias, chaves estrangeiras, restrições de checagem (`CHECK ... REGEXP`) e chaves únicas compostas multiunidade (`uq_aluno_unidade`, `uq_colaborador_unidade`).
- `test_ddl_nucleo_cadastro.sql`: Script de testes contendo consultas de verificação em `information_schema`, carga de dados base e cenários comentados de teste de violação de restrições de integridade.

## Como Executar
No MySQL Server 8.0:

```bash
# 1. Executar a criação do esquema e tabelas
mysql -u root -p kaizen_erp < 01_ddl_nucleo_cadastro.sql

# 2. Executar a validação e testes
mysql -u root -p kaizen_erp < test_ddl_nucleo_cadastro.sql
```
