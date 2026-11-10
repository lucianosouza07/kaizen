# Dicionário de Dados Relacional e Esquema Lógico (15 Relações)

**Projeto**: Kaizen BD — Camada de Banco de Dados Relacional  
**Módulo**: `modulo_modelo_logico_e_dicionario_de_dados` (`BK-DB-02`)  
**Nível de Abstração**: Modelo Lógico Relacional em 3FN (independente de colunas físicas artificiais de SGBD).

---

## 1. Catálogo de Domínios Lógicos Abstratos

| Domínio Lógico | Descrição Semântica | Regra Geral de Representação |
|---|---|---|
| `INTEIRO` | Número inteiro exato para identificadores, contadores, capacidades e prazos em dias/meses | Inteiro sem casas decimais |
| `TEXTO(n)` | Cadeia de caracteres de tamanho máximo `n` (fixo para códigos padronizados como CPF/CNPJ/competência ou variável para nomes/e-mails) | Unicode insensível a acentos e caixa |
| `DATA` | Data civil de calendário (`AAAA-MM-DD`) sem componente de fuso horário | Datas de nascimento, vigência e vencimento |
| `INSTANTE` | Carimbo de tempo preciso em UTC (`AAAA-MM-DD HH:MM:SS.fff`) | Eventos transacionais e trilhas temporais |
| `MOEDA` | Valor monetário decimal exato com 10 dígitos de precisão e 2 casas decimais (`DECIMAL(10,2)`) | Proibido ponto flutuante aproximado |
| `DECIMAL(p,s)` | Valor numérico decimal exato para percentuais (ex.: `multa_percentual`) | Precisão `p` e escala `s` fixas |
| `BOOLEANO` | Valor lógico binário (`VERDADEIRO` / `FALSO`, representado por `1` / `0`) | Flags de estado ativo e liberação |
| `ENUM(...)` | Conjunto fechado de valores simbólicos de domínio | Estados de ciclo de vida e tipos fechados |
| `JSON` | Documento estruturado para retenção de carga técnica de auditoria (`antes`/`depois`) | Exclusivo da relação técnica `AUDITORIA_LOG` |

---

## 2. Esquema Relacional Lógico das 15 Relações

**Notação**: `**negrito**` = PK · `*itálico*` = FK · `[UK]` = UNIQUE · `[CK]` = CHECK · `NN` = NOT NULL · `NULL` = Opcional.

