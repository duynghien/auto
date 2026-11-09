# Bolt.diy Self-Hosted Installer 🚀

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

Bolt.diy is an open-source AI-powered development workspace running entirely in your browser. This standalone installer packages Bolt.diy with Docker Compose for 1-Click deployment across macOS (Apple Silicon / Intel), Linux VPS (AMD64 / ARM64), and Raspberry Pi 4/5.

### 🌟 Features

- **100% Standalone Setup:** Self-contained script with inline configuration generation.
- **Bilingual Experience:** English & Tiếng Việt interactive setup.
- **Port Conflict Protection:** Automatic detection on default port `5173` with custom port selection.
- **Hardware Preflight:** RAM & Swap detection with automatic 4 GB `/swapfile` configuration on low-memory servers (LXC/OpenVZ compatible).
- **Multi-Provider AI Support:** Pre-configured for Anthropic, OpenAI, Groq, Google Gemini, Ollama, DeepSeek, OpenRouter, Mistral, and OpenAI-compatible endpoints.
- **Full-Lifecycle CLI:** Includes `./boltdiy.sh` with `status`, `start`, `stop`, `restart`, `logs`, `update`, `backup`, `restore`, `doctor`, and `uninstall`.

### 📋 Prerequisites

- **Docker:** Engine 24.0+ & Docker Compose v2.
- **Hardware Minimums:** 2 GB RAM (4 GB recommended; installer configures Swap automatically when RAM < 4 GB).
- **Free Disk Space:** Minimum 10 GB free space for source repository and Node.js build dependencies.

### 🚀 Quick Start

Run the standalone installer:

```bash
bash setup.sh
```

Or run directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/duynghien/auto/main/boltdiy/setup.sh | bash
```

The script will prompt for language, network mode (Localhost, LAN IP, Domain), and configure `$HOME/self-hosted/boltdiy`.

### 🛠️ Management CLI (`./boltdiy.sh`)

After installation, navigate to your install directory (`cd ~/self-hosted/boltdiy`) to manage the stack:

```bash
./boltdiy.sh status      # View container health, active ports, and URLs
./boltdiy.sh start       # Start Bolt.diy container
./boltdiy.sh stop        # Stop Bolt.diy container
./boltdiy.sh restart     # Restart Bolt.diy container
./boltdiy.sh logs        # Follow container logs
./boltdiy.sh update      # Pull latest upstream source, rebuild image, and restart
./boltdiy.sh backup      # Create encrypted/restricted snapshot in ./backups/ (chmod 700)
./boltdiy.sh restore <f> # Verify integrity (gzip -t), take safety snapshot, and restore
./boltdiy.sh doctor      # Diagnostic check on Docker, disk, ports, and permissions
./boltdiy.sh uninstall   # Safely stop and remove containers and data
```

### 🔑 Configuring AI Models

Edit `$HOME/self-hosted/boltdiy/.env` to configure your API keys:

```bash
# Add at least one provider key:
ANTHROPIC_API_KEY=sk-ant-api03-...
OPENAI_API_KEY=sk-proj-...
GOOGLE_GENERATIVE_AI_API_KEY=AIzaSy...
OLLAMA_API_BASE_URL=http://host.docker.internal:11434
```

Then reload the configuration:

```bash
./boltdiy.sh restart
```

---

## Tiếng Việt

Bolt.diy là môi trường lập trình AI mã nguồn mở chạy trực tiếp trên trình duyệt. Bộ cài đặt độc lập này đóng gói Bolt.diy cùng Docker Compose để triển khai 1-Click trên macOS (Apple Silicon / Intel), Linux VPS (AMD64 / ARM64), và Raspberry Pi 4/5.

### 🌟 Tính năng nổi bật

- **Cài đặt độc lập 100%:** Script tự sinh toàn bộ cấu hình, không phụ thuộc file ngoài khi chạy `curl | bash`.
- **Trải nghiệm song ngữ:** Hỗ trợ đầy đủ tiếng Anh và tiếng Việt.
- **Xử lý xung đột cổng:** Tự động kiểm tra cổng mặc định `5173` và cho phép đổi cổng linh hoạt.
- **Kiểm tra phần cứng tự động:** Cảnh báo thiếu RAM và tự động tạo Swap 4 GB trên VPS cấu hình thấp (tương thích cả LXC/OpenVZ).
- **Hỗ trợ đa nền tảng AI:** Sẵn sàng cho Anthropic, OpenAI, Groq, Gemini, Ollama, DeepSeek, OpenRouter...
- **Công cụ quản lý toàn diện:** Đi kèm `./boltdiy.sh` với `status`, `start`, `stop`, `restart`, `logs`, `update`, `backup`, `restore`, `doctor`, `uninstall`.

### 📋 Yêu cầu hệ thống

- **Docker:** Bản 24.0+ kèm Docker Compose v2.
- **RAM tối thiểu:** 2 GB (khuyến nghị 4 GB; script tự động tạo Swap khi RAM < 4 GB).
- **Dung lượng trống:** Tối thiểu 10 GB cho mã nguồn và build Node.js dependencies.

### 🚀 Cài đặt nhanh

Chạy script cài đặt:

```bash
bash setup.sh
```

Hoặc chạy trực tiếp từ GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/duynghien/auto/main/boltdiy/setup.sh | bash
```

### 🛠️ Lệnh quản lý (`./boltdiy.sh`)

Di chuyển vào thư mục cài đặt (`cd ~/self-hosted/boltdiy`):

```bash
./boltdiy.sh status      # Kiểm tra trạng thái container và cổng kết nối
./boltdiy.sh start       # Khởi động dịch vụ
./boltdiy.sh stop        # Dừng dịch vụ
./boltdiy.sh restart     # Khởi động lại
./boltdiy.sh logs        # Xem log thời gian thực
./boltdiy.sh update      # Kéo mã nguồn mới nhất từ upstream, build lại và khởi động
./boltdiy.sh backup      # Sao lưu cấu hình vào ./backups/ (phân quyền an toàn)
./boltdiy.sh restore <f> # Kiểm tra file backup, tạo snapshot an toàn rồi khôi phục
./boltdiy.sh doctor      # Chẩn đoán trạng thái Docker, ổ đĩa, cổng và quyền file
./boltdiy.sh uninstall   # Gỡ cài đặt và dọn dẹp an toàn
```

---
**Tác giả:** [duynghien](https://github.com/duynghien) • [vnROM.net](https://vnrom.net)  
**Cộng đồng:** [AI & Automation (vnROM)](https://ai.vnrom.net)
