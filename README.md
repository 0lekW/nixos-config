# NixOS Flake Configuration

My personal NixOS flake-based system configurations.

## Machines

### homelab
**Hardware:** RYZEN 5500, 16GB DDR4 RAM, GTX 1060, 1TB NVMe SSD, 4TB HDD (Seagate ST4000VX007, ext4, mounted at `/srv/torrents`).
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
- **Open WebUI** — Web UI for LLMs at `https://ai.olek.co.nz` or `http://<homelab-ip>:3001`, talks to Ollama on the zfs host
- **[lupin](https://github.com/0lekW/lupin)** — Ollama task scheduler and notifications at `https://lupin.olek.co.nz` or `http://<homelab-ip>:9500`

**Apps** (`apps.nix`)
- **Glance** — Dashboard at `http://home.olek.co.nz` or `http://<homelab-ip>:8080`
- **FileBrowser** — Web file browser at `https://files.olek.co.nz` or `http://<homelab-ip>:8090`
- **Crafty Controller** — Minecraft hosting panel at `https://mc.olek.co.nz` or `http://<homelab-ip>:8000`
- **[cjsonfmt-ui](https://github.com/0lekW/cjsonfmt-ui)** — Web UI for [cjsonfmt](https://github.com/0lekW/cjsonfmt) at `https://json.olek.co.nz` or `http://<homelab-ip>:8761`
- **[oleks-closet](https://github.com/0lekW/oleks-closet)** — Wardrobe viewer and outfit designer at `https://closet.olek.co.nz` or `http://<homelab-ip>:8762`
- **Vikunja** — Task manager at `https://tasks.olek.co.nz` or `http://<homelab-ip>:8763`
- **[Wealthfolio](https://wealthfolio.app)** — Personal finance and investment tracker at `https://wealth.olek.co.nz` or `http://<homelab-ip>:8764`

**To-do (homelab):**
- [x] Add HDDs to machine

### homelab_zfs
**Hardware:** Intel(R) Xeon(R) E E-2414, 32GB DDR5 RAM, 4x460GB SSD.
**Purpose:** NAS file storage. RAIDZ1 pool across three SSDs, mounted at `/tank`.

- **Samba** — SMB share of `/tank/shared`, LAN only
- **FileBrowser** — Web file browser at `nfs.olek.co.nz` or `http://192.168.1.201:8080`
- **Immich** — Photo manager and backups at `photos.olek.co.nz` or `http://192.168.1.201:2283`
- **Ollama** — CPU inference host at `http://192.168.1.201:11434`, serves the homelab's Open WebUI and Lupin
- **Dozzle agent** — Exposes this host's containers to the homelab's Dozzle

**To-do (homelab_zfs):**
- [ ] 

### mhrLab
**Hardware:** Intel i5-2400 (Sandy Bridge iGPU), 16GB DDR3 RAM, 1TB SATA SSD, 2x 4TB HDD (Seagate ST4000VX007, striped ZFS pool `tank`, ~7TB, no redundancy).
**Purpose:** Home server at seperate location, at `192.168.0.200`. Mostly used as a media server and for security camera footage.

- **Pi-hole** — DNS ad blocker for the house at `https://pihole.mhr.olek.co.nz/admin`
- **Tailscale** — Joins existing tailnet as `mhrlab`, advertises `192.168.0.0/24`
- **Nginx Proxy Manager** — Reverse proxy for `*.mhr.olek.co.nz`, admin UI at `https://proxy.mhr.olek.co.nz`
- **Glance** — Dashboard at `https://home.mhr.olek.co.nz`
- **Grafana / Prometheus / node-exporter** — Host metrics at `https://graphs.mhr.olek.co.nz` and `https://prometheus.mhr.olek.co.nz`
- **Dozzle** — Container logs at `https://dozzle.mhr.olek.co.nz`
- **Immich** — Photos at `https://photos.mhr.olek.co.nz`, library on `tank/photos`
- **Frigate** — Cameras at `https://cameras.mhr.olek.co.nz`, recordings on `tank/frigate`. 
- **qBittorrent** — Torrents at `https://torrent.mhr.olek.co.nz`, downloads to `tank/media/downloads`
- **Jellyfin** — Media server at `https://jellyfin.mhr.olek.co.nz`, library on `tank/media`
- **Samba** — `shared` and `media` shares, LAN only

**To-do (mhrLab):**
- [ ] 

---

## Repository layout

```
flake.nix              every machine, plus the sops-nix input
modules/common.nix     settings shared by every host
modules/olek-lan.nix   gateway, DNS and admin user for the two hosts on Olek's LAN
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