```text
1.  UNIDADE( **id_unidade**, nome NN, cnpj[UK][CK] NN, cidade NN, ativa NN, criado_em NN )

2.  CONTADOR_DOCUMENTO( **tipo**[CK], **id_unidade***→UNIDADE*, ultimo[CK] NN )

3.  PAPEL( **id_papel**, nome[UK] NN )

4.  USUARIO( **id_usuario**, login[UK] NN, nome NN, *id_unidade→UNIDADE* NULL, ativo NN, criado_em NN )

5.  USUARIO_PAPEL( **id_usuario***→USUARIO*, **id_papel***→PAPEL* )

6.  ALUNO( **id_aluno**, *id_unidade→UNIDADE* NN, nome NN, cpf[UK][CK] NN, email[UK] NN,
           data_nascimento[CK] NN, consentimento_lgpd_em NULL, ativo NN, criado_em NN,
           atualizado_em NN )
    [UK composta: (id_aluno, id_unidade)]

7.  COLABORADOR( **id_colaborador**, *id_unidade→UNIDADE* NN, nome NN, cpf[UK][CK] NN,
                 cargo NN, ativo NN )
    [UK composta: (id_colaborador, id_unidade)]

8.  PLANO( **id_plano**, nome[UK] NN, periodicidade_meses[CK] NN, valor_mensal[CK] NN,
           carencia_dias[CK] NN, multa_percentual[CK] NN, ativo NN )

9.  TURMA( **id_turma**, *id_unidade→UNIDADE* NN, *(id_instrutor, id_unidade)→COLABORADOR* NN,
           modalidade NN, sala NN, capacidade[CK] NN, inicio NN, fim[CK] NN )
    [UK composta: (id_turma, id_unidade)]

10. CONTRATO( **id_contrato**, numero[UK] NULL, *(id_aluno, id_unidade)→ALUNO* NN,
              *id_unidade→UNIDADE* NN, *id_plano→PLANO* NN, data_inicio NN,
              data_fim[CK] NULL, dia_vencimento[CK] NN, valor_mensal[CK] NN [SNAPSHOT],
              status[CK] NN, assinado_em NN )
    [UK lógica condicional: (id_aluno, status='ATIVO')]

11. MENSALIDADE( **id_mensalidade**, *id_contrato→CONTRATO* NN, competencia[CK] NN,
                 vencimento NN, valor[CK] NN, juros[CK] NN, multa[CK] NN,
                 desconto[CK] NN, status[CK] NN, criado_em NN, atualizado_em NN )
    [UK composta: (id_contrato, competencia)]

12. PAGAMENTO( **id_pagamento**, *id_mensalidade→MENSALIDADE* NN, tipo[CK] NN,
               valor[CK] NN, forma[CK] NN, id_externo[UK] NULL,
               *id_pagamento_original→PAGAMENTO* NULL, pago_em NN )

13. ACESSO( **id_acesso**, *(id_aluno, id_unidade)→ALUNO* NN, *id_unidade→UNIDADE* NN,
            data_hora NN, liberado NN, motivo NN )

14. RESERVA_TURMA( **id_reserva**, *(id_turma, id_unidade)→TURMA* NN,
                   *(id_aluno, id_unidade)→ALUNO* NN, *id_unidade→UNIDADE* NN,
                   status[CK] NN, reservada_em NN )
    [UK composta: (id_turma, id_aluno)]

15. AUDITORIA_LOG( **id_log**, tabela NN, operacao[CK] NN, chave_pk NN,
                   antes NULL, depois NULL, conta_mysql NN, ocorrido_em NN )
```

---

## 3. Dicionário de Dados Detalhado por Relação

### 3.1 `UNIDADE` (Domínio: Cadastro)
| Atributo | Domínio Lógico | Nulabilidade | Restrições (`PK/FK/UK/CK`) | Descrição Semântica |
|---|---|---|---|---|
| `id_unidade` | `INTEIRO` | `NOT NULL` | `PK` | Identificador único da unidade/filial da academia. |
| `nome` | `TEXTO(80)` | `NOT NULL` | — | Nome operacional da unidade. |
| `cnpj` | `TEXTO(14)` | `NOT NULL` | `UK`, `CK (cnpj REGEXP '^[0-9]{14}$')` | CNPJ numérico de 14 dígitos sem máscara. |
| `cidade` | `TEXTO(60)` | `NOT NULL` | — | Município de localização da unidade. |
| `ativa` | `BOOLEANO` | `NOT NULL` | Default `1` | Indica se a unidade está em operação ativa. |
| `criado_em` | `INSTANTE` | `NOT NULL` | — | Instante UTC de criação do registro. |

### 3.2 `CONTADOR_DOCUMENTO` (Relação Técnica de Apoio)
| Atributo | Domínio Lógico | Nulabilidade | Restrições (`PK/FK/UK/CK`) | Descrição Semântica |
|---|---|---|---|---|
| `tipo` | `ENUM('CONTRATO','NFSE')` | `NOT NULL` | `PK (parte 1)`, `CK` | Série documental controlada por unidade. |
| `id_unidade` | `INTEIRO` | `NOT NULL` | `PK (parte 2)`, `FK → UNIDADE(id_unidade)` | Unidade proprietária da série numérica. |
| `ultimo` | `INTEIRO` | `NOT NULL` | `CK (ultimo >= 0)`, Default `0` | Último número sequencial emitido na série/unidade. |

### 3.3 `PAPEL` (Domínio: Segurança / RBAC)
| Atributo | Domínio Lógico | Nulabilidade | Restrições (`PK/FK/UK/CK`) | Descrição Semântica |
|---|---|---|---|---|
| `id_papel` | `INTEIRO` | `NOT NULL` | `PK` | Identificador único do papel de segurança. |
| `nome` | `TEXTO(30)` | `NOT NULL` | `UK` | Nome canônico do perfil RBAC (ex.: `ROLE_DBA`, `ROLE_RECEPCAO`). |

