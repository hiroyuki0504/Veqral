# Hermes Memory Inheritance PR0

- Source: `veqral-memtest-20260601-062018-acdde521`
- Hermes home: isolated temporary home (`hermes-home`)
- Chat A: `openai-codex/gpt-5.5`
- Chat B: `openai-codex/gpt-5.4`
- Chat A credential source: Hermes ChatGPT subscription login (`auth.json`)
- Chat B credential source: Hermes ChatGPT subscription login (`auth.json`)
- Code name: `Tachibana-7-62AD929B`

## Backend Capability Check

- `openai-codex`: Hermes ChatGPT subscription login auth was available for this isolated run; selected route: `openai-codex/gpt-5.5 -> openai-codex/gpt-5.4`.
- `anthropic`: Hermes reports Claude/Anthropic login as unavailable on this Mac; use `claude /login` or `claude setup-token` before choosing this route.
- Local Ollama custom endpoint: supported through `provider=custom` + `base_url`, but `127.0.0.1:11434` is not reachable right now.
- Login auth bridge: `auth.json` linked from `~/.hermes` into isolated `HERMES_HOME`

## Chat A Transcript

```text
⚠ tirith security scanner enabled but not available — command scanning will use pattern matching only
MEMWRITE:Tachibana-7-62AD929B


session_id: 20260601_152020_9d0a1d
```

## Native Memory Check

- `MEMORY.md` exists: yes
- `MEMORY.md` contains code name: yes
- `state.db` session store: state.db, sessions total=1, source matches=0

## Chat B Transcript

```text
CODENAME:Tachibana-7-62AD929B


session_id: 20260601_152028_b5a622
```

## Result

PASS: Chat B returned the code name written by Chat A while using a different provider/model.

## #A7 Cross-Vendor Re-Run Attempt

- Date: 2026-06-02
- Requested route: `anthropic/claude-haiku-4-5 -> openai-codex/gpt-5.5`
- Report: `HERMES_CROSS_VENDOR_PR_A7.md`
- Result: BLOCKED before LLM execution. 偽 pass は作っていません。

The verifier intentionally tested the Claude side as subscription/login auth, not as an API-key route. With API-key environment removed, `hermes auth status anthropic` reports logged out, while `openai-codex` subscription login remains available through `~/.hermes/auth.json`.

Required next step: restore Hermes-readable Claude/Anthropic login with `claude /login` or `claude setup-token`, then rerun:

```sh
VEQRAL_MEMTEST_PROVIDER_A=anthropic \
VEQRAL_MEMTEST_MODEL_A=claude-haiku-4-5 \
VEQRAL_MEMTEST_PROVIDER_B=openai-codex \
VEQRAL_MEMTEST_MODEL_B=gpt-5.5 \
swift run --package-path MacHost VeqralHostSmoke verify-memory-inheritance --report HERMES_CROSS_VENDOR_PR_A7.md
```
