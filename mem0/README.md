# Mem0 OpenMemory — Self-hosted AI Memory Layer

> 🧠 Your AI second brain — private, portable, open-source.
> Persistent memory layer for LLM agents with MCP + REST API.

## Highlights

- **AI Memory API** — lưu trữ và tìm kiếm memory cho LLM agents
- **MCP Server tích hợp** — kết nối Claude Desktop, Cursor, LobeHub
- **Semantic Search** — tìm memory theo ngữ nghĩa qua Qdrant vector DB
- **Dashboard UI** — quản lý memories qua giao diện web
- **Multi-platform** — macOS, Raspberry Pi, Linux VPS

## Requirements

| Component | Minimum |
|---|---|
| Docker / OrbStack | ✅ Required |
| RAM | 2GB+ |
| Disk | 5GB+ |
| OpenAI API Key | ✅ Required |

## Installation / Cài đặt

```bash
mkdir -p ~/self-hosted && cd ~/self-hosted
git clone https://github.com/duynghien/auto.git && cd auto/mem0
chmod +x setup.sh mem0.sh && ./setup.sh
```

## Usage / Sử dụng

### Add Memory
```bash
curl -X POST http://localhost:8765/api/v1/memories/ \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test_user", "text": "I prefer dark mode"}'
```

### Search Memory
```bash
curl -X POST http://localhost:8765/api/v1/memories/filter \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test_user", "search_query": "dark mode"}'
```

### MCP Integration
```bash
# Claude Desktop
npx @openmemory/install local http://localhost:8765/mcp/claude/sse/$USER --client claude

# Cursor
npx @openmemory/install local http://localhost:8765/mcp/cursor/sse/$USER --client cursor
```

## Access URLs

| Service | URL |
|---|---|
| API Docs | http://localhost:8765/docs |
| Dashboard UI | http://localhost:3000 |
| Qdrant | http://localhost:6333 |

## Management / Quản lý

```bash
./mem0.sh start    # Start containers
./mem0.sh stop     # Stop containers
./mem0.sh restart  # Restart
./mem0.sh status   # Health check
./mem0.sh logs     # View logs
./mem0.sh test     # Smoke test
./mem0.sh update   # Pull & rebuild
```

## License

Apache-2.0 — [mem0ai/mem0](https://github.com/mem0ai/mem0)

---

Script by **vnROM.net** • Support: https://ai.vnrom.net
