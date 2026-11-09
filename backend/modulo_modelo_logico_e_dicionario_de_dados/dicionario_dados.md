# Dicionário de Dados Lógico — Kaizen BD

**Módulo**: `modulo_modelo_logico_e_dicionario_de_dados`
**Padrão**: Modelo Relacional Normalizado (3FN)
**Escopo**: Núcleo Transacional de Gestão de Academias (15 Relações: 13 de Domínio + 2 Técnicas)

---

## 1. Convenções de Domínios Abstratos e Nulabilidade

| Domínio Abstrato | Definição Semântica | Regra de Nulabilidade / Validação |
|---|---|---|
| `INTEIRO` | Valor numérico inteiro positivo para identificadores e contadores | Obrigatório (`NOT NULL`), sem valor negativo |
| `TEXTO(n)` | Cadeia de caracteres com comprimento máximo delimitado | Sem espaços supérfluos; obrigatório salvo indicação expressa |
| `DATA` | Data civil no formato calendário (ano, mês, dia) | Datas válidas; nascimentos a partir de 1900-01-01 |
| `INSTANTE` | Carimbo cronológico de precisão temporal | Marco temporal de auditoria e eventos em UTC |
| `MOEDA` | Valor monetário de precisão exata (duas casas decimais) | Estritamente positivo em valores base e cobranças (`> 0`) |
| `BOOLEANO` | Estado lógico binário (`VERDADEIRO` / `FALSO`) | Valor padrão booleano definido para cada entidade |
| `ENUM(...)` | Domínio fechado de opções discretas | Restrito estritamente aos literais homologados |
| `JSON` | Estrutura de dados semiestruturada para logs de auditoria | Validade sintática de objeto estruturado |

---

## 2. Relações do Modelo Lógico

### 2.1 Relações Independentes e de Apoio Base

#### `UNIDADE`
- **Descrição**: Representa a filial física ou sede administrativa da rede de academias.
- **Chave Primária**: `id_unidade` (INTEIRO)
- **Atributos**:
  - `id_unidade`: [PK] Identificador exclusivo da unidade.
  - `nome`: [TEXTO(80), NOT NULL] Razão social ou nome fantasia da filial.
  - `cnpj`: [TEXTO(14), NOT NULL, UNIQUE] Cadastro Nacional da Pessoa Jurídica (14 dígitos numéricos).
    - Restrição: `CHECK (cnpj REGEXP '^[0-9]{14}$')`
  - `cidade`: [TEXTO(60), NOT NULL] Município sede da instalação.
  - `ativa`: [BOOLEANO, NOT NULL, DEFAULT VERDADEIRO] Indicador de funcionamento da unidade.
  - `criado_em`: [INSTANTE, NOT NULL] Registro temporal da criação.

#### `PLANO`
- **Descrição**: Catálogo corporativo de planos e serviços ofertados aos alunos.
- **Chave Primária**: `id_plano` (INTEIRO)
- **Atributos**:
  - `id_plano`: [PK] Identificador exclusivo do plano.
  - `nome`: [TEXTO(50), NOT NULL, UNIQUE] Nome comercial único do plano.
  - `periodicidade_meses`: [INTEIRO, NOT NULL] Ciclo de renovação em meses.
    - Restrição: `CHECK (periodicidade_meses > 0)`
  - `valor_mensal`: [MOEDA, NOT NULL] Valor mensal de tabela do catálogo.
    - Restrição: `CHECK (valor_mensal > 0)`
  - `carencia_dias`: [INTEIRO, NOT NULL, DEFAULT 0] Dias de tolerância de inadimplência antes de bloqueio.
  - `multa_percentual`: [DECIMAL, NOT NULL, DEFAULT 0.00] Percentual de multa por rescisão antecipada.
    - Restrição: `CHECK (multa_percentual >= 0)`
  - `ativo`: [BOOLEANO, NOT NULL, DEFAULT VERDADEIRO] Disponibilidade comercial para novas assinaturas.

#### `PAPEL`
- **Descrição**: Definição de papéis de privilégio no modelo de segurança RBAC.
- **Chave Primária**: `id_papel` (INTEIRO)
- **Atributos**:
  - `id_papel`: [PK] Identificador numérico do papel.
  - `nome`: [TEXTO(30), NOT NULL, UNIQUE] Denominação do perfil (`DBA`, `GERENTE`, `RECEPCAO`, `FINANCEIRO`, `INSTRUTOR`, `ALUNO`).

