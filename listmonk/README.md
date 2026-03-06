# Listmonk Self-Hosted — Unified Setup / Cài đặt Tự động

> 🇺🇸 **English** | 🇻🇳 **Tiếng Việt** — scroll down for Vietnamese / cuộn xuống để đọc Tiếng Việt

---

## 🇺🇸 English

Automated script to deploy **Listmonk** with Docker Compose, aligned with this repo's setup format.

### Supported Platforms

- **macOS** (Apple Silicon / Intel)
- **Raspberry Pi** (ARM64)
- **Linux VPS** (AMD64 / ARM64)

### What the script does

1. Detects platform and checks system requirements
2. Auto-installs Docker + Compose on Linux (if missing)
3. Supports **bilingual UI** (English / Vietnamese)
4. Supports access modes: localhost, LAN, domain (behind reverse proxy)
5. Generates secure `.env` secrets and bootstrap admin credentials
6. Generates official-style Listmonk + PostgreSQL `docker-compose.yml`
7. Starts services and checks health
8. Creates helper script `listmonk.sh`

### Quick Install

```bash
mkdir -p ~/self-hosted/listmonk && cd ~/self-hosted/listmonk
curl -O https://raw.githubusercontent.com/duynghien/auto/main/listmonk/setup.sh
chmod +x setup.sh
./setup.sh
```

### Requirements

- Recommended RAM: **2GB+**
- Free disk: **8GB+**
- Docker daemon running (macOS)

### Management

```bash
./listmonk.sh start
./listmonk.sh stop
./listmonk.sh restart
./listmonk.sh status
./listmonk.sh logs app
./listmonk.sh health
./listmonk.sh backup
./listmonk.sh db-shell
./listmonk.sh admin
./listmonk.sh upgrade
./listmonk.sh reset
```

### Notes

- Config/secrets are stored in `~/self-hosted/listmonk/.env`
- Upload files are stored in `~/self-hosted/listmonk/uploads`
- Initial admin credentials are shown at the end of setup and via `./listmonk.sh admin`
- Configure SMTP in `Admin -> Settings -> SMTP`
- For production domain, place a reverse proxy (Caddy/Nginx/Traefik) in front

Branding: vnROM Self-hosted Scripts  
Support: <https://ai.vnrom.net>

---

## 🇻🇳 Tiếng Việt

Script tự động triển khai **Listmonk** bằng Docker Compose, đồng bộ format với các script khác trong repo.

### Nền tảng hỗ trợ

- **macOS** (Apple Silicon / Intel)
- **Raspberry Pi** (ARM64)
- **VPS Linux** (AMD64 / ARM64)

### Script sẽ làm gì

1. Nhận diện nền tảng và kiểm tra tài nguyên
2. Tự cài Docker + Compose trên Linux (nếu thiếu)
3. Hỗ trợ **song ngữ** (English / Tiếng Việt)
4. Hỗ trợ mode truy cập: localhost, LAN, domain (qua reverse proxy)
5. Tạo `.env` an toàn và thông tin admin bootstrap
6. Tạo `docker-compose.yml` theo chuẩn Listmonk + PostgreSQL
7. Khởi động services và kiểm tra health
8. Tạo script quản lý `listmonk.sh`

### Cài nhanh

```bash
mkdir -p ~/self-hosted/listmonk && cd ~/self-hosted/listmonk
curl -O https://raw.githubusercontent.com/duynghien/auto/main/listmonk/setup.sh
chmod +x setup.sh
./setup.sh
```

### Yêu cầu đề xuất

- RAM: **2GB+**
- Trống đĩa: **8GB+**
- Docker daemon đang chạy (macOS)

### Quản lý

```bash
./listmonk.sh start
./listmonk.sh stop
./listmonk.sh restart
./listmonk.sh status
./listmonk.sh logs app
./listmonk.sh health
./listmonk.sh backup
./listmonk.sh db-shell
./listmonk.sh admin
./listmonk.sh upgrade
./listmonk.sh reset
```

### Ghi chú

- Cấu hình/secrets nằm ở `~/self-hosted/listmonk/.env`
- File upload nằm ở `~/self-hosted/listmonk/uploads`
- Tài khoản admin bootstrap sẽ hiển thị cuối setup và xem lại bằng `./listmonk.sh admin`
- Cấu hình SMTP trong `Admin -> Settings -> SMTP`
- Dùng domain production nên đặt reverse proxy (Caddy/Nginx/Traefik)

Branding: vnROM Self-hosted Scripts  
Hỗ trợ: <https://ai.vnrom.net>
