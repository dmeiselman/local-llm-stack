# Recipe 03 — Coding agents (opencode, pi, mini-swe-agent)

**Goal:** drive the local models from terminal coding agents.
**Prereqs:** Recipe 02 (LiteLLM on `:4000`, `LITELLM_MASTER_KEY` exported).

All three agents point at the **same gateway**. `local-coder` (thinking off) is usually the best
agent model; `local-fast` is a fine general default.

---

## opencode (native tool-calling) — the recommended daily driver

Install per opencode's docs, then drop in the config:

```
mkdir -p ~/.config/opencode
cp config/opencode/opencode.json ~/.config/opencode/opencode.json
```

It reads the key from `$LITELLM_MASTER_KEY` (no secret in the file). Launch `opencode` and pick
`litellm/local-fast` or `local-coder`.

> **Context must not exceed the server's.** Each model's `limit.context` is set to match the
> llama-swap `-c` value. If you raise `-c`, raise it here too; if a client advertises **more** than
> the server allows, requests can stall. This is the #1 "it just hangs" cause.

## pi (native tool-calling)

pi verified clean native tool-calling against this backend (no workarounds).

```
mkdir -p ~/.pi/agent
cp config/pi/models.json   ~/.pi/agent/models.json
cp config/pi/settings.json ~/.pi/agent/settings.json
```

Then paste your real key into `~/.pi/agent/models.json` (pi doesn't expand env vars there).

Two schema foot-guns pi is strict about:
- **All four `cost` keys** (`input`,`output`,`cacheRead`,`cacheWrite`) must be present, or pi
  silently reports "No models available."
- `contextWindow` must match the model's real context or compaction misbehaves.

## mini-swe-agent (text protocol)

A deliberately different design: the model writes one fenced bash block per turn (regex-parsed)
instead of using tool-calls — robust when tool-calling is flaky.

```
uv tool install mini-swe-agent      # or: pipx install mini-swe-agent
mkdir -p ~/.config/mini-swe-agent
cp config/mini-swe-agent/.env      ~/.config/mini-swe-agent/.env      # paste your key
cp config/mini-swe-agent/mini.yaml ~/.config/mini-swe-agent/mini.yaml
```

Three env keys make it work against a **local** backend (all in the `.env`):
- `MSWEA_CONFIGURED=true` — skip the first-run wizard (it aborts with no TTY and only wants cloud keys).
- `MSWEA_COST_TRACKING=ignore_errors` — LiteLLM reports $0 for local models; the default mode
  treats $0 as an error and kills the run.
- `MSWEA_MINI_CONFIG_PATH=...mini.yaml` — because `model_class: litellm_textbased` can only be set
  in the yaml, not via an env var.

Run: `mini -t "your task"`.

## The tool-calling lesson (applies to all agents)

Native tool-calling depends on the model's **chat template**. Qwen3.6 works well. If you swap in a
raw `hf.co` GGUF and every tool call 400s while plain chat is fine, its template is likely aborting
the tool parser — prefer a known-good/library build, or use the text-protocol agent
(mini-swe-agent) instead. More in [troubleshooting](../../reference/troubleshooting.md).

## Verify

```
./scripts/healthcheck.sh   # includes a tool-calling probe -> expect finish_reason: tool_calls
```

**Next (optional):** [Recipe 04 — Voice](../04-voice-optional/README.md).
