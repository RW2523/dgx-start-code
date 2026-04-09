# DGX local app

FastAPI control panel for **EchoMind** (Docker), **Personaplex / moshi** conversation server, and **Wi‑Fi hotspot** scripts on DGX Spark.

## Layout

| Path | Purpose |
|------|--------|
| `backend/` | FastAPI app (`main.py`), `static/index.html`, `requirements.txt` |
| `scripts/` | Hotspot + Personaplex shell scripts |
| `systemd/dgx-app.service` | Example unit for uvicorn on **`:28734`** (uncommon dev port) + optional `ExecStartPost` hotspot |

## Localhost not loading?

- **`http://localhost`** uses **port 80** (nginx). If nginx is stopped, the page will not load. Either:
  - Open **`http://localhost:28734`** (uvicorn / `dgx-app` directly), or
  - `sudo systemctl start nginx` (and ensure `proxy_pass` in the app site points at **`127.0.0.1:28734`**).

## Quick start (dev)

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 28734
```

## Production notes

- Install the systemd unit, then: `sudo systemctl enable --now dgx-app`
- After `git pull`, restart so new API routes load: `sudo systemctl restart dgx-app`
- Hotspot buttons / `ExecStartPost` need **passwordless sudo** for the scripts: `scripts/install_passwordless_sudo.sh`
- Override paths with env vars (see `main.py`: `ECHOMIND_*`, `HOTSPOT_*`, `PERSONAPLEX_*`). If you change the listen port, set **`DGX_APP_PORT`** to match **`uvicorn --port`** and update nginx **`proxy_pass`**.

## License

Add your license if this repo is public.
