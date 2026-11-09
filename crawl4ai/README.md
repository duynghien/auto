# 🕷️ Crawl4AI Self-Hosted Stack

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

**Self-hosted [Crawl4AI v0.8.0](https://github.com/unclecode/crawl4ai)** — the most-starred open-source LLM-friendly web crawler on GitHub.  
Automated setup for **macOS (Apple Silicon)**, **Raspberry Pi**, and **Linux VPS**.

### ✨ Features

| Feature | Description |
|---|---|
| 🕷️ **Smart Crawling** | Async browser pool, caching, session management, proxy support |
| 📝 **LLM-Ready Output** | Clean Markdown with headings, tables, code, citations |
| 🤖 **AI Extraction** | LLM-powered structured data extraction (all providers via LiteLLM) |
| 📊 **Dashboard** | Real-time monitoring with system metrics & browser pool visibility |
| 🎮 **Playground** | Interactive web UI to test & generate crawl code |
| 🔌 **MCP Server** | 7 built-in tools for AI Agents — supports **SSE**, **Streamable HTTP**, **WebSocket** |
| 📸 **Media** | Screenshots, PDF export, image/video extraction |
| 🔄 **Deep Crawl** | BFS/DFS/Best-First with crash recovery & resume |
| ⚡ **Prefetch Mode** | 5-10x faster URL discovery |
| 🔒 **Security** | JWT auth, rate limiting, bot detection evasion |

---

### 🤖 MCP Server

#### Tools (7 built-in)
- `md`: Convert URL to Markdown
- `html`: Extract HTML
- `screenshot`: Capture page screenshot
- `pdf`: Generate PDF
- `execute_js`: Run JavaScript
- `crawl`: Batch crawl
- `ask`: Query docs

#### AI Agent Integration

| Protocol | Endpoint | Supported Agents |
|---|---|---|
| **SSE** | `/mcp/sse` | Claude Desktop, Antigravity, OpenClaw |
| **Streamable HTTP** | `/mcp/streamable` | LobeHub |
| **WebSocket** | `/mcp/ws` | Real-time clients |

---

### 📋 Requirements

| Platform | Requirements |
|---|---|
| **macOS** | Apple Silicon + [OrbStack](https://orbstack.dev/) or Docker Desktop |
| **Raspberry Pi** | Pi 4 (4GB+) or Pi 5 (64-bit OS) |
| **VPS** | 2GB+ RAM (4GB recommended), Ubuntu/Debian |

### 🛠️ Installation

```bash
# Method 1: Standalone 1-liner (no git clone required)
curl -fsSL https://raw.githubusercontent.com/duynghien/auto/main/crawl4ai/setup.sh | bash

# Method 2: Clone repository
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git
cd auto/crawl4ai
chmod +x setup.sh c4ai.sh
./setup.sh
```

### 📦 Management

Use the helper script (`c4ai` or `crawl4ai` or `./c4ai.sh`):

```bash
c4ai start     # Start Crawl4AI
c4ai stop      # Stop Crawl4AI
c4ai restart   # Restart Crawl4AI
c4ai status    # Container status + health check
c4ai logs      # Follow container logs
c4ai update    # Pull latest image & restart
c4ai test      # Run health/feature tests
c4ai info      # Show all endpoints & MCP tools
c4ai shell     # Open shell in container
c4ai backup    # Archive configurations to ./backups/
c4ai restore <archive.tar.gz> # Restore configurations from archive
c4ai doctor    # Run diagnostic health check
c4ai uninstall # Remove containers and volumes
```

### ⚙️ Configuration

| File | Purpose |
|---|---|
| `.env` | Docker Compose settings (port, memory limits) — auto-adjusted |
| `.llm.env` | LLM API keys — edit to add OpenAI/Anthropic keys |
| `config.yml` | Server config (security, rate limit, browser pool) |

---

## Tiếng Việt

Bộ cài đặt tự động **[Crawl4AI v0.8.0](https://github.com/unclecode/crawl4ai)** — trình thu thập dữ liệu web mã nguồn mở cho LLM.  
Hỗ trợ **macOS**, **Raspberry Pi**, và **Linux VPS**.

### ✨ Tính năng
- **Thu thập thông minh**: Browser pool bất đồng bộ, cache, proxy
- **Đầu ra LLM**: Markdown sạch, tối ưu cho RAG/LLM
- **Trích xuất AI**: Dùng LLM trích xuất dữ liệu có cấu trúc
- **MCP Server**: 7 tools cho AI Agent (Claude, LobeHub...)
- **Media**: Chụp ảnh, xuất PDF
- **Deep Crawl**: Cào sâu đệ quy

### 🛠️ Hướng dẫn cài đặt

```bash
# Cách 1: Cài đặt nhanh 1 dòng lệnh (Standalone không cần clone repo)
curl -fsSL https://raw.githubusercontent.com/duynghien/auto/main/crawl4ai/setup.sh | bash

# Cách 2: Clone repository
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git
cd auto/crawl4ai
chmod +x setup.sh c4ai.sh
./setup.sh
```

### 📦 Quản lý nhanh với CLI `c4ai`

```bash
c4ai start     # Khởi động
c4ai stop      # Dừng
c4ai restart   # Khởi động lại
c4ai status    # Kiểm tra trạng thái và sức khỏe
c4ai logs      # Xem logs
c4ai test      # Kiểm tra sức khỏe & chạy thử crawl
c4ai info      # Hiện tất cả endpoints & MCP tools
c4ai update    # Cập nhật phiên bản mới
c4ai backup    # Sao lưu file cấu hình vào ./backups/
c4ai restore <file.tar.gz> # Khôi phục file cấu hình
c4ai doctor    # Kiểm tra chẩn đoán hệ thống
c4ai uninstall # Xóa containers và volumes
```

### 🗺️ Địa chỉ truy cập

- **API**: `http://localhost:11235`
- **Dashboard**: `http://localhost:11235/dashboard`
- **MCP SSE**: `http://localhost:11235/mcp/sse`

---

## 🤝 Support & Community

- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
- **Crawl4AI**: [github.com/unclecode/crawl4ai](https://github.com/unclecode/crawl4ai)