#### `CONTADOR_DOCUMENTO`
- **Descrição**: Entidade técnica para garantia de sequenciamento numérico atômico e determinístico por filial.
- **Chave Primária**: `(tipo, id_unidade)` (COMPOSTA)
- **Chaves Estrangeiras**:
  - `id_unidade`: [FK] Referencia `UNIDADE(id_unidade)`.
- **Atributos**:
  - `tipo`: [PK, ENUM('CONTRATO','NFSE'), NOT NULL] Espécie documental sequenciada.
  - `id_unidade`: [PK, FK, INTEIRO, NOT NULL] Unidade detentora da série numérica.
  - `ultimo`: [INTEIRO, NOT NULL, DEFAULT 0] Último número ordinal emitido.

---

### 2.2 Relações de Cadastro e Atores

#### `ALUNO`
- **Descrição**: Cliente cadastrado e vinculado a uma unidade física de referência.
- **Chave Primária**: `id_aluno` (INTEIRO)
- **Chaves Estrangeiras**:
  - `id_unidade`: [FK] Referencia `UNIDADE(id_unidade)`.
- **Chaves Únicas**:
  - `cpf`: [UNIQUE] Cadastro de Pessoa Física.
  - `email`: [UNIQUE] Correio eletrônico para autenticação e comunicações.
  - `(id_aluno, id_unidade)`: [UNIQUE COMPOSTO] Suporte à integridade referencial por unidade.
- **Atributos**:
  - `id_aluno`: [PK] Identificador único do aluno.
  - `id_unidade`: [FK, INTEIRO, NOT NULL] Filial de vínculo do aluno.
  - `nome`: [TEXTO(120), NOT NULL] Nome civil completo do cliente.
  - `cpf`: [TEXTO(11), NOT NULL, UNIQUE] 11 dígitos numéricos do CPF.
    - Restrição: `CHECK (cpf REGEXP '^[0-9]{11}$')`
  - `email`: [TEXTO(120), NOT NULL, UNIQUE] Endereço de correio eletrônico válido.
  - `data_nascimento`: [DATA, NOT NULL] Data de nascimento.
    - Restrição: `CHECK (data_nascimento >= '1900-01-01')`
  - `consentimento_lgpd_em`: [INSTANTE, NULL] Carimbo de consentimento nos termos da LGPD.
  - `ativo`: [BOOLEANO, NOT NULL, DEFAULT VERDADEIRO] Indicador de cadastro ativo.
  - `criado_em`: [INSTANTE, NOT NULL] Momento do cadastro.
  - `atualizado_em`: [INSTANTE, NOT NULL] Momento da última alteração.

#### `COLABORADOR`
- **Descrição**: Funcionário ou instrutor lotado em uma unidade de operação.
- **Chave Primária**: `id_colaborador` (INTEIRO)
- **Chaves Estrangeiras**:
  - `id_unidade`: [FK] Referencia `UNIDADE(id_unidade)`.
- **Chaves Únicas**:
  - `cpf`: [UNIQUE] Cadastro de Pessoa Física.
  - `(id_colaborador, id_unidade)`: [UNIQUE COMPOSTO] Suporte à integridade referencial por unidade.
- **Atributos**:
  - `id_colaborador`: [PK] Identificador exclusivo do funcionário.
  - `id_unidade`: [FK, INTEIRO, NOT NULL] Unidade de lotação.
  - `nome`: [TEXTO(120), NOT NULL] Nome civil completo.
  - `cpf`: [TEXTO(11), NOT NULL, UNIQUE] 11 dígitos numéricos do CPF.
    - Restrição: `CHECK (cpf REGEXP '^[0-9]{11}$')`
  - `cargo`: [TEXTO(40), NOT NULL] Designação profissional (ex.: `INSTRUTOR`, `RECEPCIONISTA`).
  - `ativo`: [BOOLEANO, NOT NULL, DEFAULT VERDADEIRO] Indicador de contrato de trabalho ativo.

---

### 2.3 Relações de Segurança e Acesso (RBAC)

#### `USUARIO`
- **Descrição**: Conta de credencial e autenticação no sistema.
- **Chave Primária**: `id_usuario` (INTEIRO)
- **Chaves Estrangeiras**:
  - `id_unidade`: [FK, NULL] Referencia `UNIDADE(id_unidade)`. Valor `NULL` denota acesso corporativo global (rede).
