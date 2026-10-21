<!-- FOR AI AGENTS - Human readability is a side effect, not a goal -->
# Frontend Agent Rules

## Precedence
Rules here apply to `src/frontend/` and its submodules.

## Structure
- Cada funcionalidade ou tela deve residir em seu respectivo módulo dentro de `src/frontend/`.
- Mantenha componentes desacoplados, com separação clara de estado, visualização e serviços de API.

## Workflow
1. Antes de implementar novas telas ou componentes, valide os contratos de interface e especificações em `.specify/`.
2. Siga os padrões de commit semântico definidos no repositório raiz.
