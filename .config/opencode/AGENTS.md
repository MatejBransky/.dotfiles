<!-- context7 -->
Use the `ctx7` CLI to fetch current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service — even well-known ones like React, Next.js, Prisma, Express, Tailwind, Django, or Spring Boot. This includes API syntax, configuration, version migration, library-specific debugging, setup instructions, and CLI tool usage. Use even when you think you know the answer — your training data may not reflect recent changes. Prefer this over web search for library docs.

Do not use for: refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts.

## Steps

1. Resolve library: `npx ctx7@latest library <name> "<user's question>"` — use the official library name with proper punctuation (e.g., "Next.js" not "nextjs", "Customer.io" not "customerio", "Three.js" not "threejs")
2. Pick the best match (ID format: `/org/project`) by: exact name match, description relevance, code snippet count, source reputation (High/Medium preferred), and benchmark score (higher is better). If results don't look right, try alternate names or queries (e.g., "next.js" not "nextjs", or rephrase the question)
3. Fetch docs: `npx ctx7@latest docs <libraryId> "<user's question>"` — run a separate `docs` command per distinct concept if the question spans multiple topics, unless it's about how they interact
4. Answer using the fetched documentation

You MUST call `library` first to get a valid ID unless the user provides one directly in `/org/project` format. Use the user's full question as the query — specific and detailed queries return better results than vague single words, but keep each query to a single concept unless the question is about how concepts interact; combined multi-topic queries dilute ranking and return shallow results for each topic. Do not run more than 3 commands per question. Do not include sensitive information (API keys, passwords, credentials) in queries.

For version-specific docs, use `/org/project/version` from the `library` output (e.g., `/vercel/next.js/v14.3.0`).

If a command fails with a quota error, inform the user and suggest `npx ctx7@latest login` or setting `CONTEXT7_API_KEY` env var for higher limits. Do not silently fall back to training data.
<!-- context7 -->

## SSH & Git

SSH keys are stored in **Bitwarden**, not as files in `~/.ssh/`. The `~/.ssh/id_pub_*` files are public keys only — Bitwarden's SSH agent provides the matching private keys on demand.

### Keys

| File | Identity | Email |
|------|----------|-------|
| `~/.ssh/id_pub_work` | Macbook M4 (Momence) | matej.bransky@momence.com |
| `~/.ssh/id_pub_personal` | Macbook M4 (personal) | — |

### Git config

The work gitconfig (`~/Developer/work/.gitconfig`) sets:
```
[core]
  sshCommand = "ssh -i ~/.ssh/id_pub_work"
```

This tells SSH to use the work key. Bitwarden agent intercepts and provides the private key.

### Common commands

```bash
# Push to work repo (from ~/Developer/work/)
GIT_SSH_COMMAND="ssh -i ~/.ssh/id_pub_work" git push

# Test SSH identity
ssh -T -i ~/.ssh/id_pub_work git@github.com
# → Hi MatejBransky-Momence!

# Clone work repo
GIT_SSH_COMMAND="ssh -i ~/.ssh/id_pub_work" git clone git@github.com:MatejBransky-Momence/repo.git
```

### Rules

- **Never create or modify SSH key files** — Bitwarden manages them.
- **Never commit credentials, tokens, or keys** — use `gh auth` or environment variables.
- **For work repos** (`~/Developer/work/`): always use `id_pub_work`.
- **For personal repos**: use the default key (Bitwarden handles it automatically).
- When a git command fails with SSH errors, check if Bitwarden is running and unlocked first.

## Local Development Database

The local Momence development PostgreSQL database runs in Docker Compose.

### Connection

- Host: `localhost`
- Published port: `5433` (container port: `5432`)
- User: `postgres`
- Database: `ribbon`
- Server version: PostgreSQL 17.x
- Bitwarden item: `Momence (dev db)`

### Rules

- Prefer the local PostgreSQL 17 client (`psql`) for normal queries.
- Load the password from Bitwarden with `bw-unlock` followed by `dev-db-env`; never hardcode or print it.
- Connect from the host with `psql -h localhost -p 5433 -U postgres -d ribbon`.
- If client/server compatibility is in doubt, use the matching client inside the container: `docker exec -e PGPASSWORD="$DEV_DB_PASSWORD" -it momence_postgres psql -U postgres -d ribbon`.
- Use the Docker-matched PostgreSQL major version for `pg_dump`, `pg_restore`, and migration tooling.
- Before destructive SQL, dropping data, resetting the database, or running irreversible migrations, ask for explicit confirmation.
- Treat the database as disposable local development data, but do not assume its contents are safe to expose in logs or chat.
<!-- codebase-memory-mcp:start -->
# Codebase Memory

