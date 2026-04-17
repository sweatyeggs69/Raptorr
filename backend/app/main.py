import os
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from .db import init_db
from .routes import auth, devices, roles, settings as settings_route, setup, users

# Ensure tables exist as soon as the module is imported so both
# `uvicorn app.main:app` and `TestClient(app)` pick them up.
init_db()

app = FastAPI(title="Raptorr", version="0.1.0")


@app.get("/api/health")
def health():
    return {"ok": True}


app.include_router(setup.router, prefix="/api/setup", tags=["setup"])
app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(users.router, prefix="/api/users", tags=["users"])
app.include_router(roles.router, prefix="/api/roles", tags=["roles"])
app.include_router(devices.router, prefix="/api/devices", tags=["devices"])
app.include_router(settings_route.router, prefix="/api/settings", tags=["settings"])


@app.exception_handler(404)
async def _spa_fallback(request: Request, exc):
    # only fall through to SPA for GETs to non-API paths
    if request.method == "GET" and not request.url.path.startswith("/api"):
        index = Path(os.getenv("STATIC_DIR", "/app/static")) / "index.html"
        if index.is_file():
            return FileResponse(index)
    return JSONResponse({"detail": "Not Found"}, status_code=404)


static_dir = Path(os.getenv("STATIC_DIR", "/app/static"))
if (static_dir / "assets").is_dir():
    app.mount("/assets", StaticFiles(directory=static_dir / "assets"), name="assets")


@app.get("/", include_in_schema=False)
def _root():
    index = static_dir / "index.html"
    if index.is_file():
        return FileResponse(index)
    return JSONResponse({"detail": "Frontend not built"}, status_code=500)
