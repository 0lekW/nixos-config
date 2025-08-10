# NixOS Flake Configuration

This repository contains my personal NixOS flake-based system configurations.

## Machines

### homelab
**Role:** Self-hosting server (RYZEN 5500, 16GB DDR4 RAM, GTX 1060, 1TB NVMe SSD).  
**Purpose:** Dashboard, DNS ad-blocking, remote access, and future services.

**Currently configured:**
- **Dashy** — Web dashboard at `http://<homelab-ip>:8080`
- **Pi-hole** — DNS-based ad blocker at `http://<homelab-ip>:8082/admin`
- **RustDesk Server** — Self-hosted remote access (LAN only for now)  

**To-do (homelab):**
- [ ] Enable RustDesk for WAN access (port forwarding + secure setup)
- [ ] Move service passwords to secrets management (sops-nix or agenix)
- [ ] Add HDD to machine
- [ ] Add NAS storage
- [ ] Add monitoring
- [ ] Self hosted LLM
- [ ] Host Minecraft server (existing one)

---

## Repository To-do
- [ ] Implement secrets management for all sensitive environment variables
- [ ] Standardize container volume paths under `/var/lib`
- [ ] Create profiles for future machines (Desktop)
- [ ] Migrate dotfiles from Arch machine to future desktop machine

---

## Usage

### Rebuilding a machine
```bash
sudo nixos-rebuild switch --flake .#<hostname>
