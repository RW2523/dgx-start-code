import asyncio
import logging
import os
import socket
import subprocess
from pathlib import Path

from fastapi import BackgroundTasks, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

logger = logging.getLogger(__name__)

app = FastAPI()

_cors = os.environ.get("CORS_ALLOW_ORIGINS", "*")
_cors_origins = [o.strip() for o in _cors.split(",") if o.strip()] or ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_DIR = os.path.join(BASE_DIR, "static")

# Uncommon dev port (avoids 3000, 5173, 8000, 8080, …). Override with DGX_APP_PORT.
DGX_APP_PORT = int(os.environ.get("DGX_APP_PORT", "28734"))

ECHOMIND_COMPOSE_DIR = os.environ.get(
    "ECHOMIND_COMPOSE_DIR",
    str(Path.home() / "Documents" / "echomind" / "echomind-enterprise"),
)
ECHOMIND_PUBLIC_URL = os.environ.get(
    "ECHOMIND_PUBLIC_URL",
    "http://10.10.0.1:3443",
)
PERSONAPLEX_PUBLIC_URL = os.environ.get(
    "PERSONAPLEX_PUBLIC_URL",
    "https://127.0.0.1:8998",
)
ECHOMIND_CHECK_PORT = int(os.environ.get("ECHOMIND_CHECK_PORT", "3443"))
PERSONAPLEX_CHECK_PORT = int(os.environ.get("PERSONAPLEX_CHECK_PORT", "8998"))
PORT_CHECK_HOST = os.environ.get("PORT_CHECK_HOST", "127.0.0.1")
PORT_CHECK_TIMEOUT = float(os.environ.get("PORT_CHECK_TIMEOUT_SEC", "0.5"))

REPO_ROOT = Path(BASE_DIR).resolve().parent
_PERSONAPLEX_SCRIPT = os.environ.get(
    "PERSONAPLEX_CONVERSATION_SCRIPT",
    str(REPO_ROOT / "scripts" / "personaplex_conversation.sh"),
)
_H_SETUP = os.environ.get(
    "HOTSPOT_SETUP_SCRIPT",
    str(REPO_ROOT / "scripts" / "setup_hotspot_stack.sh"),
)
_H_START = os.environ.get(
    "HOTSPOT_START_SCRIPT",
    str(REPO_ROOT / "scripts" / "start_hotspot_stack.sh"),
)
_H_STOP = os.environ.get(
    "HOTSPOT_STOP_SCRIPT",
    str(REPO_ROOT / "scripts" / "stop_hotspot_stack.sh"),
)
_H_UNDO = os.environ.get(
    "HOTSPOT_UNDO_SCRIPT",
    str(REPO_ROOT / "scripts" / "undo_hotspot_stack.sh"),
)
_H_ENABLE = os.environ.get(
    "HOTSPOT_ENABLE_SCRIPT",
    str(REPO_ROOT / "scripts" / "hotspot_enable.sh"),
)
_H_DISABLE = os.environ.get(
    "HOTSPOT_DISABLE_SCRIPT",
    str(REPO_ROOT / "scripts" / "hotspot_disable.sh"),
)
_H_SAFE_STOP = os.environ.get(
    "HOTSPOT_SAFE_STOP_SCRIPT",
    str(REPO_ROOT / "scripts" / "hotspot_safe_stop.sh"),
)

# dgx-app is not managed by hotspot scripts — status is hotspot + reverse proxy only.
HOTSPOT_SYSTEMD_UNITS = os.environ.get(
    "HOTSPOT_SYSTEMD_UNITS",
    "hotspot-ip,hostapd,dnsmasq,nginx",
).split(",")

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


class EchomindStartResponse(BaseModel):
    ok: bool
    url: str
    message: str


class HotspotActionResponse(BaseModel):
    ok: bool
    message: str


class HotspotStatusResponse(BaseModel):
    overall: str
    summary: str
    services: dict[str, dict[str, str]]


class PersonaplexConversationResponse(BaseModel):
    ok: bool
    message: str
    url: str


class PortServiceStatus(BaseModel):
    port: int
    label: str
    active: bool
    url: str


class AppPortsResponse(BaseModel):
    services: list[PortServiceStatus]


def _tcp_port_open(host: str, port: int, timeout: float) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def _app_ports_status() -> AppPortsResponse:
    host = PORT_CHECK_HOST
    checks: list[tuple[int, str, str]] = [
        (ECHOMIND_CHECK_PORT, "EchoMind (port 3443)", ECHOMIND_PUBLIC_URL),
        (PERSONAPLEX_CHECK_PORT, "Personaplex / moshi (port 8998)", PERSONAPLEX_PUBLIC_URL),
    ]
    services = [
        PortServiceStatus(
            port=p,
            label=label,
            active=_tcp_port_open(host, p, PORT_CHECK_TIMEOUT),
            url=url,
        )
        for p, label, url in checks
    ]
    return AppPortsResponse(services=services)


