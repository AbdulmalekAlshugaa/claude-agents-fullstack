#!/usr/bin/env bash
# Install the claude-agents-fullstack toolkit into ~/.claude/
#
# Usage:
#   ./install.sh                  # interactive: asks which database is your default
#   ./install.sh --db postgres    # non-interactive
#   ./install.sh --db mongodb
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

DB=""
while [ $# -gt 0 ]; do
  case "$1" in
    --db)
      DB="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,8p' "$0"; exit 0 ;;
    *)
      echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$DB" ]; then
  if [ -t 0 ]; then
    echo "Which database should be the DEFAULT for new apps?"
    echo "(both stay installed and supported — this only sets the default)"
    echo
    echo "  1) PostgreSQL via Drizzle  [default]"
    echo "  2) MongoDB via Mongoose"
    echo
    printf "Select 1 or 2 [1]: "
    read -r choice
    case "${choice:-1}" in
      2) DB="mongodb" ;;
      *) DB="postgres" ;;
    esac
  else
    DB="postgres"
  fi
fi

case "$DB" in
  postgres|postgresql) DB="postgres" ;;
  mongo|mongodb) DB="mongodb" ;;
  *) echo "invalid --db value: $DB (use postgres or mongodb)" >&2; exit 1 ;;
esac

echo
echo "Installing to $CLAUDE_DIR (default database: $DB)"
mkdir -p "$CLAUDE_DIR"
cp -R "$REPO_DIR/agents" "$REPO_DIR/skills" "$REPO_DIR/commands" "$REPO_DIR/templates" "$CLAUDE_DIR/"

# Back up an existing global CLAUDE.md before replacing it
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.bak"
  echo "Existing CLAUDE.md backed up to CLAUDE.md.bak"
fi
cp "$REPO_DIR/global-CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

# Swap the default-database bullet for the chosen engine
if [ "$DB" = "mongodb" ]; then
  python3 - "$CLAUDE_DIR/CLAUDE.md" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text()
bullet = """- **MongoDB** via **Mongoose** for data (Atlas in prod, local/docker in dev)
  — **PostgreSQL via Drizzle ORM** as the alternative for relational domains
"""
s = re.sub(
    r"<!-- db:default:start -->\n.*?<!-- db:default:end -->\n",
    bullet,
    s,
    flags=re.S,
)
p.write_text(s)
PY
else
  # Postgres default: just strip the markers
  sed -i.tmp '/<!-- db:default:/d' "$CLAUDE_DIR/CLAUDE.md" && rm -f "$CLAUDE_DIR/CLAUDE.md.tmp"
fi

echo
echo "Done. Installed:"
echo "  agents/    $(ls "$REPO_DIR/agents"    | wc -l | tr -d ' ') subagents"
echo "  skills/    $(ls "$REPO_DIR/skills"    | wc -l | tr -d ' ') skills"
echo "  commands/  $(ls "$REPO_DIR/commands"  | wc -l | tr -d ' ') slash commands"
echo "  templates/ CLAUDE.md.template"
echo "  CLAUDE.md  global preferences (default DB: $DB)"
echo
echo "Per project: /new-app scaffolds with the $DB default; ask for the other DB any time."
