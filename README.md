# Raptorr

A small Docker app that gives you a unified, multi-console dashboard for
UniFi OS consoles reachable on your LAN (or via VPN / Tailscale). Raptorr
talks to each console's **local Network Integration API** directly — no
cloud Site Manager API dependency — so the device and client data is
real-time and per-site accurate.

## Features

- **Multi-console device search.** Fan out across every configured UOS
  console and search UniFi devices by name, MAC, IP, model, site, or
  console.
- **Per-site drill-down.** Browse each console's sites and expand to see
  devices and clients for that site, straight from the Network Integration
  API.
- **Role-based app access.** Built-in `admin`, `operator`, `viewer` roles
  plus custom roles with fine-grained permissions.
- **First-run setup wizard** creates the initial admin account.
- **Single container.** FastAPI backend, React + Tailwind frontend,
  SQLite persisted on a volume.
- **Secrets encrypted at rest** (Fernet, key derived from `SECRET_KEY`
  via HKDF). Optional `Secure` cookie when running behind HTTPS.

## Requirements

Raptorr needs **network reachability** from its Docker host to each UOS
console on TCP 443:

- **Same LAN:** run Raptorr on a host on the same network as the console.
- **Remote:** add a Tailscale or VPN sidecar to the compose stack so the
  container can route to the console's IP.

The cloud path `unifi.ui.com/proxy/consoles/…` is **not supported** —
that proxy needs browser session cookies, not API keys.

## Quick start

```bash
docker compose up -d --build
```

Open <http://localhost:8080>, walk through the setup wizard, then go to
**Consoles → Add console**. For each console you'll need:

1. A friendly **name** (e.g. "HQ main").
2. The console's **base URL** — usually `https://<console-ip>`.
3. A **Control Plane API key** generated on the UOS console:
   *Control Plane → Admins & Users → Create API Key*. (This is a local key
   on the console itself, separate from the Site Manager API key at
   unifi.ui.com.)

Use **Test connection** to verify Raptorr can reach the console and that
the key is accepted. Then **Save**.

### Without compose

```bash
docker build -t raptorr .
docker run -d --name raptorr \
  -p 8080:8080 \
  -v "$(pwd)/data:/data" \
  raptorr
```

## Configuration

| Variable            | Default                              | Notes                                      |
| ------------------- | ------------------------------------ | ------------------------------------------ |
| `SECRET_KEY`        | auto-generated in `/data/.secret_key` | Preserve across rebuilds                  |
| `SESSION_TTL_HOURS` | `168` (7 days)                        |                                            |
| `CACHE_TTL_SECONDS` | `30`                                  | Per-console inventory cache                |
| `COOKIE_SECURE`     | `false`                               | Set to `true` when behind TLS reverse proxy |

Data is persisted to `/data` inside the container.

## Development

```bash
# backend
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
DATA_DIR=./_data uvicorn app.main:app --reload --port 8080

# frontend (in another terminal)
cd frontend
npm install
npm run dev
```

Vite dev server runs on <http://localhost:5173> and proxies `/api` to 8080.

## Permissions

| Permission         | Grants                                        |
| ------------------ | --------------------------------------------- |
| `devices:read`     | Search devices, view consoles, view sites     |
| `consoles:manage`  | Add / edit / delete console connections       |
| `users:read`       | View users                                    |
| `users:manage`     | Create / edit / delete users                  |
| `roles:read`       | View roles                                    |
| `roles:manage`     | Create / edit / delete non-builtin roles      |

The `admin` built-in role always has every permission and can't be modified
or deleted.

## Security

**Secrets at rest.** Every Control Plane API key stored in the SQLite
database is Fernet-encrypted (AES-128-CBC + HMAC-SHA256). The encryption
key is derived from `SECRET_KEY` via HKDF, so it never lives in the
database and rotating `SECRET_KEY` rotates the encryption. Legacy plaintext
values (from earlier versions) are still readable and upgrade on next
write.

**`SECRET_KEY` must be preserved across restarts.** It is auto-generated
once and persisted to `/data/.secret_key`. Recreate `/data` and your stored
secrets become unrecoverable.

**Passwords** are bcrypt hashed.

**In transit.**

- Raptorr ↔ UOS console: HTTPS. Per-console `Verify TLS` toggle; uncheck
  for direct LAN with self-signed certs.
- Browser ↔ Raptorr: plain HTTP inside the container. Terminate TLS at a
  reverse proxy (Caddy, Traefik, nginx) and set `COOKIE_SECURE=true` so
  session cookies only fly over HTTPS.

**Backups.** Back up `/data` (DB) and `/data/.secret_key` together — one
without the other is useless.
