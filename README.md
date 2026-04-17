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

## Notes

- The API key is stored unencrypted in the SQLite database. Protect the
  `/data` volume accordingly.
- HTTPS isn't terminated by the container — put it behind a reverse proxy
  (Caddy, nginx, Traefik) for real deployments. Once you do, set the
  cookie to `secure` by serving over HTTPS only.
