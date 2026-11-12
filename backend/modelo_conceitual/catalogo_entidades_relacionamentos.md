# Catálogo de Entidades e Relacionamentos do Modelo Conceitual (ER/EER)

**Projeto**: Kaizen BD — Camada de Banco de Dados Relacional  
**Módulo**: `modulo_modelo_conceitual` (`BK-DB-01`)  
**Escopo**: Núcleo transacional conceitual independente de SGBD (13 entidades de domínio, 13 relacionamentos com cardinalidades, 2 entidades associativas explícitas e 0 tabelas técnicas).

---

## 1. Convenções de Notação e Modelagem Conceitual

1. **Notação Diagramática**: Pé de Galinha (*Crow's Foot*) em especificação textual/visual Mermaid (`erDiagram`) compatível com o *EER Diagram* do MySQL Workbench 8.0.47 CE.
2. **Padrão de Nomenclatura**:
   - **Entidades**: `SNAKE_CASE` em letras maiúsculas no singular (`UNIDADE`, `ALUNO`, `RESERVA_TURMA`, `USUARIO_PAPEL`).
   - **Atributos e Identificadores**: `snake_case` em letras minúsculas sem acentos (`id_unidade`, `data_nascimento`, `consentimento_lgpd_em`).
3. **Independência Tecnológica**:
   - O modelo conceitual não define tipos físicos de SGBD (`INT`, `VARCHAR`, `DECIMAL`), motores de armazenamento (`InnoDB`), índices físicos nem colunas geradas (`ativo_unico`).
   - **Regra de Rastreabilidade**: Todo atributo do modelo conceitual aparece obrigatoriamente no modelo lógico subsequente.

---

## 2. Catálogo das 13 Entidades de Domínio

### 2.1 Núcleo de Cadastro e Controle de Acesso (RBAC)

| # | Entidade | Tipo de Entidade | Identificador Conceitual | Atributos de Negócio | Descrição Semântica |
|---|---|---|---|---|---|
| 1 | `UNIDADE` | Forte | `id_unidade` | `nome`, `cnpj`, `cidade`, `ativa` | Filial física ou matriz da rede de academias onde alunos são matriculados, colaboradores são lotados e turmas/acessos ocorrem. |
| 2 | `ALUNO` | Forte | `id_aluno` | `nome`, `cpf`, `email`, `data_nascimento`, `consentimento_lgpd_em`, `ativo` | Cliente matriculado em uma unidade, titular de contratos, mensalidades, reservas de turma e registros de acesso na catraca. |
| 3 | `COLABORADOR` | Forte | `id_colaborador` | `nome`, `cpf`, `cargo`, `ativo` | Profissional ou instrutor lotado em uma unidade, responsável por ministrar turmas coletivas. |
| 11 | `USUARIO` | Forte | `id_usuario` | `login`, `nome`, `ativo` | Conta de operador do sistema, podendo estar vinculada ao escopo de uma unidade específica ou possuir visão corporativa de toda a rede. |
| 12 | `PAPEL` | Forte | `id_papel` | `nome` | Perfil de segurança e responsabilidade funcional dentro do modelo RBAC (`ROLE_DBA`, `ROLE_GERENTE`, `ROLE_RECEPCAO`, `ROLE_FINANCEIRO`, `ROLE_INSTRUTOR`, `ROLE_AUDITORIA`). |
| 13 | `USUARIO_PAPEL` | **Associativa** | `(id_usuario, id_papel)` | — | Entidade associativa explícita que decompõe o relacionamento `N : N` entre `USUARIO` e `PAPEL`. |

### 2.2 Núcleo Comercial, Financeiro e de Operação

| # | Entidade | Tipo de Entidade | Identificador Conceitual | Atributos de Negócio | Descrição Semântica |
|---|---|---|---|---|---|
| 4 | `PLANO` | Forte | `id_plano` | `nome`, `periodicidade_meses`, `valor_mensal`, `carencia_dias`, `multa_percentual` | Pacote comercial de catálogo da rede que define periodicidade, preço de tabela, carência e percentual de multa rescisória. |
| 5 | `CONTRATO` | Forte | `id_contrato` | `numero`, `data_inicio`, `data_fim`, `dia_vencimento`, `valor_mensal`, `status` | Acordo formal firmado entre o aluno e sua unidade com base em um plano, preservando o `valor_mensal` contratado na assinatura. |
| 6 | `MENSALIDADE` | Forte | `id_mensalidade` | `competencia`, `vencimento`, `valor`, `juros`, `multa`, `desconto`, `status` | Cobrança periódica gerada por competência (`AAAA-MM`) para um contrato. |
| 7 | `PAGAMENTO` | Forte | `id_pagamento` | `tipo`, `valor`, `forma`, `id_externo`, `pago_em` | Evento financeiro de recebimento ou estorno compensatório vinculado a uma mensalidade. |
| 8 | `ACESSO` | Evento | `id_acesso` | `data_hora`, `liberado`, `motivo` | Registro cronológico de tentativa de entrada do aluno na catraca da unidade, gravando a decisão (`liberado`) e o `motivo`. |
| 9 | `TURMA` | Forte | `id_turma` | `modalidade`, `sala`, `capacidade`, `inicio`, `fim` | Sessão de aula coletiva ofertada em uma sala da unidade por um colaborador instrutor em intervalo determinado. |
| 10 | `RESERVA_TURMA` | **Associativa** | `id_reserva` | `status`, `reservada_em` | Entidade associativa explícita que decompõe o relacionamento `N : N` entre `ALUNO` e `TURMA`, controlando o estado da reserva (`CONFIRMADA`, `ESPERA`, `CANCELADA`). |

---

## 3. Matriz Normativa dos 13 Relacionamentos e Cardinalidades (`R1` a `R13`)

| # | Relacionamento | Cardinalidade | Resolução Associativa | Regra de Negócio Conceitual |
|---|---|---|---|---|
| **R1** | `UNIDADE — ALUNO` | `1 : 0..N` | — | Aluno pertence a uma única unidade. |
| **R2** | `UNIDADE — COLABORADOR` | `1 : 0..N` | — | Instrutor é lotado em uma unidade. |
| **R3** | `UNIDADE — CONTRATO` | `1 : 0..N` | — | Contrato é registrado na unidade do aluno. |
| **R4** | `PLANO — CONTRATO` | `1 : 0..N` | — | Plano é catálogo global; o contrato guarda o valor contratado. |
| **R5** | `ALUNO — CONTRATO` | `1 : 0..N` | — | Histórico de contratos; **no máximo 1 `ATIVO` por aluno**. |
| **R6** | `CONTRATO — MENSALIDADE` | `1 : 0..N` | — | Uma competência (`AAAA-MM`) por contrato. |
| **R7** | `MENSALIDADE — PAGAMENTO` | `1 : 0..N` | — | Vários recebimentos/estornos por mensalidade. |
| **R8** | `ALUNO — ACESSO` | `1 : 0..N` | — | Toda tentativa de entrada é registrada, liberada ou não. |
| **R9** | `COLABORADOR — TURMA` | `1 : 0..N` | — | Instrutor ministra turmas sem sobreposição. |
| **R10** | `UNIDADE — TURMA` | `1 : 0..N` | — | Sala e instrutor não podem colidir no mesmo intervalo. |
| **R11** | `ALUNO — TURMA` | `N : N` → `RESERVA_TURMA` | `RESERVA_TURMA` | Entidade associativa com `status` (`CONFIRMADA`/`ESPERA`/`CANCELADA`). |
| **R12** | `USUARIO — PAPEL` | `N : N` → `USUARIO_PAPEL` | `USUARIO_PAPEL` | Entidade associativa de RBAC. |
| **R13** | `UNIDADE — USUARIO` | `1 : 0..N` | — | `id_unidade = NULL` significa visão de rede. |

---

## 4. Explicitação das Entidades Associativas (`RESERVA_TURMA` e `USUARIO_PAPEL`)

### 4.1 `RESERVA_TURMA` (Resolução de `R11: ALUNO — TURMA`)
- **Motivação Conceitual**: Um aluno pode reservar vagas em diversas turmas ao longo do tempo (`0..N`), e uma turma comporta diversos alunos inscritos (`0..N`).
- **Decomposição**:
  - `TURMA (1) ──< (0..N) RESERVA_TURMA`
  - `ALUNO (1) ──< (0..N) RESERVA_TURMA`
- **Atributos Próprios do Vínculo**:
  - `id_reserva`: identificador conceitual da reserva.
  - `status`: estado do agendamento no domínio `{CONFIRMADA, ESPERA, CANCELADA}`.
  - `reservada_em`: instante em que a solicitação de vaga foi registrada.

### 4.2 `USUARIO_PAPEL` (Resolução de `R12: USUARIO — PAPEL`)
- **Motivação Conceitual**: Um operador (`USUARIO`) pode acumular múltiplos perfis de acesso (`1..N` ou `0..N`), e um mesmo perfil (`PAPEL`) pode ser atribuído a vários operadores (`0..N`).
- **Decomposição**:
  - `USUARIO (1) ──< (0..N) USUARIO_PAPEL`
  - `PAPEL   (1) ──< (0..N) USUARIO_PAPEL`
- **Identificador Composto**: `(id_usuario, id_papel)`, garantindo que o mesmo papel não seja atribuído em duplicidade ao mesmo usuário.

---

## 5. Regras Conceituais de Negócio

1. **Elegibilidade de Acesso (`ACESSO`)**: Um **ACESSO** só é liberado se o **ALUNO** tiver **CONTRATO** ativo e nenhuma **MENSALIDADE** vencida há mais de 5 dias.
2. **Estorno Compensatório (`PAGAMENTO`)**: **PAGAMENTO** de estorno é um novo registro compensatório, não uma alteração do recebimento original.
3. **Unicidade por Competência (`MENSALIDADE`)**: **MENSALIDADE** é única por (`CONTRATO`, `competencia`) — base da idempotência da geração em lote.
4. **Capacidade Máxima de Turma (`RESERVA_TURMA` / `TURMA`)**: **RESERVA_TURMA** confirmada não pode ultrapassar `TURMA.capacidade`.
5. **Fonte Única de Papéis Lógicos (`USUARIO_PAPEL`)**: **USUARIO_PAPEL** é a única fonte de papéis lógicos; os privilégios efetivos são concedidos por `CREATE ROLE` no modelo físico.

---

## 6. Exclusão Estrita de Tabelas Técnicas e Rastreabilidade Conceitual → Lógico

### 6.1 Tabelas Técnicas Excluídas do Modelo Conceitual

| Estrutura Técnica | Camada em que Entra | Motivo da Exclusão no Modelo Conceitual |
|---|---|---|
| `AUDITORIA_LOG` | Lógico / Físico | Artefato técnico de infraestrutura para gravação de trilhas de auditoria (`antes`/`depois` em JSON); não representa uma entidade de negócio do domínio. |
| `CONTADOR_DOCUMENTO` | Lógico / Físico | Tabela auxiliar usada para emular sequências numéricas por unidade (`CTR-AAAA-NNNNNN`) devido à ausência de `CREATE SEQUENCE` no MySQL 8.0; depende exclusivamente de decisão física de SGBD. |

### 6.2 Matriz de Rastreabilidade de Atributos (Conceitual → Lógico)

| Entidade Conceitual | Quantidade de Atributos Conceituais (incl. ID) | Lista Completa de Atributos Conceituais | Presença no Modelo Lógico (`DESIGN.md` §3) |
|---|---|---|---|
| `UNIDADE` | 5 | `id_unidade`, `nome`, `cnpj`, `cidade`, `ativa` | 100% preservados |
| `ALUNO` | 7 | `id_aluno`, `nome`, `cpf`, `email`, `data_nascimento`, `consentimento_lgpd_em`, `ativo` | 100% preservados |
| `COLABORADOR` | 5 | `id_colaborador`, `nome`, `cpf`, `cargo`, `ativo` | 100% preservados |
| `PLANO` | 6 | `id_plano`, `nome`, `periodicidade_meses`, `valor_mensal`, `carencia_dias`, `multa_percentual` | 100% preservados |
| `CONTRATO` | 7 | `id_contrato`, `numero`, `data_inicio`, `data_fim`, `dia_vencimento`, `valor_mensal`, `status` | 100% preservados |
| `MENSALIDADE` | 8 | `id_mensalidade`, `competencia`, `vencimento`, `valor`, `juros`, `multa`, `desconto`, `status` | 100% preservados |
| `PAGAMENTO` | 6 | `id_pagamento`, `tipo`, `valor`, `forma`, `id_externo`, `pago_em` | 100% preservados |
| `ACESSO` | 4 | `id_acesso`, `data_hora`, `liberado`, `motivo` | 100% preservados |
| `TURMA` | 6 | `id_turma`, `modalidade`, `sala`, `capacidade`, `inicio`, `fim` | 100% preservados |
| `RESERVA_TURMA` | 3 | `id_reserva`, `status`, `reservada_em` | 100% preservados |
| `USUARIO` | 4 | `id_usuario`, `login`, `nome`, `ativo` | 100% preservados |
| `PAPEL` | 2 | `id_papel`, `nome` | 100% preservados |
| `USUARIO_PAPEL` | 2 | `id_usuario`, `id_papel` | 100% preservados |
