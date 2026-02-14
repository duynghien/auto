# AnyCrawl "Max Option" Stack Setup (PostgreSQL + MinIO + MCP)

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

The most complete and optimized self-hosted stack for **AnyCrawl**, featuring enterprise-grade components: **PostgreSQL**, **MinIO (S3)**, **Redis**, **SearXNG**, and a custom **MCP Server** for AI Agent integration.

### ✨ Highlights (v2.0)
- **🚀 Scalable Database**: Replaces SQLite with **PostgreSQL 17** to prevent "Database Locked" errors during concurrent crawls.
- **📦 S3 Storage**: Integrated **MinIO** for storing crawl artifacts (HTML, PDF, Screenshots) using the S3 standard.
- **🔍 Privacy-First Search**: Built-in **SearXNG** backend for Google/Bing searches without expensive proxies.
- **🛠️ AI Agent Ready**: Includes a dedicated **MCP Server** (SSE/Stdio) for seamless connection with LobeHub, Claude Desktop, and OpenClaw.
- **🪄 One-Click Setup**: Automated scripts for both macOS (Apple Silicon) and Raspberry Pi.

### 📋 Requirements
- **Hardware**: Mac (M1/M2/M3/M4) or Raspberry Pi (4/5).
- **Software**: Docker and Docker Compose installed (recommend [OrbStack](https://orbstack.dev/) for Mac).

### 🛠️ Installation Guide

Open your Terminal and run the following commands:

```bash
# Clone the automation repository
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git anycrawl-stack
cd anycrawl-stack/anycrawl

# Run the setup script (macOS)
chmod +x setup.sh
./setup.sh

# Or for Raspberry Pi
# sudo chmod +x install-pi.sh
# sudo ./install-pi.sh
```

### 🤖 MCP Integration (AI Agents)
Connect AnyCrawl to your favorite AI Agent (Claude, LobeHub) using the MCP endpoint:
- **SSE URL**: `http://localhost:8889/sse`
- **Stdio Command**: `docker exec -i anycrawl_mcp node index.js`

Available Tools:
- `crawl_url`: Scrape any URL into clean Markdown.
- `search`: Web search via SearXNG.
- `crawl_status`: Monitor background crawl jobs.

### 🗺️ Access URLs
- **AnyCrawl API**: [http://localhost:8880](http://localhost:8880)
- **MinIO Console**: [http://localhost:9001](http://localhost:9001)
- **SearXNG**: [http://localhost:8080](http://localhost:8080)

---

## Tiếng Việt

Bộ cài đặt tự động AnyCrawl tối ưu nhất, tích hợp đầy đủ các thành phần "enterprise": **PostgreSQL**, **MinIO (S3)**, **Redis**, **SearXNG** và **MCP Server** để kết nối với các AI Agent.

### ✨ Điểm nổi bật (v2.0)
- **🚀 Database chịu tải**: Thay thế SQLite bằng **PostgreSQL 17**, khắc phục triệt để lỗi "Database Locked" khi crawl đa luồng.
- **📦 Lưu trữ chuẩn S3**: Tích hợp **MinIO** để quản lý file (HTML, PDF, Ảnh chụp màn hình) theo chuẩn S3, dễ dàng backup và di chuyển.
- **🔍 Tìm kiếm bảo mật**: Tích hợp sẵn **SearXNG**, cho phép AI tìm kiếm Google/Bing mà không tốn tiền mua Proxy.
- **🛠️ Sẵn sàng cho AI Agent**: Code thêm **MCP Server** chuyên dụng, cho phép LobeHub, Claude Desktop hay OpenClaw điều khiển AnyCrawl trực tiếp.
- **🪄 Setup 1-Click**: Script tự động hóa hoàn toàn cho macOS (Apple Silicon) và Raspberry Pi.

### 📋 Yêu cầu hệ thống
- **Phần cứng**: Mac chip M1/M2/M3/M4 hoặc Raspberry Pi (4/5).
- **Phần mềm**: Đã cài đặt Docker (khuyên dùng [OrbStack](https://orbstack.dev/) trên Mac).

### 🛠️ Hướng dẫn cài đặt

Mở Terminal và chạy các lệnh sau:

```bash
# Tải bộ cài đặt
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git anycrawl-stack
cd anycrawl-stack/anycrawl

# Chạy script cài đặt (Cho macOS)
chmod +x setup.sh
./setup.sh

# Hoặc cho Raspberry Pi
# sudo chmod +x install-pi.sh
# sudo ./install-pi.sh
```

### 🤖 Tích hợp AI Agent (MCP)
Kết nối AnyCrawl với các Agent AI thông qua giao thức MCP:
- **SSE URL**: `http://localhost:8889/sse`
- **Stdio Command**: `docker exec -i anycrawl_mcp node index.js`

Các công cụ hỗ trợ:
- `crawl_url`: Cào nội dung trang web sang Markdown sạch.
- `search`: Tìm kiếm web thông qua SearXNG.
- `crawl_status`: Kiểm tra trạng thái job crawl ngầm.

### �️ Địa chỉ truy cập
- **AnyCrawl API**: [http://localhost:8880](http://localhost:8880)
- **MinIO Console**: [http://localhost:9001](http://localhost:9001)
- **SearXNG**: [http://localhost:8080](http://localhost:8080)

---

## 🤝 Support & Community
- **Website**: [vnrom.net](https://vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
- **Community**: [AI & Automation (vnROM)](https://ai.vnrom.net)
