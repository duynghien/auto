# PostHog Self-Hosted — Unified Setup / Cài đặt Tự động

> 🇺🇸 **English** | 🇻🇳 **Tiếng Việt** — scroll down for Vietnamese / cuộn xuống để đọc Tiếng Việt

---

## 🇺🇸 English

Automated script to deploy **PostHog hobby** with Docker Compose, aligned with this repo's setup format.

### Supported Platforms

- **macOS** (Apple Silicon / Intel, **OrbStack-first**)
- **Raspberry Pi** (ARM64)
- **Linux VPS** (AMD64 / ARM64)

### What the script does

1. Detects platform and checks system requirements
2. Auto-installs Docker + Compose on Linux (if missing, distro-aware)
3. Supports **bilingual UI** (English / Vietnamese)
4. Supports access modes: localhost, LAN, domain (behind reverse proxy)
5. Downloads/refreshes official [PostHog](https://github.com/PostHog/posthog) source snapshot
6. Generates secure `.env` secrets
7. Uses official `docker-compose.hobby.yml` + override for portable networking
8. Starts services and checks health
9. Creates helper script `hog.sh`
10. Applies a preflight patch so **Queue · Kafka** and **Background jobs · Celery** checks reflect runtime health on self-hosted installs

### Quick Install

```bash
mkdir -p ~/self-hosted/posthog && cd ~/self-hosted/posthog
curl -O https://raw.githubusercontent.com/duynghien/auto/main/posthog/setup.sh
chmod +x setup.sh
./setup.sh
```

### Requirements

- Recommended RAM: **8GB+**
- Free disk: **15GB+**
- Docker daemon running (macOS)

### Management

```bash
./hog.sh start        # Start default hobby stack (alias: ./posthog.sh)
./hog.sh start-full   # Start with optional profiles (temporal + exceptions)
./hog.sh stop         # Stop all services
./hog.sh restart      # Restart services with preflight patches
./hog.sh status       # Show container status
./hog.sh logs [svc]   # Follow service logs (default: web)
./hog.sh health       # Check /_health endpoint
./hog.sh backup       # Backup PostgreSQL database (service db) & .env (chmod 600)
./hog.sh restore <f>  # Safe restore PostgreSQL with safety pre-dump
./hog.sh doctor       # Diagnostics: containers, ports, db, clickhouse, disk
./hog.sh upgrade      # Pull latest source & update containers (alias: update)
./hog.sh uninstall    # Clean uninstall (keep data or full purge)
./hog.sh reset        # Delete all local data volumes
```

### Notes

- Config/secrets are stored in `~/self-hosted/posthog/.env`
- Hobby deployment is suitable for small workloads
- `start` runs core services by default; use `start-full` for Temporal/Exceptions profiles
- For production domain, place a reverse proxy (Caddy/Nginx/Traefik) in front
- Slow/unstable registry network: tune retries via `POSTHOG_START_RETRIES` and `POSTHOG_PULL_PARALLEL_LIMIT`
- On macOS, script auto-installs/starts OrbStack when Docker daemon is unavailable
- On Linux, script supports `apt`, `dnf`, `yum`, `pacman`, and `zypper` for Compose/dependencies
- In `Domain` mode, script asks for your Cloudflare Tunnel Docker network (default: `public_network`) and auto-attaches `proxy` to that external network
- Script auto-patches PostHog preflight checks (`views.py` + `utils.py`) during install and `./hog.sh upgrade`
- Installer keeps startup production-safe: `compose/start` always runs `./bin/migrate` before `./bin/docker-server`
- Kafka preflight patch supports both `KAFKA_HOSTS` string and list/tuple formats

Support: <https://ai.vnrom.net>

---

## 🇻🇳 Tiếng Việt

Script tự động triển khai **PostHog hobby** bằng Docker Compose, đồng bộ format với các script khác trong repo.

### Nền tảng hỗ trợ

- **macOS** (Apple Silicon / Intel, **ưu tiên OrbStack**)
- **Raspberry Pi** (ARM64)
- **VPS Linux** (AMD64 / ARM64)

### Script sẽ làm gì

1. Nhận diện nền tảng và kiểm tra tài nguyên
2. Tự cài Docker + Compose trên Linux (nếu thiếu, có fallback theo distro)
3. Hỗ trợ **song ngữ** (English / Tiếng Việt)
4. Hỗ trợ mode truy cập: localhost, LAN, domain (qua reverse proxy)
5. Tải/cập nhật source snapshot chính thức của [PostHog](https://github.com/PostHog/posthog)
6. Tạo `.env` với secrets bảo mật
7. Dùng `docker-compose.hobby.yml` chính thức + file override để chạy linh hoạt
8. Khởi động services và kiểm tra health
9. Tạo script quản lý `hog.sh`
10. Tự vá preflight để check **Queue · Kafka** và **Background jobs · Celery** phản ánh đúng trạng thái runtime trên self-hosted

### Cài nhanh

```bash
mkdir -p ~/self-hosted/posthog && cd ~/self-hosted/posthog
curl -O https://raw.githubusercontent.com/duynghien/auto/main/posthog/setup.sh
chmod +x setup.sh
./setup.sh
```

### Yêu cầu đề xuất

- RAM: **8GB+**
- Trống đĩa: **15GB+**
- Docker daemon đang chạy (macOS)

### Quản lý

```bash
./hog.sh start        # Khởi động hobby stack mặc định (alias: ./posthog.sh)
./hog.sh start-full   # Khởi động kèm profile phụ (temporal + exceptions)
./hog.sh stop         # Dừng toàn bộ services
./hog.sh restart      # Khởi động lại kèm patch preflight
./hog.sh status       # Xem trạng thái containers
./hog.sh logs [svc]   # Xem logs service (mặc định: web)
./hog.sh health       # Kiểm tra endpoint /_health
./hog.sh backup       # Sao lưu PostgreSQL database (service db) & .env vào ./backups
./hog.sh restore <f>  # Khôi phục an toàn database kèm snapshot tự động
./hog.sh doctor       # Chuẩn đoán: containers, cổng, PostgreSQL, ClickHouse, đĩa
./hog.sh upgrade      # Cập nhật mã nguồn & containers (alias: update)
./hog.sh uninstall    # Gỡ cài đặt (giữ data hoặc xóa sạch)
./hog.sh reset        # Xóa toàn bộ volume dữ liệu
```

### Ghi chú

- Cấu hình/secrets nằm ở `~/self-hosted/posthog/.env`
- Bản hobby phù hợp workload nhỏ
- `start` mặc định chạy core services; dùng `start-full` để bật profile Temporal/Exceptions
- Dùng domain production nên đặt reverse proxy (Caddy/Nginx/Traefik)
- Nếu mạng kéo image chậm/không ổn định: chỉnh `POSTHOG_START_RETRIES` và `POSTHOG_PULL_PARALLEL_LIMIT`
- Trên macOS, script sẽ tự cài/chạy OrbStack khi Docker daemon chưa sẵn sàng
- Trên Linux, script hỗ trợ `apt`, `dnf`, `yum`, `pacman`, `zypper` để cài Compose/phụ thuộc
- Ở mode `Domain`, script sẽ hỏi tên Docker network của Cloudflare Tunnel (mặc định: `public_network`) và tự nối service `proxy` vào external network đó
- Script tự vá preflight (`views.py` + `utils.py`) khi cài đặt và khi chạy `./hog.sh upgrade`
- Trình cài đặt giữ startup theo hướng production-safe: `compose/start` luôn chạy `./bin/migrate` trước `./bin/docker-server`
- Patch Kafka preflight hỗ trợ cả `KAFKA_HOSTS` dạng chuỗi và dạng list/tuple

Hỗ trợ: <https://ai.vnrom.net>
