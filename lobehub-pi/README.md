# LobeHub Raspberry Pi Installer (v3.0) 🧠

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

Automatic installation script for LobeHub v3.0, specifically optimized for **Raspberry Pi 4 (8GB RAM)** or **Pi 5**. This version brings the full power of LobeHub to your home server with a single command.

### 🚀 Key Features
- **Bilingual Setup**: Choose between English and Tiếng Việt during installation.
- **Home Server Ready**: Supports **LAN Mode** (auto-detects Pi IP) so you can access LobeHub from any device in your network.
- **Storage Choice**: Support for both **RustFS** (lightweight) and **MinIO** (stable) S3 storage.
- **Enhanced Search**: Integrated **SearXNG** (self-hosted) for real-time web search.
- **Knowledge Base**: Uses PostgreSQL + pgvector for full vector memory and file analysis.
- **Easy Management**: Includes the `lobe.sh` helper tool for start/stop/logs/update commands.
- **Maximum Security**: Automatic generation of `AUTH_SECRET`, `JWKS_KEY`, and secure database credentials.

### 📋 System Requirements
- **Device**: Raspberry Pi 4 (8GB) or Pi 5.
- **OS**: Raspberry Pi OS 64-bit (ARM64).
- **Storage**: Minimum 16GB free space (SD Card or SSD/NVMe).
- **Network**: Wired Ethernet recommended for stable LAN access.

### 🛠️ Installation Guide

Run this command on your Raspberry Pi terminal:

```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/lobehub-pi/setup.sh
chmod +x setup.sh
./setup.sh
```

### ⚙️ Post-Installation & Management

The script installs everything in the `~/lobehub` directory and creates a management tool `lobe.sh`.

#### 1. Add API Keys
The system needs API keys to function. Edit the `.env` file:
```bash
nano ~/lobehub/.env
```
Uncomment and add your keys (e.g., `OPENAI_API_KEY=sk-xxxx`). Then restart:
```bash
~/lobehub/lobe.sh restart
```

#### 2. Accessing from Other Devices
If you selected **LAN Mode** during setup:
- **LobeHub**: `http://<PI_IP_ADDRESS>:3210`
- **S3 Console**: `http://<PI_IP_ADDRESS>:9001`

#### 3. Management Tool (`lobe.sh`)
Navigate to the installation directory and use these commands:
- `./lobe.sh start` / `./lobe.sh stop` / `./lobe.sh restart`
- `./lobe.sh logs` - View real-time logs.
- `./lobe.sh upgrade` - Update to the latest version.
- `./lobe.sh search-test` - Test if SearXNG is working.

### 🤝 Contact & Support
- **Website**: [vnrom.net](https://vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
- **Community**: [AI & Automation (vnROM)](https://ai.vnrom.net) - Support for AI & Automation deployment.

---

## Tiếng Việt

Script cài đặt tự động LobeHub v3.0, tối ưu hóa cho **Raspberry Pi 4 (8GB RAM)** hoặc **Pi 5**. Phiên bản này mang toàn bộ sức mạnh của LobeHub lên home server của bạn chỉ với một câu lệnh.

### 🚀 Tính năng chính
- **Hỗ trợ song ngữ**: Lựa chọn English hoặc Tiếng Việt ngay khi bắt đầu cài đặt.
- **Home Server Ready**: Chế độ **LAN Mode** (tự nhận IP của Pi) giúp truy cập từ mọi thiết bị trong mạng nội bộ.
- **Lựa chọn lưu trữ**: Hỗ trợ cả **RustFS** (siêu nhẹ) và **MinIO** (ổn định) cho S3 storage.
- **Tìm kiếm nâng cao**: Tích hợp **SearXNG** (self-hosted) để AI tìm kiếm thông tin thời gian thực.
- **Knowledge Base**: Sử dụng PostgreSQL + pgvector hỗ trợ đầy đủ bộ nhớ vector và phân tích tài liệu.
- **Quản lý dễ dàng**: Tích hợp bộ công cụ `lobe.sh` giúp bật/tắt/xem log/cập nhật cực nhanh.
- **Bảo mật tối đa**: Tự động sinh khóa `AUTH_SECRET`, `JWKS_KEY` và mật khẩu database an toàn.

### 📋 Yêu cầu hệ thống
- **Thiết bị**: Raspberry Pi 4 (8GB) hoặc Pi 5.
- **Hệ điều hành**: Raspberry Pi OS 64-bit (ARM64).
- **Lưu trữ**: Trống tối thiểu 16GB (Thẻ SD hoặc SSD/NVMe).
- **Kết nối**: Nên dùng mạng dây (Ethernet) để truy cập LAN ổn định nhất.

### 🛠️ Hướng dẫn cài đặt

Chạy lệnh sau trên terminal của Raspberry Pi:

```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/lobehub-pi/setup.sh
chmod +x setup.sh
./setup.sh
```

### ⚙️ Quản lý và Cấu hình

Script cài đặt mọi thứ trong thư mục `~/lobehub` và tạo ra file quản lý `lobe.sh`.

#### 1. Thêm API Keys
Hệ thống cần API key để hoạt động. Hãy sửa file `.env`:
```bash
nano ~/lobehub/.env
```
Bỏ dấu comment và điền key của bạn (ví dụ: `OPENAI_API_KEY=sk-xxxx`). Sau đó khởi động lại:
```bash
~/lobehub/lobe.sh restart
```

#### 2. Truy cập từ thiết bị khác
Nếu bạn đã chọn **LAN Mode** khi cài đặt:
- **LobeHub**: `http://<IP_CUA_PI>:3210`
- **S3 Console**: `http://<IP_CUA_PI>:9001`

#### 3. Công cụ quản trị (`lobe.sh`)
Truy cập thư mục cài đặt và sử dụng các lệnh:
- `./lobe.sh start` / `./lobe.sh stop` / `./lobe.sh restart`
- `./lobe.sh logs` - Xem log thời gian thực.
- `./lobe.sh upgrade` - Cập nhật phiên bản mới nhất.
- `./lobe.sh search-test` - Kiểm tra tính năng tìm kiếm SearXNG.

### 🤝 Liên hệ & Hỗ trợ
- **Website**: [vnrom.net](https://vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
- **Cộng đồng**: [AI & Automation (vnROM)](https://ai.vnrom.net) - Hỗ trợ triển khai AI & Automation.
