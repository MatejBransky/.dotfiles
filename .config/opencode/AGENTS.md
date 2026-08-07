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
