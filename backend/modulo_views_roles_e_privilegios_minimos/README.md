# Módulo de Views, Roles e Privilégios Mínimos (BK-DB-08)

| Metadado | Detalhe |
|---|---|
| **Tarefa** | `BK-DB-08`: Views, roles e privilégios mínimos |
| **Etapa do Plano** | Etapa 4 (Objetos e Segurança) |
| **SGBD** | MySQL Server 8.0.46 / MySQL Workbench 8.0.47 CE |
| **Engine / Collation** | InnoDB / `utf8mb4` / `utf8mb4_0900_ai_ci` |
| **Dependências** | Núcleo de Cadastro (`BK-DB-03`), DDL Comercial/Financeiro (`BK-DB-04`), DDL Operação e Tabela Técnica (`BK-DB-05`), Functions e Procedures (`BK-DB-06`), Triggers (`BK-DB-07`) |

---

## 1. Visão Geral

Este módulo implementa a camada de segurança lógica, controle de acesso baseado em papéis (RBAC) e exposição controlada de dados no motor relacional MySQL. Ele substitui mecanismos ausentes no SGBD como segurança por linha (RLS), garantindo que cada perfil de usuário consulte estritamente as projeções e agregações necessárias para sua atuação funcional, sem concessão de acesso direto às tabelas-base de domínio. Atua como salvaguarda regulatória para conformidade com a LGPD mediante ofuscação de identificadores pessoais (CPF) e preserva a imutabilidade forense da trilha de auditoria para todos os perfis operacionais.

---

## 2. Estrutura de Artefatos do Módulo

```text
src/backend/modulo_views_roles_e_privilegios_minimos/
├── 01_views_roles.sql      # DDL de criação das 5 visões, 6 roles e declarações GRANT
├── test_views_roles.sql    # Script de validação automatizada de permissões e asserções
└── README.md               # Este documento de especificação e guia de execução
```

---

## 3. Catálogo das Visões de Banco de Dados (5 Views)

| Visão | Projeção Principal | Regra de Agrupamento / Filtro | Conformidade LGPD / Negócio |
|---|---|---|---|
| `vw_inadimplentes` | `id_unidade`, `id_aluno`, `nome`, `cpf_mascarado`, `competencia`, `vencimento`, `valor_nominal`, `saldo_devido`, `dias_atraso` | `WHERE m.status IN ('ABERTA','PARCIAL') AND m.vencimento < CURDATE()` | Mascaramento de CPF (`***.XXX`) exibindo apenas os 3 dígitos finais; apuração dinâmica de saldo devido e dias de atraso. |
| `vw_fluxo_caixa` | `id_unidade`, `dia`, `competencia`, `valor_liquido`, `qtd_lancamentos` | `GROUP BY c.id_unidade, DATE(p.pago_em), m.competencia` | Balanço monetário compensatório (recebimentos menos estornos) em conformidade estrita com `ONLY_FULL_GROUP_BY`. |
| `vw_ocupacao_turma` | `id_unidade`, `id_turma`, `modalidade`, `sala`, `inicio`, `fim`, `capacidade`, `confirmados`, `vagas_livres` | Projeção direta com invocação de `fn_ocupacao_turma(t.id_turma)` | Cálculo dinâmico de vagas livres (`GREATEST(capacidade - confirmados, 0)`), sem valores negativos. |
| `vw_aluno_financeiro` | `id_unidade`, `id_aluno`, `nome`, `cpf_mascarado`, `numero_contrato`, `status_contrato`, `qtd_mensalidades`, `saldo_devido` | `GROUP BY a.id_unidade, a.id_aluno, a.nome, a.cpf, c.numero, c.status` | Ficha consolidada do aluno cruzada com contrato ativo e títulos, com CPF ofuscado sob `ONLY_FULL_GROUP_BY`. |
| `vw_auditoria_resumo` | `id_log`, `tabela`, `operacao`, `chave_pk`, `conta_mysql`, `ocorrido_em`, `usuario`, `papeis` | `GROUP BY l.id_log, l.tabela, l.operacao, l.chave_pk, l.conta_mysql, l.ocorrido_em, u.nome` | Resolução do login da conta MySQL para nome de usuário do sistema e agregação ordenada de papéis sob `ONLY_FULL_GROUP_BY`. |

---

## 4. Catálogo de Papéis (6 Roles) e Matriz de Privilégios Mínimos (RBAC)

