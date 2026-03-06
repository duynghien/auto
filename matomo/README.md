# Matomo Self-Hosted — Unified Setup / Cài đặt Tự động

> 🇺🇸 **English** | 🇻🇳 **Tiếng Việt** — scroll down for Vietnamese / cuộn xuống để đọc Tiếng Việt

---

## 🇺🇸 English

One-script installer for Matomo (self-hosted analytics) using Docker Compose. Auto-detects your platform:

| Platform | Arch | Database | Default Access |
|---|---|---|---|
| **macOS** | arm64 / x86_64 | MariaDB 11.4 | Localhost |
| **Raspberry Pi** | aarch64 | MariaDB 11.4 | LAN |
| **VPS — ARM64** | aarch64 | MariaDB 11.4 | LAN |
| **VPS — AMD64** | x86_64 | MariaDB 11.4 | LAN |

### Stack

| Component | Purpose |
|---|---|
| **Matomo** | Web analytics dashboard and tracking engine |
| **MariaDB** | Matomo database |

### Quick Install

```bash
# Create directory and download script
mkdir -p ~/self-hosted/matomo && cd ~/self-hosted/matomo
curl -O https://raw.githubusercontent.com/duynghien/auto/main/matomo/setup.sh

# Run setup
chmod +x setup.sh
./setup.sh
```

The script will:
1. Detect OS and architecture
2. Check/install Docker dependencies (Linux auto-install)
3. Let you choose access mode (localhost / LAN / domain)
4. Generate secure `.env` defaults
5. Generate `docker-compose.yml`
6. Validate compose configuration
7. Start containers and verify health
8. Create helper script `matomo.sh`

### Features

- ✅ Bilingual installer (English / Vietnamese)
- ✅ Works on macOS, Raspberry Pi, and VPS
- ✅ Auto Docker setup on Linux
- ✅ Health-check flow for Matomo + MariaDB
- ✅ Helper commands for operations and backup
- ✅ Trusted host support for domain mode

### Management

After installation, use `matomo.sh`:

```bash
./matomo.sh start        # Start/upgrade stack
./matomo.sh stop         # Stop services
./matomo.sh restart      # Restart services
./matomo.sh status       # Show container status
./matomo.sh logs [svc]   # Follow logs (default: matomo)
./matomo.sh health       # Check web health endpoint
./matomo.sh backup       # Backup MariaDB to .sql file
./matomo.sh upgrade      # Pull latest images and restart
./matomo.sh reset        # ⚠️ Delete all local data volumes
```

### Configuration

All settings are stored in `~/self-hosted/matomo/.env`:

```bash
MATOMO_HTTP_PORT=8080
MATOMO_URL=http://localhost:8080
MATOMO_TRUSTED_HOSTS=localhost:8080
MATOMO_IMAGE_TAG=latest
MARIADB_IMAGE=mariadb:11.4
```

After editing `.env`, apply changes:

```bash
./matomo.sh restart
```

### First Run Notes

- Open `MATOMO_URL` in browser and complete Matomo web installer.
- Create admin account and finish tracking setup wizard.
- For domain mode, ensure reverse proxy forwards to local Matomo port.

### Platform Notes

#### macOS
- Requires [OrbStack](https://orbstack.dev) or Docker Desktop pre-installed.
- Defaults to localhost mode.

#### Raspberry Pi
- Docker is auto-installed if missing.
- Auto-swap is configured when RAM is low.
- LAN mode is default.

#### VPS (ARM64 / AMD64)
- Docker is auto-installed if missing.
- LAN mode is default.
- Use reverse proxy (Caddy/Nginx) for HTTPS in production.

---

## 🇻🇳 Tiếng Việt

Script cài đặt Matomo tự động bằng Docker Compose. Tự nhận diện nền tảng:

| Nền tảng | Kiến trúc | Cơ sở dữ liệu | Truy cập mặc định |
|---|---|---|---|
| **macOS** | arm64 / x86_64 | MariaDB 11.4 | Localhost |
| **Raspberry Pi** | aarch64 | MariaDB 11.4 | LAN |
| **VPS — ARM64** | aarch64 | MariaDB 11.4 | LAN |
| **VPS — AMD64** | x86_64 | MariaDB 11.4 | LAN |

### Thành phần

| Thành phần | Mục đích |
|---|---|
| **Matomo** | Dashboard analytics và tracking |
| **MariaDB** | Cơ sở dữ liệu cho Matomo |

### Cài đặt nhanh

```bash
# Tạo thư mục và tải script
mkdir -p ~/self-hosted/matomo && cd ~/self-hosted/matomo
curl -O https://raw.githubusercontent.com/duynghien/auto/main/matomo/setup.sh

# Chạy setup
chmod +x setup.sh
./setup.sh
```

Script sẽ:
1. Nhận diện hệ điều hành và kiến trúc
2. Kiểm tra/cài Docker dependencies (Linux tự cài)
3. Cho chọn chế độ truy cập (localhost / LAN / domain)
4. Sinh cấu hình `.env` an toàn
5. Tạo `docker-compose.yml`
6. Kiểm tra compose config
7. Khởi động container và verify health
8. Tạo script quản lý `matomo.sh`

### Tính năng

- ✅ Trình cài song ngữ (English / Vietnamese)
- ✅ Hỗ trợ macOS, Raspberry Pi, VPS
- ✅ Linux tự cài Docker khi thiếu
- ✅ Luồng health-check cho Matomo + MariaDB
- ✅ Có helper command để vận hành và backup
- ✅ Hỗ trợ trusted host cho chế độ domain

### Quản lý

Sau khi cài đặt, dùng `matomo.sh`:

```bash
./matomo.sh start        # Khởi động/cập nhật stack
./matomo.sh stop         # Dừng services
./matomo.sh restart      # Khởi động lại
./matomo.sh status       # Xem trạng thái container
./matomo.sh logs [svc]   # Theo dõi logs (mặc định: matomo)
./matomo.sh health       # Kiểm tra web health endpoint
./matomo.sh backup       # Backup MariaDB ra file .sql
./matomo.sh upgrade      # Pull image mới nhất và restart
./matomo.sh reset        # ⚠️ Xóa toàn bộ volume dữ liệu
```

### Cấu hình

Tất cả cấu hình nằm trong `~/self-hosted/matomo/.env`:

```bash
MATOMO_HTTP_PORT=8080
MATOMO_URL=http://localhost:8080
MATOMO_TRUSTED_HOSTS=localhost:8080
MATOMO_IMAGE_TAG=latest
MARIADB_IMAGE=mariadb:11.4
```

Sau khi sửa `.env`, áp dụng bằng:

```bash
./matomo.sh restart
```

### Lưu ý lần chạy đầu

- Mở `MATOMO_URL` trên trình duyệt và hoàn tất web installer của Matomo.
- Tạo tài khoản admin và cấu hình tracking theo wizard.
- Nếu dùng domain, cần reverse proxy trỏ về cổng Matomo local.

### Lưu ý theo nền tảng

#### macOS
- Cần cài sẵn [OrbStack](https://orbstack.dev) hoặc Docker Desktop.
- Mặc định chạy localhost.

#### Raspberry Pi
- Tự cài Docker nếu chưa có.
- Tự cấu hình swap khi RAM thấp.
- Mặc định chạy chế độ LAN.

#### VPS (ARM64 / AMD64)
- Tự cài Docker nếu chưa có.
- Mặc định chạy chế độ LAN.
- Production nên dùng reverse proxy (Caddy/Nginx) để có HTTPS.

---

## Support

- GitHub: https://github.com/duynghien/auto
- Website: https://ai.vnrom.net
