"""Turnstile Solver 进程管理 - 后端启动时自动拉起"""
import subprocess
import sys
import os
import time
import threading
from pathlib import Path
import requests
from core.runtime_paths import env_flag, resolve_runtime_file

SOLVER_PORT = int(os.getenv("SOLVER_PORT", "8889"))
SOLVER_URL = f"http://127.0.0.1:{SOLVER_PORT}"
SOLVER_BROWSER_TYPE = str(os.getenv("APP_SOLVER_BROWSER_TYPE", "chromium") or "chromium").strip()
SOLVER_HEADLESS = env_flag("APP_SOLVER_HEADLESS", True)
AUTO_START_SOLVER = env_flag("APP_AUTO_START_SOLVER", True)
SOLVER_LOG_PATH = resolve_runtime_file(
    "APP_SOLVER_LOG_PATH",
    "logs/solver/solver.log",
    Path(__file__).resolve().parent / "turnstile_solver" / "solver.log",
)
_proc: subprocess.Popen = None
_log_file = None
_lock = threading.Lock()


def is_running() -> bool:
    try:
        r = requests.get(f"{SOLVER_URL}/", timeout=2)
        return r.status_code < 500
    except Exception:
        return False


def auto_start_enabled() -> bool:
    return AUTO_START_SOLVER


def start():
    global _proc, _log_file
    with _lock:
        if is_running():
            print("[Solver] 已在运行")
            return
        solver_script = os.path.join(
            os.path.dirname(__file__), "turnstile_solver", "start.py"
        )
        log_path = str(SOLVER_LOG_PATH)
        _log_file = open(log_path, "a", encoding="utf-8")
        command = [
            sys.executable,
            "-u",
            solver_script,
            "--browser_type",
            SOLVER_BROWSER_TYPE,
            "--port",
            str(SOLVER_PORT),
        ]
        if not SOLVER_HEADLESS:
            command.append("--no-headless")
        _proc = subprocess.Popen(command, stdout=_log_file, stderr=subprocess.STDOUT)
        # 等待服务就绪（最多30s）
        for _ in range(30):
            time.sleep(1)
            if is_running():
                print(f"[Solver] 已启动 PID={_proc.pid}")
                return
            if _proc.poll() is not None:
                print(f"[Solver] 启动失败，退出码={_proc.returncode}，日志: {log_path}")
                _proc = None
                if _log_file:
                    _log_file.close()
                    _log_file = None
                return
        print(f"[Solver] 启动超时，日志: {log_path}")


def stop():
    global _proc, _log_file
    with _lock:
        if _proc and _proc.poll() is None:
            _proc.terminate()
            _proc.wait(timeout=5)
            print("[Solver] 已停止")
        _proc = None
        if _log_file:
            _log_file.close()
            _log_file = None


def start_async():
    """在后台线程启动，不阻塞主进程"""
    if not AUTO_START_SOLVER:
        print("[Solver] 已通过 APP_AUTO_START_SOLVER=0 禁用自动启动")
        return
    t = threading.Thread(target=start, daemon=True)
    t.start()
