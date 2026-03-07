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
./grafana.sh start
./grafana.sh stop
./grafana.sh restart
./grafana.sh status
./grafana.sh logs grafana
./grafana.sh health
./grafana.sh datasource
./grafana.sh dashboard
./grafana.sh credentials
./grafana.sh upgrade
./grafana.sh reset
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
./grafana.sh start
./grafana.sh stop
./grafana.sh restart
./grafana.sh status
./grafana.sh logs grafana
./grafana.sh health
./grafana.sh datasource
./grafana.sh dashboard
./grafana.sh credentials
./grafana.sh upgrade
./grafana.sh reset
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
