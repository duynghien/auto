# Grafana Self-Hosted — Unified Setup / Cài đặt Tự động

> 🇺🇸 **English** | 🇻🇳 **Tiếng Việt** — scroll down for Vietnamese / cuộn xuống để đọc Tiếng Việt

---

## 🇺🇸 English

One-script installer for **Grafana self-hosted** with Docker Compose, integrated with this repo's Prometheus installer.

### Supported Platforms

| Platform | Arch | Notes |
|---|---|---|
| **macOS** | arm64 / x86_64 | Requires OrbStack or Docker Desktop |
| **Raspberry Pi** | arm64 | Works with the Prometheus shared network |
| **Linux VPS** | amd64 / arm64 | Auto-installs Docker on Debian/Ubuntu-style systems |

### What the script does

1. Detects platform and checks Docker, RAM, disk, and required commands
2. Supports **bilingual UI** (English / Vietnamese)
3. Supports access modes: localhost, LAN, domain (behind reverse proxy)
4. Detects local `~/self-hosted/prometheus` and can auto-link it through the shared Docker network `prometheus-shared`
5. Generates `.env`, Grafana provisioning files, and a starter dashboard
6. Deploys Grafana with Docker Compose
7. Verifies `/api/health`, the provisioned Prometheus datasource, and the starter dashboard
8. Creates helper script `grafana.sh`

### Quick Install

```bash
mkdir -p ~/self-hosted/grafana && cd ~/self-hosted/grafana
curl -O https://raw.githubusercontent.com/duynghien/auto/main/grafana/setup.sh
chmod +x setup.sh
./setup.sh
```

### Integration with Prometheus

- Best path: run the repo's Prometheus installer first so the shared network `prometheus-shared` exists.
- Grafana then auto-provisions datasource `prometheus-main` pointing to `http://prometheus-core:9090`.
- If you do not use the local Prometheus installer, the script can target any external Prometheus URL.

### Provisioned Assets

| Asset | Purpose |
|---|---|
| **Prometheus datasource** (`prometheus-main`) | Default metrics source |
| **vnROM Monitoring folder** | Keeps starter dashboards organized |
| **Prometheus Overview** dashboard | Quick visibility into Prometheus health, series, memory, node exporter |

### Management

```bash
./grafana.sh start        # Start/upgrade stack
./grafana.sh stop         # Stop services
./grafana.sh restart      # Restart services
./grafana.sh status       # Show service status
./grafana.sh logs [svc]   # Follow logs (default: grafana)
./grafana.sh health       # Check /api/health
./grafana.sh backup       # Backup provisioning and data volume to ./backups
./grafana.sh restore <f>  # Safe restore configuration from backup
./grafana.sh doctor       # Diagnostics: containers, ports, health, datasource
./grafana.sh datasource   # Show provisioned Prometheus datasource
./grafana.sh dashboard    # Show starter dashboard metadata
./grafana.sh credentials  # Show Grafana login and Prometheus target
./grafana.sh upgrade      # Pull latest images and restart (alias: update)
./grafana.sh uninstall    # Clean uninstall (keep data or full purge)
./grafana.sh reset        # Delete Grafana data volume
```

### Files Generated

```text
~/self-hosted/grafana/
├── .env
├── docker-compose.yml
├── grafana.sh
├── dashboards/
│   └── prometheus-overview.json
└── provisioning/
    ├── dashboards/default.yml
    └── datasources/prometheus.yml
```

### References

- Official Grafana Docker docs: <https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/>
- Official provisioning docs: <https://grafana.com/docs/grafana/latest/administration/provisioning/>
- Prometheus installer in this repo: <../prometheus>

---

## 🇻🇳 Tiếng Việt

Script tự động triển khai **Grafana self-hosted** bằng Docker Compose, ghép sẵn với installer Prometheus trong repo này.

### Nền tảng hỗ trợ

