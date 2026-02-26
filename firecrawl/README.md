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
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git && cd auto/firecrawl

chmod +x setup.sh && ./setup.sh
```

### 🔧 Usage

```bash
# Health check
curl http://localhost:3002/v1/health

# Scrape a URL → Markdown
curl -X POST http://localhost:3002/v1/scrape \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com", "formats": ["markdown"]}'

# Scrape → structured JSON with AI
curl -X POST http://localhost:3002/v1/scrape \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com", "formats": ["extract"], "actions": [{"type": "wait", "milliseconds": 2000}]}'

# Crawl an entire site
curl -X POST http://localhost:3002/v1/crawl \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com", "limit": 10, "formats": ["markdown"]}'
```

### 🗺️ Access URLs
- **FireCrawl API**: [http://localhost:3002](http://localhost:3002)
- **Queue Admin**: [http://localhost:3002/admin/queues](http://localhost:3002/admin/queues)

### 🔧 Management

```bash
./fc.sh start    # Start all containers
./fc.sh stop     # Stop all containers
./fc.sh logs     # Follow API logs
./fc.sh status   # Show status + health check
./fc.sh test     # Run a test scrape
./fc.sh update   # Pull latest source & rebuild
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
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git && cd auto/firecrawl

chmod +x setup.sh && ./setup.sh
```

### 🗺️ Địa chỉ truy cập
- **FireCrawl API**: [http://localhost:3002](http://localhost:3002)
- **Queue Admin**: [http://localhost:3002/admin/queues](http://localhost:3002/admin/queues)

---

## 🤝 Support & Community
- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