def _run_hotspot_script(script_path: str, timeout_sec: int = 300) -> tuple[bool, str]:
    script = Path(script_path).resolve()
    if not script.is_file():
        return False, f"Script not found: {script}"
    r = subprocess.run(
        ["sudo", str(script)],
        capture_output=True,
        text=True,
        timeout=timeout_sec,
    )
    combined = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0:
        err = combined.strip() or f"Exit code {r.returncode}"
        if "terminal is required" in err.lower() or "password is required" in err.lower():
            err += (
                "\n\nInstall passwordless sudo for the hotspot scripts (one-time, from a real "
                "terminal): cd …/dgx-local-app/scripts && ./install_passwordless_sudo.sh"
            )
        return False, err
    return True, combined.strip() or "Done."


def _systemctl_line(args: list[str]) -> str:
    try:
        r = subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=15,
        )
        line = (r.stdout or "").strip().splitlines()
        return line[0] if line else "unknown"
    except (OSError, subprocess.TimeoutExpired):
        return "unknown"


def _systemctl_show_props(unit: str) -> dict[str, str]:
    try:
        r = subprocess.run(
            ["systemctl", "show", unit, "-p", "ActiveState", "-p", "SubState"],
            capture_output=True,
            text=True,
            timeout=15,
        )
        out: dict[str, str] = {}
        for line in (r.stdout or "").strip().splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                out[k] = v
        return out
    except (OSError, subprocess.TimeoutExpired):
        return {}


def _hotspot_status() -> HotspotStatusResponse:
    units = [u.strip() for u in HOTSPOT_SYSTEMD_UNITS if u.strip()]
    services: dict[str, dict[str, str]] = {}
    active_count = 0
    for name in units:
        props = _systemctl_show_props(name)
        active_state = props.get("ActiveState", "unknown")
        sub_state = props.get("SubState", "")
        enabled = _systemctl_line(["systemctl", "is-enabled", name])
        display_active = (
            f"{active_state} ({sub_state})" if sub_state else active_state
        )
        services[name] = {"active": display_active, "enabled": enabled}
        if active_state == "active":
            active_count += 1

    n = len(units)
    if n == 0:
        overall = "unknown"
        summary = "No hotspot units configured to check."
    elif active_count == n:
        overall = "running"
        summary = f"Hotspot stack is running ({n}/{n} services active)."
    elif active_count == 0:
        overall = "stopped"
        summary = f"Hotspot stack is stopped (0/{n} services active)."
    else:
        overall = "partial"
        summary = (
            f"Hotspot stack is partially running ({active_count}/{n} services active)."
        )

    return HotspotStatusResponse(overall=overall, summary=summary, services=services)


def _run_compose_restart() -> tuple[bool, str, str]:
    root = Path(ECHOMIND_COMPOSE_DIR).resolve()
    if not root.is_dir():
        return False, "", f"Compose directory does not exist: {root}"
    compose_file = root / "compose.yaml"
    alt = root / "docker-compose.yml"
    if not compose_file.is_file() and not alt.is_file():
        return (
            False,
            "",
            f"No compose.yaml or docker-compose.yml in {root}",
        )

    def run(args: list[str]) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            args,
            cwd=root,
            capture_output=True,
            text=True,
            timeout=3600,
        )

    down = run(["docker", "compose", "down"])
    if down.returncode != 0:
        err = (down.stderr or down.stdout or "").strip() or "docker compose down failed"
        return False, "", err

    # -d so containers stay up and this call can return (same as typical "up" for a server).
    up = run(["docker", "compose", "up", "-d"])
    if up.returncode != 0:
        err = (up.stderr or up.stdout or "").strip() or "docker compose up failed"
        return False, "", err

    return True, ECHOMIND_PUBLIC_URL, "EchoMind: docker compose down + up -d finished OK."


def _run_personaplex_conversation() -> tuple[bool, str]:
    script = Path(_PERSONAPLEX_SCRIPT).resolve()
    if not script.is_file():
        return False, f"Script not found: {script}"
    r = subprocess.run(
        ["/bin/bash", str(script)],
        capture_output=True,
        text=True,
        timeout=int(os.environ.get("PERSONAPLEX_BUILD_TIMEOUT_SEC", "120")),
        env=os.environ.copy(),
    )
    combined = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0:
        return False, combined.strip() or f"Exit code {r.returncode}"
    return True, combined.strip() or "Done."


@app.get("/health")
def health():
    return {"status": "ok", "port": DGX_APP_PORT}


@app.get("/api/apps/ports", response_model=AppPortsResponse)
async def apps_ports():
    """TCP reachability of EchoMind (3443) and Personaplex moshi (8998) on this host."""
    return await asyncio.to_thread(_app_ports_status)