### 3.4 `USUARIO` (Domínio: Segurança / RBAC)
| Atributo | Domínio Lógico | Nulabilidade | Restrições (`PK/FK/UK/CK`) | Descrição Semântica |
|---|---|---|---|---|
| `id_usuario` | `INTEIRO` | `NOT NULL` | `PK` | Identificador único da conta de operador. |
| `login` | `TEXTO(60)` | `NOT NULL` | `UK` | Identificador de login único do operador. |
| `nome` | `TEXTO(80)` | `NOT NULL` | — | Nome completo do usuário do sistema. |
| `id_unidade` | `INTEIRO` | `NULL` | `FK → UNIDADE(id_unidade)` | Unidade de escopo do usuário; `NULL` indica escopo corporativo de rede. |
| `ativo` | `BOOLEANO` | `NOT NULL` | Default `1` | Indica se a conta de usuário está ativa. |
| `criado_em` | `INSTANTE` | `NOT NULL` | — | Instante UTC de criação da conta. |

### 3.5 `USUARIO_PAPEL` (Domínio: Associativa RBAC — Resolução `N : N`)
| Atributo | Domínio Lógico | Nulabilidade | Restrições (`PK/FK/UK/CK`) | Descrição Semântica |
|---|---|---|---|---|
| `id_usuario` | `INTEIRO` | `NOT NULL` | `PK (parte 1)`, `FK → USUARIO(id_usuario)` | Usuário que recebe a concessão do papel. |
| `id_papel` | `INTEIRO` | `NOT NULL` | `PK (parte 2)`, `FK → PAPEL(id_papel)` | Papel RBAC concedido ao usuário. |

### 3.6 `ALUNO` (Domínio: Cadastro)
| Atributo | Domínio Lógico | Nulabilidade | Restrições (`PK/FK/UK/CK`) | Descrição Semântica |
|---|---|---|---|---|
| `id_aluno` | `INTEIRO` | `NOT NULL` | `PK`, `UK composta (id_aluno, id_unidade)` | Identificador único do aluno. |
| `id_unidade` | `INTEIRO` | `NOT NULL` | `FK → UNIDADE(id_unidade)`, `UK composta (id_aluno, id_unidade)` | Unidade de matrícula do aluno. |
| `nome` | `TEXTO(120)` | `NOT NULL` | — | Nome civil completo do aluno. |
| `cpf` | `TEXTO(11)` | `NOT NULL` | `UK`, `CK (cpf REGEXP '^[0-9]{11}$')` | CPF numérico de 11 dígitos. |
| `email` | `TEXTO(120)` | `NOT NULL` | `UK` | Endereço de e-mail único (case-insensitive). |
| `data_nascimento` | `DATA` | `NOT NULL` | `CK (data_nascimento >= '1900-01-01')` | Data de nascimento do aluno. |
| `consentimento_lgpd_em` | `INSTANTE` | `NULL` | — | Instante de registro do consentimento LGPD (`NULL` após anonimização). |
| `ativo` | `BOOLEANO` | `NOT NULL` | Default `1` | Indicador de cadastro ativo. |
| `criado_em` | `INSTANTE` | `NOT NULL` | — | Instante UTC de criação do cadastro. |
| `atualizado_em` | `INSTANTE` | `NOT NULL` | — | Instante UTC da última atualização cadastral. |

### 3.7 `COLABORADOR` (Domínio: Cadastro)
| Atributo | Domínio Lógico | Nulabilidade | Restrições (`PK/FK/UK/CK`) | Descrição Semântica |
|---|---|---|---|---|
| `id_colaborador` | `INTEIRO` | `NOT NULL` | `PK`, `UK composta (id_colaborador, id_unidade)` | Identificador único do colaborador/instrutor. |
| `id_unidade` | `INTEIRO` | `NOT NULL` | `FK → UNIDADE(id_unidade)`, `UK composta (id_colaborador, id_unidade)` | Unidade de lotação do colaborador. |
| `nome` | `TEXTO(120)` | `NOT NULL` | — | Nome completo do colaborador. |
| `cpf` | `TEXTO(11)` | `NOT NULL` | `UK`, `CK (cpf REGEXP '^[0-9]{11}$')` | CPF numérico de 11 dígitos. |
| `cargo` | `TEXTO(40)` | `NOT NULL` | — | Cargo ou função exercida (ex.: `INSTRUTOR`). |
| `ativo` | `BOOLEANO` | `NOT NULL` | Default `1` | Indicador de vínculo funcional ativo. |

