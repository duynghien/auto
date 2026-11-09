# Prometheus Self-Hosted — Unified Setup / Cài đặt Tự động

> 🇺🇸 **English** | 🇻🇳 **Tiếng Việt** — scroll down for Vietnamese / cuộn xuống để đọc Tiếng Việt

---

## 🇺🇸 English

One-script installer for **Prometheus self-hosted** with Docker Compose, aligned with this repo's bilingual setup format.

### Supported Platforms

| Platform | Arch | Notes |
|---|---|---|
| **macOS** | arm64 / x86_64 | Requires OrbStack or Docker Desktop |
| **Raspberry Pi** | arm64 | Auto-enables `node-exporter`, optional swap on low RAM |
| **Linux VPS** | amd64 / arm64 | Auto-installs Docker on Debian/Ubuntu-style systems |

### What the script does

1. Detects platform and checks Docker, RAM, disk, and required commands
2. Supports **bilingual UI** (English / Vietnamese)
3. Supports access modes: localhost, LAN, domain (behind reverse proxy)
4. Generates `.env`, `prometheus.yml`, and starter alert rules
5. Deploys Prometheus with Docker Compose
6. Auto-enables **node-exporter** on Linux / Raspberry Pi using the official host-monitoring container pattern
7. Validates config via `docker compose config` and `promtool check config`
8. Starts the stack and checks `/-/healthy` + `/-/ready`
9. Creates helper script `prometheus.sh`

### Quick Install

```bash
mkdir -p ~/self-hosted/prometheus && cd ~/self-hosted/prometheus
curl -O https://raw.githubusercontent.com/duynghien/auto/main/prometheus/setup.sh
chmod +x setup.sh
./setup.sh
```

### Stack

| Component | Purpose |
|---|---|
| **Prometheus** | Metrics collection, TSDB, PromQL UI, rule evaluation |
| **node-exporter** | Host metrics on Linux / Raspberry Pi |
| **rules/default.yml** | Starter alert rules for Prometheus and node-exporter |

### Management

```bash
./prometheus.sh start         # Start/upgrade stack
./prometheus.sh stop          # Stop services
./prometheus.sh restart       # Restart services
./prometheus.sh status        # Show service status
./prometheus.sh logs [svc]    # Follow logs (default: prometheus)
./prometheus.sh health        # Check /-/healthy and /-/ready
./prometheus.sh backup        # Backup config & TSDB volume to ./backups
./prometheus.sh restore <f>   # Safe restore configuration from backup
./prometheus.sh doctor        # Diagnostics: containers, ports, health, promtool
./prometheus.sh reload        # Reload prometheus.yml without restart
./prometheus.sh config-check  # Validate prometheus.yml via promtool
./prometheus.sh upgrade       # Pull latest images and restart (alias: update)
./prometheus.sh uninstall     # Clean uninstall (keep data or full purge)
./prometheus.sh reset         # Delete Prometheus data volume
```

### Files Generated

```text
~/self-hosted/prometheus/
├── .env
├── docker-compose.yml
├── prometheus.yml
├── prometheus.sh
└── rules/
    └── default.yml
```

### Notes

- The script defaults to **Prometheus only** on macOS for portability.
- Linux / Raspberry Pi auto-enable `node-exporter` because the official containerized host-monitoring guidance relies on Linux host namespaces.
- The stack joins the stable Docker network `prometheus-shared` and publishes alias `prometheus-core` for cross-stack integrations such as Grafana.
- Add more scrape targets by editing `prometheus.yml`, then run `./prometheus.sh reload`.
- For public domain use, place a reverse proxy (Caddy/Nginx/Traefik/Cloudflare Tunnel) in front.
- Prometheus does **not** include authentication by default; do not expose it publicly without access controls.

### Smoke Test (Linux / Raspberry Pi)

Run the same smoke test script locally or in CI to verify the `node-exporter` branch end-to-end:

```bash
bash prometheus/smoke-test-linux.sh
```

### References

- Official Prometheus repo: <https://github.com/prometheus/prometheus>
- Official Node Exporter repo: <https://github.com/prometheus/node_exporter>
- Prometheus docs: <https://prometheus.io/docs/prometheus/latest/>

---

## 🇻🇳 Tiếng Việt

Script tự động triển khai **Prometheus self-hosted** bằng Docker Compose, đồng bộ format song ngữ với các installer khác trong repo.

### Nền tảng hỗ trợ

