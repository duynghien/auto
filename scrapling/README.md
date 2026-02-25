# Scrapling — Docker Setup (Web Scraping + MCP)

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

A fully automated Docker setup for **Scrapling** — an undetectable, high-performance Python web scraping library with **MCP Server** support for AI Agent integration.

### ✨ Highlights
- **🕵️ Undetectable**: Mimics real browser fingerprints via `curl_cffi` + stealth headers — bypasses most bot detection.
- **🌐 Multi-mode Fetching**: HTTP GET, Playwright (headless browser), or Stealthy (maximum evasion).
- **📄 Flexible Output**: Save scraped content as `.html`, `.md` (Markdown), or `.txt`.
- **🤖 MCP Ready**: Built-in MCP Server for connecting to Claude Desktop, LobeHub, n8n, and other AI Agents.
- **🪄 One-Click Setup**: Automated script for **macOS**, **Raspberry Pi**, and **Linux VPS** (amd64/arm64).

### � Requirements
- **Hardware**: Mac (Apple Silicon / Intel), Raspberry Pi (4/5), or Linux VPS.
- **Software**:
  - macOS: Docker Desktop or [OrbStack](https://orbstack.dev/) (recommended).
  - Linux: Docker will be installed automatically if missing.

### �️ Installation

```bash
# Clone the automation repository
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git
cd auto/scrapling

# Run setup
chmod +x setup.sh
./setup.sh
```

The script auto-detects your OS (macOS, Raspberry Pi, or VPS) and configures everything accordingly.

### � Usage

```bash
# HTTP GET → HTML (fast, stealth mode)
docker run --rm -v "$(pwd)/data:/data" scrapling:latest \
  extract get https://example.com /data/output.html

# HTTP GET → Markdown
docker run --rm -v "$(pwd)/data:/data" scrapling:latest \
  extract get https://example.com /data/output.md

# Playwright (JavaScript-heavy sites)
docker run --rm -v "$(pwd)/data:/data" scrapling:latest \
  extract fetch https://example.com /data/output.html

# Stealthy (maximum bot evasion)
docker run --rm -v "$(pwd)/data:/data" scrapling:latest \
  extract stealthy-fetch https://example.com /data/output.html

# CSS Selector extraction
docker run --rm -v "$(pwd)/data:/data" scrapling:latest \
  extract get https://example.com /data/output.html -s "h1, p"
```

> **Note**: Containers run with `--rm` (one-shot, auto-removed). They won't show in OrbStack after completing — this is expected.

### 🤖 MCP Integration (AI Agents)

```bash
# Start MCP Server
docker compose --profile mcp up -d
```

- **MCP URL**: `http://localhost:8000/mcp`

Add to **Claude Desktop** (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "scrapling": {
      "url": "http://localhost:8000/mcp"
    }
  }
}
```

### 🗺️ Access URLs
- **MCP Server**: [http://localhost:8000/mcp](http://localhost:8000/mcp)
- **Output files**: `./data/`

---

## Tiếng Việt

Bộ cài đặt Docker tự động cho **Scrapling** — thư viện scraping Python không bị phát hiện, hiệu năng cao, tích hợp **MCP Server** để kết nối với AI Agent.

### ✨ Điểm nổi bật
- **Không bị phát hiện**: Giả lập browser fingerprint thật qua `curl_cffi` + stealth headers — vượt qua hầu hết các hệ thống chống bot.
- **Đa chế độ**: HTTP GET, Playwright (trình duyệt headless), hoặc Stealthy (tối đa hóa ẩn mình).
- **Đầu ra linh hoạt**: Lưu kết quả dưới dạng `.html`, `.md` (Markdown), hoặc `.txt`.
- **Tích hợp MCP**: Sẵn sàng kết nối với Claude Desktop, LobeHub, n8n và các AI Agent khác.
- **Setup 1-Click**: Script tự động hóa cho **macOS**, **Raspberry Pi**, và **Linux VPS**.

### 📋 Yêu cầu hệ thống
- **Phần cứng**: Mac (Apple Silicon / Intel), Raspberry Pi (4/5), hoặc Linux VPS.
- **Phần mềm**:
  - macOS: Cần cài sẵn Docker Desktop hoặc [OrbStack](https://orbstack.dev/).
  - Linux: Tự động cài Docker nếu chưa có.

### 🛠️ Hướng dẫn cài đặt

```bash
# Tải bộ cài đặt
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git
cd auto/scrapling

# Chạy script (tự nhận diện OS)
chmod +x setup.sh
./setup.sh
```

### 🔧 Sử dụng

```bash
# GET trang web → HTML (nhanh, stealth)
docker run --rm -v "$(pwd)/data:/data" scrapling:latest \
  extract get https://example.com /data/output.html

# GET trang web → Markdown
docker run --rm -v "$(pwd)/data:/data" scrapling:latest \
  extract get https://example.com /data/output.md

# Playwright (trang web dùng JavaScript)
docker run --rm -v "$(pwd)/data:/data" scrapling:latest \
  extract fetch https://example.com /data/output.html

# Stealthy (vượt bot tối đa)
docker run --rm -v "$(pwd)/data:/data" scrapling:latest \
  extract stealthy-fetch https://example.com /data/output.html

# Lọc theo CSS Selector
docker run --rm -v "$(pwd)/data:/data" scrapling:latest \
  extract get https://example.com /data/output.html -s "h1, p"
```

> **Lưu ý**: Container chạy với `--rm` (dùng một lần, tự xóa sau khi xong). Sẽ không hiển thị trong OrbStack sau khi hoàn thành — đây là hành vi bình thường.

### 🤖 Tích hợp AI Agent (MCP)

```bash
# Khởi động MCP Server
docker compose --profile mcp up -d
```

- **MCP URL**: `http://localhost:8000/mcp`

Thêm vào cấu hình **Claude Desktop**:

```json
{
  "mcpServers": {
    "scrapling": {
      "url": "http://localhost:8000/mcp"
    }
  }
}
```

### Địa chỉ truy cập
- **MCP Server**: [http://localhost:8000/mcp](http://localhost:8000/mcp)
- **File output**: `./data/`

---

## 🤝 Support & Community
- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
