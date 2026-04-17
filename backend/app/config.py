import os
import secrets
from pathlib import Path
from pydantic_settings import BaseSettings


def _load_or_create_secret(path: Path) -> str:
    if path.exists():
        return path.read_text().strip()
    path.parent.mkdir(parents=True, exist_ok=True)
    key = secrets.token_urlsafe(48)
    path.write_text(key)
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass
    return key


class Settings(BaseSettings):
    data_dir: str = "/data"
    database_url: str = ""
    secret_key: str = ""
    session_cookie: str = "raptorr_session"
    session_ttl_hours: int = 24 * 7
    cookie_secure: bool = False
    unifi_base_url: str = "https://api.ui.com"
    unifi_api_prefix: str = "/ea"
    unifi_device_window_days: int = 30
    cache_ttl_seconds: int = 30

    class Config:
        env_file = ".env"
        env_prefix = ""

    def model_post_init(self, _):
        Path(self.data_dir).mkdir(parents=True, exist_ok=True)
        if not self.database_url:
            self.database_url = f"sqlite:///{self.data_dir}/app.db"
        if not self.secret_key:
            self.secret_key = _load_or_create_secret(Path(self.data_dir) / ".secret_key")


settings = Settings()
