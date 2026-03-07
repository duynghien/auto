# n8n Self-Hosted — Unified Setup / Cai dat Tu dong

> 🇺🇸 **English** | 🇻🇳 **Tieng Viet** — scroll down for Vietnamese / cuon xuong de doc Tieng Viet

---

## 🇺🇸 English

One-script installer for **n8n self-hosted** using Docker Compose.
Auto-detects your platform and guides you with interactive options.

### Supported Platforms

| Platform | Arch | Notes |
|---|---|---|
| **macOS** | arm64 / x86_64 | Requires OrbStack or Docker Desktop |
| **Raspberry Pi** | arm64 | Optional swap setup for low RAM |
| **VPS Linux** | amd64 / arm64 | Auto-installs Docker (Debian/Ubuntu) |

### What this script can configure

| Option | Default | Description |
|---|---|---|
| PostgreSQL | OFF | Use Postgres instead of SQLite |
| Redis | OFF | Redis service for queue mode / scaling |
| Queue mode | OFF | n8n queue execution mode |
| Worker | OFF | Dedicated `worker` service |
| Webhook processor | OFF | Dedicated `webhook` service |
| External task runners | OFF | Sidecar runners for advanced execution |
| Metrics endpoint | OFF | Enable `/metrics` |
| Telemetry disable | OFF | Disable diagnostics/version checks |
| Public API disable | OFF | Disable REST API + Swagger UI |
| Execution pruning | OFF | Auto-prune old executions |
| FFmpeg | OFF | Build custom n8n image with FFmpeg |
| Puppeteer runtime deps | OFF | Build custom image with Chromium libs |
| S3 binary mode (Enterprise) | OFF | Store binary data in S3 |

All advanced options default to **NO** when pressing Enter.

### Quick Install

```bash
mkdir -p ~/self-hosted/n8n && cd ~/self-hosted/n8n
curl -O https://raw.githubusercontent.com/duynghien/auto/main/n8n/setup.sh
chmod +x setup.sh
./setup.sh
```

### Script Flow

1. System checks (Docker, RAM, disk)
2. Access mode (localhost / LAN / domain)
3. n8n feature selection
4. Generate `.env` + secrets
5. Generate `docker-compose.yml` (+ optional `Dockerfile.n8n`)
6. Validate compose
7. Start containers
8. Verify health
9. Create helper script `n8n.sh`

### Management

After installation, use:

```bash
./n8n.sh start
./n8n.sh stop
./n8n.sh restart
./n8n.sh status
./n8n.sh logs [service]
./n8n.sh health
./n8n.sh upgrade
./n8n.sh env
./n8n.sh doctor
./n8n.sh reset
```

### Important Notes

- Queue mode requires PostgreSQL + Redis (script auto-enables if needed).
- For public domain, use reverse proxy (Caddy/Nginx/Cloudflare Tunnel).
- Do not share `.env` (contains secrets).

---

## 🇻🇳 Tieng Viet

Script 1-lenh de cai dat **n8n self-hosted** bang Docker Compose.
Tu nhan dien nen tang va hoi tuy chon theo nhu cau.

### Nen tang ho tro

| Nen tang | Kien truc | Ghi chu |
|---|---|---|
| **macOS** | arm64 / x86_64 | Can OrbStack hoac Docker Desktop |
| **Raspberry Pi** | arm64 | Co tuy chon tao swap neu RAM thap |
| **VPS Linux** | amd64 / arm64 | Tu cai Docker (Debian/Ubuntu) |

### Cac tuy chon co the bat/tat

| Tuy chon | Mac dinh | Mo ta |
|---|---|---|
| PostgreSQL | TAT | Dung Postgres thay SQLite |
| Redis | TAT | Redis cho queue mode / scale |
| Queue mode | TAT | Che do queue cua n8n |
| Worker | TAT | Dich vu `worker` rieng |
| Webhook processor | TAT | Dich vu `webhook` rieng |
| External task runners | TAT | Sidecar runners cho nhu cau nang cao |
| Metrics endpoint | TAT | Bat `/metrics` |
| Tat telemetry | TAT | Tat diagnostics/version checks |
| Tat public API | TAT | Tat REST API + Swagger UI |
| Execution pruning | TAT | Tu dong xoa execution cu |
| FFmpeg | TAT | Build image n8n co FFmpeg |
| Puppeteer runtime deps | TAT | Build image co Chromium libs |
| S3 binary mode (Enterprise) | TAT | Luu binary data len S3 |

Tat ca tuy chon nang cao deu mac dinh **KHONG** neu bam Enter.

### Cai dat nhanh

```bash
mkdir -p ~/self-hosted/n8n && cd ~/self-hosted/n8n
curl -O https://raw.githubusercontent.com/duynghien/auto/main/n8n/setup.sh
chmod +x setup.sh
./setup.sh
```

### Luong script

1. Kiem tra he thong (Docker, RAM, disk)
2. Chon che do truy cap (localhost / LAN / domain)
3. Chon tinh nang n8n
4. Tao `.env` + secrets
5. Tao `docker-compose.yml` (+ `Dockerfile.n8n` neu can)
6. Kiem tra compose
7. Khoi dong containers
8. Xac minh health
9. Tao script quan ly `n8n.sh`

### Quan ly sau cai dat

```bash
./n8n.sh start
./n8n.sh stop
./n8n.sh restart
./n8n.sh status
./n8n.sh logs [service]
./n8n.sh health
./n8n.sh upgrade
./n8n.sh env
./n8n.sh doctor
./n8n.sh reset
```

### Luu y

- Queue mode can PostgreSQL + Redis (script tu dong bat neu can).
- Neu dung domain public, nen dat reverse proxy (Caddy/Nginx/Cloudflare Tunnel).
- Khong chia se file `.env` (chua secrets).

---

## Support

- GitHub: https://github.com/duynghien/auto
- Website: https://ai.vnrom.net
- n8n Docs: https://docs.n8n.io
