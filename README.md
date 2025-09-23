# NixOS Flake Configuration

This repository contains my personal NixOS flake-based system configurations.

## Machines

### homelab
**Hardware:** RYZEN 5500, 16GB DDR4 RAM, GTX 1060, 1TB NVMe SSD.  
**Purpose:** Dashboard, DNS ad-blocking, remote access, and future services.

**Currently configured:**
- **Dashy** — Web dashboard at `http://home.olek.co.nz` or `http://<homelab-ip>:8080`
- **Pi-hole** — DNS-based ad blocker at `http://pihole.olek.co.nz` or `http://<homelab-ip>:8082/admin`
- **RustDesk Server** — Self-hosted remote access (LAN only for now)
- **qBittorrent** — Torrent management at `http://torrent.olek.co.nz` or `http://<homelab-ip>:8081`
- **Jellyfin** — Media server at `http://jellyfin.olek.co.nz` or `http://<homelab-ip>:8096`
- **Grafana** — Graphs for system monitoring at `http://graphs.olek.co.nz` or `http://<homelab-ip>:3000`
- **Prometheus** — Pipeline to system hardware monitoring at `http://prometheus.olek.co.nz` or `http://<homelab-ip>:9090`
- **Nginx** — Reverse proxy manager at `http://nginx.olek.co.nz` or `http://<homelab-ip>:81`
- **FileBrowser** — Web UI file browser
- **TTYD** — Web UI terminal

**To-do (homelab):**
- [ ] Remote access to services using Wireguard
- [ ] Move service passwords to secrets management (sops-nix or agenix)
- [ ] Add HDDs to machine + Setup NAS Storage
- [ ] Self hosted LLM
- [ ] Host Minecraft server (existing one) through cloudflare tunnel


### homelab2
**Hardware:** TODO.  
**Purpose:** TODO. Machine not currently setup.

**Currently configured:**
- **Nothing**

**To-do (homelab2):**
- [ ] Everything.


---

## Repository To-do
- [ ] Implement secrets management for all sensitive environment variables
- [ ] Create profiles for future machines (Desktop)
- [ ] Migrate dotfiles from Arch machine to future desktop machine
- [ ] Track Dashy config file in Git
- [ ] Complete homelab2 machine
- [ ] Find use for homelab2 machine

---

## Usage

### Rebuilding a machine
```bash
sudo nixos-rebuild switch --flake .#<hostname>
