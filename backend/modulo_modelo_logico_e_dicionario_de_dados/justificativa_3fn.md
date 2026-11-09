# Justificativa Formal de Normalização Relacional (3FN) — Kaizen BD

**Módulo**: `modulo_modelo_logico_e_dicionario_de_dados`
**Objetivo**: Demonstrar formalmente a aderência de todas as 15 relações do esquema à Terceira Forma Normal (3FN), atestando a eliminação de anomalias de inserção, atualização e exclusão.

---

## 1. Fundamentação Teórica

- **Primeira Forma Normal (1FN)**:
  Uma relação \(R\) está na 1FN se, e somente se, o domínio de cada atributo contiver apenas valores atômicos (indivisíveis) e o valor de qualquer atributo em uma tupla for um valor único pertencente a esse domínio. Não são admitidos atributos multivalorados, listas ou tuplas aninhadas.
- **Segunda Forma Normal (2FN)**:
  Uma relação \(R\) está na 2FN se, e somente se, estiver na 1FN e todo atributo não-chave for total e plenamente dependente funcional da chave primária (isto é, nenhum atributo não-chave depende de um subconjunto próprio de qualquer chave candidata). Em relações cuja chave primária é simples (um único atributo), a 2FN é satisfeita por definição se a 1FN for cumprida.
- **Terceira Forma Normal (3FN)**:
  Uma relação \(R\) está na 3FN se, e somente se, estiver na 2FN e nenhum atributo não-chave depender transitivamente de uma chave candidata. Formalmente, para toda dependência funcional não trivial \(X \to Y\), ou \(X\) é uma superchave de \(R\), ou \(Y\) é um atributo primo (membro de alguma chave candidata).

---

## 2. Análise Relação por Relação

### 2.1 `UNIDADE`
- **Chave Primária**: `{id_unidade}`
- **Chaves Candidatas**: `{id_unidade}`, `{cnpj}`
- **Atributos não-chave**: `nome`, `cidade`, `ativa`, `criado_em`
- **Dependências Funcionais**:
  - `id_unidade` \(\to\) `{nome, cnpj, cidade, ativa, criado_em}`
  - `cnpj` \(\to\) `{id_unidade, nome, cidade, ativa, criado_em}`
- **Avaliação 3FN**:
  - 1FN: Atributos atômicos.
  - 2FN: Chave primária simples; não há dependências parciais.
  - 3FN: Todas as dependências funcionais partem de superchaves (`id_unidade` ou `cnpj`). Nenhum atributo não-chave determina outro atributo não-chave (ex.: cidade não determina unidade, pois múltiplas filiais podem coexistir na mesma cidade). **Está na 3FN**.

---

### 2.2 `PLANO`
- **Chave Primária**: `{id_plano}`
- **Chaves Candidatas**: `{id_plano}`, `{nome}`
- **Atributos não-chave**: `periodicidade_meses`, `valor_mensal`, `carencia_dias`, `multa_percentual`, `ativo`
- **Dependências Funcionais**:
  - `id_plano` \(\to\) `{nome, periodicidade_meses, valor_mensal, carencia_dias, multa_percentual, ativo}`
  - `nome` \(\to\) `{id_plano, periodicidade_meses, valor_mensal, carencia_dias, multa_percentual, ativo}`
- **Avaliação 3FN**:
  - Chave simples. Todos os atributos dependem diretamente e exclusivamente do identificador ou nome do plano. Não há dependências transitivas. **Está na 3FN**.

---

### 2.3 `PAPEL`
- **Chave Primária**: `{id_papel}`
- **Chaves Candidatas**: `{id_papel}`, `{nome}`
- **Atributos não-chave**: Nenhum (apenas `nome`, que é chave candidata).
- **Avaliação 3FN**:
  - Satisfeita trivialmente em 3FN e BCNF.

---

### 2.4 `CONTADOR_DOCUMENTO`
- **Chave Primária**: `{tipo, id_unidade}` (Composta)
- **Atributos não-chave**: `ultimo`
- **Dependências Funcionais**:
  - `{tipo, id_unidade}` \(\to\) `ultimo`
