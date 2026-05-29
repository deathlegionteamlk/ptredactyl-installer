# Pterodactyl Auto Installer

**by demo x hexa | [github.com/Deathlegionteamlk](https://github.com/Deathlegionteamlk)**

Fully autonomous Pterodactyl Panel + Wings installer with Zone.id DNS auto-config, Node.js setup, and all-eggs import.

---

## Quick Install

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Deathlegionteamlk/pterodactyl-installer/main/install.sh)
```

Or manually:

```bash
wget https://raw.githubusercontent.com/Deathlegionteamlk/pterodactyl-installer/main/install.sh
chmod +x install.sh
sudo bash install.sh
```

---

## Supported OS

| OS | Version |
|---|---|
| Ubuntu | 20.04, 22.04, 24.04 |
| Debian | 11, 12 |

---

## What Gets Installed

| Component | Details |
|---|---|
| Pterodactyl Panel | v1.11.10 — PHP/Laravel web panel |
| Pterodactyl Wings | v1.11.13 — Go daemon (node agent) |
| PHP | 8.3 + all required extensions |
| Node.js | 20 LTS via NodeSource |
| MariaDB | Auto-configured database + user |
| Redis | Cache, session, and queue backend |
| Nginx | Reverse proxy with HTTPS |
| Docker | Container runtime for server instances |
| Let's Encrypt SSL | Auto-issued via Certbot for both Panel and Wings |
| Supervisor | Queue worker process manager |
| All Official Eggs | Cloned from pterodactyl/eggs and auto-imported |

---

## Zone.id DNS Auto-Config

Provide your Zone.id API key during setup and the installer will:

1. Authenticate to the Zone.id API (`https://api.zone.id/v2`)
2. Find your root domain by name
3. Create or update A records for your panel subdomain and wings subdomain
4. Point both to your server's public IP
5. Wait for propagation before issuing SSL

**Required Zone.id API permissions:** DNS Read + Write

---

## Configuration Prompts

```
Panel Domain        e.g. panel.yourdomain.com
Wings/Node Domain   e.g. node1.yourdomain.com
Admin Email
Admin Username
Admin Password
Database Password   (auto-generated if blank)
Zone.id API Key     (optional — skip to configure DNS manually)
Root Domain         e.g. yourdomain.com (only if Zone.id key provided)
Server IP           (auto-detected)
Node Name           e.g. Node-01
Node Location       e.g. ID-JKT
Wings Port          default: 8080
Wings SFTP Port     default: 2022
```

---

## Post-Install

**Service Status**

```bash
systemctl status wings
systemctl status nginx
systemctl status mariadb
systemctl status php8.3-fpm
supervisorctl status pterodactyl-worker:*
```

**Logs**

```bash
tail -f /var/log/ptero-install.log
journalctl -u wings -f
```

**Wings config**

```
/etc/pterodactyl/config.yml
```

---

## Default Port Allocations

The installer creates these port allocations on the node automatically:

| Port | Game |
|---|---|
| 25565-25569 | Minecraft |
| 27015-27017 | Source Engine (CS, GMOD, TF2) |
| 7777-7778 | Unreal Engine (ARK, etc.) |
| 2456-2457 | Valheim |
| 30120-30121 | FiveM |

---



MIT — github.com/Deathlegionteamlk
