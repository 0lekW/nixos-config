# NixOS Flake Configuration

This repository contains my personal NixOS flake-based system configurations.

## Machines

### homelab
**Hardware:** RYZEN 5500, 16GB DDR4 RAM, GTX 1060, 1TB NVMe SSD.  
**Purpose:** Dashboard and main services.

**Currently configured:**
- **Dashy** — Web dashboard at `http://home.olek.co.nz` or `http://<homelab-ip>:8080`
- **Pi-hole** — DNS-based ad blocker at `http://pihole.olek.co.nz` or `http://<homelab-ip>:8082/admin`
- **RustDesk Server** — Self-hosted remote access (LAN only for now)
- **qBittorrent** — Torrent management at `http://torrent.olek.co.nz` or `http://<homelab-ip>:8081`
- **Jellyfin** — Media server at `http://jellyfin.olek.co.nz` or `http://<homelab-ip>:8096`
- **Grafana** — Graphs for system monitoring at `http://graphs.olek.co.nz` or `http://<homelab-ip>:3000`
- **Prometheus** — Pipeline to system hardware monitoring at `http://prometheus.olek.co.nz` or `http://<homelab-ip>:9090`
- **Nginx** — Reverse proxy manager at `http://nginx.olek.co.nz` or `http://<homelab-ip>:81`
- **FileBrowser** — Web UI file browser at `192.168.1.201::8090` or `https://files.olek.co.nz/` 
- **TTYD** — Web UI terminal at `192.168.1.201::8091` or `https://terminal.olek.co.nz/` 
- **Crafty Controller** — Web UI Minecraft Server hosting panel at `https://mc.olek.co.nz` or `http://<homelab-ip>:8000`
- **[cjsonfmt-ui](https://github.com/0lekW/cjsonfmt-ui)** - Web UI interface for [cjsonfmt](https://github.com/0lekW/cjsonfmt) at `https://json.olek.co.nz` or `http://<homelab-ip>::8761`

**To-do (homelab):**
- [ ] Remote access to services using Wireguard
- [ ] Add HDDs to machine
- [ ] Self hosted LLM

### homelab_zfs
**Hardware:** Intel(R) Xeon(R) E E-2414, 32GB DDR5 RAM, 4x460GB SSD.  
**Purpose:** NAS File Storage

**Currently configured:**
- **Samba** - NFS
- **FileBrowser** - Web UI file browser at `nfs.olek.co.nz` or `192.168.1.201::8080` 

**To-do (homelab_zfs):**
- [ ] - 

---

## Repository To-do
- [ ] Create profiles for future machines (Desktop)
- [ ] Migrate dotfiles from Arch machine to future desktop machine
- [ ] Track Dashy config file in Git

---

## Usage

### Rebuilding a machine
```bash
sudo nixos-rebuild switch --flake .#<hostname>
