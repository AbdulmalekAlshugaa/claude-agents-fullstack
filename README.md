# claude-agents

Personal Claude Code toolkit for building fullstack web apps with
**Next.js (App Router) + TypeScript + Node.js + MongoDB**.

## Install (global — available in every project)

```bash
git clone https://github.com/malik-onecredit/claude-agents
cp -R claude-agents/agents claude-agents/skills claude-agents/commands claude-agents/templates ~/.claude/
cp claude-agents/global-CLAUDE.md ~/.claude/CLAUDE.md
```

Or per-project: copy `agents/`, `skills/`, `commands/` into the repo's `.claude/`
directory and `templates/CLAUDE.md.template` to the repo root as `CLAUDE.md`.

## Contents

| Dir | What |
|---|---|
| `agents/` | Subagents: `planner`, `fullstack-implementer`, `db-designer`, `code-reviewer`, `test-writer`, `debugger` |
| `skills/` | Stack conventions: scaffold, MongoDB modeling, API design, components, auth, testing, deploy |
| `commands/` | Slash commands: `/new-app`, `/new-feature`, `/review`, `/fix`, `/ship` |
| `templates/` | `CLAUDE.md.template` — drop into each new app repo |
| `global-CLAUDE.md` | Global preferences for `~/.claude/CLAUDE.md` |
