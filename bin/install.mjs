#!/usr/bin/env node
// Install the claude-agents-fullstack toolkit into ~/.claude/
//
// Usage:
//   npx claude-agents-fullstack                 # interactive: asks for the default DB
//   npx claude-agents-fullstack --db postgres   # non-interactive
//   npx claude-agents-fullstack --db mongodb
import { cpSync, copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createInterface } from 'node:readline/promises'

const pkgRoot = join(dirname(fileURLToPath(import.meta.url)), '..')
const claudeDir = process.env.CLAUDE_DIR || join(homedir(), '.claude')

function fail(msg) {
  console.error(msg)
  process.exit(1)
}

let db = ''
const args = process.argv.slice(2)
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--db') db = args[++i] ?? ''
  else if (args[i] === '-h' || args[i] === '--help') {
    console.log('Usage: npx claude-agents-fullstack [--db postgres|mongodb]')
    process.exit(0)
  } else fail(`unknown option: ${args[i]}`)
}

if (!db) {
  if (process.stdin.isTTY) {
    console.log('Which database should be the DEFAULT for new apps?')
    console.log('(both stay installed and supported — this only sets the default)\n')
    console.log('  1) PostgreSQL via Drizzle  [default]')
    console.log('  2) MongoDB via Mongoose\n')
    const rl = createInterface({ input: process.stdin, output: process.stdout })
    const choice = (await rl.question('Select 1 or 2 [1]: ')).trim()
    rl.close()
    db = choice === '2' ? 'mongodb' : 'postgres'
  } else {
    db = 'postgres'
  }
}

if (db === 'postgresql') db = 'postgres'
if (db === 'mongo') db = 'mongodb'
if (db !== 'postgres' && db !== 'mongodb') fail(`invalid --db value: ${db} (use postgres or mongodb)`)

console.log(`\nInstalling to ${claudeDir} (default database: ${db})`)
mkdirSync(claudeDir, { recursive: true })
for (const dir of ['agents', 'skills', 'commands', 'templates']) {
  cpSync(join(pkgRoot, dir), join(claudeDir, dir), { recursive: true })
}

const claudeMd = join(claudeDir, 'CLAUDE.md')
if (existsSync(claudeMd)) {
  copyFileSync(claudeMd, `${claudeMd}.bak`)
  console.log('Existing CLAUDE.md backed up to CLAUDE.md.bak')
}

let md = readFileSync(join(pkgRoot, 'global-CLAUDE.md'), 'utf8')
const block = /<!-- db:default:start -->\n[\s\S]*?<!-- db:default:end -->\n/
if (db === 'mongodb') {
  md = md.replace(
    block,
    '- **MongoDB** via **Mongoose** for data (Atlas in prod, local/docker in dev)\n' +
      '  — **PostgreSQL via Drizzle ORM** as the alternative for relational domains\n',
  )
} else {
  md = md.replace(block, (m) =>
    m
      .split('\n')
      .filter((l) => !l.includes('<!-- db:default:'))
      .join('\n'),
  )
}
writeFileSync(claudeMd, md)

const count = (dir) => readdirSync(join(pkgRoot, dir)).length
console.log(`
Done. Installed:
  agents/    ${count('agents')} subagents
  skills/    ${count('skills')} skills
  commands/  ${count('commands')} slash commands
  templates/ CLAUDE.md.template
  CLAUDE.md  global preferences (default DB: ${db})

Per project: /new-app scaffolds with the ${db} default; ask for the other DB any time.`)
