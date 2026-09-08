# NixOS Flake Configuration

My personal NixOS flake-based system configurations.

## Machines

### homelab
**Hardware:** RYZEN 5500, 16GB DDR4 RAM, GTX 1060, 1TB NVMe SSD.
**Purpose:** Dashboard and main services.

**Network** (`network.nix`)
- **Pi-hole** — DNS ad blocker at `http://pihole.olek.co.nz` or `http://<homelab-ip>:8082/admin`
- **Nginx Proxy Manager** — Reverse proxy, admin UI at `http://<homelab-ip>:81`
- **Tailscale** — Remote access, advertises the LAN as a subnet route
- **RustDesk Server** — Self-hosted remote desktop (LAN only for now)

**Monitoring** (`monitoring/`)
- **Grafana** — Dashboards at `http://graphs.olek.co.nz` or `http://<homelab-ip>:3000`
- **Prometheus** — Metrics store at `http://prometheus.olek.co.nz` or `http://<homelab-ip>:9090`
- **node-exporter / cAdvisor** — Host and container metrics
- **Dozzle** — Live container logs from both machines at `https://dozzle.olek.co.nz` or `http://<homelab-ip>:8087`

**Media** (`media.nix`)
- **qBittorrent** — Torrents at `http://torrent.olek.co.nz` or `http://<homelab-ip>:8081`
- **Jellyfin** — Media server at `http://jellyfin.olek.co.nz`, GPU transcoding

**AI** (`ai.nix`)
- **Ollama** — Local model hosting with GPU acceleration at `http://<homelab-ip>:11434`
- **Open WebUI** — Web UI for LLMs at `https://ai.olek.co.nz` or `http://<homelab-ip>:3001`
- **[lupin](https://github.com/0lekW/lupin)** — Ollama task scheduler and notifications at `https://lupin.olek.co.nz` or `http://<homelab-ip>:9500`

**Apps** (`apps.nix`)
- **Glance** — Dashboard at `http://home.olek.co.nz` or `http://<homelab-ip>:8080`
- **FileBrowser** — Web file browser at `https://files.olek.co.nz` or `http://<homelab-ip>:8090`
- **Crafty Controller** — Minecraft hosting panel at `https://mc.olek.co.nz` or `http://<homelab-ip>:8000`
- **[cjsonfmt-ui](https://github.com/0lekW/cjsonfmt-ui)** — Web UI for [cjsonfmt](https://github.com/0lekW/cjsonfmt) at `https://json.olek.co.nz` or `http://<homelab-ip>:8761`
- **[oleks-closet](https://github.com/0lekW/oleks-closet)** — Wardrobe viewer and outfit designer at `https://closet.olek.co.nz` or `http://<homelab-ip>:8762`
- **Vikunja** — Task manager at `https://tasks.olek.co.nz` or `http://<homelab-ip>:8763`

**To-do (homelab):**
- [ ] Add HDDs to machine

### homelab_zfs
**Hardware:** Intel(R) Xeon(R) E E-2414, 32GB DDR5 RAM, 4x460GB SSD.
**Purpose:** NAS file storage. RAIDZ1 pool across three SSDs, mounted at `/tank`.

- **Samba** — SMB share of `/tank/shared`, LAN only
- **FileBrowser** — Web file browser at `nfs.olek.co.nz` or `http://192.168.1.201:8080`
- **Immich** — Photo manager and backups at `photos.olek.co.nz` or `http://192.168.1.201:2283`
- **Dozzle agent** — Exposes this host's containers to the homelab's Dozzle

**To-do (homelab_zfs):**
- [ ] 

---

## Repository layout

```
flake.nix              both machines, plus the sops-nix input
modules/common.nix     settings shared by every host
secrets/               encrypted credentials, one file per host
hosts/<host>/          hardware, networking, anything host-specific
  monitoring/          module plus the Prometheus and Grafana config it mounts
  media.nix
  ai.nix               services grouped by theme
  network.nix
  apps.nix
```

Each service module declares its own containers, directories, firewall ports and
secrets, so a service is described in one place rather than four. Container
images are pinned by digest, so a rebuild from scratch gets the same versions
that are running now.

## Secrets

Credentials are committed encrypted with [sops-nix](https://github.com/Mic92/sops-nix),
so nothing sensitive appears in plaintext here. `.sops.yaml` says which keys may
decrypt which file.

Each machine decrypts its own file at boot using its SSH host key, so a rebuild
from scratch needs nothing typed in by hand.

---

## Usage

### Rebuilding a machine
```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

### Editing secrets
```bash
sops secrets/<hostname>.yaml
```

---

## Repository To-do
- [ ] Create profiles for future machines (Desktop)
- [ ] Include photos of hardware and dashboard
