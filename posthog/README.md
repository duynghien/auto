# PostHog Self-Hosted — Unified Setup / Cài đặt Tự động

> 🇺🇸 **English** | 🇻🇳 **Tiếng Việt** — scroll down for Vietnamese / cuộn xuống để đọc Tiếng Việt

---

## 🇺🇸 English

Automated script to deploy **PostHog hobby** with Docker Compose, aligned with this repo's setup format.

### Supported Platforms

- **macOS** (Apple Silicon / Intel)
- **Raspberry Pi** (ARM64)
- **Linux VPS** (AMD64 / ARM64)

### What the script does

1. Detects platform and checks system requirements
2. Auto-installs Docker + Compose on Linux (if missing)
3. Supports **bilingual UI** (English / Vietnamese)
4. Supports access modes: localhost, LAN, domain (behind reverse proxy)
5. Downloads/refreshes official [PostHog](https://github.com/PostHog/posthog) source snapshot
6. Generates secure `.env` secrets
7. Uses official `docker-compose.hobby.yml` + override for portable networking
8. Starts services and checks health
9. Creates helper script `hog.sh`

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
./hog.sh start
./hog.sh start-full
./hog.sh stop
./hog.sh restart
./hog.sh status
./hog.sh logs web
./hog.sh health
./hog.sh upgrade
./hog.sh reset
```

### Notes

- Config/secrets are stored in `~/self-hosted/posthog/.env`
- Hobby deployment is suitable for small workloads
- `start` runs core services by default; use `start-full` for Temporal/Exceptions profiles
- For production domain, place a reverse proxy (Caddy/Nginx/Traefik) in front
- Slow/unstable registry network: tune retries via `POSTHOG_START_RETRIES` and `POSTHOG_PULL_PARALLEL_LIMIT`

Support: <https://ai.vnrom.net>

---

## 🇻🇳 Tiếng Việt

Script tự động triển khai **PostHog hobby** bằng Docker Compose, đồng bộ format với các script khác trong repo.

### Nền tảng hỗ trợ

- **macOS** (Apple Silicon / Intel)
- **Raspberry Pi** (ARM64)
- **VPS Linux** (AMD64 / ARM64)

### Script sẽ làm gì

1. Nhận diện nền tảng và kiểm tra tài nguyên
2. Tự cài Docker + Compose trên Linux (nếu thiếu)
3. Hỗ trợ **song ngữ** (English / Tiếng Việt)
4. Hỗ trợ mode truy cập: localhost, LAN, domain (qua reverse proxy)
5. Tải/cập nhật source snapshot chính thức của [PostHog](https://github.com/PostHog/posthog)
6. Tạo `.env` với secrets bảo mật
7. Dùng `docker-compose.hobby.yml` chính thức + file override để chạy linh hoạt
8. Khởi động services và kiểm tra health
9. Tạo script quản lý `hog.sh`

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
./hog.sh start
./hog.sh start-full
./hog.sh stop
./hog.sh restart
./hog.sh status
./hog.sh logs web
./hog.sh health
./hog.sh upgrade
./hog.sh reset
```

### Ghi chú

- Cấu hình/secrets nằm ở `~/self-hosted/posthog/.env`
- Bản hobby phù hợp workload nhỏ
- `start` mặc định chạy core services; dùng `start-full` để bật profile Temporal/Exceptions
- Dùng domain production nên đặt reverse proxy (Caddy/Nginx/Traefik)
- Nếu mạng kéo image chậm/không ổn định: chỉnh `POSTHOG_START_RETRIES` và `POSTHOG_PULL_PARALLEL_LIMIT`

Hỗ trợ: <https://ai.vnrom.net>