- **Avaliação 3FN**:
  - 1FN: Atômico.
  - 2FN: O valor de `ultimo` depende simultaneamente do tipo do documento e da filial (uma unidade possui contadores distintos para CONTRATO e NFSE, e diferentes filiais têm sequências independentes para o mesmo tipo). Não há dependência parcial.
  - 3FN: O único determinante é a chave primária inteira. **Está na 3FN**.

---

### 2.5 `ALUNO`
- **Chave Primária**: `{id_aluno}`
- **Chaves Candidatas**: `{id_aluno}`, `{cpf}`, `{email}`, `{id_aluno, id_unidade}` (superchave)
- **Atributos não-chave**: `nome`, `data_nascimento`, `consentimento_lgpd_em`, `ativo`, `criado_em`, `atualizado_em`
- **Dependências Funcionais**:
  - `id_aluno` \(\to\) `{id_unidade, nome, cpf, email, data_nascimento, consentimento_lgpd_em, ativo, criado_em, atualizado_em}`
  - `cpf` \(\to\) demais atributos
  - `email` \(\to\) demais atributos
- **Avaliação 3FN**:
  - Chave simples. O atributo `id_unidade` é uma chave estrangeira que identifica a lotação; os dados da filial não foram desnormalizados na tabela aluno, evitando dependência transitiva (ex.: `id_aluno` \(\to\) `id_unidade`, e se tivéssemos `cidade_unidade`, teríamos `id_unidade` \(\to\) `cidade_unidade`, gerando transitividade). Ao isolar os dados da filial em `UNIDADE`, `ALUNO` **permanece rigorosamente na 3FN**.

---

### 2.6 `COLABORADOR`
- **Chave Primária**: `{id_colaborador}`
- **Chaves Candidatas**: `{id_colaborador}`, `{cpf}`
- **Atributos não-chave**: `id_unidade`, `nome`, `cargo`, `ativo`
- **Avaliação 3FN**:
  - Idêntica à de `ALUNO`. O colaborador apenas aponta para `id_unidade`. Dados da unidade não constam em `COLABORADOR`. **Está na 3FN**.

---

### 2.7 `USUARIO`
- **Chave Primária**: `{id_usuario}`
- **Chaves Candidatas**: `{id_usuario}`, `{login}`
- **Atributos não-chave**: `nome`, `id_unidade`, `ativo`, `criado_em`
- **Avaliação 3FN**:
  - Chave simples; todas as dependências funcionais partem de superchaves. **Está na 3FN**.

---

### 2.8 `USUARIO_PAPEL` (Resolução N:N)
- **Chave Primária**: `{id_usuario, id_papel}` (Composta)
- **Atributos não-chave**: Nenhum
- **Avaliação 3FN**:
  - Tabela associativa pura. A chave é composta pelos dois identificadores de relacionamento. Como não possui atributos não-chave, satisfaz 2FN, 3FN e BCNF por vacuidade.

---

### 2.9 `TURMA`
- **Chave Primária**: `{id_turma}`
- **Chaves Candidatas**: `{id_turma}`
- **Atributos não-chave**: `id_unidade`, `id_instrutor`, `modalidade`, `sala`, `capacidade`, `inicio`, `fim`
- **Avaliação 3FN**:
  - `modalidade`, `sala`, `capacidade`, `inicio` e `fim` são características intrínsecas daquela sessão específica de aula.
  - Os dados do instrutor ficam em `COLABORADOR` e os dados da filial em `UNIDADE`.
  - Não há dependência transitiva entre atributos não-chave. **Está na 3FN**.

---

### 2.10 `RESERVA_TURMA` (Resolução N:N)
- **Chave Primária**: `{id_reserva}`
- **Chaves Candidatas**: `{id_reserva}`, `{id_turma, id_aluno}`
- **Atributos não-chave**: `id_unidade`, `status`, `reservada_em`
- **Avaliação 3FN**:
  - Resolve a cardinalidade N:N entre `ALUNO` e `TURMA`.
  - Os atributos `status` e `reservada_em` referem-se estritamente à transação de reserva daquela vaga específica daquela turma por aquele aluno.
  - Não dependem isoladamente apenas do aluno nem apenas da turma.
  - Chave primária surrogate `{id_reserva}` com chave alternativa `{id_turma, id_aluno}`. Todos os atributos dependem plenamente de ambas. **Está na 3FN**.

