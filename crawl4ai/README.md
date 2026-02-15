# 🕷️ Crawl4AI Self-Hosted Stack

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

**Self-hosted [Crawl4AI v0.8.0](https://github.com/unclecode/crawl4ai)** — the most-starred open-source LLM-friendly web crawler on GitHub.  
Automated setup for **macOS (Apple Silicon + OrbStack)** and **Raspberry Pi (ARM64)**.

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
| 🪝 **Hooks API** | 8 hook points for custom crawling pipeline |
| 📡 **Webhooks** | Job queue with webhook notifications |
| 🌊 **WebSocket** | Real-time streaming results |
| 📈 **Prometheus** | Metrics endpoint for monitoring |
| 🔒 **Security** | JWT auth, rate limiting, bot detection evasion |

---

### 🤖 MCP Server

#### Tools (7 built-in)

| Tool | Description |
|---|---|
| `md` | Convert any URL to clean, LLM-ready Markdown (supports raw/fit/bm25/llm filters) |
| `html` | Extract preprocessed, sanitized HTML for schema building |
| `screenshot` | Capture full-page PNG screenshots of any URL |
| `pdf` | Generate PDF documents from web pages |
| `execute_js` | Run JavaScript snippets on pages and get results |
| `crawl` | Multi-URL batch crawling with browser/crawler configs |
| `ask` | Query Crawl4AI library docs/code for AI assistant context |

#### Transport Protocols

The MCP server supports **3 transport protocols** for maximum compatibility with different AI agents:

| Protocol | Endpoint | Best For |
|---|---|---|
| **SSE** (Server-Sent Events) | `/mcp/sse` | Claude Desktop, Claude Code, Antigravity, most MCP clients |
| **Streamable HTTP** | `/mcp/streamable` | LobeHub, agents requiring POST-based JSON-RPC |
| **WebSocket** | `/mcp/ws` | Real-time bidirectional communication |

Additional endpoints:
- **Schema**: `/mcp/schema` — JSON schema of all available tools

#### AI Agent Integration

<details>
<summary><b>🟣 Claude Desktop</b></summary>

Add to `~/.claude/claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "crawl4ai": {
      "transport": "sse",
      "url": "http://localhost:11235/mcp/sse"
    }
  }
}
```
</details>

<details>
<summary><b>🟣 Claude Code (CLI)</b></summary>

```bash
claude mcp add --transport sse crawl4ai http://localhost:11235/mcp/sse
```
</details>

<details>
<summary><b>🔵 LobeHub</b></summary>

1. Go to **Settings → MCP Plugins → Add Custom Plugin**
2. Set **Transport**: `Streamable HTTP`
3. Set **URL**: `http://<your-ip>:11235/mcp/streamable`
4. Save — all 7 tools will be discovered automatically
</details>

<details>
<summary><b>🟢 Antigravity</b></summary>

Add to `.agent/mcp.json`:
```json
{
  "mcpServers": {
    "crawl4ai": {
      "transport": "sse",
      "url": "http://localhost:11235/mcp/sse"
    }
  }
}
```
</details>

<details>
<summary><b>🔴 OpenClaw / n8n</b></summary>

Use SSE transport:
- **URL**: `http://<your-ip>:11235/mcp/sse`
- **Transport**: SSE
</details>

<details>
<summary><b>🟡 Other MCP Clients</b></summary>

Any MCP-compatible client can connect via:
- **SSE**: `http://<host>:11235/mcp/sse` (most common)
- **Streamable HTTP**: `http://<host>:11235/mcp/streamable` (POST JSON-RPC)
- **WebSocket**: `ws://<host>:11235/mcp/ws`
</details>

---

### 📋 Requirements

| Platform | Requirements |
|---|---|
| **macOS** | Apple Silicon (M1/M2/M3/M4) + [OrbStack](https://orbstack.dev/) or Docker Desktop |
| **Raspberry Pi** | Pi 4 (4GB+) or Pi 5 + Raspberry Pi OS 64-bit |

### 🛠️ Installation

```bash
# Clone the repository
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git
cd auto/crawl4ai

# macOS
chmod +x setup.sh c4ai.sh
./setup.sh

# Raspberry Pi
sudo chmod +x install-pi.sh c4ai.sh
sudo ./install-pi.sh
```

The setup script will:
1. Check prerequisites (Docker, architecture)
2. Let you choose between **Pull Image** (recommended) or **Build from Source**
3. Configure LLM API keys (optional — can add later)
4. Deploy the container with all features
5. Run health checks and show all endpoints

### 🗺️ All Endpoints

| Endpoint | URL |
|---|---|
| API | `http://localhost:11235` |
| Dashboard | `http://localhost:11235/dashboard` |
| Playground | `http://localhost:11235/playground` |
| Health | `http://localhost:11235/health` |
| Metrics | `http://localhost:11235/metrics` |
| MCP SSE | `http://localhost:11235/mcp/sse` |
| MCP Streamable HTTP | `http://localhost:11235/mcp/streamable` |
| MCP WebSocket | `ws://localhost:11235/mcp/ws` |
| MCP Schema | `http://localhost:11235/mcp/schema` |

### 📦 Management

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
| `.env` | Docker Compose settings — created from `.env.example` (port, memory, build type) |
| `.llm.env` | LLM API keys — created from `.llm.env.example` (gitignored) |
| `config.yml` | Server config (security, rate limit, logging, browser pool) |
| `docker-entrypoint.sh` | Auto-patches on startup (LLM provider, MCP transport) |

#### LLM Configuration

Edit `.llm.env` to configure your LLM provider:

```bash
# Use OpenAI
LLM_PROVIDER=openai/gpt-4o-mini
OPENAI_API_KEY=sk-...

# Use Anthropic
LLM_PROVIDER=anthropic/claude-3-haiku
ANTHROPIC_API_KEY=sk-ant-...

# Use self-hosted (Ollama, vLLM, CLIProxy)
LLM_PROVIDER=openai/your-model
OPENAI_API_BASE=http://host.docker.internal:8317/v1
OPENAI_API_KEY=your-key
```

After editing, restart the container:
```bash
./c4ai.sh restart
```

### 📁 Project Structure

```
crawl4ai/
├── setup.sh                # macOS setup script
├── install-pi.sh           # Raspberry Pi setup script
├── c4ai.sh                 # Management helper
├── docker-compose.yml      # Docker Compose config
├── docker-entrypoint.sh    # Auto-patch entrypoint (LLM + MCP)
├── config.yml              # Server configuration
├── .env.example            # Docker Compose variables template
├── .llm.env.example        # LLM API keys template
└── .gitignore              # Ignores .env, .llm.env, debug files
```

---

## Tiếng Việt

Bộ cài đặt tự động **[Crawl4AI v0.8.0](https://github.com/unclecode/crawl4ai)** — trình thu thập dữ liệu web mã nguồn mở cho LLM, được star nhiều nhất trên GitHub.  
Hỗ trợ **macOS (Apple Silicon + OrbStack)** và **Raspberry Pi (ARM64)**.

### ✨ Tính năng

| Tính năng | Mô tả |
|---|---|
| 🕷️ **Thu thập thông minh** | Browser pool bất đồng bộ, cache, quản lý session, proxy |
| 📝 **Đầu ra cho LLM** | Markdown sạch với tiêu đề, bảng, code, trích dẫn |
| 🤖 **Trích xuất AI** | Dùng LLM để trích xuất dữ liệu có cấu trúc (hỗ trợ tất cả providers) |
| 📊 **Bảng điều khiển** | Giám sát realtime với metrics hệ thống & browser pool |
| 🎮 **Playground** | Giao diện web test & tạo code crawl |
| 🔌 **MCP Server** | 7 tools cho AI Agent — hỗ trợ SSE, Streamable HTTP, WebSocket |
| 📸 **Media** | Chụp ảnh, xuất PDF, trích xuất hình ảnh/video |
| 🔄 **Deep Crawl** | BFS/DFS/Best-First với khôi phục & tiếp tục khi crash |
| ⚡ **Chế độ Prefetch** | Khám phá URL nhanh hơn 5-10 lần |

### � MCP Server

#### Giao thức kết nối

| Giao thức | Endpoint | Dùng cho |
|---|---|---|
| **SSE** | `/mcp/sse` | Claude Desktop, Claude Code, Antigravity |
| **Streamable HTTP** | `/mcp/streamable` | LobeHub (dùng POST JSON-RPC) |
| **WebSocket** | `/mcp/ws` | Giao tiếp hai chiều realtime |

#### Kết nối AI Agent

```bash
# Claude Desktop/Code
claude mcp add --transport sse crawl4ai http://localhost:11235/mcp/sse

# LobeHub → Settings → MCP Plugins
# Transport: Streamable HTTP
# URL: http://<ip>:11235/mcp/streamable

# Antigravity / OpenClaw
# SSE URL: http://localhost:11235/mcp/sse
```

### 🛠️ Hướng dẫn cài đặt

```bash
# Tải mã nguồn
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git
cd auto/crawl4ai

# macOS
chmod +x setup.sh c4ai.sh
./setup.sh

# Raspberry Pi
sudo chmod +x install-pi.sh c4ai.sh
sudo ./install-pi.sh
```

### 📦 Quản lý

```bash
./c4ai.sh start     # Khởi động
./c4ai.sh stop      # Dừng
./c4ai.sh restart   # Khởi động lại
./c4ai.sh logs      # Xem logs
./c4ai.sh test      # Kiểm tra sức khỏe
./c4ai.sh info      # Hiện tất cả endpoints + MCP tools
./c4ai.sh update    # Cập nhật phiên bản mới
```

### ⚙️ Cấu hình

| File | Chức năng |
|---|---|
| `.env` | Cài đặt Docker Compose — tạo từ `.env.example` (port, bộ nhớ, kiểu build) |
| `.llm.env` | API keys cho LLM — tạo từ `.llm.env.example` (gitignored) |
| `config.yml` | Cấu hình server (bảo mật, giới hạn, logging) |
| `docker-entrypoint.sh` | Tự động patch khi khởi động (LLM provider, MCP transport) |

---

## 🤝 Support & Community

- **Website**: [vnrom.net](https://vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
- **Crawl4AI**: [github.com/unclecode/crawl4ai](https://github.com/unclecode/crawl4ai)

## 📄 License

This setup automation is provided as-is under the MIT License.  
Crawl4AI itself is licensed under [Apache 2.0](https://github.com/unclecode/crawl4ai/blob/main/LICENSE).