- **Atributos**:
  - `id_usuario`: [PK] Identificador da conta de usuário.
  - `login`: [TEXTO(60), NOT NULL, UNIQUE] Identificador de autenticação de acesso.
  - `nome`: [TEXTO(80), NOT NULL] Nome amigável de exibição.
  - `id_unidade`: [FK, INTEIRO, NULL] Escopo da filial ou visão corporativa.
  - `ativo`: [BOOLEANO, NOT NULL, DEFAULT VERDADEIRO] Status da conta.
  - `criado_em`: [INSTANTE, NOT NULL] Data/hora de registro.

#### `USUARIO_PAPEL` (Entidade Associativa N:N)
- **Descrição**: Relação associativa que resolve o relacionamento de muitos-para-muitos entre usuários e papéis do sistema.
- **Chave Primária**: `(id_usuario, id_papel)` (COMPOSTA)
- **Chaves Estrangeiras**:
  - `id_usuario`: [FK] Referencia `USUARIO(id_usuario)`.
  - `id_papel`: [FK] Referencia `PAPEL(id_papel)`.
- **Atributos**:
  - `id_usuario`: [PK, FK, INTEIRO, NOT NULL] Conta associada.
  - `id_papel`: [PK, FK, INTEIRO, NOT NULL] Perfil concedido.

---

### 2.4 Relações Comerciais e Financeiras

#### `CONTRATO`
- **Descrição**: Instrumento contratual firmado entre um aluno e uma unidade, aderindo a um plano comercial.
- **Chave Primária**: `id_contrato` (INTEIRO)
- **Chaves Estrangeiras**:
  - `(id_aluno, id_unidade)`: [FK COMPOSTA] Referencia `ALUNO(id_aluno, id_unidade)`.
  - `id_unidade`: [FK] Referencia `UNIDADE(id_unidade)`.
  - `id_plano`: [FK] Referencia `PLANO(id_plano)`.
- **Chaves Únicas**:
  - `numero`: [UNIQUE, NULL] Identificador formal do documento gerado via sequenciador.
  - `(id_aluno, status='ATIVO')`: [REGRA DE UNICIDADE LÓGICA CONDICIONAL] Cada aluno pode possuir no máximo 1 contrato ativo simultaneamente.
- **Atributos**:
  - `id_contrato`: [PK] Identificador numérico do contrato.
  - `numero`: [TEXTO(24), NULL, UNIQUE] Número formatado do contrato.
  - `id_aluno`: [FK, INTEIRO, NOT NULL] Aluno contratante.
  - `id_unidade`: [FK, INTEIRO, NOT NULL] Filial contratante (coincide com a unidade do aluno).
  - `id_plano`: [FK, INTEIRO, NOT NULL] Plano escolhido.
  - `data_inicio`: [DATA, NOT NULL] Início da vigência do contrato.
  - `data_fim`: [DATA, NULL] Término pactuado da vigência (opcional para planos recorrentes).
    - Restrição: `CHECK (data_fim IS NULL OR data_fim >= data_inicio)`
  - `dia_vencimento`: [INTEIRO, NOT NULL] Dia fixo de vencimento mensal da fatura.
    - Restrição: `CHECK (dia_vencimento BETWEEN 1 AND 28)`
  - `valor_mensal`: [MOEDA, NOT NULL] **SNAPSHOT IMUTÁVEL** do valor mensal negociado na assinatura. Não sofre alteração por reajustes futuros em `PLANO.valor_mensal`.
    - Restrição: `CHECK (valor_mensal > 0)`
  - `status`: [ENUM('ATIVO','SUSPENSO','CANCELADO'), NOT NULL, DEFAULT 'ATIVO'] Situação da vigência.
  - `assinado_em`: [INSTANTE, NOT NULL] Data e hora da celebração contratual.

*Nota de Abstração Lógica*: A coluna física gerada `ativo_unico` (usada no MySQL para emular índice único condicional) **NÃO existe** no modelo lógico. A regra é puramente declarativa no nível lógico.

#### `MENSALIDADE`
- **Descrição**: Título financeiro emitido periodicamente com base em um contrato ativo.
- **Chave Primária**: `id_mensalidade` (INTEIRO)
- **Chaves Estrangeiras**:
  - `id_contrato`: [FK] Referencia `CONTRATO(id_contrato)`.
- **Chaves Únicas**:
  - `(id_contrato, competencia)`: [UNIQUE COMPOSTO] Idempotência de faturamento (apenas uma fatura por competência por contrato).
