---
description: Snapshot current work and commit it in the background
agent: git-committer
subagent: true
---

The current working changes have been staged as a snapshot.

Staged changes:

!`git add -A && git diff --cached --stat`

Create one atomic commit containing only the staged changes.

Do not stage additional files.
Do not modify source files.
Do not push.