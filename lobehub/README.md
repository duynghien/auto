# LobeHub Self-Hosted — Unified Setup / Cài đặt Tự động

> 🇺🇸 **English** | 🇻🇳 **Tiếng Việt** — scroll down for Vietnamese / cuộn xuống để đọc Tiếng Việt

---

## 🇺🇸 English

One-script installer for LobeHub with all features enabled. Auto-detects your platform:

| Platform | Arch | PostgreSQL | Memory Limits |
|---|---|---|---|
| **macOS** (Apple Silicon) | arm64 | ParadeDB (pg17) | None |
| **Raspberry Pi** (4/5) | aarch64 | pgvector (pg16) | Yes |
| **VPS — ARM64** | aarch64 | ParadeDB (pg17) | None |
| **VPS — AMD64** | x86_64 | ParadeDB (pg17) | None |

### Stack

| Component | Purpose |
|---|---|
| **LobeHub** | AI chat frontend & backend |
| **PostgreSQL** | Database (with pgvector for Knowledge Base) |
| **Redis** | Queue & caching |
| **SearXNG** | Self-hosted search engine (online search) |
| **RustFS / MinIO** | S3-compatible object storage (uploads) |

### Quick Install

```bash
# Create directory and download script
mkdir -p ~/self-hosted/lobehub && cd ~/self-hosted/lobehub
curl -O https://raw.githubusercontent.com/duynghien/auto/main/lobehub/setup.sh

# Run setup
chmod +x setup.sh
./setup.sh
```

The script will:
1. Detect your OS and architecture
2. Check dependencies (Docker, openssl, python3, curl)
3. Install Docker if needed (Linux only)
4. Configure swap for Pi (if needed)
5. Generate secrets and JWKS keys
6. Let you choose S3 storage (RustFS or MinIO)
7. Create optimized docker-compose.yml
8. Start all services and verify health
9. Create `lobe.sh` helper script

### Features Enabled

- ✅ **Knowledge Base** — pgvector + full-text search
- ✅ **Online Search** — SearXNG (self-hosted, no API keys)
- ✅ **File Upload** — S3-compatible storage with proxy
- ✅ **Image Vision** — LLM reads uploaded images
- ✅ **Artifacts** — SVG, HTML, code rendering
- ✅ **Memory** — Server-side chat history in PostgreSQL
- ✅ **Web Crawling** — Naive crawler for URL content
- ✅ **Auth** — Email/password via Better Auth

### Management

After installation, use the `lobe.sh` (or `lobehub.sh`) helper:

```bash
./lobe.sh start        # Start all services
./lobe.sh stop         # Stop all services
./lobe.sh restart      # Restart all services
./lobe.sh upgrade      # Pull latest images & restart (alias: update)
./lobe.sh logs [svc]   # View logs (default: lobe)
./lobe.sh status       # Show container status
./lobe.sh backup       # Safe PostgreSQL & .env backup to ./backups (chmod 600)
./lobe.sh restore <f>  # Safe PostgreSQL restore with pre-restore backup
./lobe.sh doctor       # Diagnostics: containers, ports, database, S3 endpoint
./lobe.sh search-test  # Test SearXNG search
./lobe.sh s3-test      # Test S3 upload endpoint reachability
./lobe.sh secrets      # Show .env file
./lobe.sh s3-login     # Show S3 credentials
./lobe.sh uninstall    # Clean uninstall (keep data or full purge)
./lobe.sh reset        # ⚠️ Delete all data
```

### Configuration

All settings are stored in `~/self-hosted/lobehub/.env`:

```bash
# Add your AI API keys:
OPENAI_API_KEY=sk-xxx
ANTHROPIC_API_KEY=sk-ant-xxx
GOOGLE_API_KEY=xxx

# Use local Ollama:
OLLAMA_PROXY_URL=http://host.docker.internal:11434
```

After editing `.env`, restart:
```bash
./lobe.sh restart
```

### Platform Notes

