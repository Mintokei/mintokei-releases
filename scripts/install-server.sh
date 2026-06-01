#!/usr/bin/env bash
# Mintokei server installer (Docker Compose path) — SKELETON.
#
# Brings up the self-hosted stack with one command. TLS is a toggle, not a
# separate build: pass --domain to enable bundled HTTPS (Caddy), or --no-tls to
# run plain HTTP behind your own proxy. See docs/packaging-distribution-options.md.
#
# Usage:
#   ./install-server.sh --domain mintokei.example.com --email you@example.com
#   ./install-server.sh --no-tls          # bring-your-own-proxy, plain HTTP on loopback
#
set -euo pipefail

# docker-compose.yml + Caddyfile are published as assets on the PUBLIC api-v*
# releases. That repo's "latest" release is the desktop app, so we resolve the
# newest api-v* tag rather than using /releases/latest.
RELEASES_REPO="Mintokei/mintokei-releases"
SERVER_TAG="${SERVER_TAG:-}"          # empty = auto-resolve newest api-v*; or pin e.g. api-v0.1.0
API_IMAGE="ghcr.io/mintokei/mintokei-api:latest"
WEBAPP_IMAGE="ghcr.io/mintokei/mintokei-webapp:latest"
INSTALL_DIR="${INSTALL_DIR:-/opt/mintokei}"

DOMAIN=""; EMAIL=""; TLS="caddy"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --email)  EMAIL="$2";  shift 2 ;;
    --no-tls) TLS="none";  shift ;;
    --tls)    TLS="$2";    shift 2 ;;   # caddy | none
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

command -v docker >/dev/null || { echo "docker is required" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "docker compose v2 is required" >&2; exit 1; }

# Interactive fill-in: a blank domain means "no bundled TLS, I'll use my own proxy".
if [[ "$TLS" == "caddy" && -z "$DOMAIN" ]]; then
  read -rp "Public domain (blank = no bundled TLS, use your own proxy): " DOMAIN
  [[ -z "$DOMAIN" ]] && TLS="none"
fi
if [[ "$TLS" == "caddy" && -z "$EMAIL" ]]; then
  read -rp "Email for Let's Encrypt: " EMAIL
fi

sudo mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Fetch docker-compose.yml + Caddyfile from the newest api-v* release assets
# (public). Resolve the tag unless one was pinned via SERVER_TAG.
if [[ -z "$SERVER_TAG" ]]; then
  SERVER_TAG=$(curl -fsSL "https://api.github.com/repos/${RELEASES_REPO}/releases" \
    | grep -oE '"tag_name": *"api-v[^"]+"' | head -1 | sed -E 's/.*"(api-v[^"]+)".*/\1/')
  [[ -n "$SERVER_TAG" ]] || { echo "could not resolve an api-v* release in ${RELEASES_REPO}" >&2; exit 1; }
fi
ASSET_BASE="https://github.com/${RELEASES_REPO}/releases/download/${SERVER_TAG}"
for f in docker-compose.yml Caddyfile; do
  [[ -f "$f" ]] || sudo curl -fsSL "$ASSET_BASE/$f" -o "$f"
done

# Generate .env on first run only (never clobber an existing one).
if [[ ! -f .env ]]; then
  JWT_KEY="$(openssl rand -base64 48)"
  {
    echo "DOMAIN=${DOMAIN:-localhost}"
    echo "ACME_EMAIL=${EMAIL}"
    echo "JWT_SIGNING_KEY=${JWT_KEY}"
    echo "API_IMAGE=${API_IMAGE}"
    echo "WEBAPP_IMAGE=${WEBAPP_IMAGE}"
    # DOMAIN-driven default: a real domain + TLS requested → enable Caddy.
    if [[ "$TLS" == "caddy" && -n "$DOMAIN" ]]; then
      echo "COMPOSE_PROFILES=tls"
    else
      echo "COMPOSE_PROFILES="
    fi
  } | sudo tee .env >/dev/null
fi

sudo docker compose pull
sudo docker compose up -d

echo
echo "Mintokei is starting in $INSTALL_DIR."
if [[ "$TLS" == "caddy" && -n "$DOMAIN" ]]; then
  echo "  → https://$DOMAIN  (Caddy is requesting a certificate; first load may take ~30s)"
  echo "  → Make sure DNS for $DOMAIN points at this host and ports 80+443 are open."
else
  echo "  → API:    http://127.0.0.1:8080     WebApp: http://127.0.0.1:8088"
  echo "  → Put your reverse proxy in front and forward WebSocket + h2c gRPC (see docs)."
fi
echo "  → Then open the WebApp, sign in, create a runner enrollment token, and"
echo "    install runners with scripts/install-runner.sh."
