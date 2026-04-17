# Raptorr

Unified management for the UniFi Site Manager API — a small Docker app to
search every device across every site behind your API key, and manage who on
your team can use it.

## Features

- **Device search** across every site behind your Site Manager API key
  (name, MAC, IP, model, firmware, site, host).
- **Role-based access** for the app itself. Built-in `admin`, `operator`,
  `viewer` roles plus custom roles with fine-grained permissions.
- **First-run setup wizard** creates the initial admin and (optionally)
  stores your API key.
- **Single container.** FastAPI backend, React + Tailwind frontend, SQLite
  persisted on a volume.

## Quick start

```bash
docker compose up -d --build
```

Open <http://localhost:8080> and walk through the setup wizard.

### Without compose

```bash
docker build -t raptorr .
docker run -d --name raptorr \
  -p 8080:8080 \
  -v "$(pwd)/data:/data" \
  raptorr
```

## Configuration

All environment variables are optional. Useful ones:

| Variable            | Default                 | Notes                                    |
| ------------------- | ----------------------- | ---------------------------------------- |
| `SECRET_KEY`        | auto-generated in `/data/.secret_key` | Set to keep sessions across rebuilds |
| `UNIFI_BASE_URL`    | `https://api.ui.com`    |                                          |
| `UNIFI_API_PREFIX`  | `/ea`                   | Change to `/v1` if UI rotates the prefix |
| `SESSION_TTL_HOURS` | `168` (7 days)          |                                          |
| `CACHE_TTL_SECONDS` | `30`                    | Caches hosts + devices to save rate limit |

Data is persisted to `/data` inside the container. Mount it to a host path.

## Getting a Site Manager API key

1. Sign in to <https://unifi.ui.com>.
2. Open the **API** section and create a key.
3. Paste it into the setup wizard, or later under **Settings → API key**.

The Site Manager API is currently read-only and rate-limited to 100 req/min.
Raptorr caches `hosts`/`devices` responses to stay well under that.

## Local console integrations (optional)

The Site Manager cloud API returns lagging, aggregated device state with no
per-site attribution. To get fresh, site-accurate devices and clients straight
from a UOS console, configure a local Network Integration API integration per
console in **Settings → UniFi OS consoles**.

Requirements:

1. A **Control Plane API key** generated on the UOS console
   (*Control Plane → Admins & Users → Create API Key*). This is different from
   the Site Manager API key at unifi.ui.com.
2. **Network reachability** from the Raptorr container to the console's IP or
   hostname on TCP 443. Same LAN works directly; otherwise add a VPN/Tailscale
   sidecar to the compose stack.

The `unifi.ui.com` cloud proxy is *not* supported — that path requires
browser session cookies and does not accept the Control Plane API key.

## Development

Run the backend and frontend separately while iterating:

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

| Permission         | Grants                                    |
| ------------------ | ----------------------------------------- |
| `devices:read`     | Search devices and view sites             |
| `users:read`       | View users                                |
| `users:manage`     | Create / edit / delete users              |
| `roles:read`       | View roles                                |
| `roles:manage`     | Create / edit / delete non-builtin roles  |
| `settings:read`    | View API key status                       |
| `settings:manage`  | Change the UniFi API key                  |

The `admin` built-in role always has every permission and can't be modified
or deleted.

## Security

**Secrets at rest.** All UniFi credentials stored in the SQLite database are
encrypted with Fernet (AES-128-CBC + HMAC-SHA256). The encryption key is
derived from `SECRET_KEY` via HKDF, so:

- The encryption key never lives in the database.
- Rotating `SECRET_KEY` rotates the encryption key.
- Anyone with DB-only access can't read the API keys without `SECRET_KEY`.
- **`SECRET_KEY` must be preserved across restarts.** It is auto-generated
  once and persisted to `/data/.secret_key`. If you recreate the container
  without keeping `/data`, stored secrets become unreadable and you'll need
  to re-enter them.

User passwords are hashed with bcrypt. Session IDs are random opaque tokens
(not a secret source, so not encrypted).

**In transit.**

- Raptorr ↔ `api.ui.com` and browser ↔ `unifi.ui.com` are HTTPS with
  certificate verification.
- Raptorr ↔ local UOS console is HTTPS. Per-integration `verify_tls` toggle
  lets you keep cert verification on when going through the cloud proxy and
  turn it off for direct LAN connections with self-signed certs.
- Browser ↔ Raptorr is **plain HTTP** inside the container. Put Raptorr
  behind a reverse proxy (Caddy, nginx, Traefik) that terminates TLS, then
  set `COOKIE_SECURE=true` so session cookies are only sent over HTTPS:

  ```yaml
  environment:
    COOKIE_SECURE: "true"
  ```

**Backups.** The `/data` volume contains the SQLite DB and the persisted
`SECRET_KEY`. Back them up together — the DB is useless without the key,
and the key is useless without the DB.
