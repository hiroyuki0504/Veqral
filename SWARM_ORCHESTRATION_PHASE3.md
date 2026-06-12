# Swarm Orchestration Phase 3

## Scope

Phase 3 tightens scheduling for parallel agents:

- queued tasks with overlapping `scopeHints` in the same repo do not run at the same time
- Xcode-like work (`xcodebuild`, `.xcodeproj`, `.xcworkspace`) uses a separate fixed slot limit
- effective parallel slots adapt to `ProcessInfo.thermalState` and 1-minute load average
- process monitoring now uses a termination handler instead of polling `Process.isRunning`

## Behavior

Scope conflict detection is conservative. Empty `scopeHints` do not block each other, but matching files or parent/child module paths in the same repo are serialized. This reduces merge conflicts without pretending they can be eliminated.

Xcode tasks are still run in worktrees, but only `VEQRAL_SWARM_XCODE_MAX_SLOTS` Xcode-like tasks can be active at once. The default is `1`.

## Verification

`swift run --package-path MacHost VeqralHost smoke-swarm-runner`

Result on 2026-06-02:

- independent tasks overlapped
- same-file scope tasks serialized
- Xcode-like tasks respected the Xcode slot limit
- base repository stayed clean
- kill switch cancelled active work

Observed smoke:

```text
PASS: Swarm runner isolated 2 worktrees in 2.90s, serialized conflicting scopes in 4.06s, held Xcode slot to 4.36s, kept base clean, and kill switch cancelled active work.
```

## Known Limits

- Scope hints are only as good as the task input. Unknown files can still conflict at integration time.
- Load-average throttling is intentionally simple; finer CPU/memory pressure integration can be tuned after real usage.
- Native Swift/iOS builds remain outside container isolation and should keep a low Xcode slot limit.
