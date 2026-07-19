#!/usr/bin/env bash
# Render every *.template / *.example under config/, systemd/, compose/ into real
# files by substituting the __PLACEHOLDERS__. This does NOT install anything --
# it just produces filled copies next to the templates (without the suffix) that
# you then copy into place (see scripts/install-units.sh and the recipes).
#
# Values come from scripts/lib.sh and the environment. Secrets come from
# config/litellm/.env (run gen-secrets.sh first) unless overridden.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=lib.sh
source scripts/lib.sh

# Pull the master key from the generated .env if present.
if [[ -f config/litellm/.env ]]; then
  # shellcheck disable=SC1091
  source config/litellm/.env
fi
: "${LITELLM_MASTER_KEY:?run scripts/gen-secrets.sh first, or export LITELLM_MASTER_KEY}"
: "${SEARXNG_SECRET:?export SEARXNG_SECRET (gen-secrets.sh prints one)}"

render() {
  local src="$1" dst="$2"
  info "render $src -> $dst"
  sed \
    -e "s#__USER__#$(id -un)#g" \
    -e "s#__HOME__#$HOME#g" \
    -e "s#__LLAMACPP_BIN__#${LLAMACPP_BIN}#g" \
    -e "s#__MODELS_DIR__#${MODELS_DIR}#g" \
    -e "s#__LLAMASWAP_DIR__#${LLAMASWAP_DIR}#g" \
    -e "s#__LITELLM_MASTER_KEY__#${LITELLM_MASTER_KEY}#g" \
    -e "s#__SEARXNG_SECRET__#${SEARXNG_SECRET}#g" \
    "$src" > "$dst"
}

# Render each template to a sibling file with the suffix stripped.
while IFS= read -r -d '' tpl; do
  out="${tpl%.template}"; out="${out%.example}"
  render "$tpl" "$out"
done < <(find config systemd compose -type f \( -name '*.template' -o -name '*.example' \) -print0)

echo
echo "Done. Rendered files sit next to their templates (e.g. config/llama-swap/config.yaml)."
echo "Rendered files may contain secrets and are gitignored -- copy them into place per the recipes."
