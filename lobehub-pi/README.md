# LobeHub Pi 4 Installer (v2.0+) 🧠

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

Automatic installation script for LobeHub v2.0+, specifically optimized for **Raspberry Pi 4 (8GB RAM)** or equivalent ARM64 devices. This version integrates the most powerful features of LobeHub.

### 🚀 Key Features
- **Cloud-Native Architecture**: Runs on Docker with a 6-service orchestration.
- **Vector Database**: Uses PostgreSQL + pgvector to support Knowledge Base and Memory.
- **Local S3 Storage**: Integrates RustFS (S3-compatible), which is extremely lightweight for storing files, images, and artifacts.
- **Online Search**: Integrated SearXNG allows Agents to update with real-time information.
- **Maximum Security**: Automatically generates `AUTH_SECRET`, `JWKS_KEY`, and other security secrets.
- **Better Auth**: Supports Email/Password login immediately after installation.

### 📋 System Requirements
- **Device**: Raspberry Pi 4 (8GB) or Pi 5.
- **OS**: Raspberry Pi OS 64-bit (ARM64).
- **Storage**: Minimum 16GB free space (SD Card or SSD).
- **Connection**: Stable internet to pull Docker images.

### 🛠️ Installation Guide

You only need to run a single command to set up the entire system:

```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/lobehub-pi/setup.sh
chmod +x setup.sh
./setup.sh
```

### ⚙️ Post-Installation Configuration

The script installs everything in the `$HOME/lobehub` directory.

#### 1. Add API Keys
By default, the script does not include API Keys for providers (OpenAI, Anthropic...). To add a key:
1. Open the `.env` file: `nano ~/lobehub/.env`
2. Uncomment and fill in your key (e.g., `OPENAI_API_KEY=sk-xxxx`).
3. Restart the service:
   ```bash
   cd ~/lobehub
   docker compose restart lobe
   ```

#### 2. Access the System
- **LobeHub**: `http://<YOUR_PI_IP>:3210`
- **RustFS Console**: `http://<YOUR_PI_IP>:9001` (User/Pass displayed at the end of the installation script).

### 📂 Service List (Docker containers)
- `lobehub`: Main application.
- `lobe-postgres`: Vector database.
- `lobe-redis`: Cache and session storage.
- `lobe-rustfs`: S3 data storage.
- `lobe-searxng`: Search engine.
- `lobe-network`: Gateway and network management.

### 🤝 Contact & Support
- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
- **Community**: [AI & Automation (vnROM)](https://ai.vnrom.net) - Support for AI & Automation deployment.

---

## Tiếng Việt

Script cài đặt tự động LobeHub v2.0+, tối ưu riêng cho **Raspberry Pi 4 (8GB RAM)** hoặc các thiết bị ARM64 tương đương. Phiên bản này tích hợp những tính năng mạnh mẽ nhất của LobeHub.

### 🚀 Tính năng chính
- **Cloud-Native Architecture**: Chạy trên Docker với hệ thống 6 dịch vụ phối hợp.
- **Cơ sở dữ liệu Vector**: Sử dụng PostgreSQL + pgvector để hỗ trợ Knowledge Base và Memory.
- **Lưu trữ S3 nội bộ**: Tích hợp RustFS (tương thích S3) siêu nhẹ để lưu trữ file, hình ảnh và artifacts.
- **Tìm kiếm trực tuyến**: SearXNG tích hợp sẵn cho phép các Agent cập nhật thông tin thời gian thực.
- **Bảo mật tối đa**: Tự động sinh `AUTH_SECRET`, `JWKS_KEY` và các secrets bảo mật khác.
- **Xác thực tốt hơn**: Hỗ trợ đăng nhập bằng Email/Mật khẩu ngay sau khi cài đặt.

### 📋 Yêu cầu hệ thống
- **Thiết bị**: Raspberry Pi 4 (8GB) hoặc Pi 5.
- **Hệ điều hành**: Raspberry Pi OS 64-bit (ARM64).
- **Lưu trữ**: Trống tối thiểu 16GB (Thẻ SD hoặc SSD).
- **Kết nối**: Internet ổn định để tải các Docker images.

### 🛠️ Hướng dẫn cài đặt

Bạn chỉ cần chạy một lệnh duy nhất để thiết lập toàn bộ hệ thống:

```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/lobehub-pi/setup.sh
chmod +x setup.sh
./setup.sh
```

### ⚙️ Cấu hình sau khi cài đặt

Script cài đặt mọi thứ trong thư mục `$HOME/lobehub`.

#### 1. Thêm API Keys
Mặc định script không bao gồm API Keys của các nhà cung cấp (OpenAI, Anthropic...). Để thêm key:
1. Mở file `.env`: `nano ~/lobehub/.env`
2. Bỏ comment và điền key của bạn (ví dụ: `OPENAI_API_KEY=sk-xxxx`).
3. Khởi động lại dịch vụ:
   ```bash
   cd ~/lobehub
   docker compose restart lobe
   ```

#### 2. Truy cập hệ thống
- **LobeHub**: `http://<IP_CUA_PI>:3210`
- **RustFS Console**: `http://<IP_CUA_PI>:9001` (User/Pass hiển thị ở thông báo cuối script cài đặt).

### 📂 Danh sách dịch vụ (Docker containers)
- `lobehub`: Ứng dụng chính.
- `lobe-postgres`: Cơ sở dữ liệu Vector.
- `lobe-redis`: Bộ nhớ đệm và phiên làm việc.
- `lobe-rustfs`: Lưu trữ dữ liệu S3.
- `lobe-searxng`: Bộ máy tìm kiếm.
- `lobe-network`: Gateway và quản lý mạng.

### 🤝 Liên hệ & Hỗ trợ
- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
- **Cộng đồng**: [AI & Automation (vnROM)](https://ai.vnrom.net) - Hỗ trợ triển khai AI & Automation.
