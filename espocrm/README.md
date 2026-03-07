# EspoCRM Self-Hosted — Unified Setup / Cài đặt Tự động

> 🇺🇸 **English** | 🇻🇳 **Tiếng Việt** — scroll down for Vietnamese / cuộn xuống để đọc Tiếng Việt

---

## 🇺🇸 English

Automated script to deploy **EspoCRM** with Docker Compose, aligned with this repo setup format.

### Supported Platforms

- **macOS** (Apple Silicon / Intel)
- **Raspberry Pi** (ARM64)
- **Linux VPS** (AMD64 / ARM64)

### Stack

| Component | Purpose |
|---|---|
| **EspoCRM (app)** | Main CRM web application |
| **EspoCRM daemon** | Background jobs (scheduler) |
| **EspoCRM websocket** | Real-time websocket service |
| **MariaDB** | Application database |

### What the script does

1. Detects platform and checks system requirements
2. Auto-installs Docker + Compose on Linux (if missing)
3. Supports **bilingual setup** (English / Vietnamese)
4. Supports access modes: localhost, LAN, domain (reverse proxy)
5. Generates secure `.env` secrets and bootstrap admin credentials
6. Generates official-style EspoCRM `docker-compose.yml`
7. Starts services and checks health
8. Creates helper script `espocrm.sh`

### Quick Install

```bash
mkdir -p ~/self-hosted/espocrm && cd ~/self-hosted/espocrm
curl -O https://raw.githubusercontent.com/duynghien/auto/main/espocrm/setup.sh
chmod +x setup.sh
./setup.sh
```

### Requirements

- Recommended RAM: **2GB+** (4GB+ recommended on Raspberry Pi)
- Free disk: **8GB+**
- Docker daemon running (macOS)

### Management

```bash
./espocrm.sh start
./espocrm.sh stop
./espocrm.sh restart
./espocrm.sh status
./espocrm.sh logs app
./espocrm.sh health
./espocrm.sh backup
./espocrm.sh db-shell
./espocrm.sh admin
./espocrm.sh upgrade
./espocrm.sh reset
```

### Notes

- Config/secrets are stored in `~/self-hosted/espocrm/.env`
- Database backups are stored in `~/self-hosted/espocrm/backups`
- Initial admin credentials are shown after setup and via `./espocrm.sh admin`
- In domain mode, configure reverse proxy for both HTTP and WebSocket ports
- After first login, change the bootstrap admin password immediately

Branding: vnROM Self-hosted Scripts  
Support: <https://ai.vnrom.net>

---

## 🇻🇳 Tiếng Việt

Script tự động triển khai **EspoCRM** bằng Docker Compose, đồng bộ format với các script khác trong repo.

### Nền tảng hỗ trợ

- **macOS** (Apple Silicon / Intel)
- **Raspberry Pi** (ARM64)
- **VPS Linux** (AMD64 / ARM64)

### Thành phần

| Thành phần | Mục đích |
|---|---|
| **EspoCRM (app)** | Ứng dụng CRM chính |
| **EspoCRM daemon** | Tác vụ nền (scheduler) |
| **EspoCRM websocket** | Dịch vụ realtime websocket |
| **MariaDB** | Cơ sở dữ liệu |

### Script sẽ làm gì

1. Nhận diện nền tảng và kiểm tra tài nguyên
2. Tự cài Docker + Compose trên Linux (nếu thiếu)
3. Hỗ trợ **song ngữ** (English / Tiếng Việt)
4. Hỗ trợ mode truy cập: localhost, LAN, domain (qua reverse proxy)
5. Tạo `.env` bảo mật và thông tin admin bootstrap
6. Tạo `docker-compose.yml` theo chuẩn EspoCRM
7. Khởi động services và kiểm tra health
8. Tạo script quản lý `espocrm.sh`

### Cài nhanh

```bash
mkdir -p ~/self-hosted/espocrm && cd ~/self-hosted/espocrm
curl -O https://raw.githubusercontent.com/duynghien/auto/main/espocrm/setup.sh
chmod +x setup.sh
./setup.sh
```

### Yêu cầu đề xuất

- RAM: **2GB+** (khuyến nghị 4GB+ cho Raspberry Pi)
- Trống đĩa: **8GB+**
- Docker daemon đang chạy (macOS)

### Quản lý

```bash
./espocrm.sh start
./espocrm.sh stop
./espocrm.sh restart
./espocrm.sh status
./espocrm.sh logs app
./espocrm.sh health
./espocrm.sh backup
./espocrm.sh db-shell
./espocrm.sh admin
./espocrm.sh upgrade
./espocrm.sh reset
```

### Ghi chú

- Cấu hình/secrets nằm ở `~/self-hosted/espocrm/.env`
- Backup database lưu tại `~/self-hosted/espocrm/backups`
- Tài khoản admin bootstrap hiển thị sau setup và qua `./espocrm.sh admin`
- Ở chế độ domain, cần reverse proxy cho cả cổng HTTP và WebSocket
- Sau đăng nhập lần đầu, hãy đổi mật khẩu admin bootstrap ngay

Branding: vnROM Self-hosted Scripts  
Hỗ trợ: <https://ai.vnrom.net>
