# Spacebot Auto-Installer

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

An automated deployment script for [Spacebot](https://github.com/spacedriveapp/spacebot) (An AI agent for teams, communities, and multi-user environments).

### ✨ Highlights
- **🪄 One-Click Setup**: Automated script for **macOS**, **Raspberry Pi**, and **Linux VPS** (amd64/arm64).
- **Auto OS Detection**: Automatically adapts to your operating system.
- **Docker Auto-Install**: Installs Docker and Docker Compose on Linux if missing.
- **Swap Management**: Creates a 2GB swap file on low-RAM devices like Raspberry Pi.
- **Secure Deployment**: Generates a `.env` file for API keys if none exists.
- **Health Checks**: Verifies that the container is up and accessible.

### 📋 Requirements
- **Hardware**: Mac (Apple Silicon & Intel), Raspberry Pi (4/5), or Linux VPS.
- **Software**: 
  - macOS: Docker Desktop or [OrbStack](https://orbstack.dev/) (recommended).
  - Linux: Docker will be installed automatically if missing.

### 🛠️ Installation Guide

Open your Terminal and run the following commands:

```bash
# Clone the automation repository
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git auto-stack
cd auto-stack/spacebot

# Run the setup script
chmod +x setup.sh
./setup.sh
```

The script will automatically detect your OS (macOS, Pi, or VPS) and configure the environment accordingly.

### 🗺️ Access URLs
Once installed:
- **Spacebot UI**: [http://localhost:19898](http://localhost:19898) (Open in browser to complete onboarding)
- Data is stored locally in `./data` mapping to `/data` in the container.

### ⚙️ Management
```bash
# Start
docker compose up -d

# Stop
docker compose stop

# View Logs
docker compose logs -f spacebot

# Update Spacebot
docker compose pull && docker compose up -d
```

---

## Tiếng Việt

Bộ cài đặt tự động cho [Spacebot](https://github.com/spacedriveapp/spacebot) (AI Agent dành cho team, cộng đồng và môi trường nhiều người dùng).

### ✨ Điểm nổi bật
- **🪄 Setup 1-Click**: Script tự động hóa hoàn toàn cho **macOS**, **Raspberry Pi**, và **Linux VPS** (amd64/arm64).
- **Tự động nhận diện OS**: Tự động thích ứng với hệ điều hành của bạn.
- **Cài đặt Docker tự động**: Tự động cài Docker và Docker Compose trên Linux nếu chưa có.
- **Quản lý Swap**: Tạo file swap 2GB cho các thiết bị có RAM thấp như Raspberry Pi.
- **Khởi tạo an toàn**: Tự động tạo file `.env` mẫu để cấu hình các API Key bảo mật.
- **Health Checks**: Kiểm tra tự động trạng thái khởi động của container.

### 📋 Yêu cầu hệ thống
- **Phần cứng**: Mac (Apple Silicon & Intel), Raspberry Pi (4/5), hoặc Linux VPS.
- **Phần mềm**: 
  - macOS: Cần cài sẵn Docker Desktop hoặc [OrbStack](https://orbstack.dev/).
  - Linux: Tự động cài Docker nếu chưa có.

### 🛠️ Hướng dẫn cài đặt

Mở Terminal và chạy các lệnh sau:

```bash
# Tải bộ cài đặt
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git auto-stack
cd auto-stack/spacebot

# Chạy script cài đặt (tự nhận diện OS)
chmod +x setup.sh
./setup.sh
```

Script sẽ tự động nhận diện hệ điều hành của bạn (macOS, Pi, hoặc VPS) và làm mọi thứ tự động.

### 🗺️ Địa chỉ truy cập
Sau khi cài đặt xong:
- **Giao diện Spacebot**: [http://localhost:19898](http://localhost:19898) (Mở trên trình duyệt để hoàn tất thiết lập ban đầu)
- Dữ liệu được lưu trữ cố định ở thư mục `./data` trên máy chủ.

### ⚙️ Quản lý
```bash
# Bật
docker compose up -d

# Tắt
docker compose stop

# Xem Logs
docker compose logs -f spacebot

# Cập nhật Spacebot
docker compose pull && docker compose up -d
```

---

## 🤝 Support & Community
- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
