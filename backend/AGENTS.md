<!-- FOR AI AGENTS - Human readability is a side effect, not a goal -->
# Backend Agent Rules

## Precedence
Rules here apply to `src/backend/` and its submodules.

## Structure
- Cada funcionalidade ou domínio deve residir em seu respectivo módulo dentro de `src/backend/`.
- Mantenha separação clara de responsabilidades entre rotas, regras de negócio e acesso a dados.

## Workflow
1. Antes de implementar novas rotas ou serviços, verifique a especificação correspondente em `.specify/` ou `docs/`.
2. Siga os padrões de commit semântico definidos no repositório raiz.
