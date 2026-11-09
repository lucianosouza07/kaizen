# Regras de Confinamento Multiunidade e Validação de Acessos — Kaizen BD

**Módulo**: `modulo_modelo_logico_e_dicionario_de_dados`
**Objetivo**: Especificar as diretrizes de integridade arquitetural para operação em rede multiunidade (filiais compartilhando o mesmo schema transacional).

---

## 1. Princípio do Confinamento por Unidade

A rede de academias Kaizen opera sob o padrão de **banco de dados compartilhado com segregação relacional por unidade**. Para garantir que os dados de diferentes filiais não se misturem inadvertidamente e que as regras de negócio sejam invioláveis no próprio banco de dados, o modelo lógico adota o princípio do confinamento declarativo.

### Propagação Controlada de `id_unidade`
O atributo `id_unidade` atua não apenas como identificador da filial proprietária, mas como componente de **chaves alternativas compostas** e **chaves estrangeiras compostas**:

```text
UNIDADE
  │
  ├──> ALUNO(id_aluno, id_unidade) ───────┐
  │                                        ├──> CONTRATO(id_aluno, id_unidade)
  ├──> COLABORADOR(id_colaborador, id_unidade)
  │         │
  │         └──> TURMA(id_turma, id_unidade, id_instrutor)
  │                   │
  │                   └──> RESERVA_TURMA(id_turma, id_unidade, id_aluno)
  │
  └──> ACESSO(id_aluno, id_unidade)
```

---

## 2. Garantias Declarativas por Entidade

### 2.1 Aluno e Contrato
- Um contrato é celebrado obrigatoriamente na unidade do aluno (`CONTRATO(id_aluno, id_unidade) -> ALUNO(id_aluno, id_unidade)`).
- **Impacto**: É impossível criar um contrato na filial "Matriz Salvador" para um aluno cuja matrícula pertença à filial "Alagoinhas" sem realizar um procedimento explícito de transferência de cadastro.

### 2.2 Instrutor e Turma
- A grade de turmas vincula o instrutor e a aula à mesma unidade física (`TURMA(id_instrutor, id_unidade) -> COLABORADOR(id_colaborador, id_unidade)`).
- **Impacto**: Impede que um instrutor lotado em uma unidade seja acidentalmente alocado para aulas de outra unidade no mesmo horário.

### 2.3 Turma, Aluno e Reserva
- A entidade associativa `RESERVA_TURMA` impõe validação composta dupla:
  - `(id_turma, id_unidade)` referencia `TURMA(id_turma, id_unidade)`
  - `(id_aluno, id_unidade)` referencia `ALUNO(id_aluno, id_unidade)`
- **Impacto**: Garante que alunos só possam se inscrever diretamente em turmas oferecidas na sua própria unidade de matrícula.

---

## 3. Regras Lógicas de Validação de Acesso (Catraca)

Toda leitura de catraca gera uma tupla na relação `ACESSO`. A elegibilidade para liberação (`liberado = VERDADEIRO`) é determinada logicamente pelas seguintes condições cumulativas:

1. **Vínculo Cadastral Ativo**:
   - O aluno deve possuir `ALUNO.ativo = VERDADEIRO`.
2. **Contrato Vigente**:
   - O aluno deve possuir um contrato com `status = 'ATIVO'`.
   - A data atual deve estar dentro do período de vigência (`data_inicio <= data_atual` e `data_fim IS NULL OR data_fim >= data_atual`).
3. **Adimplência Financeira**:
   - Nenhuma fatura (`MENSALIDADE`) do contrato do aluno com status `ABERTA` ou `PARCIAL` pode estar vencida há mais dias do que o período estipulado em `PLANO.carencia_dias` (tolerância padrão de carência).
4. **Resultado da Verificação**:
   - Se todas as condições forem atendidas: `liberado = VERDADEIRO`, `motivo = ''`.
   - Se houver inadimplência: `liberado = FALSO`, `motivo = 'MENSALIDADE EM ATRASO'`.
   - Se não houver contrato ativo: `liberado = FALSO`, `motivo = 'SEM CONTRATO ATIVO'`.
   - Se cadastro inativo: `liberado = FALSO`, `motivo = 'CADASTRO INATIVO'`.

---

## 4. Escopo Global de Usuários (Visão de Rede)

Na relação `USUARIO`:
- Se `id_unidade` for informado (`NOT NULL`), o usuário possui escopo operacional restrito àquela filial específica (ex.: recepcionista, instrutor, gerente de unidade).
- Se `id_unidade` for nulo (`NULL`), o usuário possui **visão corporativa global de rede** (ex.: DBA, auditor corporativo, diretor de operações), podendo consultar e consolidar informações de todas as filiais.
