# Swarm Orchestration Phase 4

## Scope

Phase 4 adds a user-GO-gated integration preparation path:

- authenticated `POST /v1/swarm/integration/prepare`
- serial merge of ready branches into a fresh `codex/swarm-integration/<id>` worktree branch
- per-integration verification commands
- optional push + Draft PR creation
- explicit stop before `main`; the Host never merges or pushes `main`
- approval queue priority view with safe batch actions: high-risk items stay individual review, medium-risk items can be approved together, and all pending items can be rejected after confirmation

This is the integration candidate step. Final `main` landing remains manual/user approved.

## API

`POST /v1/swarm/integration/prepare`

Request fields:

- `repoPath`
- `baseBranch`
- `branches`
- `verifyCommands`
- `pushDraftPR`
- `title`
- `body`

Response includes the integration branch, worktree path, merged branches, logs, status, and optional Draft PR URL.

## Verification

`swift run --package-path MacHost VeqralHost smoke-swarm-integration`

Result on 2026-06-02:

```text
PASS: Serial integration branch codex/swarm-integration/7e7fde82 contains both feature branches and left main clean.
```

The existing runner smoke was also re-run:

```text
PASS: Swarm runner isolated 2 worktrees in 2.78s, serialized conflicting scopes in 3.85s, held Xcode slot to 4.31s, kept base clean, and kill switch cancelled active work.
```

## Notes

- Merge conflicts can still happen. They surface as a failed integration response with redacted command logs.
- Approval batching stays within the existing approval queue and does not change high-severity policy.
- No force-push, deploy, or main merge is performed.
