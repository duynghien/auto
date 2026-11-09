# FireCrawl — Docker Setup

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

Automated Docker setup for **FireCrawl** — a powerful, open-source web scraping platform with AI extraction, crawling, and REST API.

### ✨ Highlights
- **🔥 Full-stack scraper**: REST API with `/scrape`, `/crawl`, `/search` endpoints out of the box.
- **🌐 Playwright powered**: JavaScript-heavy sites handled natively via dedicated Playwright microservice.
- **🤖 AI Extraction**: Structured JSON output via OpenAI/Ollama — no manual parsing needed.
- **📊 Queue Dashboard**: Built-in Bull queue admin panel for monitoring crawl jobs.
- **🪄 One-Click Setup**: Automated script for **macOS**, **Raspberry Pi**, and **Linux VPS** (amd64/arm64).

### 📋 Requirements
- **Hardware**: Mac (Apple Silicon / Intel), Raspberry Pi (4/5 with 4GB+ recommended), or Linux VPS (4GB+ RAM).
- **Software**:
  - macOS: Docker Desktop or [OrbStack](https://orbstack.dev/) (recommended).
  - Linux: Docker will be installed automatically if missing.

### 🛠️ Installation

```bash
# Method 1: Standalone 1-liner (no git clone required)
curl -fsSL https://raw.githubusercontent.com/duynghien/auto/main/firecrawl/setup.sh | bash

# Method 2: Clone repository
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git && cd auto/firecrawl

chmod +x setup.sh && ./setup.sh
```

### 🔧 Management (`fc` or `firecrawl`)

```bash
fc start    # Start all containers
fc stop     # Stop all containers
fc restart  # Restart all containers
fc logs     # Follow API logs (or fc logs <service>)
fc status   # Show status + health check diagnostics
fc test     # Run a test scrape
fc update   # Pull latest source & rebuild
fc backup   # Dump PostgreSQL (nuq) and archive config
fc restore <archive.sql.gz> # Restore database
fc doctor   # Diagnostic system check
fc uninstall # Remove containers and volumes
```

---

## Tiếng Việt

Bộ cài đặt Docker tự động cho **FireCrawl** — nền tảng web scraping mạnh mẽ, mã nguồn mở với API REST, trích xuất AI và hỗ trợ trang JavaScript nặng.

### ✨ Điểm nổi bật
- **🔥 Scraper toàn diện**: REST API sẵn có với `/scrape`, `/crawl`, `/search`.
- **🌐 Playwright tích hợp**: Xử lý trang JavaScript nặng qua microservice Playwright chuyên dụng.
- **🤖 Trích xuất bằng AI**: Output JSON cấu trúc qua OpenAI/Ollama.
- **📊 Queue Dashboard**: Giao diện theo dõi crawl job tích hợp sẵn.
- **🪄 Setup 1-Click**: Script tự động cho **macOS**, **Raspberry Pi**, và **Linux VPS**.

### 📋 Yêu cầu hệ thống
- **Phần cứng**: Mac (Apple Silicon / Intel), Raspberry Pi (4/5, khuyến nghị 4GB+ RAM), hoặc Linux VPS (4GB+ RAM).
- **Phần mềm**:
  - macOS: Cần cài sẵn Docker Desktop hoặc [OrbStack](https://orbstack.dev/).
  - Linux: Tự động cài Docker nếu chưa có.

### 🛠️ Hướng dẫn cài đặt

```bash
# Cách 1: Cài đặt nhanh 1 dòng lệnh (Standalone không cần clone repo)
curl -fsSL https://raw.githubusercontent.com/duynghien/auto/main/firecrawl/setup.sh | bash

# Cách 2: Clone repository
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git && cd auto/firecrawl

chmod +x setup.sh && ./setup.sh
```

### 🔧 Quản lý nhanh với CLI `fc`

```bash
fc start    # Khởi động containers
fc stop     # Dừng containers
fc restart  # Khởi động lại
fc logs     # Xem logs (hoặc fc logs <service>)
fc status   # Xem trạng thái containers & sức khỏe dịch vụ
fc test     # Chạy thử lệnh scrape
fc update   # Kéo mã nguồn mới nhất & build lại
fc backup   # Sao lưu PostgreSQL (nuq) và cấu hình
fc restore <file.sql.gz> # Khôi phục cơ sở dữ liệu
fc doctor   # Kiểm tra chẩn đoán hệ thống
fc uninstall # Xóa sạch containers và dữ liệu
```

### 🗺️ Địa chỉ truy cập
- **FireCrawl API**: [http://localhost:3002](http://localhost:3002)
- **Queue Admin**: [http://localhost:3002/admin/queues](http://localhost:3002/admin/queues)

---

## 🤝 Support & Community
- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