| Nền tảng | Kiến trúc | Ghi chú |
|---|---|---|
| **macOS** | arm64 / x86_64 | Cần OrbStack hoặc Docker Desktop |
| **Raspberry Pi** | arm64 | Tự bật `node-exporter`, có swap nếu RAM thấp |
| **VPS Linux** | amd64 / arm64 | Tự cài Docker trên hệ Debian/Ubuntu phổ biến |

### Script sẽ làm gì

1. Nhận diện nền tảng và kiểm tra Docker, RAM, ổ đĩa, command cần thiết
2. Hỗ trợ **song ngữ** (English / Tiếng Việt)
3. Hỗ trợ mode truy cập: localhost, LAN, domain (qua reverse proxy)
4. Tạo `.env`, `prometheus.yml` và rule cảnh báo khởi đầu
5. Triển khai Prometheus bằng Docker Compose
6. Tự bật **node-exporter** trên Linux / Raspberry Pi theo pattern host-monitoring chính thức
7. Validate bằng `docker compose config` và `promtool check config`
8. Khởi động stack và kiểm tra `/-/healthy` + `/-/ready`
9. Tạo script quản lý `prometheus.sh`

### Cài nhanh

```bash
mkdir -p ~/self-hosted/prometheus && cd ~/self-hosted/prometheus
curl -O https://raw.githubusercontent.com/duynghien/auto/main/prometheus/setup.sh
chmod +x setup.sh
./setup.sh
```

### Thành phần

| Thành phần | Vai trò |
|---|---|
| **Prometheus** | Thu thập metrics, TSDB, PromQL UI, rule evaluation |
| **node-exporter** | Metrics máy host trên Linux / Raspberry Pi |
| **rules/default.yml** | Rule cảnh báo mẫu cho Prometheus và node-exporter |

### Quản lý

```bash
./prometheus.sh start         # Khởi động/cập nhật stack
./prometheus.sh stop          # Dừng services
./prometheus.sh restart       # Khởi động lại
./prometheus.sh status        # Xem trạng thái services
./prometheus.sh logs [svc]    # Xem logs (mặc định: prometheus)
./prometheus.sh health        # Kiểm tra /-/healthy và /-/ready
./prometheus.sh backup        # Sao lưu cấu hình & volume TSDB vào ./backups
./prometheus.sh restore <f>   # Khôi phục cấu hình an toàn từ file backup
./prometheus.sh doctor        # Chuẩn đoán: containers, cổng, health, promtool
./prometheus.sh reload        # Tải lại prometheus.yml không cần khởi động lại
./prometheus.sh config-check  # Kiểm tra tính hợp lệ prometheus.yml bằng promtool
./prometheus.sh upgrade       # Kéo images mới nhất & khởi động lại (alias: update)
./prometheus.sh uninstall     # Gỡ cài đặt (giữ data hoặc xóa sạch)
./prometheus.sh reset         # Xóa volume dữ liệu Prometheus
```

### Các file được tạo

```text
~/self-hosted/prometheus/
├── .env
├── docker-compose.yml
├── prometheus.yml
├── prometheus.sh
└── rules/
    └── default.yml
```

### Ghi chú

- Trên macOS, script mặc định chỉ chạy **Prometheus core** để giữ tính portable.
- Linux / Raspberry Pi tự bật `node-exporter` vì hướng dẫn monitor host bằng container chính thức dựa trên Linux namespaces.
- Stack tham gia Docker network ổn định `prometheus-shared` và publish alias `prometheus-core` để ghép với stack khác như Grafana.
- Muốn thêm scrape target, sửa `prometheus.yml` rồi chạy `./prometheus.sh reload`.
- Nếu dùng domain public, nên đặt reverse proxy (Caddy/Nginx/Traefik/Cloudflare Tunnel) phía trước.
- Prometheus mặc định **không có authentication**; không nên public trực tiếp nếu chưa có lớp bảo vệ.

### Smoke Test (Linux / Raspberry Pi)

Chạy cùng script smoke test trên máy local hoặc CI để verify đầy đủ nhánh `node-exporter`:

```bash
bash prometheus/smoke-test-linux.sh
```

### Tham khảo

- Prometheus chính thức: <https://github.com/prometheus/prometheus>
- Node Exporter chính thức: <https://github.com/prometheus/node_exporter>
- Tài liệu Prometheus: <https://prometheus.io/docs/prometheus/latest/>

---

## Support

- GitHub: https://github.com/duynghien/auto
- Website: https://ai.vnrom.net
