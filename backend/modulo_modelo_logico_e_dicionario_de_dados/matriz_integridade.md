# Matriz de Integridade Lógica — Kaizen BD

**Módulo**: `modulo_modelo_logico_e_dicionario_de_dados`
**Finalidade**: Especificação exaustiva de todas as restrições declarativas de integridade relacional do sistema.

---

## 1. Matriz Consolidada de Integridade (15 Relações)

| Relação | Chave Primária (PK) | Chaves Estrangeiras (FK) | Chaves Únicas (UK) | Restrições de Checagem (CK) |
|---|---|---|---|---|
| **`UNIDADE`** | `id_unidade` | — | `cnpj` | `CHECK (cnpj REGEXP '^[0-9]{14}$')` |
| **`ALUNO`** | `id_aluno` | `id_unidade` \(\to\) `UNIDADE(id_unidade)` | `cpf`<br>`email`<br>`(id_aluno, id_unidade)` | `CHECK (cpf REGEXP '^[0-9]{11}$')`<br>`CHECK (data_nascimento >= '1900-01-01')` |
| **`COLABORADOR`** | `id_colaborador` | `id_unidade` \(\to\) `UNIDADE(id_unidade)` | `cpf`<br>`(id_colaborador, id_unidade)` | `CHECK (cpf REGEXP '^[0-9]{11}$')` |
| **`PLANO`** | `id_plano` | — | `nome` | `CHECK (periodicidade_meses > 0)`<br>`CHECK (valor_mensal > 0)`<br>`CHECK (multa_percentual >= 0)` |
| **`TURMA`** | `id_turma` | `id_unidade` \(\to\) `UNIDADE(id_unidade)`<br>`(id_instrutor, id_unidade)` \(\to\) `COLABORADOR(id_colaborador, id_unidade)` | `(id_turma, id_unidade)` | `CHECK (capacidade > 0)`<br>`CHECK (fim > inicio)` |
| **`CONTRATO`** | `id_contrato` | `(id_aluno, id_unidade)` \(\to\) `ALUNO(id_aluno, id_unidade)`<br>`id_unidade` \(\to\) `UNIDADE(id_unidade)`<br>`id_plano` \(\to\) `PLANO(id_plano)` | `numero`<br>`(id_aluno, status='ATIVO')` *[Lógica condicional]* | `CHECK (dia_vencimento BETWEEN 1 AND 28)`<br>`CHECK (data_fim IS NULL OR data_fim >= data_inicio)`<br>`CHECK (valor_mensal > 0)` |
| **`MENSALIDADE`** | `id_mensalidade` | `id_contrato` \(\to\) `CONTRATO(id_contrato)` | `(id_contrato, competencia)` | `CHECK (competencia REGEXP '^[0-9]{4}-(0[1-9]\|1[0-2])$')`<br>`CHECK (valor > 0)`<br>`CHECK (juros >= 0)`<br>`CHECK (multa >= 0)`<br>`CHECK (desconto >= 0 AND desconto <= valor)` |
| **`PAGAMENTO`** | `id_pagamento` | `id_mensalidade` \(\to\) `MENSALIDADE(id_mensalidade)`<br>`id_pagamento_original` \(\to\) `PAGAMENTO(id_pagamento)` | `id_externo` | `CHECK (valor > 0)` |
| **`ACESSO`** | `id_acesso` | `(id_aluno, id_unidade)` \(\to\) `ALUNO(id_aluno, id_unidade)`<br>`id_unidade` \(\to\) `UNIDADE(id_unidade)` | — | — |
| **`RESERVA_TURMA`** | `id_reserva` | `(id_turma, id_unidade)` \(\to\) `TURMA(id_turma, id_unidade)`<br>`(id_aluno, id_unidade)` \(\to\) `ALUNO(id_aluno, id_unidade)`<br>`id_unidade` \(\to\) `UNIDADE(id_unidade)` | `(id_turma, id_aluno)` | Domínio fechado de status: `CONFIRMADA`, `ESPERA`, `CANCELADA` |
| **`USUARIO`** | `id_usuario` | `id_unidade` \(\to\) `UNIDADE(id_unidade)` *[Opcional, NULL = Rede]* | `login` | — |
| **`PAPEL`** | `id_papel` | — | `nome` | Domínio fechado de nomes de papéis |
| **`USUARIO_PAPEL`** | `(id_usuario, id_papel)` | `id_usuario` \(\to\) `USUARIO(id_usuario)`<br>`id_papel` \(\to\) `PAPEL(id_papel)` | — | — |
| **`AUDITORIA_LOG`** | `id_log` | — | — | `operacao IN ('INSERT','UPDATE','DELETE')` |
| **`CONTADOR_DOCUMENTO`** | `(tipo, id_unidade)` | `id_unidade` \(\to\) `UNIDADE(id_unidade)` | — | `tipo IN ('CONTRATO','NFSE')` |

---

## 2. Detalhamento das Restrições de Integridade Referencial Composta (Multiunidade)

A arquitetura de dados adota **Chaves Estrangeiras Compostas** para impor o isolamento relacional geográfico diretamente no motor de banco de dados:

1. **Vínculo Aluno — Contrato**:
   - Chave Referenciada: `ALUNO(id_aluno, id_unidade)`
   - Chave Estrangeira: `CONTRATO(id_aluno, id_unidade)`
   - *Garantia*: Um contrato só pode ser registrado na mesma unidade física em que o aluno está matriculado. Impede cruzamento indevido de alunos com contratos de outras unidades.

2. **Vínculo Instrutor — Turma**:
   - Chave Referenciada: `COLABORADOR(id_colaborador, id_unidade)`
   - Chave Estrangeira: `TURMA(id_instrutor, id_unidade)`
   - *Garantia*: Um instrutor só pode ser alocado para ministrar aulas em turmas da filial na qual está formalmente lotado.

3. **Vínculo Turma / Aluno — Reserva de Turma**:
   - Chaves Referenciadas:
     - `TURMA(id_turma, id_unidade)`
     - `ALUNO(id_aluno, id_unidade)`
   - Chaves Estrangeiras em `RESERVA_TURMA`:
     - `(id_turma, id_unidade)`
     - `(id_aluno, id_unidade)`
   - *Garantia*: A reserva de uma aula coletiva exige estrita compatibilidade entre a unidade da turma e a unidade do aluno, prevenindo inscrições não autorizadas entre filiais diferentes.

4. **Vínculo Catraca — Acesso**:
   - Chave Referenciada: `ALUNO(id_aluno, id_unidade)`
   - Chave Estrangeira: `ACESSO(id_aluno, id_unidade)`
   - *Garantia*: Todo registro de leitura de catraca audita expressamente a filial de cadastro do aluno.

---

## 3. Restrição de Unicidade de Contrato Ativo

- **Regra Lógica**: Cada aluno cadastrado pode possuir, em qualquer instante, no máximo um único contrato com status `ATIVO`.
- **Expressão Conceitual**:
  \[
  \text{UNIQUE}(id\_aluno) \quad \text{onde } status = \text{'ATIVO'}
  \]
- **Separação de Camadas**:
  - No **Modelo Lógico**, a regra é expressa puramente como uma restrição de unicidade condicional declarativa.
  - A coluna física calculada `ativo_unico` (usada no MySQL para emular índices parciais inexistentes) pertence exclusivamente ao DDL físico e **não faz parte** do modelo lógico.
