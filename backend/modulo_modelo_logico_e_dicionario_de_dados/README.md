# Módulo: Modelo Lógico e Dicionário de Dados — `BK-DB-02`

Este módulo materializa a **Etapa 2 (Modelo Lógico e Dicionário de Dados)** do banco de dados relacional do sistema **Kaizen ERP**, formalizando as **15 relações normalizadas em Terceira Forma Normal (3FN)** (13 de domínio + 2 técnicas: `AUDITORIA_LOG` e `CONTADOR_DOCUMENTO`), o dicionário de dados semântico e a matriz completa de integridade declarativa (`PK`, `FK`, `UK`, `CK`).

---

## 1. Estrutura de Artefatos do Módulo

| Arquivo | Finalidade |
|---|---|
| `README.md` | Visão geral do módulo, sumário de artefatos e checklist de conformidade dos critérios de aceite. |
| `justificativa_3fn.md` | Demonstração formal de 1FN, 2FN e 3FN para as 15 relações, resolução de todos os relacionamentos `N : N` e justificativa do *snapshot* em `CONTRATO.valor_mensal`. |
| `dicionario_dados.md` | Catálogo de domínios lógicos abstratos, esquema relacional lógico das 15 relações e dicionário detalhado de todos os atributos. |
| `matriz_integridade.md` | Matriz consolidada de Chaves Primárias (`PK`), Chaves Estrangeiras simples e compostas (`FK`), Chaves Únicas (`UK`) e Checagens (`CK`). |
| `regras_multiunidade.md` | Especificação do isolamento multiunidade por chaves compostas e da unicidade lógica condicional de contrato ativo. |

---

## 2. Resumo de Conformidade com os Critérios de Aceite (`BK-DB-02`)

- [x] **3FN justificada**: Todas as 15 relações estão formalmente analisadas e justificadas em 1FN, 2FN e 3FN em `justificativa_3fn.md`.
- [x] **Toda `N : N` resolvida**: Os relacionamentos `ALUNO — TURMA` e `USUARIO — PAPEL` estão integralmente decompostos pelas relações associativas `RESERVA_TURMA` e `USUARIO_PAPEL`.
- [x] **`contrato.valor_mensal` documentado como *snapshot***: Documentado no esquema lógico, no dicionário de dados e no relatório de normalização como fotografia histórica imutável do valor contratado no ato da assinatura.
- [x] **Matriz de integridade completa**: `PK`, `FK`, `UK` e `CK` de todas as 15 relações consolidadas em `matriz_integridade.md`.
- [x] **Pureza lógica preservada**: Nenhuma coluna artificial gerada de emulação física consta no esquema lógico ou no dicionário de dados.
