# Matriz de Integridade Lógica Declarativa (PK / FK / UK / CK)

**Projeto**: Kaizen BD — Camada de Banco de Dados Relacional  
**Módulo**: `modulo_modelo_logico_e_dicionario_de_dados` (`BK-DB-02`)  
**Objetivo**: Consolidar de forma exaustiva todas as Chaves Primárias (`PK`), Chaves Estrangeiras simples e compostas (`FK`), Restrições de Unicidade (`UK`) e Restrições de Checagem (`CK`) das 15 relações do modelo lógico, impedindo que o modelo físico invente regras não especificadas.

---

## 1. Matriz Completa das 15 Relações

| # | Relação | Chave Primária (`PK`) | Chaves Estrangeiras (`FK`) | Chaves Únicas (`UK`) | Restrições de Checagem (`CK`) |
|---|---|---|---|---|---|
| 1 | `UNIDADE` | `id_unidade` | — | `cnpj` | `cnpj REGEXP '^[0-9]{14}$'` |
| 2 | `CONTADOR_DOCUMENTO` | `(tipo, id_unidade)` | `id_unidade → UNIDADE(id_unidade)` | — | `tipo IN ('CONTRATO','NFSE')`; `ultimo >= 0` |
| 3 | `PAPEL` | `id_papel` | — | `nome` | — |
| 4 | `USUARIO` | `id_usuario` | `id_unidade → UNIDADE(id_unidade)` (`NULL` permitido) | `login` | — |
| 5 | `USUARIO_PAPEL` | `(id_usuario, id_papel)` | `id_usuario → USUARIO(id_usuario)`; `id_papel → PAPEL(id_papel)` | — | — |
| 6 | `ALUNO` | `id_aluno` | `id_unidade → UNIDADE(id_unidade)` | `cpf`; `email`; `(id_aluno, id_unidade)` | `cpf REGEXP '^[0-9]{11}$'`; `data_nascimento >= '1900-01-01'` |
| 7 | `COLABORADOR` | `id_colaborador` | `id_unidade → UNIDADE(id_unidade)` | `cpf`; `(id_colaborador, id_unidade)` | `cpf REGEXP '^[0-9]{11}$'` |
| 8 | `PLANO` | `id_plano` | — | `nome` | `periodicidade_meses > 0`; `valor_mensal > 0`; `carencia_dias >= 0`; `multa_percentual >= 0` |
| 9 | `TURMA` | `id_turma` | `id_unidade → UNIDADE(id_unidade)`; `(id_instrutor, id_unidade) → COLABORADOR(id_colaborador, id_unidade)` | `(id_turma, id_unidade)` | `capacidade > 0`; `fim > inicio` |
| 10 | `CONTRATO` | `id_contrato` | `(id_aluno, id_unidade) → ALUNO(id_aluno, id_unidade)`; `id_unidade → UNIDADE(id_unidade)`; `id_plano → PLANO(id_plano)` | `numero`; `(id_aluno, status='ATIVO')` [unicidade lógica condicional] | `dia_vencimento BETWEEN 1 AND 28`; `data_fim IS NULL OR data_fim >= data_inicio`; `valor_mensal > 0` |
| 11 | `MENSALIDADE` | `id_mensalidade` | `id_contrato → CONTRATO(id_contrato)` | `(id_contrato, competencia)` | `competencia REGEXP '^[0-9]{4}-(0[1-9]|1[0-2])$'`; `valor > 0`; `juros >= 0`; `multa >= 0`; `desconto >= 0 AND desconto <= valor` |
| 12 | `PAGAMENTO` | `id_pagamento` | `id_mensalidade → MENSALIDADE(id_mensalidade)`; `id_pagamento_original → PAGAMENTO(id_pagamento)` (`NULL` permitido) | `id_externo` | `valor > 0`; `tipo IN ('RECEBIMENTO','ESTORNO')`; `forma IN ('PIX','CARTAO','BOLETO','DINHEIRO')` |
| 13 | `ACESSO` | `id_acesso` | `(id_aluno, id_unidade) → ALUNO(id_aluno, id_unidade)`; `id_unidade → UNIDADE(id_unidade)` | — | — |
| 14 | `RESERVA_TURMA` | `id_reserva` | `(id_turma, id_unidade) → TURMA(id_turma, id_unidade)`; `(id_aluno, id_unidade) → ALUNO(id_aluno, id_unidade)`; `id_unidade → UNIDADE(id_unidade)` | `(id_turma, id_aluno)` | `status IN ('CONFIRMADA','ESPERA','CANCELADA')` |
| 15 | `AUDITORIA_LOG` | `id_log` | — | — | `operacao IN ('INSERT','UPDATE','DELETE')` |

---

## 2. Chaves Únicas de Apoio para Integridade Referencial Composta

Para viabilizar a integridade referencial composta por unidade nas relações filhas, três relações-mãe expõem chaves únicas compostas explícitas:

1. `ALUNO`: `UK (id_aluno, id_unidade)` — referenciada por `CONTRATO`, `ACESSO` e `RESERVA_TURMA`.
2. `COLABORADOR`: `UK (id_colaborador, id_unidade)` — referenciada por `TURMA`.
3. `TURMA`: `UK (id_turma, id_unidade)` — referenciada por `RESERVA_TURMA`.

---

## 3. Políticas Referenciais Lógicas (`ON DELETE` / `ON UPDATE`)

- Em todas as Chaves Estrangeiras (`FK`) do esquema lógico, a política padrão é:
  - **Exclusão (`ON DELETE`)**: `RESTRICT` — registros-pai com histórico dependente nunca são removidos fisicamente (usa-se inativação lógica via `ativa`/`ativo` ou anonimização LGPD em `ALUNO`).
  - **Atualização (`ON UPDATE`)**: `RESTRICT` — chaves primárias substitutas e códigos de unidade são imutáveis.
