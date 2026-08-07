---
description: Create high-quality git commits with auto-detected commit style
subtask: true
---

# Commit

Create well-crafted git commits.

## Auto-detection of commit style
1. `!`git log --oneline -30 --no-decorate``
2. If <5 commits → fall back to Conventional Commits
3. Report detected style

## Workflow (checklist)
1) `!`git status`` + `!`git diff --stat``
2) Detect style
3) Split if needed: feature vs refactor, backend vs frontend, formatting vs logic, tests vs prod, deps vs behavior
4) Stage: `git add -p`, unstage: `git restore --staged`
5) `!`git diff --cached`` — check no secrets, debug logs, formatting churn
6) Describe change in 1-2 sentences. If unclear → go back to step 3.
7) Write message:
   - Subject: concise, imperative, business-focused
   - Body: bullet list of key changes only for complex commits (omit for simple ones)
   - Footer: `BREAKING CHANGE` if needed
8) Verify: `!`npm test -- --bail 2>&1 || echo "No test script" && npm run lint 2>&1 || echo "No lint script"``
9) Repeat until clean ($ARGUMENTS)

## Deliverable
- detected style
- commit message(s)
- summary per commit (what/why)
- commands used