def _echomind_compose_background() -> None:
    """Runs in FastAPI BackgroundTasks after the HTTP response is sent (avoids nginx/browser timeouts)."""
    ok, _url, detail = _run_compose_restart()
    if ok:
        logger.info("EchoMind docker compose: %s", detail)
    else:
        logger.error("EchoMind docker compose failed: %s", detail)


@app.post("/api/echomind/start", response_model=EchomindStartResponse)
async def echomind_start(background_tasks: BackgroundTasks):
    # Do not block the request on docker (can take many minutes) — prevents "NetworkError" via nginx :80.
    background_tasks.add_task(_echomind_compose_background)
    return EchomindStartResponse(
        ok=True,
        url=ECHOMIND_PUBLIC_URL,
        message=(
            "Started: docker compose down, then docker compose up -d (background). "
            "Wait a few minutes, then open the link. "
            "If something fails, check: sudo journalctl -u dgx-app -n 80 --no-pager"
        ),
    )


@app.get("/api/personaplex/conversation")
async def personaplex_conversation_ping():
    """GET = ping only. POST runs moshi.server only (no npm build); see scripts/personaplex_conversation.sh."""
    script = Path(_PERSONAPLEX_SCRIPT).resolve()
    return {
        "use_post": True,
        "script_exists": script.is_file(),
        "script_path": str(script),
    }


@app.post(
    "/api/personaplex/conversation",
    response_model=PersonaplexConversationResponse,
)
@app.post(
    "/api/personaplex/conversation/",
    response_model=PersonaplexConversationResponse,
)
async def personaplex_conversation():
    ok, message = await asyncio.to_thread(_run_personaplex_conversation)
    if not ok:
        raise HTTPException(status_code=500, detail=message)
    return PersonaplexConversationResponse(
        ok=True,
        message=message,
        url=PERSONAPLEX_PUBLIC_URL,
    )


# Short alias (some proxies or bookmarks choke on long paths)
@app.post(
    "/api/personaplex/start",
    response_model=PersonaplexConversationResponse,
)
async def personaplex_start_alias():
    ok, message = await asyncio.to_thread(_run_personaplex_conversation)
    if not ok:
        raise HTTPException(status_code=500, detail=message)
    return PersonaplexConversationResponse(
        ok=True,
        message=message,
        url=PERSONAPLEX_PUBLIC_URL,
    )


@app.get("/api/hotspot/status", response_model=HotspotStatusResponse)
async def hotspot_status():
    return await asyncio.to_thread(_hotspot_status)


@app.post("/api/hotspot/enable", response_model=HotspotActionResponse)
async def hotspot_enable():
    ok, message = await asyncio.to_thread(_run_hotspot_script, _H_ENABLE, 7200)
    if not ok:
        raise HTTPException(status_code=500, detail=message)
    return HotspotActionResponse(ok=True, message=message)


@app.post("/api/hotspot/disable", response_model=HotspotActionResponse)
async def hotspot_disable():
    ok, message = await asyncio.to_thread(_run_hotspot_script, _H_DISABLE, 600)
    if not ok:
        raise HTTPException(status_code=500, detail=message)
    return HotspotActionResponse(ok=True, message=message)


@app.post("/api/hotspot/safe-stop", response_model=HotspotActionResponse)
async def hotspot_safe_stop():
    ok, message = await asyncio.to_thread(_run_hotspot_script, _H_SAFE_STOP, 300)
    if not ok:
        raise HTTPException(status_code=500, detail=message)
    return HotspotActionResponse(ok=True, message=message)


@app.post("/api/hotspot/setup", response_model=HotspotActionResponse)
async def hotspot_setup():
    ok, message = await asyncio.to_thread(_run_hotspot_script, _H_SETUP, 7200)
    if not ok:
        raise HTTPException(status_code=500, detail=message)
    return HotspotActionResponse(ok=True, message=message)


@app.post("/api/hotspot/start", response_model=HotspotActionResponse)
async def hotspot_start():
    ok, message = await asyncio.to_thread(_run_hotspot_script, _H_START)
    if not ok:
        raise HTTPException(status_code=500, detail=message)
    return HotspotActionResponse(ok=True, message=message)


@app.post("/api/hotspot/stop", response_model=HotspotActionResponse)
async def hotspot_stop():
    ok, message = await asyncio.to_thread(_run_hotspot_script, _H_STOP)
    if not ok:
        raise HTTPException(status_code=500, detail=message)
    return HotspotActionResponse(ok=True, message=message)


@app.post("/api/hotspot/undo", response_model=HotspotActionResponse)
async def hotspot_undo():
    ok, message = await asyncio.to_thread(_run_hotspot_script, _H_UNDO, 600)
    if not ok:
        raise HTTPException(status_code=500, detail=message)
    return HotspotActionResponse(ok=True, message=message)


@app.get("/")
def root():
    return FileResponse(os.path.join(STATIC_DIR, "index.html"))