### 3.8 `PLANO` (Domínio: Comercial)
| Atributo | Domínio Lógico | Nulabilidade | Restrições (`PK/FK/UK/CK`) | Descrição Semântica |
|---|---|---|---|---|
| `id_plano` | `INTEIRO` | `NOT NULL` | `PK` | Identificador único do plano no catálogo. |
| `nome` | `TEXTO(50)` | `NOT NULL` | `UK` | Nome comercial único do plano. |
| `periodicidade_meses` | `INTEIRO` | `NOT NULL` | `CK (periodicidade_meses > 0)` | Duração do ciclo contratual em meses. |
| `valor_mensal` | `MOEDA` | `NOT NULL` | `CK (valor_mensal > 0)` | Preço mensal vigente no catálogo. |
| `carencia_dias` | `INTEIRO` | `NOT NULL` | `CK (carencia_dias >= 0)`, Default `0` | Dias de carência contratual. |
| `multa_percentual` | `DECIMAL(5,2)` | `NOT NULL` | `CK (multa_percentual >= 0)`, Default `0.00` | Percentual de multa rescisória. |
| `ativo` | `BOOLEANO` | `NOT NULL` | Default `1` | Indica se o plano está disponível para venda. |

### 3.9 `TURMA` (Domínio: Operação)
| Atributo | Domínio Lógico | Nulabilidade | Restrições (`PK/FK/UK/CK`) | Descrição Semântica |
|---|---|---|---|---|
| `id_turma` | `INTEIRO` | `NOT NULL` | `PK`, `UK composta (id_turma, id_unidade)` | Identificador único da sessão de aula coletiva. |
| `id_unidade` | `INTEIRO` | `NOT NULL` | `FK → UNIDADE(id_unidade)`, `UK composta (id_turma, id_unidade)` | Unidade onde a aula é realizada. |
| `id_instrutor` | `INTEIRO` | `NOT NULL` | `FK composta (id_instrutor, id_unidade) → COLABORADOR(id_colaborador, id_unidade)` | Instrutor responsável lotado na mesma unidade. |
| `modalidade` | `TEXTO(50)` | `NOT NULL` | — | Nome da modalidade coletiva (ex.: `Spinning`, `Pilates`). |
| `sala` | `TEXTO(30)` | `NOT NULL` | — | Identificação da sala física na unidade. |
| `capacidade` | `INTEIRO` | `NOT NULL` | `CK (capacidade > 0)` | Lotação máxima permitida de alunos confirmados. |
| `inicio` | `INSTANTE` | `NOT NULL` | — | Data e hora de início da aula. |
| `fim` | `INSTANTE` | `NOT NULL` | `CK (fim > inicio)` | Data e hora de término da aula (posterior ao início). |

### 3.10 `CONTRATO` (Domínio: Comercial)
| Atributo | Domínio Lógico | Nulabilidade | Restrições (`PK/FK/UK/CK`) | Descrição Semântica |
|---|---|---|---|---|
| `id_contrato` | `INTEIRO` | `NOT NULL` | `PK` | Identificador único do contrato. |
| `numero` | `TEXTO(24)` | `NULL` | `UK` | Código padronizado (`CTR-AAAA-NNNNNN`) atribuído na criação. |
| `id_aluno` | `INTEIRO` | `NOT NULL` | `FK composta (id_aluno, id_unidade) → ALUNO(id_aluno, id_unidade)`, `UK condicional (id_aluno, status='ATIVO')` | Aluno titular do contrato. |
| `id_unidade` | `INTEIRO` | `NOT NULL` | `FK → UNIDADE(id_unidade)` | Unidade celebrante (mesma unidade do aluno). |
| `id_plano` | `INTEIRO` | `NOT NULL` | `FK → PLANO(id_plano)` | Plano escolhido no ato da contratação. |
| `data_inicio` | `DATA` | `NOT NULL` | — | Data de início da vigência contratual. |
| `data_fim` | `DATA` | `NULL` | `CK (data_fim IS NULL OR data_fim >= data_inicio)` | Data final de vigência (quando aplicável). |
| `dia_vencimento` | `INTEIRO` | `NOT NULL` | `CK (dia_vencimento BETWEEN 1 AND 28)` | Dia do mês para vencimento das mensalidades (1 a 28). |
| `valor_mensal` | `MOEDA` | `NOT NULL` | `CK (valor_mensal > 0)` | **Snapshot imutável** do valor mensal contratado na assinatura. |
| `status` | `ENUM('ATIVO','SUSPENSO','CANCELADO','ENCERRADO')` | `NOT NULL` | `UK condicional (id_aluno, status='ATIVO')` | Estado atual do contrato; no máximo 1 contrato `ATIVO` por aluno. |
| `assinado_em` | `INSTANTE` | `NOT NULL` | — | Instante UTC da assinatura do contrato. |

