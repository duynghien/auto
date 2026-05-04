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
# Clone repository
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git
cd auto/twenty

# Run setup
chmod +x setup.sh
./setup.sh
```

What the setup script does:
- Detects platform (macOS/Linux)
- Checks and installs Docker on Linux if needed
- Creates install directory: `~/self-hosted/twenty`
- Generates/updates `.env` with required values
- Lets you choose public port and `SERVER_URL`
- Starts `server`, `worker`, `db`, `redis`
- Verifies health endpoint
- Creates helper script: `~/self-hosted/twenty/twenty.sh`

### 🔗 Access URLs

After successful install:
- **Twenty CRM**: `http://localhost:3020` (or your selected port)
- **Health Check**: `http://localhost:<your-port>/healthz`

### 🛠 Management (Helper Script)

Use the generated helper script for quick operations:

```bash
cd ~/self-hosted/twenty
./twenty.sh status
./twenty.sh logs
./twenty.sh restart
./twenty.sh health
./twenty.sh update
```

Available commands:
- `start` — start all services
- `stop` — stop all services
- `restart` — restart all services
- `logs [service]` — stream logs (default: `server`)
- `status` — show container status
- `update` — pull latest images and restart
- `health` — check `/healthz`

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
# Clone repository
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git
cd auto/twenty

# Chạy setup
chmod +x setup.sh
./setup.sh
```

Script sẽ:
- Tự nhận diện nền tảng (macOS/Linux)
- Kiểm tra và cài Docker trên Linux nếu thiếu
- Tạo thư mục cài đặt: `~/self-hosted/twenty`
- Tạo/cập nhật `.env` với thông số cần thiết
- Cho chọn cổng public và `SERVER_URL`
- Khởi động `server`, `worker`, `db`, `redis`
- Kiểm tra health endpoint
- Tạo helper script: `~/self-hosted/twenty/twenty.sh`

### 🔗 URL truy cập

Sau khi cài đặt thành công:
- **Twenty CRM**: `http://localhost:3020` (hoặc cổng bạn chọn)
- **Health Check**: `http://localhost:<port>/healthz`

### 🛠 Quản lý nhanh (Helper Script)

Dùng script helper để thao tác nhanh:

```bash
cd ~/self-hosted/twenty
./twenty.sh status
./twenty.sh logs
./twenty.sh restart
./twenty.sh health
./twenty.sh update
```

Các lệnh hỗ trợ:
- `start` — chạy toàn bộ dịch vụ
- `stop` — dừng toàn bộ dịch vụ
- `restart` — khởi động lại dịch vụ
- `logs [service]` — xem logs realtime (mặc định: `server`)
- `status` — xem trạng thái containers
- `update` — kéo image mới và khởi động lại
- `health` — kiểm tra `/healthz`

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
