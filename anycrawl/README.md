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
- **🪄 One-Click Setup**: Automated script for **macOS**, **Raspberry Pi**, and **Linux VPS** (amd64/arm64).

### 📋 Requirements
- **Hardware**: Mac (Apple Silicon), Raspberry Pi (4/5), or Linux VPS.
- **Software**: 
  - macOS: Docker Desktop or [OrbStack](https://orbstack.dev/) (recommended).
  - Linux: Docker will be installed automatically if missing.

### 🛠️ Installation Guide

Run standalone with a single command or clone the repository:

```bash
# Method 1: Standalone 1-liner (no git clone required)
curl -fsSL https://raw.githubusercontent.com/duynghien/auto/main/anycrawl/setup.sh | bash

# Method 2: Clone repository
git clone https://github.com/duynghien/auto.git
cd auto/anycrawl
chmod +x setup.sh
./setup.sh
```

### ⚡ Management CLI (`anycrawl`)

After installation, use the `anycrawl` command anywhere in your terminal:

```bash
anycrawl status     # Check container health and port bindings
anycrawl logs       # Follow AnyCrawl core logs (or anycrawl logs <service>)
anycrawl start      # Start stack
anycrawl stop       # Stop stack
anycrawl restart    # Restart stack
anycrawl backup     # Archive PostgreSQL database and configurations
anycrawl restore <archive.sql.gz> # Restore PostgreSQL database
anycrawl update     # Pull images, rebuild MCP server, and restart
anycrawl doctor     # Run diagnostic health check
anycrawl uninstall  # Remove containers and volumes
```

### 🤖 MCP Integration (AI Agents)
Connect AnyCrawl to your favorite AI Agent (Claude, LobeHub) using the MCP endpoint:
- **SSE URL**: `http://localhost:8889/sse`
- **Stdio Command**: `docker exec -i anycrawl_mcp node index.js`

Available Tools (8 total):
- `scrape_url`: **(New)** Synchronous high-speed scraping with **LLM content extraction** and screenshots.
- `crawl_url`: Asynchronous scraping into clean Markdown (best for many pages).
- `crawl_results`: **(New)** Retrieve detailed data from completed crawl jobs.
- `crawl_status`: Monitor background crawl job progress.
- `crawl_cancel`: **(New)** Stop an active crawl job.
- `search`: Web search via SearXNG.
- `list_scheduled_tasks`: **(New)** View automation schedules.
- `list_webhooks`: **(New)** Manage notification endpoints.

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
- **🪄 Setup 1-Click**: Script tự động hóa hoàn toàn cho **macOS**, **Raspberry Pi**, và **Linux VPS**.

### 📋 Yêu cầu hệ thống
- **Phần cứng**: Mac (Apple Silicon), Raspberry Pi (4/5), hoặc Linux VPS.
- **Phần mềm**: 
  - macOS: Cần cài sẵn Docker Desktop hoặc [OrbStack](https://orbstack.dev/).
  - Linux: Tự động cài Docker nếu chưa có.

### 🛠️ Hướng dẫn cài đặt

Chạy cài đặt nhanh với 1 dòng lệnh hoặc clone repository:

```bash
# Cách 1: Chạy trực tiếp (Standalone không cần clone repo)
curl -fsSL https://raw.githubusercontent.com/duynghien/auto/main/anycrawl/setup.sh | bash

# Cách 2: Clone repository
git clone https://github.com/duynghien/auto.git
cd auto/anycrawl
chmod +x setup.sh
./setup.sh
```

### ⚡ Quản lý nhanh với `anycrawl` CLI

Sau khi cài đặt xong, bạn có thể gọi lệnh `anycrawl` trực tiếp từ Terminal:

```bash
anycrawl status     # Kiểm tra trạng thái và sức khỏe containers
anycrawl logs       # Xem log AnyCrawl (hoặc anycrawl logs <tên_service>)
anycrawl start      # Khởi động hệ thống
anycrawl stop       # Dừng hệ thống
anycrawl restart    # Khởi động lại
anycrawl backup     # Sao lưu database PostgreSQL và cấu hình vào ./backups
anycrawl restore <file.sql.gz> # Khôi phục database từ file backup
anycrawl update     # Kéo image mới, build lại MCP server và restart
anycrawl doctor     # Kiểm tra lỗi cấu hình, disk, cổng mạng
anycrawl uninstall  # Xóa sạch container và dữ liệu (yêu cầu gõ yes)
```

### 🤖 Tích hợp AI Agent (MCP)
Kết nối AnyCrawl với các Agent AI thông qua giao thức MCP:
- **SSE URL**: `http://localhost:8889/sse`
- **Stdio Command**: `docker exec -i anycrawl_mcp node index.js`

Các công cụ hỗ trợ (Tổng cộng 8 tools):
- `scrape_url`: **(Mới)** Cào 1 trang đồng bộ, hỗ trợ **trích xuất dữ liệu bằng AI (LLM)** và chụp ảnh màn hình.
- `crawl_url`: Cào nội dung sang Markdown (phù hợp cho số lượng trang lớn).
- `crawl_results`: **(Mới)** Lấy dữ liệu chi tiết của một đợt crawl.
- `crawl_status`: Kiểm tra trạng thái job crawl ngầm.
- `crawl_cancel`: **(Mới)** Hủy bỏ một đợt crawl đang chạy.
- `search`: Tìm kiếm web thông qua SearXNG.
- `list_scheduled_tasks`: **(Mới)** Xem danh sách lịch trình cào tự động.
- `list_webhooks`: **(Mới)** Quản lý các kênh nhận thông báo.

### 🗺️ Địa chỉ truy cập
- **AnyCrawl API**: [http://localhost:8880](http://localhost:8880)
- **MinIO Console**: [http://localhost:9001](http://localhost:9001)
- **SearXNG**: [http://localhost:8080](http://localhost:8080)

---

## 🤝 Support & Community
- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
