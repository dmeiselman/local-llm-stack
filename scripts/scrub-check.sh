#!/usr/bin/env bash
# Anonymization gate: fail if a personal/host identifier or a real secret is
# about to be committed. Scans git-tracked files only.
#
# This file deliberately contains NO identifying literals of its own. It checks:
#   1. Generic secret SHAPES (API-key-like tokens, GitHub tokens, long hex).
#   2. Real RFC1918 LAN IPv4 addresses (should be placeholders, not real IPs).
#   3. Your current username / short hostname, derived at RUNTIME.
#   4. Any extra site-specific regexes in scripts/.scrub-patterns (gitignored) --
#      put your real domain, old secret prefixes, etc. there; they never get
#      committed. See scripts/.scrub-patterns.example.
set -uo pipefail
cd "$(dirname "$0")/.."

self='scripts/scrub-check.sh'

patterns=()
# --- generic secret shapes ---
patterns+=('sk-[A-Za-z0-9_-]{16,}')                 # OpenAI/LiteLLM-style API keys
patterns+=('gh[pousr]_[A-Za-z0-9]{20,}')            # GitHub tokens
patterns+=('[0-9a-f]{40,}')                         # long hex secrets (e.g. searxng secret_key)
# --- real private-range IPv4 (full dotted quads only, to avoid version-string noise) ---
patterns+=('\b10(\.[0-9]{1,3}){3}\b')
patterns+=('\b192\.168(\.[0-9]{1,3}){2}\b')
patterns+=('\b172\.(1[6-9]|2[0-9]|3[01])(\.[0-9]{1,3}){2}\b')
# --- runtime-derived identity (never written into this file) ---
u=$(id -un 2>/dev/null || true); [ -n "${u:-}" ] && patterns+=("\\b${u}\\b")
h=$(hostname -s 2>/dev/null || true); [ -n "${h:-}" ] && patterns+=("\\b${h}\\b")
# --- optional site-specific extras (gitignored) ---
if [ -f scripts/.scrub-patterns ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    patterns+=("$line")
  done < scripts/.scrub-patterns
fi

files() { git ls-files 2>/dev/null | grep -vx "$self"; }

hits=0
for pat in "${patterns[@]}"; do
  if m=$(files | xargs -r grep -InE -- "$pat" 2>/dev/null); then
    echo "FORBIDDEN pattern /$pat/ matched:"
    echo "$m"
    hits=1
  fi
done

if [ "$hits" -eq 0 ]; then
  echo "scrub-check: clean."
else
  echo
  echo "scrub-check: FAILED -- replace the above with placeholders before committing."
fi
exit "$hits"