- **Atributos**:
  - `id_mensalidade`: [PK] Identificador da fatura.
  - `id_contrato`: [FK, INTEIRO, NOT NULL] Contrato de origem.
  - `competencia`: [TEXTO(7), NOT NULL] Mês e ano de apuração no formato `AAAA-MM`.
    - Restrição: `CHECK (competencia REGEXP '^[0-9]{4}-(0[1-9]|1[0-2])$')`
  - `vencimento`: [DATA, NOT NULL] Data limite para pagamento sem incidência de mora.
  - `valor`: [MOEDA, NOT NULL] Valor base da mensalidade no período.
    - Restrição: `CHECK (valor > 0)`
  - `juros`: [MOEDA, NOT NULL, DEFAULT 0.00] Encargo por atraso acumulado.
    - Restrição: `CHECK (juros >= 0)`
  - `multa`: [MOEDA, NOT NULL, DEFAULT 0.00] Penalidade financeira por mora.
    - Restrição: `CHECK (multa >= 0)`
  - `desconto`: [MOEDA, NOT NULL, DEFAULT 0.00] Abatimento concedido.
    - Restrição: `CHECK (desconto >= 0 AND desconto <= valor)`
  - `status`: [ENUM('ABERTA','PARCIAL','PAGA','CANCELADA'), NOT NULL, DEFAULT 'ABERTA'] Estado da liquidação.
  - `criado_em`: [INSTANTE, NOT NULL] Data de emissão da cobrança.
  - `atualizado_em`: [INSTANTE, NOT NULL] Data da última modificação de status ou encargos.

#### `PAGAMENTO`
- **Descrição**: Evento financeiro de recebimento ou estorno vinculado a uma mensalidade.
- **Chave Primária**: `id_pagamento` (INTEIRO)
- **Chaves Estrangeiras**:
  - `id_mensalidade`: [FK] Referencia `MENSALIDADE(id_mensalidade)`.
  - `id_pagamento_original`: [FK, NULL] Auto-relacionamento para pagamentos de estorno referenciando o recebimento de origem.
- **Chaves Únicas**:
  - `id_externo`: [UNIQUE, NULL] Código de transação do gateway/banco (idempotência de baixa).
- **Atributos**:
  - `id_pagamento`: [PK] Identificador do lançamento.
  - `id_mensalidade`: [FK, INTEIRO, NOT NULL] Mensalidade liquidada ou estornada.
  - `tipo`: [ENUM('RECEBIMENTO','ESTORNO'), NOT NULL, DEFAULT 'RECEBIMENTO'] Fluxo contábil.
  - `valor`: [MOEDA, NOT NULL] Montante financeiro positivo movimentado.
    - Restrição: `CHECK (valor > 0)`
  - `forma`: [ENUM('PIX','BOLETO','CARTAO','DINHEIRO'), NOT NULL] Meio de liquidação.
  - `id_externo`: [TEXTO(64), NULL, UNIQUE] Identificador de idempotência externa.
  - `id_pagamento_original`: [FK, INTEIRO, NULL] Referência obrigatória no caso de `tipo = 'ESTORNO'`.
  - `pago_em`: [INSTANTE, NOT NULL] Carimbo de data/hora da confirmação do pagamento.

---

### 2.5 Relações Operacionais e Controle de Acesso

#### `TURMA`
- **Descrição**: Aula coletiva programada em sala e horário definidos, ministrada por um instrutor da unidade.
- **Chave Primária**: `id_turma` (INTEIRO)
- **Chaves Estrangeiras**:
  - `id_unidade`: [FK] Referencia `UNIDADE(id_unidade)`.
  - `(id_instrutor, id_unidade)`: [FK COMPOSTA] Referencia `COLABORADOR(id_colaborador, id_unidade)`.
- **Chaves Únicas**:
  - `(id_turma, id_unidade)`: [UNIQUE COMPOSTO] Suporte à integridade referencial por unidade.