### 3.11 `MENSALIDADE` (Domínio: Financeiro)
| Atributo | Domínio Lógico | Nulabilidade | Restrições (`PK/FK/UK/CK`) | Descrição Semântica |
|---|---|---|---|---|
| `id_mensalidade` | `INTEIRO` | `NOT NULL` | `PK` | Identificador único da fatura/mensalidade. |
| `id_contrato` | `INTEIRO` | `NOT NULL` | `FK → CONTRATO(id_contrato)`, `UK composta (id_contrato, competencia)` | Contrato gerador da obrigação mensal. |
| `competencia` | `TEXTO(7)` | `NOT NULL` | `UK composta (id_contrato, competencia)`, `CK (competencia REGEXP '^[0-9]{4}-(0[1-9]|1[0-2])$')` | Ano e mês de referência no formato `AAAA-MM`. |
| `vencimento` | `DATA` | `NOT NULL` | — | Data de vencimento da cobrança. |
| `valor` | `MOEDA` | `NOT NULL` | `CK (valor > 0)` | Valor principal nominal da mensalidade. |
| `juros` | `MOEDA` | `NOT NULL` | `CK (juros >= 0)`, Default `0.00` | Encargo de juros moratórios. |
| `multa` | `MOEDA` | `NOT NULL` | `CK (multa >= 0)`, Default `0.00` | Encargo de multa por atraso. |
| `desconto` | `MOEDA` | `NOT NULL` | `CK (desconto >= 0 AND desconto <= valor)`, Default `0.00` | Desconto concedido limitado ao valor principal. |
| `status` | `ENUM('ABERTA','PAGA','ATRASADA','CANCELADA')` | `NOT NULL` | Default `'ABERTA'` | Situação financeira atual da mensalidade. |
| `criado_em` | `INSTANTE` | `NOT NULL` | — | Instante UTC de geração da mensalidade. |
| `atualizado_em` | `INSTANTE` | `NOT NULL` | — | Instante UTC da última atualização de status/valores. |

### 3.12 `PAGAMENTO` (Domínio: Financeiro)
| Atributo | Domínio Lógico | Nulabilidade | Restrições (`PK/FK/UK/CK`) | Descrição Semântica |
|---|---|---|---|---|
| `id_pagamento` | `INTEIRO` | `NOT NULL` | `PK` | Identificador único do lançamento financeiro. |
| `id_mensalidade` | `INTEIRO` | `NOT NULL` | `FK → MENSALIDADE(id_mensalidade)` | Mensalidade vinculada ao pagamento ou estorno. |
| `tipo` | `ENUM('RECEBIMENTO','ESTORNO')` | `NOT NULL` | `CK` | Natureza da operação financeira. |
| `valor` | `MOEDA` | `NOT NULL` | `CK (valor > 0)` | Valor estritamente positivo movimentado no evento. |
| `forma` | `ENUM('PIX','CARTAO','BOLETO','DINHEIRO')` | `NOT NULL` | `CK` | Meio de pagamento utilizado. |
| `id_externo` | `TEXTO(64)` | `NULL` | `UK` | Identificador externo de idempotência do gateway/transação. |
| `id_pagamento_original` | `INTEIRO` | `NULL` | `FK → PAGAMENTO(id_pagamento)` | Autorreferência ao recebimento original quando `tipo = 'ESTORNO'`. |
| `pago_em` | `INSTANTE` | `NOT NULL` | — | Instante UTC em que o recebimento ou estorno foi registrado. |

