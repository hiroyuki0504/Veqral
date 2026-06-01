# Hermes Memory Inheritance PR0

- Source: `veqral-memtest-20260601-052940-5a8e6e14`
- Hermes home: isolated temporary home (`hermes-home`)
- Chat A: `openai-codex/gpt-5.5`
- Chat B: `openai-codex/gpt-5.4`
- Chat A credential source: Hermes ChatGPT subscription login (`auth.json`)
- Chat B credential source: Hermes ChatGPT subscription login (`auth.json`)
- Code name: `Tachibana-7-E7A3D834`

## Backend Capability Check

- `openai-codex`: Hermes ChatGPT subscription login auth was available for this isolated run; selected route: `openai-codex/gpt-5.5 -> openai-codex/gpt-5.4`.
- `anthropic`: Hermes reports Claude/Anthropic login as unavailable on this Mac; use `claude /login` or `claude setup-token` before choosing this route.
- Local Ollama custom endpoint: supported through `provider=custom` + `base_url`, but `127.0.0.1:11434` is not reachable right now.
- Login auth bridge: `auth.json` linked from `~/.hermes` into isolated `HERMES_HOME`

## Chat A Transcript

```text
⚠ tirith security scanner enabled but not available — command scanning will use pattern matching only
MEMWRITE:Tachibana-7-E7A3D834


session_id: 20260601_142941_809abf
```

## Native Memory Check

- `MEMORY.md` exists: yes
- `MEMORY.md` contains code name: yes
- `state.db` session store: state.db, sessions total=1, source matches=0

## Chat B Transcript

```text
CODENAME:Tachibana-7-E7A3D834


session_id: 20260601_142950_d9ab90
```

## Result

PASS: Chat B returned the code name written by Chat A while using a different provider/model.
