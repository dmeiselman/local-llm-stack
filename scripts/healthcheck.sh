#!/usr/bin/env bash
# End-to-end "is it working?" probe. Reads LITELLM_MASTER_KEY from env or
# config/litellm/.env. Exit 0 if all checks pass.
set -uo pipefail
cd "$(dirname "$0")/.."
[[ -f config/litellm/.env ]] && source config/litellm/.env
KEY="${LITELLM_MASTER_KEY:-}"

pass=0; fail=0
check() { # description  command...
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "  OK   $desc"; ((pass++)); else echo "  FAIL $desc"; ((fail++)); fi
}

echo "== llama-swap (:8080) =="
check "GET /v1/models"      curl -fsS http://127.0.0.1:8080/v1/models
echo "== LiteLLM gateway (:4000) =="
check "GET /v1/models"      curl -fsS -H "Authorization: Bearer $KEY" http://127.0.0.1:4000/v1/models
check "chat completion"     bash -c 'curl -fsS -H "Authorization: Bearer '"$KEY"'" -H "Content-Type: application/json" -d "{\"model\":\"local-fast\",\"messages\":[{\"role\":\"user\",\"content\":\"say hi\"}],\"max_tokens\":8}" http://127.0.0.1:4000/v1/chat/completions'
echo "== Open WebUI (:3000) =="
check "HTTP reachable"      curl -fsS http://127.0.0.1:3000/
echo "== SearXNG (:8888) =="
check "JSON search"         bash -c 'curl -fsS "http://127.0.0.1:8888/search?q=test&format=json"'

echo
echo "Tool-calling probe (expect finish_reason: tool_calls):"
curl -fsS -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"model":"local-coder","messages":[{"role":"user","content":"What is the weather in Paris? Use the tool."}],"tools":[{"type":"function","function":{"name":"get_weather","parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}],"max_tokens":64}' \
  http://127.0.0.1:4000/v1/chat/completions | grep -o '"finish_reason":"[^"]*"' || echo "  (no tool_calls returned -- see reference/troubleshooting.md)"

echo
echo "passed=$pass failed=$fail"
[[ $fail -eq 0 ]]
