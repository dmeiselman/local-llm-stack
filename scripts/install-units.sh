#!/usr/bin/env bash
# Copy the RENDERED systemd unit files into /etc/systemd/system and reload.
# Run render-configs.sh first so the units have real paths (not __PLACEHOLDERS__).
# Needs sudo -- this prints what it will do and asks before touching anything.
#
# It installs llama-swap + open-webui by default. It does NOT enable the voice
# units (speaches/kokoro) or the single-model llama-server alternative.
set -euo pipefail
cd "$(dirname "$0")/.."

UNITS=(systemd/llama-swap.service systemd/open-webui.service)

echo "About to install these rendered units to /etc/systemd/system/:"
for u in "${UNITS[@]}"; do
  [[ -f "$u" ]] || { echo "  MISSING: $u (run scripts/render-configs.sh first)"; exit 1; }
  echo "  $u"
  grep -q '__' "$u" && { echo "  ^ still has __PLACEHOLDERS__ -- render first"; exit 1; }
done
read -r -p "Proceed with sudo? [y/N] " ans
[[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "aborted"; exit 0; }

for u in "${UNITS[@]}"; do
  sudo cp "$u" /etc/systemd/system/
done
sudo systemctl daemon-reload
echo
echo "Installed. Enable + start with:"
echo "  sudo systemctl enable --now llama-swap open-webui"
echo "(Start the docker compose stack separately -- see recipes/02-gateway-and-chat.)"
