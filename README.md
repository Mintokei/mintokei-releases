# Mintokei Releases

Public release artifacts and the auto-update manifest (`latest.json`) for **Mintokei Desktop**.

- **Source code is private** (`Mintokei/mintokei`). Only compiled, signed binaries and the update manifest are published here — a public binary does not expose private source.
- The desktop app's updater fetches the manifest from this repo's **latest published release**:
  `https://github.com/Mintokei/mintokei-releases/releases/latest/download/latest.json`

## Releasing

Run **Actions → Desktop Release → Run workflow** with:
- `tag` — e.g. `desktop-v0.2.0` (bump `version` in the source's `tauri.conf.json` first)
- `source_ref` — the ref/sha in `Mintokei/mintokei` to build

It builds per-OS, signs the bundles, and publishes a **draft** release + `latest.json`. Review, then publish it; installs at or below that version auto-update on launch.

### Required secrets
| Secret | Purpose |
|---|---|
| `SOURCE_TOKEN` | read access to private `Mintokei/mintokei` |
| `TAURI_SIGNING_PRIVATE_KEY` | updater signing private key (generate locally; never commit) |
| `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` | its password |

Full setup: `docs/desktop-auto-update.md` in the source repo.
