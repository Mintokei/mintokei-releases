# Mintokei — Downloads & Install

Public downloads for **Mintokei**. These are the signed/built artifacts; the
source is private. Verify binaries against their matching `.sha256`.

> This repo's **Latest** release is the **Desktop** app (the auto-updater relies
> on it). The **API** and **Runner** binaries are tagged `api-v*` / `runner-v*` —
> use the commands below or browse all [Releases](../../releases).

## 🖥️ Desktop app

Grab the installer for your OS from the **[latest release](../../releases/latest)**:

- **Windows** — `Mintokei_*_x64-setup.exe` (or `.msi`)
- **macOS (Apple Silicon)** — `Mintokei_*_aarch64.dmg`
- **Linux** — `.AppImage`, `.deb`, or `.rpm`

Runs a local server out of the box and **auto-updates** itself. It can also
connect to a remote server (Sign out → enter the server URL).

## 🖧 Self-host the server

**Docker (recommended):**

```bash
# Bundled HTTPS — Caddy gets a Let's Encrypt cert for your domain:
curl -fsSL https://raw.githubusercontent.com/Mintokei/mintokei-releases/main/scripts/install-server.sh \
  | sudo bash -s -- --domain mintokei.example.com --email you@example.com

# Or plain HTTP behind your OWN reverse proxy (no domain/email needed):
curl -fsSL https://raw.githubusercontent.com/Mintokei/mintokei-releases/main/scripts/install-server.sh \
  | sudo bash -s -- --no-tls
```

…or manually: download `docker-compose.yml` + `env.example` from the latest
[**API release**](../../releases), set `DOMAIN` / `ACME_EMAIL` / `JWT_SIGNING_KEY`,
then `docker compose up -d` (set `COMPOSE_PROFILES=tls` for bundled HTTPS via the
included `Caddyfile`).

**Container images:** `ghcr.io/mintokei/mintokei-api` (API **+** WebApp UI) and
`ghcr.io/mintokei/mintokei-webapp`.

**Bare binary:** download `mintokei-api-<rid>` from the API release (serves the
API; serve the WebApp separately or use the image).

## 🤖 Add a runner (headless machine — no GUI needed)

On any Linux/macOS box:

```bash
curl -fsSL https://raw.githubusercontent.com/Mintokei/mintokei-releases/main/scripts/install-runner.sh \
  | sudo bash -s -- --backend https://your-server --token <enrollment-token>
```

Generate the one-time token in the WebApp → **Runners → Add**. The runner dials
**out** only (no inbound ports, no TLS). It installs as a systemd service. Or
download `mintokei-runner-<rid>` from the [Runner release](../../releases) and run
it directly.

---

*Artifacts are built from the private source by CI and published here. The
install scripts in `scripts/` are mirrored from source for stable bootstrap URLs.*
