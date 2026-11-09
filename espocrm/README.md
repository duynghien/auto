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
./espocrm.sh start        # Start EspoCRM services
./espocrm.sh stop         # Stop services
./espocrm.sh restart      # Restart services
./espocrm.sh status       # Show container status
./espocrm.sh logs [svc]   # Follow logs (default: app)
./espocrm.sh health       # Check web, db and websocket ports
./espocrm.sh backup       # Backup MariaDB database (chmod 600) & .env to ./backups
./espocrm.sh restore <f>  # Safe database restore with pre-restore dump
./espocrm.sh doctor       # Diagnostics: containers, ports, MariaDB, disk
./espocrm.sh db-shell     # Open MariaDB interactive shell
./espocrm.sh admin        # Show bootstrap admin credentials
./espocrm.sh upgrade      # Pull latest images and restart (alias: update)
./espocrm.sh uninstall    # Clean uninstall (keep data or full purge)
./espocrm.sh reset        # Delete all local data volumes
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
./espocrm.sh start        # Khởi động dịch vụ EspoCRM
./espocrm.sh stop         # Dừng dịch vụ
./espocrm.sh restart      # Khởi động lại
./espocrm.sh status       # Xem trạng thái containers
./espocrm.sh logs [svc]   # Xem logs (mặc định: app)
./espocrm.sh health       # Kiểm tra cổng web, database và websocket
./espocrm.sh backup       # Sao lưu cơ sở dữ liệu MariaDB & .env vào ./backups
./espocrm.sh restore <f>  # Khôi phục database an toàn kèm snapshot tự động
./espocrm.sh doctor       # Chuẩn đoán: containers, cổng, MariaDB, đĩa
./espocrm.sh db-shell     # Mở shell tương tác MariaDB
./espocrm.sh admin        # Hiển thị tài khoản quản trị khởi tạo
./espocrm.sh upgrade      # Kéo images mới nhất & khởi động lại (alias: update)
./espocrm.sh uninstall    # Gỡ cài đặt (giữ data hoặc xóa sạch)
./espocrm.sh reset        # Xóa toàn bộ volume dữ liệu
```

### Ghi chú

- Cấu hình/secrets nằm ở `~/self-hosted/espocrm/.env`
- Backup database lưu tại `~/self-hosted/espocrm/backups`
- Tài khoản admin bootstrap hiển thị sau setup và qua `./espocrm.sh admin`
- Ở chế độ domain, cần reverse proxy cho cả cổng HTTP và WebSocket
- Sau đăng nhập lần đầu, hãy đổi mật khẩu admin bootstrap ngay

Branding: vnROM Self-hosted Scripts  
Hỗ trợ: <https://ai.vnrom.net>
