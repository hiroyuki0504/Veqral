# Hermes Memory Inheritance PR0

- Source: `veqral-memtest-20260601-031522-57257ec1`
- Hermes home: isolated temporary home (`hermes-home`)
- Chat A: `custom/qwen2.5:7b`
- Chat B: `openrouter/google/gemini-2.5-flash`
- Chat A credential source: local Ollama placeholder (`OPENAI_API_KEY=ollama`)
- Chat B credential source: missing env `OPENROUTER_API_KEY` / Keychain account `openrouter:api-key`
- Code name: `Tachibana-7-87F08337`

## Credential / Provider Preflight

- Chat A points at local Ollama, but `http://127.0.0.1:11434/api/tags` is not reachable. Start Ollama and pull the configured model before rerunning.
- Chat B uses `openrouter`, but `OPENROUTER_API_KEY` is not set and Keychain account `openrouter:api-key` is empty.

## Result

FAIL: Hermes memory inheritance was not run because at least one real provider/model route is not ready. 偽 pass は作っていません。