- **Atributos**:
  - `id_turma`: [PK] Identificador exclusivo da turma.
  - `id_unidade`: [FK, INTEIRO, NOT NULL] Unidade física onde a aula ocorre.
  - `id_instrutor`: [FK, INTEIRO, NOT NULL] Colaborador responsável pela aula (da mesma filial).
  - `modalidade`: [TEXTO(50), NOT NULL] Descrição da atividade (ex.: Spinning, Pilates, Boxe).
  - `sala`: [TEXTO(30), NOT NULL] Designação da sala de aula nas instalações.
  - `capacidade`: [INTEIRO, NOT NULL] Lotação máxima de alunos admitidos simultaneamente.
    - Restrição: `CHECK (capacidade > 0)`
  - `inicio`: [INSTANTE, NOT NULL] Horário agendado para início da aula.
  - `fim`: [INSTANTE, NOT NULL] Horário agendado para encerramento da aula.
    - Restrição: `CHECK (fim > inicio)`

#### `RESERVA_TURMA` (Entidade Associativa N:N)
- **Descrição**: Resolve o relacionamento N:N entre `ALUNO` e `TURMA`, gerenciando a ocupação da grade de horários e a fila de espera.
- **Chave Primária**: `id_reserva` (INTEIRO)
- **Chaves Estrangeiras**:
  - `(id_turma, id_unidade)`: [FK COMPOSTA] Referencia `TURMA(id_turma, id_unidade)`.
  - `(id_aluno, id_unidade)`: [FK COMPOSTA] Referencia `ALUNO(id_aluno, id_unidade)`.
  - `id_unidade`: [FK] Referencia `UNIDADE(id_unidade)`.
- **Chaves Únicas**:
  - `(id_turma, id_aluno)`: [UNIQUE COMPOSTO] Impede reservas duplicadas do mesmo aluno na mesma turma.
- **Atributos**:
  - `id_reserva`: [PK] Identificador surrogate da reserva.
  - `id_turma`: [FK, INTEIRO, NOT NULL] Turma reservada.
  - `id_aluno`: [FK, INTEIRO, NOT NULL] Aluno inscrito.
  - `id_unidade`: [FK, INTEIRO, NOT NULL] Filial da reserva (conforme integridade composta).
  - `status`: [ENUM('CONFIRMADA','ESPERA','CANCELADA'), NOT NULL, DEFAULT 'CONFIRMADA'] Situação da vaga.
  - `reservada_em`: [INSTANTE, NOT NULL] Carimbo de data/hora do agendamento.

#### `ACESSO`
- **Descrição**: Registro cronológico de passagens ou tentativas de entrada de alunos pela catraca física da unidade.
- **Chave Primária**: `id_acesso` (INTEIRO)
- **Chaves Estrangeiras**:
  - `(id_aluno, id_unidade)`: [FK COMPOSTA] Referencia `ALUNO(id_aluno, id_unidade)`.
  - `id_unidade`: [FK] Referencia `UNIDADE(id_unidade)`.
- **Atributos**:
  - `id_acesso`: [PK] Identificador do registro de catraca.
  - `id_aluno`: [FK, INTEIRO, NOT NULL] Aluno solicitante do acesso.
  - `id_unidade`: [FK, INTEIRO, NOT NULL] Unidade onde a catraca está instalada.
  - `data_hora`: [INSTANTE, NOT NULL] Instante da leitura de acesso.
  - `liberado`: [BOOLEANO, NOT NULL, DEFAULT FALSO] Flag de autorização concedida pela catraca.
  - `motivo`: [TEXTO(40), NOT NULL, DEFAULT ''] Justificativa em caso de recusa (ex.: INADIMPLENTE, SEM CONTRATO ATIVO).

---

### 2.6 Relações Técnicas e de Auditoria

#### `AUDITORIA_LOG`
- **Descrição**: Trilha técnica de auditoria com captura de estados anteriores e posteriores para operações transacionais críticas.
- **Chave Primária**: `id_log` (INTEIRO)
- **Atributos**:
  - `id_log`: [PK] Identificador sequencial do registro de auditoria.
  - `tabela`: [TEXTO(64), NOT NULL] Nome da relação afetada pela operação.
  - `operacao`: [ENUM('INSERT','UPDATE','DELETE'), NOT NULL] Tipo da operação DML.
  - `chave_pk`: [TEXTO(64), NOT NULL] Chave primária da linha modificada em formato textual.
  - `antes`: [JSON, NULL] Fotografia dos atributos antes da modificação (nulo para `INSERT`).
  - `depois`: [JSON, NULL] Fotografia dos atributos após a modificação (nulo para `DELETE`).
  - `conta_mysql`: [TEXTO(100), NOT NULL] Identidade do usuário/conta de banco de dados responsável.
  - `ocorrido_em`: [INSTANTE, NOT NULL] Carimbo temporal exato do evento.
