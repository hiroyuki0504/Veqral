# Swarm Orchestration Phase 1

## Scope

Phase 1 adds the Mac Host core for parallel agent orchestration:

- persistent swarm task ledger under the Host home directory
- authenticated `/v1/swarm/*` API
- isolated `git worktree` per task
- per-task branch naming under `codex/swarm/`
- scheduler with resource-aware max slots
- agent command runner for Codex, Claude, Hermes, and shell tasks
- per-task verification commands
- automatic commit of task changes
- optional draft PR creation
- cancellation and global kill switch

The runner does not merge to `main`. Draft PR creation is optional per task and still uses normal GitHub flow. Any final main integration remains user-GO gated.

## API

- `GET /v1/swarm/tasks`
- `POST /v1/swarm/tasks`
- `POST /v1/swarm/tasks/{id}/cancel`
- `POST /v1/swarm/kill`

Task requests include `repoPath`, `baseBranch`, `instruction`, `scopeHints`, `agent`, `verifyCommands`, `createDraftPR`, and `cleanupWorktree`.

## Safety

- Each task receives a separate worktree and branch.
- The base working tree is not used for agent execution.
- `~/.codex` and `~/.claude` remain read-only from Veqral's side; the runner invokes CLIs without editing their history stores.
- Logs are redacted before being persisted.
- The kill switch marks all active/pending work cancelled and sends termination to known child processes.
- `main` is never merged or pushed by the swarm runner.

## Verification

`swift run --package-path MacHost VeqralHost smoke-swarm-runner`

Result on 2026-06-02:

- 2 shell-backed tasks ran in isolated worktrees
- elapsed time: 1.93s, confirming overlapping execution
- base repository stayed clean
- kill switch cancelled active work

## Known Limits

- Merge conflicts are not eliminated in Phase 1. Scope-aware scheduling is Phase 3.
- Xcode build concurrency is only represented as a separate configured limit in Phase 1. Full adaptive scheduling is Phase 3.
- Draft PR creation requires an origin remote and `gh` authentication.