| Nền tảng | Kiến trúc | Ghi chú |
|---|---|---|
| **macOS** | arm64 / x86_64 | Cần OrbStack hoặc Docker Desktop |
| **Raspberry Pi** | arm64 | Hoạt động cùng shared network của Prometheus |
| **VPS Linux** | amd64 / arm64 | Tự cài Docker trên hệ Debian/Ubuntu phổ biến |

### Script sẽ làm gì

1. Nhận diện nền tảng và kiểm tra Docker, RAM, ổ đĩa, command cần thiết
2. Hỗ trợ **song ngữ** (English / Tiếng Việt)
3. Hỗ trợ mode truy cập: localhost, LAN, domain (qua reverse proxy)
4. Phát hiện `~/self-hosted/prometheus` local và có thể tự ghép qua shared Docker network `prometheus-shared`
5. Tạo `.env`, file provisioning của Grafana, và dashboard khởi đầu
6. Triển khai Grafana bằng Docker Compose
7. Kiểm tra `/api/health`, datasource Prometheus đã provision, và starter dashboard
8. Tạo script quản lý `grafana.sh`

### Cài nhanh

```bash
mkdir -p ~/self-hosted/grafana && cd ~/self-hosted/grafana
curl -O https://raw.githubusercontent.com/duynghien/auto/main/grafana/setup.sh
chmod +x setup.sh
./setup.sh
```

### Ghép với Prometheus

- Tốt nhất: chạy installer Prometheus của repo trước để shared network `prometheus-shared` đã tồn tại.
- Grafana sẽ tự provision datasource `prometheus-main` trỏ đến `http://prometheus-core:9090`.
- Nếu không dùng Prometheus local của repo, script vẫn có thể trỏ tới Prometheus URL bên ngoài.

### Tài nguyên được provision

| Tài nguyên | Vai trò |
|---|---|
| **Prometheus datasource** (`prometheus-main`) | Nguồn metrics mặc định |
| **vnROM Monitoring folder** | Gom starter dashboard gọn gàng |
| **Prometheus Overview** dashboard | Theo dõi nhanh health, series, memory, node exporter |

### Quản lý

```bash
./grafana.sh start        # Khởi động/cập nhật stack
./grafana.sh stop         # Dừng services
./grafana.sh restart      # Khởi động lại
./grafana.sh status       # Xem trạng thái services
./grafana.sh logs [svc]   # Xem logs (mặc định: grafana)
./grafana.sh health       # Kiểm tra endpoint /api/health
./grafana.sh backup       # Sao lưu cấu hình provisioning và data volume vào ./backups
./grafana.sh restore <f>  # Khôi phục cấu hình an toàn từ file backup
./grafana.sh doctor       # Chuẩn đoán: containers, cổng, health, datasource
./grafana.sh datasource   # Xem thông tin datasource Prometheus đã cấu hình
./grafana.sh dashboard    # Xem metadata starter dashboard
./grafana.sh credentials  # Hiển thị tài khoản đăng nhập & đích Prometheus
./grafana.sh upgrade      # Kéo images mới nhất & khởi động lại (alias: update)
./grafana.sh uninstall    # Gỡ cài đặt (giữ data hoặc xóa sạch)
./grafana.sh reset        # Xóa volume dữ liệu Grafana
```

### Các file được tạo

```text
~/self-hosted/grafana/
├── .env
├── docker-compose.yml
├── grafana.sh
├── dashboards/
│   └── prometheus-overview.json
└── provisioning/
    ├── dashboards/default.yml
    └── datasources/prometheus.yml
```

### Tham khảo

- Grafana Docker docs chính thức: <https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/>
- Provisioning docs chính thức: <https://grafana.com/docs/grafana/latest/administration/provisioning/>
- Installer Prometheus trong repo: <../prometheus>

---

## Support

- GitHub: https://github.com/duynghien/auto
- Website: https://ai.vnrom.net
