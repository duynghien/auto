# 🧠 Mem0 OpenMemory Self-Hosted Stack

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

**Self-hosted [Mem0 OpenMemory](https://github.com/mem0ai/mem0)** — Your AI second brain: private, portable, and open-source.  
A persistent memory layer for LLM agents with MCP + REST API.  
Automated setup for **macOS (Apple Silicon)**, **Raspberry Pi**, and **Linux VPS**.

### ✨ Features

| Feature | Description |
|---|---|
| 🧠 **AI Memory API** | Store and search memories for LLM agents |
| 🔌 **Built-in MCP Server** | Connect Claude Desktop, Cursor, LobeHub seamlessly |
| 🔍 **Semantic Search** | Meaning-based memory search via Qdrant vector DB |
| 🕸️ **Graph Memory** | Entity relationships via Neo4j (auto-extract entities & relations) |
| 📊 **Dashboard UI** | Manage your memories through a web interface |
| 🌍 **Multi-platform** | Support for macOS, Raspberry Pi, Linux VPS |

### 📋 Requirements

| Component | Minimum Requirements |
|---|---|
| **macOS** | Apple Silicon + [OrbStack](https://orbstack.dev/) or Docker Desktop |
| **Linux/Pi** | Ubuntu/Debian, Pi 4 (4GB+) or Pi 5 (64-bit OS) |
| **RAM/Disk** | 2GB+ RAM (4GB+ recommended) / 5GB+ Disk |
| **API Key** | OpenAI API Key (Required for embeddings and extraction) |

### 🛠️ Installation

```bash
# Clone the repository
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git
cd auto/mem0

# Run unified setup (detects OS automatically)
chmod +x setup.sh mem0.sh
./setup.sh
```

> **Note:** The script automatically installs `qdrant-client` + `neo4j` driver, configures graph memory, and seeds config via API.

### 📦 Management

Use the helper script:

```bash
./mem0.sh start    # Start containers
./mem0.sh stop     # Stop containers
./mem0.sh restart  # Restart
./mem0.sh status   # Health check (API + Qdrant + Neo4j + UI + packages)
./mem0.sh logs     # View all logs
./mem0.sh logs openmemory-mcp  # View API logs only
./mem0.sh test     # Smoke test (add memory)
./mem0.sh update   # Pull latest image & rebuild
./mem0.sh purge    # ⚠️ Remove ALL containers + volumes (deletes all data)
```

### 🗺️ Access URLs

| Service | URL |
|---|---|
| API Docs | `http://localhost:8765/docs` |
| Dashboard UI | `http://localhost:3000` |
| Qdrant | `http://localhost:6333` |
| Neo4j Browser | `http://localhost:7474` (user: `neo4j`, pass: `mem0_neo4j_pass`) |

### 🚀 Usage

#### Add Memory
```bash
curl -X POST http://localhost:8765/api/v1/memories/ \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test_user", "text": "I prefer dark mode and use Claude for coding"}'
```
> With Neo4j, mem0 auto-extracts entities: `test_user → prefers → dark mode`, `test_user → uses → Claude`

#### Search Memory
```bash
curl -X POST http://localhost:8765/api/v1/memories/filter \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test_user", "search_query": "dark mode"}'
```

#### MCP Integration
```bash
# Claude Desktop
npx @openmemory/install local http://localhost:8765/mcp/claude/sse/$USER --client claude

# Cursor
npx @openmemory/install local http://localhost:8765/mcp/cursor/sse/$USER --client cursor
```

### ⚙️ Environment Variables

| Variable | File | Purpose |
|---|---|---|
| `OPENAI_API_KEY` | `api/.env` | Used by mem0ai Python library |
| `API_KEY` | `api/.env` | Used by config.json (`env:API_KEY`) |
| `USER` | `api/.env` | User ID for memory association |
| `NEO4J_URI` | `api/.env` | Neo4j connection URI |
| `NEO4J_USERNAME` | `api/.env` | Neo4j username |
| `NEO4J_PASSWORD` | `api/.env` | Neo4j password |

---

## Tiếng Việt

Bộ cài đặt tự động **[Mem0 OpenMemory](https://github.com/mem0ai/mem0)** — Bộ não thứ hai cho AI của bạn: riêng tư, linh hoạt và mã nguồn mở.  
Lớp bộ nhớ bền vĩnh viễn cho LLM agents tích hợp MCP + REST API.  
Hỗ trợ cài đặt tự động trên **macOS (Apple Silicon)**, **Raspberry Pi**, và **Linux VPS**.

### ✨ Tính năng

| Tính năng | Mô tả |
|---|---|
| 🧠 **AI Memory API** | Lưu trữ và tìm kiếm bộ nhớ cho LLM agents |
| 🔌 **MCP Server** | Kết nối trực tiếp Claude Desktop, Cursor, LobeHub |
| 🔍 **Semantic Search** | Tìm kiếm theo ngữ nghĩa qua Qdrant vector DB |
| 🕸️ **Graph Memory** | Trích xuất thực thể và mối quan hệ tự động qua Neo4j |
| 📊 **Dashboard UI** | Giao diện web quản lý dữ liệu bộ nhớ |
| 🌍 **Đa nền tảng** | Hỗ trợ tối ưu cho macOS, Raspberry Pi, Linux VPS |

### 📋 Yêu cầu hệ thống

| Thành phần | Yêu cầu tối thiểu |
|---|---|
| **macOS** | Apple Silicon + [OrbStack](https://orbstack.dev/) hoặc Docker Desktop |
| **Linux/Pi** | Ubuntu/Debian, Pi 4 (4GB+) hoặc Pi 5 (HĐH 64-bit) |
| **RAM/Ổ cứng** | RAM 2GB+ (khuyên dùng 4GB+) / Disk 5GB+ |
| **API Key** | OpenAI API Key (Bắt buộc để nhúng và trích xuất dữ liệu) |

### 🛠️ Hướng dẫn cài đặt

```bash
# Tải mã nguồn
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git
cd auto/mem0

# Chạy script cài đặt (tự nhận diện OS)
chmod +x setup.sh mem0.sh
./setup.sh
```

> **Lưu ý:** Script sẽ tự động cài `qdrant-client` + `neo4j` driver, cấu hình graph memory và seed config thông qua API.

### 📦 Quản lý

Sử dụng script hỗ trợ sau:

```bash
./mem0.sh start    # Khởi động dịch vụ
./mem0.sh stop     # Dừng dịch vụ
./mem0.sh restart  # Khởi động lại
./mem0.sh status   # Kiểm tra sức khỏe (API + Qdrant + Neo4j + UI + packages)
./mem0.sh logs     # Xem toàn bộ logs
./mem0.sh logs openmemory-mcp  # Xem log của API
./mem0.sh test     # Chạy test cơ bản (thêm memory)
./mem0.sh update   # Cập nhật image mới nhất & khởi tạo lại
./mem0.sh purge    # ⚠️ Xóa TOÀN BỘ container + volumes (xóa mọi dữ liệu)
```

### 🗺️ Địa chỉ truy cập

| Dịch vụ | Địa chỉ URL |
|---|---|
| API Docs | `http://localhost:8765/docs` |
| Dashboard UI | `http://localhost:3000` |
| Qdrant | `http://localhost:6333` |
| Neo4j Browser | `http://localhost:7474` (user: `neo4j`, pass: `mem0_neo4j_pass`) |

### 🚀 Cách sử dụng

#### Thêm Memory
```bash
curl -X POST http://localhost:8765/api/v1/memories/ \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test_user", "text": "Tôi thích dùng dark mode và dùng Claude để viết code"}'
```
> Nhờ có Neo4j, mem0 sẽ tự động trích xuất các thực thể: `test_user → thích → dark mode`, `test_user → dùng → Claude`

#### Tìm kiếm Memory
```bash
curl -X POST http://localhost:8765/api/v1/memories/filter \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test_user", "search_query": "dark mode"}'
```

#### Tích hợp MCP
```bash
# Cho Claude Desktop
npx @openmemory/install local http://localhost:8765/mcp/claude/sse/$USER --client claude

# Cho Cursor
npx @openmemory/install local http://localhost:8765/mcp/cursor/sse/$USER --client cursor
```

### ⚙️ Các biến môi trường

| Biến số | Tập tin | Mục đích |
|---|---|---|
| `OPENAI_API_KEY` | `api/.env` | Dùng cho thư viện Python mem0ai |
| `API_KEY` | `api/.env` | Dùng cho config.json (`env:API_KEY`) |
| `USER` | `api/.env` | User ID để gắn liên kết bộ nhớ |
| `NEO4J_URI` | `api/.env` | Địa chỉ kết nối Neo4j |
| `NEO4J_USERNAME` | `api/.env` | Tài khoản Neo4j |
| `NEO4J_PASSWORD` | `api/.env` | Mật khẩu Neo4j |

---

## 🤝 Support & Community

- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
- **Mem0**: [github.com/mem0ai/mem0](https://github.com/mem0ai/mem0)