## Codebase Knowledge Graph (codebase-memory-mcp)

This project uses codebase-memory-mcp to maintain a knowledge graph of the codebase.
ALWAYS prefer MCP graph tools over grep/glob/file-search for code discovery.

### Priority Order
1. `search_graph` — find functions, classes, routes, variables by pattern
2. `trace_path` — trace who calls a function or what it calls
3. `get_code_snippet` — read specific function/class source code
4. `check_index_coverage` — validate candidate paths and missed ranges before claims
5. `query_graph` — run Cypher queries for complex patterns
6. `get_architecture` — high-level project summary

### Evidence tiers
- **Scout (Tier 1):** quick positive lookup with few calls and targeted source checks. Mark it provisional; do not make negative or exhaustive claims.
- **Verify (Tier 2, default):** task-directed graph evidence, relevant trace directions, exact snippets for material claims, and relevant pagination.
- **Auditor (Tier 3):** bounded-scope full verification with current generation, complete relevant pagination, both call directions and broader relationships when material, and every limitation disclosed.
- After candidate paths are known in any tier, call `check_index_coverage` once with every evidence path. Add relevant scopes for negative or exhaustive claims. A clean result means no recorded gap, not proof of completeness. For partial, skipped, excluded, stale, pending, or unknown coverage, read/grep the reported ranges or scope before relying on graph results.

### When to fall back to grep/glob
- Searching for string literals, error messages, config values
- Searching non-code files (Dockerfiles, shell scripts, configs)
- When MCP tools return insufficient results

### Examples
- Find a handler: `search_graph(name_pattern=".*OrderHandler.*")`
- Who calls it: `trace_path(function_name="OrderHandler", direction="inbound")`
- Read source: `get_code_snippet(qualified_name="pkg/orders.OrderHandler")`

### Session resets and subagents
- At session start or after compaction, confirm the nearest graph project and generation with `list_projects` or `index_status`, then choose Scout, Verify, or Auditor.
- Before spawning a subagent, query the graph and coverage in the parent. Pass the tier, project, generation/freshness, bounded scope, queries and pagination state, qualified symbols, paths, call-chain findings, coverage evidence with ranges/reasons, source fallback already performed, and unresolved questions in the delegated task context.
- Do not assume subagents inherit MCP access or the parent conversation. If a child lacks MCP tools, it must not call or claim MCP access. It should use the supplied evidence and read/grep exact source, especially every reported missed-coverage range.
<!-- codebase-memory-mcp:end -->

## Personal Dotfiles Repository

This workstation manages dotfiles with a Git directory at `~/.cfg` and the home directory (`$HOME`) as its working tree. The repository is hosted at `git@github.com:MatejBransky/.dotfiles.git`. Its local Git config has `core.bare=false` and `core.worktree=$HOME`; this is a separate-Git-dir/work-tree setup commonly described as a bare-style dotfiles repo.

### Daily commands

The `cfg` shell function runs `git --git-dir="$HOME/.cfg" --work-tree="$HOME"` with its arguments, so it works from any directory. `cfgui` opens LazyGit against the same repo. `cfgvim` starts Neovim at `$HOME` with `GIT_DIR` and `GIT_WORK_TREE` set for dotfiles.

Use `cfg status`, `cfg diff`, `cfg ls-files`, and `cfg diff --cached` to inspect state. For a new path, first add it to `~/.config/workstation/git-exclude` and copy that allowlist to `~/.cfg/info/exclude`; then `cfg add <path>`, inspect the staged diff, and commit. The exclude rules start with `*` and explicitly allow selected files/directories, reducing accidental tracking of home-directory contents. `cfg add -f` bypasses that safeguard and should be deliberate.

### Identity and safety

The global `~/.gitconfig` uses `includeIf "gitdir:~/.cfg"` to load the personal Git identity from `~/Developer/personal/.gitconfig`. SSH uses the public identity file while Bitwarden's SSH agent supplies the private key. Never put credentials, tokens, passwords, or private keys in tracked dotfiles; use Bitwarden or an appropriate secret mechanism.

At the time this note was written (2026-09-23), local `main` was at `2db68c3`, `origin/main` at `5957445`, and local `main` was 7 commits ahead with the remote tip as its ancestor. Local `main` had no upstream configured. Treat those as an observation, not guaranteed current state: always inspect `cfg status`, branch refs, and divergence before syncing or changing history. The branch `backup/pre-bare-repo-2026-08-07` preserves the pre-migration history.

The workstation's `~/.zshenv` was observed to contain a production database credential. It is excluded from this repository, but plaintext shell configuration is not a safe place for credentials. Do not read, print, copy, or commit the value; if it is still active, rotate it and load it from a secret manager instead.
