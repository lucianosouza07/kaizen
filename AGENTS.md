<!-- FOR AI AGENTS - Human readability is a side effect, not a goal -->
<!-- Managed by agent: keep sections and order; edit content, not structure -->
<!-- Last updated: 2026-10-20 | Last verified: 2026-10-20 -->

# AGENTS.md

**Precedence:** the **closest `AGENTS.md`** to the files you're changing wins. Root holds global defaults only.

## Commands
> Source: workspace conventions (Git & Spec Kit)

<!-- AGENTS-GENERATED:START commands -->
| Task | Command | ~Time |
|------|---------|-------|
| Git Status | `git -C src status` | ~1s |
| Git Branch | `git -C src branch -vv` | ~1s |
| Spec Constitution | `specify init --help` | ~1s |
| Commit Msg Check | `bash .git/hooks/commit-msg` | ~1s |
<!-- AGENTS-GENERATED:END commands -->

## Response Style
- Answer first, elaborate only if needed. No sycophantic openers ("Great question!", "Absolutely!").
- For yes/no or status questions, lead with the answer.
- Skip preamble. Match response length to task complexity.

## Workflow
1. **Before coding**: Read nearest `AGENTS.md` and check specs in `.specify/`.
2. **Git Flow**: Never commit directly to `main`. Always work on the assigned feature branch.
3. **Commit Standards**: Strictly follow Conventional Commits format `<tipo>(<escopo>): <descrição>` (see `.agents/rules/padroes-commits.md`).
4. **Before claiming done**: Run verification and **show output as evidence** — never say "tested" or "all green" without command output.

## File Map
<!-- AGENTS-GENERATED:START filemap -->
```
workspace_bd/
├── .agents/               # Agent configuration, rules and skills
│   ├── rules/             # Permanent agent rules (e.g. padroes-commits.md)
│   └── skills/            # Custom and installed skills
├── .specify/              # GitHub Spec Kit templates, memory, and workflows
├── docs/                  # Project specifications and documentation
└── src/                   # Active codebase git repository
    ├── backend/           # Backend application modules
    └── frontend/          # Frontend application modules
```
<!-- AGENTS-GENERATED:END filemap -->

## Git & Commit Rules
<!-- AGENTS-GENERATED:START heuristics -->
| When | Do |
|------|-----|
| Creating commits | Use semantic prefixes: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `raw`, `cleanup`, `remove` |
| New feature or requirement | Check and update specs in `.specify/` before writing code |
| Working in `src/` | Verify active branch and tracked with remote |
<!-- AGENTS-GENERATED:END heuristics -->