| Role | Descrição e Finalidade | Visões Autorizadas (`GRANT SELECT`) | Rotinas Autorizadas (`GRANT EXECUTE`) | Acesso a Tabelas-Base |
|---|---|---|---|:---:|
| `rl_dba` | Administração e governança técnica de dados | `vw_auditoria_resumo`, todas as visões | `sp_anonimizar_aluno`, rotinas administrativas | **AMPLO** (exceção auditada) |
| `rl_gerente` | Gestão operacional e indicadores de filial | `vw_aluno_financeiro`, `vw_inadimplentes`, `vw_fluxo_caixa`, `vw_ocupacao_turma` | — | **NEGADO** |
| `rl_recepcao` | Atendimento balcão e conferência de salas | `vw_ocupacao_turma` | — | **NEGADO** |
| `rl_financeiro` | Faturamento, baixa e conciliação de caixa | `vw_aluno_financeiro`, `vw_inadimplentes`, `vw_fluxo_caixa` | `sp_gerar_mensalidades`, `sp_registrar_pagamento`, `fn_valor_devido` | **NEGADO** |
| `rl_instrutor` | Acompanhamento de aulas e presenças | `vw_ocupacao_turma` | — | **NEGADO** |
| `rl_leitura` | Auditoria fiscal e cobrança externa | `vw_inadimplentes` | — | **NEGADO** |

---

## 5. Imutabilidade e Governança da Trilha de Auditoria

- A tabela técnica `AUDITORIA_LOG` não possui concessão de privilégios de `UPDATE` ou `DELETE` para nenhum perfil operacional (`rl_gerente`, `rl_recepcao`, `rl_financeiro`, `rl_instrutor`, `rl_leitura`).
- O registro na trilha de auditoria ocorre exclusivamente de forma reativa através do gatilho `trg_auditoria_aluno` (`AFTER UPDATE ON aluno`).
- Apenas a role administrativa `rl_dba` detém privilégios amplos como exceção técnica de infraestrutura controlada.

---

## 6. Guia de Instalação e Execução

### 6.1 Criação das Visões e Roles no MySQL 8.0 / MySQL Workbench

Execute o script `01_views_roles.sql` conectado à instância com usuário administrativo (`root` ou `DBA`):

```sql
USE kaizen;
SOURCE src/backend/modulo_views_roles_e_privilegios_minimos/01_views_roles.sql;
```

*Nota para execução no Workbench*: Execute o arquivo completo (*Execute the entire script*, `Ctrl+Shift+Enter`).

### 6.2 Execução da Suíte de Testes Automatizados

Após a criação das visões e concessão das roles, execute o script de validação:

```sql
USE kaizen;
SOURCE src/backend/modulo_views_roles_e_privilegios_minimos/test_views_roles.sql;
```

O script executa asserções cobrindo metadados, integridade de consultas sob `ONLY_FULL_GROUP_BY`, mascaramento LGPD, existência das 6 roles, concessões autorizadas, bloqueio de tabelas-base e imutabilidade de `AUDITORIA_LOG`.

---

## 7. Matriz de Conformidade com os Critérios de Aceite (`BK-DB-08`)

| Critério de Aceite | Implementação no Módulo | Evidência de Teste | Status |
|---|---|---|:---:|
| **5 views criadas** | `vw_inadimplentes`, `vw_fluxo_caixa`, `vw_ocupacao_turma`, `vw_aluno_financeiro`, `vw_auditoria_resumo`. | Verificação em `information_schema.views`. | **ATENDIDO** |
| **CPF mascarado** | `CONCAT('***.', RIGHT(a.cpf, 3))` implementado em `vw_inadimplentes` e `vw_aluno_financeiro`. | Testes 1.2 e 1.4 em `test_views_roles.sql`. | **ATENDIDO** |
| **6 roles criadas** | `rl_dba`, `rl_gerente`, `rl_recepcao`, `rl_financeiro`, `rl_instrutor`, `rl_leitura`. | Teste 2.1 em `test_views_roles.sql` (`mysql.user`). | **ATENDIDO** |
| **GRANT SELECT apenas sobre views** | Concessões direcionadas estritamente a visões de negócio; zero privilégios em tabelas-base para operacionais. | Teste 2.3 em `test_views_roles.sql`. | **ATENDIDO** |
| **auditoria_log sem UPDATE/DELETE** | Nenhum perfil operacional recebe privilégios de escrita ou modificação em `AUDITORIA_LOG`. | Teste 3.2 em `test_views_roles.sql`. | **ATENDIDO** |
| **ONLY_FULL_GROUP_BY respeitado** | Todas as colunas projetadas não-agregadas constam explicitamente no `GROUP BY` das visões sumarizadas. | Testes 1.4, 3.1 e 4.1 em `test_views_roles.sql`. | **ATENDIDO** |
