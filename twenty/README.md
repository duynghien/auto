# Twenty CRM Auto Setup (v2.0) | Cài đặt tự động Twenty CRM

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

Automated setup script for **Twenty CRM** on **macOS** and **Linux** (AMD64/ARM64) using Docker Compose.

### 🚀 Stack Overview

| Component | Description |
|---|---|
| **Twenty CRM Server** | Main web app/API (container port 3000) |
| **Twenty CRM Worker** | Background jobs |
| **PostgreSQL 16** | Primary database |
| **Redis** | Cache and queue |

### 📋 Requirements

- **macOS**: Docker Desktop or [OrbStack](https://orbstack.dev/)
- **Linux**: Docker will be installed automatically if missing
- `curl` and `openssl`

### 🛠 Installation

```bash
# Method 1: Standalone 1-liner
curl -fsSL https://raw.githubusercontent.com/duynghien/auto/main/twenty/setup.sh | bash

# Method 2: Clone repository
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git
cd auto/twenty
chmod +x setup.sh && ./setup.sh
```

What the setup script does:
- Detects platform (macOS/Linux)
- Checks and installs Docker on Linux if needed
- Creates install directory: `~/self-hosted/twenty`
- Generates/updates `.env` with required values
- Lets you choose public port and `SERVER_URL` (auto-adds `http://` if missing)
- Starts `server`, `worker`, `db`, `redis`
- Verifies health endpoint
- Creates helper script: `~/self-hosted/twenty/twenty.sh`

`SERVER_URL` must be a valid URL origin, for example:
- `http://localhost:3020`
- `https://crm.example.com`

### 🔗 Access URLs

After successful install:
- **Twenty CRM**: `http://localhost:3020` (or your selected port)
- **Health Check**: `http://localhost:<your-port>/healthz`

### 🛠 Management (`twenty` CLI)

Use the helper CLI `twenty` (or `./twenty.sh`):

```bash
twenty status   # Check container status
twenty logs     # View logs (default: server)
twenty start    # Start all services
twenty stop     # Stop all services
twenty restart  # Restart all services
twenty update   # Pull latest images and restart
twenty health   # Check /healthz endpoint
twenty backup   # Dump PostgreSQL database & archive configs to ./backups/
twenty restore <archive.sql.gz> # Safely restore database
twenty doctor   # Run diagnostic health checks
twenty uninstall # Remove containers and data volumes
```

### 🔐 Important

- Credentials and secrets are stored in:
  - `~/self-hosted/twenty/.env`
- Do not share this file publicly.

### 🧩 Common Troubleshooting

```bash
cd ~/self-hosted/twenty

# Check running containers
./twenty.sh status

# View server logs
./twenty.sh logs server

# Restart whole stack
./twenty.sh restart
```

---

## Tiếng Việt

Script tự động cài đặt **Twenty CRM** trên **macOS** và **Linux** (AMD64/ARM64) bằng Docker Compose.

### 🚀 Thành phần hệ thống

| Thành phần | Mô tả |
|---|---|
| **Twenty CRM Server** | Ứng dụng web/API chính (port nội bộ 3000) |
| **Twenty CRM Worker** | Xử lý tác vụ nền |
| **PostgreSQL 16** | Cơ sở dữ liệu chính |
| **Redis** | Cache và queue |

### 📋 Yêu cầu

- **macOS**: Docker Desktop hoặc [OrbStack](https://orbstack.dev/)
- **Linux**: script sẽ tự cài Docker nếu chưa có
- Có sẵn `curl` và `openssl`

### 🛠 Cài đặt

```bash
# Cách 1: Cài đặt nhanh 1 dòng lệnh (Standalone)
curl -fsSL https://raw.githubusercontent.com/duynghien/auto/main/twenty/setup.sh | bash

# Cách 2: Clone repository
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git
cd auto/twenty
chmod +x setup.sh && ./setup.sh
```

Script sẽ:
- Tự nhận diện nền tảng (macOS/Linux)
- Kiểm tra và cài Docker trên Linux nếu thiếu
- Tạo thư mục cài đặt: `~/self-hosted/twenty`
- Tạo/cập nhật `.env` với thông số cần thiết
- Cho chọn cổng public và `SERVER_URL` (tự thêm `http://` nếu thiếu)
- Khởi động `server`, `worker`, `db`, `redis`
- Kiểm tra health endpoint
- Tạo helper script: `~/self-hosted/twenty/twenty.sh`

`SERVER_URL` phải là URL hợp lệ, ví dụ:
- `http://localhost:3020`
- `https://crm.example.com`

### 🔗 URL truy cập

Sau khi cài đặt thành công:
- **Twenty CRM**: `http://localhost:3020` (hoặc cổng bạn chọn)
- **Health Check**: `http://localhost:<port>/healthz`

### 🛠 Quản lý nhanh với CLI `twenty`

```bash
twenty status   # Xem trạng thái containers
twenty logs     # Xem logs (mặc định: server)
twenty start    # Chạy toàn bộ dịch vụ
twenty stop     # Dừng toàn bộ dịch vụ
twenty restart  # Khởi động lại dịch vụ
twenty update   # Kéo image mới và khởi động lại
twenty health   # Kiểm tra endpoint /healthz
twenty backup   # Sao lưu PostgreSQL và cấu hình vào ./backups/
twenty restore <file.sql.gz> # Khôi phục cơ sở dữ liệu
twenty doctor   # Chẩn đoán sức khỏe hệ thống
twenty uninstall # Xóa sạch containers và volumes
```

### 🔐 Lưu ý quan trọng

- Tài khoản/mật khẩu/secret nằm trong:
  - `~/self-hosted/twenty/.env`
- Không chia sẻ file này công khai.

### 🧩 Khắc phục nhanh

```bash
cd ~/self-hosted/twenty

# Kiểm tra container đang chạy
./twenty.sh status

# Xem log server
./twenty.sh logs server

# Restart toàn bộ stack
./twenty.sh restart
```

---

Support: https://ai.vnrom.net