#### macOS
- Requires [OrbStack](https://orbstack.dev) or Docker Desktop pre-installed
- Default: localhost only (option to enable LAN access)

#### Raspberry Pi
- Requires 4GB+ RAM (8GB recommended)
- Auto-configures 2GB swap
- Auto-installs Docker if missing
- Memory limits applied to all containers
- Default: LAN mode (accessible from other devices)

#### VPS (ARM64 / AMD64)
- Auto-installs Docker if missing
- Default: LAN mode
- Use a reverse proxy (Caddy/Nginx) for HTTPS in production

---

## 🇻🇳 Tiếng Việt

Script cài đặt LobeHub tự động với đầy đủ tính năng. Tự nhận diện nền tảng:

| Nền tảng | Kiến trúc | PostgreSQL | Giới hạn RAM |
|---|---|---|---|
| **macOS** (Apple Silicon) | arm64 | ParadeDB (pg17) | Không |
| **Raspberry Pi** (4/5) | aarch64 | pgvector (pg16) | Có |
| **VPS — ARM64** | aarch64 | ParadeDB (pg17) | Không |
| **VPS — AMD64** | x86_64 | ParadeDB (pg17) | Không |

### Thành phần

| Thành phần | Mục đích |
|---|---|
| **LobeHub** | Giao diện chat AI & backend |
| **PostgreSQL** | Cơ sở dữ liệu (pgvector cho Knowledge Base) |
| **Redis** | Hàng đợi & caching |
| **SearXNG** | Công cụ tìm kiếm tự lưu trữ |
| **RustFS / MinIO** | Lưu trữ S3 (upload file) |

### Cài đặt nhanh

```bash
# Tạo thư mục và tải script
mkdir -p ~/self-hosted/lobehub && cd ~/self-hosted/lobehub
curl -O https://raw.githubusercontent.com/duynghien/auto/main/lobehub/setup.sh

# Chạy script
chmod +x setup.sh
./setup.sh
```

Script sẽ:
1. Nhận diện hệ điều hành và kiến trúc
2. Kiểm tra dependencies (Docker, openssl, python3, curl)
3. Cài Docker nếu cần (chỉ Linux)
4. Cấu hình swap cho Pi (nếu cần)
5. Sinh secrets và JWKS keys
6. Cho chọn S3 storage (RustFS hoặc MinIO)
7. Tạo docker-compose.yml tối ưu cho nền tảng
8. Khởi động và kiểm tra tất cả services
9. Tạo script quản lý `lobe.sh`

### Tính năng đã bật

- ✅ **Knowledge Base** — pgvector + tìm kiếm toàn văn
- ✅ **Online Search** — SearXNG (tự lưu trữ, không cần API key)
- ✅ **Upload File** — Lưu trữ S3 với proxy
- ✅ **Image Vision** — LLM đọc ảnh upload
- ✅ **Artifacts** — SVG, HTML, code rendering
- ✅ **Memory** — Lịch sử chat lưu trong PostgreSQL
- ✅ **Web Crawling** — Crawler đọc nội dung URL
- ✅ **Auth** — Email/password qua Better Auth

### Quản lý

Sau khi cài đặt, sử dụng script `lobe.sh` (hoặc `lobehub.sh`):

```bash
./lobe.sh start        # Khởi động tất cả services
./lobe.sh stop         # Dừng tất cả services
./lobe.sh restart      # Khởi động lại
./lobe.sh upgrade      # Cập nhật images mới nhất (alias: update)
./lobe.sh logs [svc]   # Xem logs (mặc định: lobe)
./lobe.sh status       # Xem trạng thái containers
./lobe.sh backup       # Sao lưu an toàn PostgreSQL & .env vào ./backups
./lobe.sh restore <f>  # Khôi phục an toàn database kèm snapshot tự động
./lobe.sh doctor       # Kiểm tra chuẩn đoán: containers, cổng, database, S3
./lobe.sh search-test  # Test tìm kiếm SearXNG
./lobe.sh s3-test      # Test kết nối upload S3
./lobe.sh secrets      # Xem file .env
./lobe.sh s3-login     # Xem thông tin S3
./lobe.sh uninstall    # Gỡ cài đặt (giữ data hoặc xóa sạch)
./lobe.sh reset        # ⚠️ Xóa toàn bộ dữ liệu
```

### Cấu hình

Tất cả cài đặt lưu trong `~/self-hosted/lobehub/.env`:

```bash
# Thêm API key AI:
OPENAI_API_KEY=sk-xxx
ANTHROPIC_API_KEY=sk-ant-xxx
GOOGLE_API_KEY=xxx

# Dùng Ollama local:
OLLAMA_PROXY_URL=http://host.docker.internal:11434
```

Sau khi sửa `.env`, restart để áp dụng:
```bash
./lobe.sh restart
```

### Lưu ý theo nền tảng

#### macOS
- Yêu cầu cài sẵn [OrbStack](https://orbstack.dev) hoặc Docker Desktop
- Mặc định: chỉ truy cập localhost (có tùy chọn bật LAN)

#### Raspberry Pi
- Yêu cầu 4GB+ RAM (khuyến nghị 8GB)
- Tự cấu hình swap 2GB
- Tự cài Docker nếu chưa có
- Giới hạn RAM cho tất cả containers
- Mặc định: chế độ LAN (truy cập từ thiết bị khác)

#### VPS (ARM64 / AMD64)
- Tự cài Docker nếu chưa có
- Mặc định: chế độ LAN
- Nên dùng reverse proxy (Caddy/Nginx) cho HTTPS trên production

---

## Support

- GitHub: https://github.com/duynghien/auto
- Website: https://ai.vnrom.net