---

### 2.11 `CONTRATO`
- **Chave Primária**: `{id_contrato}`
- **Chaves Candidatas**: `{id_contrato}`, `{numero}` (quando preenchido)
- **Atributos não-chave**: `id_aluno`, `id_unidade`, `id_plano`, `data_inicio`, `data_fim`, `dia_vencimento`, `valor_mensal`, `status`, `assinado_em`
- **Justificativa do Snapshot de Preço (`valor_mensal`)**:
  - No modelo relacional estático, poderia parecer que `valor_mensal` depende de `id_plano` (\(id\_plano \to valor\_mensal\)).
  - Contudo, no domínio de negócios, o contrato constitui um **acordo formal temporal**. O preço contratado é uma propriedade imutável e irrevogável daquela assinatura específica:
    \[
    id\_contrato \to valor\_mensal_{\text{contratado}}
    \]
  - O valor contido em `PLANO.valor_mensal` representa apenas a tabela de preços do momento presente, sujeita a flutuações e reajustes comerciais futuros.
  - Se o valor do contrato fosse obtido por join com `PLANO`, violar-se-ia a integridade histórica e jurídica das faturas.
  - Logo, `CONTRATO.valor_mensal` é uma propriedade funcional direta e exclusiva de `id_contrato`, inexistindo dependência transitiva com `PLANO`. **Está na 3FN**.

---

### 2.12 `MENSALIDADE`
- **Chave Primária**: `{id_mensalidade}`
- **Chaves Candidatas**: `{id_mensalidade}`, `{id_contrato, competencia}`
- **Atributos não-chave**: `vencimento`, `valor`, `juros`, `multa`, `desconto`, `status`, `criado_em`, `atualizado_em`
- **Avaliação 3FN**:
  - Todos os valores e encargos dependem unicamente da fatura específica daquela competência daquele contrato.
  - Não há dependência transitiva. **Está na 3FN**.

---

### 2.13 `PAGAMENTO`
- **Chave Primária**: `{id_pagamento}`
- **Chaves Candidatas**: `{id_pagamento}`, `{id_externo}` (quando preenchido)
- **Atributos não-chave**: `id_mensalidade`, `tipo`, `valor`, `forma`, `id_pagamento_original`, `pago_em`
- **Avaliação 3FN**:
  - Cada lançamento financeiro possui identificador exclusivo e atributos atômicos correspondentes ao evento de liquidação ou estorno.
  - Pagamentos de estorno utilizam auto-relacionamento (`id_pagamento_original`) sem violar a normalização. **Está na 3FN**.

---

### 2.14 `ACESSO`
- **Chave Primária**: `{id_acesso}`
- **Atributos não-chave**: `id_aluno`, `id_unidade`, `data_hora`, `liberado`, `motivo`
- **Avaliação 3FN**:
  - Registro de fato histórico imutável de passagem pela catraca. Depende diretamente do identificador do registro. **Está na 3FN**.

---

### 2.15 `AUDITORIA_LOG`
- **Chave Primária**: `{id_log}`
- **Atributos não-chave**: `tabela`, `operacao`, `chave_pk`, `antes`, `depois`, `conta_mysql`, `ocorrido_em`
- **Avaliação 3FN**:
  - Registro técnico append-only de modificações. Todos os atributos dependem funcionalmente de `id_log`. **Está na 3FN**.

---

## 3. Conclusão da Análise de 3FN

Todas as 15 relações do esquema Kaizen BD cumprem integralmente os postulados da Primeira, Segunda e Terceira Formas Normais. As redundâncias identificadas (`id_unidade` replicado para integridade composta e `CONTRATO.valor_mensal` como snapshot de preço) são plenamente justificadas pelas regras de integridade referencial física e integridade histórica do negócio contábil.
