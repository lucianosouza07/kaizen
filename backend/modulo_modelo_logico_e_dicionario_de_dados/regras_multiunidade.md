# Regras de Isolamento Multiunidade e Abstração Lógica de Unicidade Condicional

**Projeto**: Kaizen BD — Camada de Banco de Dados Relacional  
**Módulo**: `modulo_modelo_logico_e_dicionario_de_dados` (`BK-DB-02`)

---

## 1. Confinamento Relacional Multiunidade via Chaves Estrangeiras Compostas

O isolamento entre unidades da rede Kaizen é garantido declarativamente na própria estrutura de chaves do modelo lógico, impedindo cruzamentos indevidos entre filiais:

| Relação Filha | Chave Estrangeira Composta | Relação Mãe Referenciada | Invariante de Negócio Garantida |
|---|---|---|---|
| `TURMA` | `(id_instrutor, id_unidade)` | `COLABORADOR(id_colaborador, id_unidade)` | Um instrutor lotado na Unidade A jamais pode ser alocado para ministrar uma turma na Unidade B. |
| `CONTRATO` | `(id_aluno, id_unidade)` | `ALUNO(id_aluno, id_unidade)` | O contrato de um aluno é obrigatoriamente firmado na mesma unidade em que o aluno está matriculado. |
| `ACESSO` | `(id_aluno, id_unidade)` | `ALUNO(id_aluno, id_unidade)` | O registro de passagem na catraca valida a consistência entre o aluno e a sua unidade cadastral. |
| `RESERVA_TURMA` | `(id_turma, id_unidade)` e `(id_aluno, id_unidade)` | `TURMA(id_turma, id_unidade)` e `ALUNO(id_aluno, id_unidade)` | Como o atributo `id_unidade` de `RESERVA_TURMA` participa simultaneamente de ambas as FKs compostas, um aluno só pode reservar vaga em turma pertencente à sua própria unidade. |

### Escopo de `USUARIO` (`id_unidade NULL`)
- Na relação `USUARIO`, a chave estrangeira `id_unidade → UNIDADE(id_unidade)` aceita `NULL`.
- Quando `id_unidade` está preenchido, o operador atua circunscrito àquela filial; quando `id_unidade IS NULL`, o operador possui visão corporativa global da rede.

---

## 2. Abstração Lógica Pura da Regra de Único Contrato Ativo por Aluno

1. **Enunciado da Regra**: Um aluno pode possuir múltiplos contratos ao longo de seu histórico (`ENCERRADO`, `CANCELADO`, `SUSPENSO`), porém **no máximo um contrato pode estar com `status = 'ATIVO'` simultaneamente**.
2. **Representação no Modelo Lógico**:
   - Expressa como restrição de unicidade lógica condicional sobre `CONTRATO`:
     \[
     \text{UNIQUE}(id\_aluno) \text{ WHERE } status = \text{'ATIVO'}
     \]
3. **Independência de Implementação Física**:
   - O modelo lógico **não contém** colunas virtuais ou geradas destinadas a contornar limitações sintáticas de SGBDs específicos.
   - A tradução dessa restrição condicional para mecanismos físicos do SGBD alvo pertence estritamente à Etapa 3 (Modelo Físico / DDL).
