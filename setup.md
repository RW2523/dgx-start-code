# End-to-end setup on a new machine

Use this after `git clone` / `git pull` so the DGX local app matches a working install: FastAPI on **port 28734**, dashboard static files, optional Wi‑Fi hotspot scripts, and systemd **`dgx-app`**.

**Assumptions:** Ubuntu or Debian-style host, **`NetworkManager`**, `sudo`, and internet for **first-time** `apt` / `pip` (see [Offline installs](#offline-installs) if needed).

---

## 1. Clone or update the repo

```bash
git clone <your-remote-url> dgx-local-app
cd dgx-local-app
git pull   # on an existing clone
```

---

## 2. Pick install location, user, and Wi‑Fi interface

| Setting | What to decide |
|--------|----------------|
| **Repo path** | e.g. `/home/youruser/dgx-local-app` — used everywhere below. |
| **Service user** | The Linux user that runs `dgx-app` (default in scripts: `echomind`). Set **`DG_HOTSPOT_USER`** / **`DG_HOTSPOT_SUDO_USER`** if different. |
| **Wi‑Fi interface** | Default in scripts: **`wlP9s9`**. On another box run `nmcli device status` or `ip link` and set **`WIFI_IFACE`** for setup/undo if yours differs. |

Hotspot scripts read optional environment variables (export before running setup, or set in a small wrapper):

- **`DG_HOTSPOT_USER`** — Unix user for systemd `User=` and file ownership (default `echomind`).
- **`DG_APP_DIR`** — Backend directory (default: `$REPO_ROOT/backend`).
- **`WIFI_IFACE`** — Wireless device for AP mode (default `wlP9s9`).
- **`HOTSPOT_SSID`**, **`HOTSPOT_WIFI_PASSWORD`**, **`HOTSPOT_IP`**, **`DGX_APP_PORT`** — optional overrides.

---

## 3. Make scripts executable

Required because passwordless **`sudo`** is granted for **exact script paths**; non-executable files can break the dashboard.

```bash
./scripts/init_machine.sh
```

---

## 4. Python virtual environment and dependencies

```bash
cd backend
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
deactivate
cd ..
```

- **`python3-venv`** must exist (`sudo apt install python3-venv` if `ensurepip` fails).
- The systemd unit expects **`backend/.venv/bin/uvicorn`**.

---

## 5. Passwordless sudo for hotspot scripts

The UI and **`ExecStartPost`** run **`sudo`** without a TTY. Install rules **once** (you type your password only for this step):

```bash
cd scripts
# If the service runs as someone other than the account installing sudoers:
#   DG_HOTSPOT_SUDO_USER=youruser ./install_passwordless_sudo.sh
./install_passwordless_sudo.sh
cd ..
```

This writes **`/etc/sudoers.d/dgx-hotspot`** with **`NOPASSWD`** for the listed scripts under **this repo path**. If you **move the repo**, run the installer again.

---

## 6. Systemd unit for `dgx-app`

You have two equivalent paths.

### Option A — Copy the repo unit (manual paths)

Edit **`systemd/dgx-app.service`** so every path matches this machine (user, repo location, port), then:

```bash
sudo cp systemd/dgx-app.service /etc/systemd/system/dgx-app.service
sudo systemctl daemon-reload
sudo systemctl enable --now dgx-app
```

### Option B — Let hotspot setup write the unit

Running **`scripts/setup_hotspot_stack.sh`** (from the dashboard **Enable** or manually) writes **`/etc/systemd/system/dgx-app.service`** using **`REPO_ROOT`** from the script’s location and **`APP_USER`** / **`APP_DIR`**. Do **step 4** first so **`.venv/bin/uvicorn`** exists before **`systemctl enable --now dgx-app`**.

After any change to the unit file:

```bash
sudo systemctl daemon-reload
sudo systemctl restart dgx-app
```

---

## 7. Smoke test (no hotspot yet)

```bash
systemctl --user status   # N/A for system service
sudo systemctl status dgx-app
curl -sS http://127.0.0.1:28734/health
```

Open **`http://<host>:28734`** in a browser (or **`http://localhost:28734`** on the machine).

---

## 8. Hotspot (optional)

1. In the dashboard, use **Enable hotspot** (runs **`hotspot_enable.sh`**: first time runs **`setup_hotspot_stack.sh`** → `apt`, configs, **`dgx-app`** unit, hostapd, dnsmasq, nginx).
2. Or from a terminal (same env overrides as above if needed):

   ```bash
   sudo ./scripts/hotspot_enable.sh
   ```

**Disable** turns off the AP and runs **undo** (removes configured marker, restores NetworkManager, etc.). A file under **`/tmp`** prevents an immediate re-enable if **`dgx-app`** restarts; **reboot** clears that and will try to bring the hotspot up again unless you disable again.

**Wi‑Fi interface** must match **`WIFI_IFACE`** in **`setup_hotspot_stack.sh`** / **`undo_hotspot_stack.sh`** (or export **`WIFI_IFACE`** before running those scripts).

---

## 9. Nginx on port 80 (optional)

After hotspot setup, nginx may proxy **`/`** to **`127.0.0.1:28734`**. If **`http://localhost`** does not load:

```bash
sudo systemctl start nginx
```

---

## 10. After `git pull` on an existing machine

```bash
git pull
./scripts/init_machine.sh
cd backend && . .venv/bin/activate && pip install -r requirements.txt && deactivate && cd ..
# If install_passwordless_sudo.sh gained new script paths:
cd scripts && ./install_passwordless_sudo.sh && cd ..
sudo systemctl restart dgx-app
```

---

## Offline installs

1. **Python wheels** (on a networked machine **with the same OS / Python version** as the target):

   ```bash
   ./scripts/vendor_python_deps.sh
   ```

   Copy the repo including **`backend/vendor/wheels/*.whl`**, then on the offline host:

   ```bash
   cd backend
   python3 -m venv .venv
   . .venv/bin/activate
   pip install --no-index --find-links vendor/wheels -r requirements.txt
   ```

2. **Dashboard fonts** are already under **`backend/static/fonts/`** (no Google Fonts at runtime).

3. **First hotspot setup** still uses **`apt`** in **`setup_hotspot_stack.sh`**; for fully offline OS packages you need a local mirror or preinstalled **hostapd**, **dnsmasq**, **nginx**, **python3-venv**, etc.

---

## 11. EchoMind / Personaplex paths

The API uses environment variables (see **`backend/main.py`**), e.g. **`ECHOMIND_COMPOSE_DIR`**, **`PERSONAPLEX_*`**, **`HOTSPOT_*`**. Set them in **`/etc/systemd/system/dgx-app.service`** under **`[Service]`**:

```ini
Environment=ECHOMIND_COMPOSE_DIR=/path/to/compose
```

Then **`sudo systemctl daemon-reload && sudo systemctl restart dgx-app`**.

---

## Checklist summary

| Step | Action |
|------|--------|
| 1 | Clone / pull repo |
| 2 | Set user, paths, **`WIFI_IFACE`** if not defaults |
| 3 | **`./scripts/init_machine.sh`** |
| 4 | **`backend`**: venv + **`pip install -r requirements.txt`** |
| 5 | **`scripts/install_passwordless_sudo.sh`** |
| 6 | Install **`dgx-app.service`** (copy + edit, or via hotspot setup) → **`daemon-reload`**, **`enable --now`** |
| 7 | **`curl` /health**, open **:28734** |
| 8 | Optional: Enable hotspot in UI |
| 9 | Optional: **`systemctl start nginx`** for port 80 |

---

## Troubleshooting

| Symptom | What to check |
|--------|----------------|
| Dashboard buttons say sudo / password | Re-run **`install_passwordless_sudo.sh`**; confirm repo path matches **`/etc/sudoers.d/dgx-hotspot`**. |
| **`dgx-app` fails to start** | **`journalctl -u dgx-app -b`**, confirm **`backend/.venv/bin/uvicorn`** exists and **`WorkingDirectory`** is **`.../backend`**. |
| Hotspot starts then stops after Disable + restart | Expected until reboot or **Enable**; see **`/tmp/dgx-hotspot-skip-autostart`** behavior in **`maybe_start_hotspot_stack.sh`**. |
| Wrong Wi‑Fi chip name | Set **`WIFI_IFACE`** and re-run setup (or edit **`undo_hotspot_stack.sh`** / **`setup_hotspot_stack.sh`**). |
