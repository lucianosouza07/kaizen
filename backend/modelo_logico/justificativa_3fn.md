# Relatório de Normalização em Terceira Forma Normal (3FN) e Resolução de Relacionamentos N:N

**Projeto**: Kaizen BD — Camada de Banco de Dados Relacional  
**Módulo**: `modulo_modelo_logico_e_dicionario_de_dados` (`BK-DB-02`)  
**Escopo**: 15 relações lógicas (13 de domínio + 2 técnicas: `AUDITORIA_LOG` e `CONTADOR_DOCUMENTO`).

---

## 1. Análise de Conformidade nas Três Formas Normais

### 1.1 Primeira Forma Normal (1FN) — Atomicidade de Atributos
Todas as 15 relações do esquema lógico satisfazem estritamente a **1FN**:
- Nenhum atributo admite listas multivaloradas, vetores ou grupos repetidores (por exemplo, um usuário com vários papéis não armazena uma string `"GERENTE,FINANCEIRO"`, mas sim tuplas atômicas em `USUARIO_PAPEL`).
- Em `AUDITORIA_LOG`, os atributos `antes` e `depois` utilizam o domínio documental `JSON` exclusivamente como carga técnica opaca de auditoria histórica (`OLD`/`NEW`), não participando de chaves nem de junções relacionais de negócio.

### 1.2 Segunda Forma Normal (2FN) — Dependência Funcional Total da Chave Primária
Todas as relações satisfazem a **2FN**:
- **Relações com chave primária simples (13 relações)**: `UNIDADE`, `PAPEL`, `USUARIO`, `ALUNO`, `COLABORADOR`, `PLANO`, `TURMA`, `CONTRATO`, `MENSALIDADE`, `PAGAMENTO`, `ACESSO`, `RESERVA_TURMA` e `AUDITORIA_LOG` possuem chave primária de atributo único (`id_*`). Por definição, é impossível existir dependência parcial de parte da chave primária.
- **Relações com chave primária composta (2 relações)**:
  1. `USUARIO_PAPEL(id_usuario, id_papel)`: relação associativa pura composta exclusivamente pelos dois atributos que formam sua chave primária; não possui atributos não-chave.
  2. `CONTADOR_DOCUMENTO(tipo, id_unidade, ultimo)`: o atributo não-chave `ultimo` depende funcionalmente do par completo `(tipo, id_unidade)`, pois cada unidade mantém sua própria sequência numérica para cada tipo de documento (`CONTRATO` ou `NFSE`).

### 1.3 Terceira Forma Normal (3FN) — Ausência de Dependências Transitivas
Todas as relações satisfazem a **3FN** (\(X \to A\) implica que \(X\) é superchave ou \(A\) é atributo primo):

