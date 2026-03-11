# Supabase Self-Hosted — Unified Setup / Cài đặt Tự động

> 🇺🇸 **English** | 🇻🇳 **Tiếng Việt** — scroll down for Vietnamese / cuộn xuống để đọc Tiếng Việt

---

## 🇺🇸 English

Automated installer for **Supabase self-hosted** with a format aligned to the other scripts in this repo.

### Supported Platforms

- **macOS** (Apple Silicon / Intel)
- **Raspberry Pi** (ARM64, 64-bit OS)
- **Linux VPS** (AMD64 / ARM64)

### What the script does

1. Detects platform and checks RAM / disk / Docker
2. Auto-installs Docker on Linux if needed
3. Supports **bilingual onboarding** (English / Vietnamese)
4. Supports access modes: localhost, LAN, domain (behind reverse proxy)
5. Downloads the official [Supabase Docker self-hosting stack](https://github.com/supabase/supabase/tree/master/docker)
6. Generates secure secrets, JWT keys, dashboard credentials, and MinIO credentials
7. Adds a portable compose override for host ports and macOS compatibility
8. Starts the full stack and verifies health
9. Creates `supa.sh` helper commands

### Included Services

- **Studio** dashboard
- **Kong** API gateway
- **Auth**
- **PostgREST**
- **Realtime**
- **Storage** with **MinIO S3 backend**
- **Image transformations** via imgproxy
- **Postgres Meta**
- **Edge Functions**
- **Analytics / Logflare**
- **Vector**
- **Supavisor** pooler
- **PostgreSQL**

### Quick Install

```bash
mkdir -p ~/self-hosted/supabase && cd ~/self-hosted/supabase
curl -O https://raw.githubusercontent.com/duynghien/auto/main/supabase/setup.sh
chmod +x setup.sh
./setup.sh
```

### Recommended Requirements

- RAM: **8GB+** recommended
- Disk: **15GB+** free
- Raspberry Pi: **64-bit OS required**
- macOS: Docker Desktop or OrbStack must already be running

### Management

```bash
./supa.sh start
./supa.sh stop
./supa.sh restart
./supa.sh status
./supa.sh logs kong
./supa.sh health
./supa.sh keys
./supa.sh upgrade
./supa.sh reset
```

### Notes

- The installer keeps an upstream snapshot in `./supabase-upstream`
- S3-backed storage is enabled by default via `docker-compose.s3.yml`
- MinIO uses the official Docker Hub images by default to avoid `cgr.dev` pull timeouts
- The script exposes host ports for HTTP, HTTPS, session pooler, and transaction pooler
- For production domains, place Caddy / Nginx / Traefik in front of the HTTP port
- If you change `.env`, run `./supa.sh restart`

### References

- Official repo: <https://github.com/supabase/supabase>
- Official self-hosting docs: <https://supabase.com/docs/guides/self-hosting/docker>

### Support

- GitHub: <https://github.com/duynghien/auto>
- Community: <https://ai.vnrom.net>

---

## 🇻🇳 Tiếng Việt

Script tự động triển khai **Supabase self-hosted** với format đồng bộ cùng các script khác trong repo này.

### Nền tảng hỗ trợ

- **macOS** (Apple Silicon / Intel)
- **Raspberry Pi** (ARM64, bắt buộc OS 64-bit)
- **VPS Linux** (AMD64 / ARM64)

### Script sẽ làm gì

1. Nhận diện nền tảng và kiểm tra RAM / ổ đĩa / Docker
2. Tự cài Docker trên Linux nếu cần
3. Hỗ trợ **song ngữ** (English / Tiếng Việt)
4. Hỗ trợ các mode truy cập: localhost, LAN, domain (sau reverse proxy)
5. Tải stack Docker self-hosted chính thức của [Supabase](https://github.com/supabase/supabase/tree/master/docker)
6. Tạo secrets bảo mật, JWT keys, tài khoản dashboard và credentials MinIO
7. Thêm compose override portable cho host ports và tương thích macOS
8. Khởi động full stack và kiểm tra health
9. Tạo script quản lý `supa.sh`

### Các service được bật

- **Studio** dashboard
- **Kong** API gateway
- **Auth**
- **PostgREST**
- **Realtime**
- **Storage** với **MinIO S3 backend**
- **Image transformations** qua imgproxy
- **Postgres Meta**
- **Edge Functions**
- **Analytics / Logflare**
- **Vector**
- **Supavisor** pooler
- **PostgreSQL**

### Cài nhanh

```bash
mkdir -p ~/self-hosted/supabase && cd ~/self-hosted/supabase
curl -O https://raw.githubusercontent.com/duynghien/auto/main/supabase/setup.sh
chmod +x setup.sh
./setup.sh
```

### Yêu cầu khuyến nghị

- RAM: khuyến nghị **8GB+**
- Ổ đĩa trống: **15GB+**
- Raspberry Pi: **bắt buộc OS 64-bit**
- macOS: cần cài sẵn và chạy Docker Desktop hoặc OrbStack

### Quản lý

```bash
./supa.sh start
./supa.sh stop
./supa.sh restart
./supa.sh status
./supa.sh logs kong
./supa.sh health
./supa.sh keys
./supa.sh upgrade
./supa.sh reset
```

### Ghi chú

- Installer giữ một snapshot upstream trong `./supabase-upstream`
- Storage S3-backed được bật mặc định qua `docker-compose.s3.yml`
- MinIO mặc định dùng image chính thức từ Docker Hub để tránh lỗi timeout khi kéo từ `cgr.dev`
- Script expose host ports cho HTTP, HTTPS, session pooler và transaction pooler
- Với domain production, nên đặt Caddy / Nginx / Traefik phía trước cổng HTTP
- Sau khi sửa `.env`, chạy `./supa.sh restart`

### Tài liệu tham khảo

- Repo chính thức: <https://github.com/supabase/supabase>
- Tài liệu self-hosted chính thức: <https://supabase.com/docs/guides/self-hosting/docker>

### Hỗ trợ

- GitHub: <https://github.com/duynghien/auto>
- Community: <https://ai.vnrom.net>
