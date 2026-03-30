"""运行时路径与环境开关工具。"""
from __future__ import annotations

import os
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
_APP_DATA_DIR = str(os.getenv("APP_DATA_DIR", "") or "").strip()


def _resolve_path(env_name: str, app_data_relative: str, legacy_default: str | Path) -> Path:
    raw = str(os.getenv(env_name, "") or "").strip()
    if raw:
        return Path(raw).expanduser()
    if _APP_DATA_DIR:
        return Path(_APP_DATA_DIR).expanduser() / app_data_relative
    return Path(legacy_default)


def resolve_runtime_dir(env_name: str, app_data_relative: str, legacy_default: str | Path) -> Path:
    path = _resolve_path(env_name, app_data_relative, legacy_default)
    path.mkdir(parents=True, exist_ok=True)
    return path


def resolve_runtime_file(env_name: str, app_data_relative: str, legacy_default: str | Path) -> Path:
    path = _resolve_path(env_name, app_data_relative, legacy_default)
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def env_flag(name: str, default: bool = False) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def default_solver_url() -> str:
    return str(
        os.getenv("APP_LOCAL_SOLVER_URL")
        or f"http://localhost:{os.getenv('SOLVER_PORT', '8889')}"
    ).rstrip("/")