| Relação | Chave Primária (`X`) | Dependências Funcionais Verificadas | Justificativa de 3FN |
|---|---|---|---|
| `UNIDADE` | `id_unidade` | `id_unidade → nome, cnpj, cidade, ativa, criado_em`; `cnpj → id_unidade` (`[UK]`) | Todos os atributos descrevem diretamente a unidade; `cnpj` é chave candidata alternativa. |
| `CONTADOR_DOCUMENTO` | `(tipo, id_unidade)` | `(tipo, id_unidade) → ultimo` | `ultimo` depende exclusivamente da chave composta inteira. |
| `PAPEL` | `id_papel` | `id_papel → nome`; `nome → id_papel` (`[UK]`) | Sem dependências transitivas. |
| `USUARIO` | `id_usuario` | `id_usuario → login, nome, id_unidade, ativo, criado_em`; `login → id_usuario` (`[UK]`) | Dados da unidade (`nome`, `cidade`) não são duplicados em `USUARIO`. |
| `USUARIO_PAPEL` | `(id_usuario, id_papel)` | `(id_usuario, id_papel)` | Relação associativa pura em 3FN. |
| `ALUNO` | `id_aluno` | `id_aluno → id_unidade, nome, cpf, email, data_nascimento, consentimento_lgpd_em, ativo, criado_em, atualizado_em` | `cpf` e `email` são chaves candidatas (`[UK]`). Atributos de `UNIDADE` não são repetidos em `ALUNO`. |
| `COLABORADOR` | `id_colaborador` | `id_colaborador → id_unidade, nome, cpf, cargo, ativo` | `cpf` é chave candidata (`[UK]`). Separado de `ALUNO` para evitar nulos estruturais e herança artificial. |
| `PLANO` | `id_plano` | `id_plano → nome, periodicidade_meses, valor_mensal, carencia_dias, multa_percentual, ativo` | `nome` é chave candidata (`[UK]`). Todos os parâmetros comerciais dependem apenas de `id_plano`. |
| `TURMA` | `id_turma` | `id_turma → id_unidade, id_instrutor, modalidade, sala, capacidade, inicio, fim` | O vínculo composto `(id_instrutor, id_unidade)` garante integridade de lotação na mesma unidade sem duplicar nome/cargo do instrutor. |
| `CONTRATO` | `id_contrato` | `id_contrato → numero, id_aluno, id_unidade, id_plano, data_inicio, data_fim, dia_vencimento, valor_mensal, status, assinado_em` | `valor_mensal` é **snapshot histórico imutável** do preço acordado no ato da contratação (ver §3). |
| `MENSALIDADE` | `id_mensalidade` | `id_mensalidade → id_contrato, competencia, vencimento, valor, juros, multa, desconto, status, criado_em, atualizado_em` | Par `(id_contrato, competencia)` é chave candidata (`[UK]`). Todos os valores pertencem ao título daquela competência. |
| `PAGAMENTO` | `id_pagamento` | `id_pagamento → id_mensalidade, tipo, valor, forma, id_externo, id_pagamento_original, pago_em` | `id_externo` é chave candidata (`[UK]`). Cada evento financeiro é imutável e independente. |
| `ACESSO` | `id_acesso` | `id_acesso → id_aluno, id_unidade, data_hora, liberado, motivo` | Registro factual de evento na catraca; depende integralmente de `id_acesso`. |
| `RESERVA_TURMA` | `id_reserva` | `id_reserva → id_turma, id_aluno, id_unidade, status, reservada_em` | Par `(id_turma, id_aluno)` é chave candidata (`[UK]`). Resolve o relacionamento `N : N`. |
| `AUDITORIA_LOG` | `id_log` | `id_log → tabela, operacao, chave_pk, antes, depois, conta_mysql, ocorrido_em` | Registro imutável de trilha de auditoria técnica. |

---

## 2. Resolução Completa dos Relacionamentos Muitos-para-Muitos (`N : N`)

Nenhum relacionamento `N : N` permanece direto no modelo lógico:

1. **`ALUNO — TURMA` → Resolvido por `RESERVA_TURMA`**:
   - Chave primária substituta: `id_reserva`.
   - Chave única de negócio: `UK (id_turma, id_aluno)` impedindo dupla inscrição do mesmo aluno na mesma turma.
   - Chaves estrangeiras compostas por unidade:
     - `(id_turma, id_unidade) → TURMA(id_turma, id_unidade)`
     - `(id_aluno, id_unidade) → ALUNO(id_aluno, id_unidade)`
   - Atributos próprios da associação: `status ENUM('CONFIRMADA','ESPERA','CANCELADA')` e `reservada_em`.
2. **`USUARIO — PAPEL` → Resolvido por `USUARIO_PAPEL`**:
   - Chave primária composta: `PK (id_usuario, id_papel)`.
   - Chaves estrangeiras: `id_usuario → USUARIO(id_usuario)` e `id_papel → PAPEL(id_papel)`.

---

## 3. Justificativa de `CONTRATO.valor_mensal` como Snapshot Imutável

- Em `PLANO`, o atributo `valor_mensal` representa o **preço de catálogo atual** para novas adesões.
- Em `CONTRATO`, o atributo `valor_mensal` representa o **preço efetivamente contratado pelo aluno na data de assinatura (`assinado_em`)**.
- Trata-se de um **snapshot temporal obrigatório**: caso `PLANO.valor_mensal` sofra reajuste comercial futuro, os contratos vigentes e o histórico contábil de contratos encerrados ou cancelados não podem ter seu valor alterado retroativamente. Portanto, `CONTRATO.valor_mensal` depende funcionalmente de `id_contrato` no tempo e não constitui anomalia de atualização.
