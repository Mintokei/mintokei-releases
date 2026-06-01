#!/usr/bin/env bash
# Mintokei runner installer for a HEADLESS (no-screen) machine — SKELETON.
#
# Downloads the self-contained runner binary, enrols it against your server with
# a one-time token, and installs it as a systemd service. The runner dials OUT
# only (gRPC + SignalR + tunnel WS) — no inbound ports, no TLS to terminate here,
# so this works on any server / build box / GPU host with no GUI.
#
# Generate the enrollment token in the WebApp: Runners → Add.
#
# Usage:
#   sudo ./install-runner.sh --backend https://mintokei.example.com --token <enrollment-token>
#
set -euo pipefail

# Runner binaries are published to the PUBLIC releases repo. Note: that repo's
# "latest" release is the desktop app, so we resolve the newest runner-v* tag
# rather than using /releases/latest.
REPO="Mintokei/mintokei-releases"
VERSION="${VERSION:-}"                # empty = auto-resolve newest runner-v*; or pin e.g. runner-v0.1.0
RUNNER_DATA="${RUNNER_DATA:-/var/lib/mintokei-runner}"
BIN_DIR="/opt/mintokei-runner"
BIN="$BIN_DIR/mintokei-runner"

BACKEND=""; TOKEN=""; NAME="$(hostname)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend) BACKEND="$2"; shift 2 ;;
    --token)   TOKEN="$2";   shift 2 ;;
    --name)    NAME="$2";    shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
[[ -n "$BACKEND" && -n "$TOKEN" ]] || { echo "need --backend and --token" >&2; exit 1; }

# Map host arch → release asset (self-contained single file).
case "$(uname -m)" in
  x86_64|amd64)  RID="linux-x64" ;;
  aarch64|arm64) RID="linux-arm64" ;;
  *) echo "unsupported arch $(uname -m)" >&2; exit 1 ;;
esac
ASSET="mintokei-runner-${RID}"

# Resolve the newest runner-v* tag unless one was pinned via VERSION.
if [[ -z "$VERSION" ]]; then
  VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases" \
    | grep -oE '"tag_name": *"runner-v[^"]+"' | head -1 | sed -E 's/.*"(runner-v[^"]+)".*/\1/')
  [[ -n "$VERSION" ]] || { echo "could not resolve a runner-v* release in ${REPO}" >&2; exit 1; }
fi
URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET}"

install -d "$BIN_DIR" "$RUNNER_DATA"
echo "Downloading $ASSET ($VERSION) ..."
curl -fsSL "$URL" -o "$BIN"           # tip: verify against the matching .sha256 before running
chmod +x "$BIN"

# One-time enrollment: run with the token until durable credentials are written,
# then stop. Subsequent starts load those creds and need no token.
echo "Enrolling runner '$NAME' against $BACKEND ..."
"$BIN" --backend "$BACKEND" --token "$TOKEN" --name "$NAME" --data-dir "$RUNNER_DATA" &
ENROLL_PID=$!
for _ in $(seq 1 30); do
  [[ -f "$RUNNER_DATA/runner-credentials.json" ]] && break
  sleep 1
done
kill "$ENROLL_PID" 2>/dev/null || true
wait "$ENROLL_PID" 2>/dev/null || true
[[ -f "$RUNNER_DATA/runner-credentials.json" ]] || { echo "enrollment failed — check token/backend" >&2; exit 1; }

# systemd service — runs without a token (credentials are persisted).
# NOTE: runs as root here for simplicity. To let agents use a specific user's
# CLI tool configs (Claude Code / Codex auth), set User= to that account and
# chown "$RUNNER_DATA" to it.
cat >/etc/systemd/system/mintokei-runner.service <<EOF
[Unit]
Description=Mintokei Runner
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=${BIN} --backend ${BACKEND} --name ${NAME} --data-dir ${RUNNER_DATA}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mintokei-runner
echo "Runner '$NAME' installed and connected. Status: systemctl status mintokei-runner"
