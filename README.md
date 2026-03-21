# DGX local app

FastAPI control panel for **EchoMind** (Docker), **Personaplex / moshi** conversation server, and **Wi‑Fi hotspot** scripts on DGX Spark.

## Layout

| Path | Purpose |
|------|--------|
| `backend/` | FastAPI app (`main.py`), `static/index.html`, `requirements.txt` |
| `scripts/` | Hotspot + Personaplex shell scripts |
| `systemd/dgx-app.service` | Example unit for uvicorn on `:8000` + optional `ExecStartPost` hotspot |

## Quick start (dev)

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

## Production notes

- Install the systemd unit, then: `sudo systemctl enable --now dgx-app`
- Hotspot buttons / `ExecStartPost` need **passwordless sudo** for the scripts: `scripts/install_passwordless_sudo.sh`
- Override paths with env vars (see `main.py`: `ECHOMIND_*`, `HOTSPOT_*`, `PERSONAPLEX_*`)

## License

Add your license if this repo is public.