### 3.13 `ACESSO` (Domínio: Operação)
| Atributo | Domínio Lógico | Nulabilidade | Restrições (`PK/FK/UK/CK`) | Descrição Semântica |
|---|---|---|---|---|
| `id_acesso` | `INTEIRO` | `NOT NULL` | `PK` | Identificador único do evento de passagem na catraca. |
| `id_aluno` | `INTEIRO` | `NOT NULL` | `FK composta (id_aluno, id_unidade) → ALUNO(id_aluno, id_unidade)` | Aluno que solicitou passagem na catraca. |
| `id_unidade` | `INTEIRO` | `NOT NULL` | `FK → UNIDADE(id_unidade)` | Unidade da catraca acionada. |
| `data_hora` | `INSTANTE` | `NOT NULL` | — | Instante UTC da leitura de acesso. |
| `liberado` | `BOOLEANO` | `NOT NULL` | — | Decisão de liberação (`1` = liberado, `0` = bloqueado). |
| `motivo` | `TEXTO(40)` | `NOT NULL` | — | Código/descrição do motivo da decisão (ex.: `OK`, `INADIMPLENTE`). |

### 3.14 `RESERVA_TURMA` (Domínio: Associativa Operação — Resolução `N : N`)
| Atributo | Domínio Lógico | Nulabilidade | Restrições (`PK/FK/UK/CK`) | Descrição Semântica |
|---|---|---|---|---|
| `id_reserva` | `INTEIRO` | `NOT NULL` | `PK` | Identificador único da reserva de turma. |
| `id_turma` | `INTEIRO` | `NOT NULL` | `FK composta (id_turma, id_unidade) → TURMA(id_turma, id_unidade)`, `UK composta (id_turma, id_aluno)` | Turma coletiva objeto da reserva. |
| `id_aluno` | `INTEIRO` | `NOT NULL` | `FK composta (id_aluno, id_unidade) → ALUNO(id_aluno, id_unidade)`, `UK composta (id_turma, id_aluno)` | Aluno solicitante da vaga. |
| `id_unidade` | `INTEIRO` | `NOT NULL` | `FK → UNIDADE(id_unidade)` | Unidade compartilhada entre aluno e turma. |
| `status` | `ENUM('CONFIRMADA','ESPERA','CANCELADA')` | `NOT NULL` | `CK (status IN ('CONFIRMADA','ESPERA','CANCELADA'))` | Estado da reserva na turma. |
| `reservada_em` | `INSTANTE` | `NOT NULL` | — | Instante UTC da solicitação da reserva. |

### 3.15 `AUDITORIA_LOG` (Relação Técnica de Apoio)
| Atributo | Domínio Lógico | Nulabilidade | Restrições (`PK/FK/UK/CK`) | Descrição Semântica |
|---|---|---|---|---|
| `id_log` | `INTEIRO` | `NOT NULL` | `PK` | Identificador sequencial do evento de auditoria. |
| `tabela` | `TEXTO(64)` | `NOT NULL` | — | Nome da relação auditada. |
| `operacao` | `ENUM('INSERT','UPDATE','DELETE')` | `NOT NULL` | `CK (operacao IN ('INSERT','UPDATE','DELETE'))` | Tipo de comando DML auditado. |
| `chave_pk` | `TEXTO(64)` | `NOT NULL` | — | Valor textual da chave primária do registro afetado. |
| `antes` | `JSON` | `NULL` | — | Estado anterior da tupla em formato JSON. |
| `depois` | `JSON` | `NULL` | — | Estado posterior da tupla em formato JSON. |
| `conta_mysql` | `TEXTO(100)` | `NOT NULL` | — | Conta autenticada no SGBD que executou a alteração. |
| `ocorrido_em` | `INSTANTE` | `NOT NULL` | — | Instante UTC exato da operação. |
