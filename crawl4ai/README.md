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
# Clone the repository
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git
cd auto/crawl4ai

# Run unified setup (detects OS automatically)
chmod +x setup.sh c4ai.sh
./setup.sh
```

The script will:
1. Detect OS and architecture
2. Install Docker & dependencies (Linux only)
3. Configure Swap & Memory limits (Linux only)
4. Configre LLM API keys (optional)
5. Deploy container and set up auto-start service (Linux)

### 📦 Management

Use the helper script:

```bash
./c4ai.sh start     # Start Crawl4AI
./c4ai.sh stop      # Stop Crawl4AI
./c4ai.sh restart   # Restart Crawl4AI
./c4ai.sh status    # Container status + health check
./c4ai.sh logs      # Follow container logs
./c4ai.sh update    # Pull latest image & restart
./c4ai.sh test      # Run health/feature tests
./c4ai.sh info      # Show all endpoints & MCP tools
./c4ai.sh shell     # Open shell in container
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
# Tải mã nguồn
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git
cd auto/crawl4ai

# Chạy script cài đặt (tự nhận diện OS)
chmod +x setup.sh c4ai.sh
./setup.sh
```

Script sẽ tự động:
1. Nhận diện hệ điều hành
2. Cài Docker và dependencies (nếu là Linux/Pi)
3. Cấu hình Swap và giới hạn RAM (nếu RAM thấp)
4. Thiết lập dịch vụ tự khởi động (systemd)

### 📦 Quản lý

```bash
./c4ai.sh start     # Khởi động
./c4ai.sh stop      # Dừng
./c4ai.sh restart   # Khởi động lại
./c4ai.sh logs      # Xem logs
./c4ai.sh test      # Kiểm tra sức khỏe
./c4ai.sh info      # Hiện tất cả endpoints
./c4ai.sh update    # Cập nhật phiên bản mới
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
