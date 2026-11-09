# duynghien auto-scripts 🚀

> **Gen 4 Standalone Gold Standard** — 24 production-ready, self-contained self-hosted automation installers and helper CLIs.

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

A unified collection of **24 self-contained automation installers** designed for rapid, secure, and resilient 1-click self-hosting. Every stack operates with 100% standalone execution (no repo clone required on target machines), strict fault-tolerant preflight (`set -euo pipefail` + `ERR` traps), automated RAM/swap guards with LXC/OpenVZ compatibility, universal security hardening (`chmod 600 .env`, `0700` backup dirs), and standardized management helper CLIs.

### 📊 Quick Reference Matrix

| Tool | Category | Default Port(s) | Min RAM | Target Platforms | Helper CLI |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **[OpenClaw + n8n + MCP](./openclaw-n8n-mcp)** | AI & Dev | 5678, 18789 | 4 GB | Linux VPS (Ubuntu/Debian) | `openclaw` / `./openclaw.sh` |
| **[LobeHub](./lobehub)** | AI & Dev | 3210, 9000 | 2-4 GB | macOS, Pi (4/5), VPS | `lobe` / `./lobe.sh` / `lobehub` |
| **[Mem0 AI Memory](./mem0)** | AI & Dev | 3000, 8765 | 2-4 GB | macOS, Pi (4/5), VPS | `./mem0.sh` |
| **[Bolt.diy](./boltdiy)** | AI & Dev | 5173 | 2 GB | macOS, Pi (4/5), VPS | `./boltdiy.sh` |
| **[SpaceBot](./spacebot)** | AI & Dev | 19898 | 1-2 GB | Linux VPS | `./spacebot.sh` |
| **[n8n](./n8n)** | Automation | 5678 | 2-4 GB | macOS, Pi (4/5), VPS | `n8n` / `./n8n.sh` |
| **[Supabase](./supabase)** | Automation | 8000, 5432 | 4-8 GB | macOS, Pi (ARM64), VPS | `supa` / `./supa.sh` / `supabase` |
| **[Firecrawl](./firecrawl)** | Web Crawling | 3002 | 4-8 GB | macOS, Pi (4/5), VPS | `fc` / `./fc.sh` / `firecrawl` |
| **[AnyCrawl](./anycrawl)** | Web Crawling | 8880, 9000, 8080 | 2-4 GB | macOS, Pi (4/5), VPS | `./anycrawl.sh` |
| **[Crawl4AI](./crawl4ai)** | Web Crawling | 11235 | 2-4 GB | macOS, Pi (4/5), VPS | `c4ai` / `./c4ai.sh` / `crawl4ai` |
| **[Scrapling](./scrapling)** | Web Crawling | 8000 | 1-2 GB | macOS, Pi (4/5), VPS | `./scrapling.sh` |
| **[Twenty CRM](./twenty)** | CRM & Business | 3000 | 2-4 GB | macOS, Pi (4/5), VPS | `./twenty.sh` |
| **[EspoCRM](./espocrm)** | CRM & Business | 8080, 8081 | 2-4 GB | macOS, Pi (4/5), VPS | `espocrm` / `./espocrm.sh` |
| **[Mautic](./mautic)** | CRM & Business | 8080 | 2-4 GB | macOS, Pi (4/5), VPS | `./mautic.sh` |
| **[Listmonk](./listmonk)** | CRM & Business | 9000 | 1-2 GB | macOS, Pi (4/5), VPS | `listmonk` / `./listmonk.sh` |
| **[Postiz](./postiz)** | CRM & Business | 5000, 4200 | 1.5-5 GB | macOS, Pi (4/5), VPS | `./postiz.sh` |
| **[PostHog](./posthog)** | Analytics & Infra | 8000 | 4-8 GB | macOS, Pi (4/5), VPS | `hog` / `./hog.sh` / `posthog` |
| **[Matomo](./matomo)** | Analytics & Infra | 8080 | 2-4 GB | macOS, Pi (4/5), VPS | `matomo` / `./matomo.sh` |
| **[Prometheus](./prometheus)** | Analytics & Infra | 9090 | 1-2 GB | macOS, Pi (4/5), VPS | `prometheus` / `./prometheus.sh` |
| **[Grafana](./grafana)** | Analytics & Infra | 3000 | 1-2 GB | macOS, Pi (4/5), VPS | `grafana` / `./grafana.sh` |
| **[Headscale](./headscale)** | Analytics & Infra | 8080, 9090 | 1 GB | Linux VPS | `./headscale.sh` |
| **[Proxies (Caddy)](./proxies)** | Analytics & Infra | 80, 443 | 512 MB | Linux VPS | `./proxies.sh` |
| **[Raspberry Pi Toolbox](./raspberry-pi)** | Analytics & Infra | 9000, 9443 | 1-8 GB | Raspberry Pi (3/4/5) | `./pi-toolbox.sh` |
| **[WordOps Backup](./wordops)** | Analytics & Infra | N/A | 1-2 GB | Linux VPS (Ubuntu/Debian) | `wo-backup` / `./wo-backup.sh` |

---

### 📂 Catalog by Category

#### 1. AI Agents, Memory & Developer Platforms
- **[OpenClaw + n8n + MCP Stack](./openclaw-n8n-mcp)**: End-to-end autonomous AI Agent operating environment pairing OpenClaw with n8n workflow execution and Model Context Protocol (MCP) tool integration.
- **[LobeHub](./lobehub)**: Modern ChatGPT/Claude alternative with Knowledge Base (pgvector/ParadeDB), SearXNG online search, and S3-compatible file storage (RustFS/MinIO).
- **[Mem0 AI Memory](./mem0)**: Universal memory layer for AI agents and LLMs with dual vector (Qdrant) and graph (Neo4j) database backends.
- **[Bolt.diy](./boltdiy)**: In-browser full-stack AI development sandbox running on Docker with containerized Vite dev server and multi-LLM support.
- **[SpaceBot](./spacebot)**: High-speed Telegram bot integration for automated trading, monitoring, and notification pipelines.

#### 2. Workflow Automation & Backend
- **[n8n Self-Hosted Installer](./n8n)**: Enterprise workflow automation with optional Queue Mode (Redis), dedicated Worker/Webhook runners, PostgreSQL backend, FFmpeg, and Puppeteer support.
- **[Supabase Self-Hosted Installer](./supabase)**: Complete open-source Firebase alternative featuring Studio dashboard, Auth (GoTrue), PostgREST, Realtime, MinIO storage, Edge Functions, and Supavisor pooling.

#### 3. Web Crawling & Data Extraction
- **[Firecrawl](./firecrawl)**: Production API service turning entire websites into clean Markdown and structured LLM-ready JSON.
- **[AnyCrawl Stack](./anycrawl)**: Multi-engine web scraper with SearXNG integration, PostgreSQL, MinIO storage, and AI MCP server bridge.
- **[Crawl4AI](./crawl4ai)**: Ultra-fast, LLM-friendly asynchronous web crawler and HTML-to-Markdown extractor with Playwright browser support.
- **[Scrapling](./scrapling)**: Lightweight anti-bot web scraping service and API running with undetceted browser automation.

#### 4. CRM, Marketing & Business Suite
- **[Twenty CRM](./twenty)**: Modern open-source Notion-like CRM featuring GraphQL API, Postgres, Redis queue, and customizable workflow modules.
- **[EspoCRM](./espocrm)**: Robust open-source CRM platform with responsive web app, MariaDB backend, and real-time WebSocket notifications.
- **[Mautic](./mautic)**: Leading open-source marketing automation platform with MariaDB backend, email campaigns, contact segmentation, and cron workers.
- **[Listmonk](./listmonk)**: High-performance, self-hosted newsletter and mailing list manager powered by PostgreSQL.
- **[Postiz](./postiz)**: Multi-network social media scheduling and automation platform with dual architecture profiles (Lightweight 1.5GB RAM vs Full Enterprise).

#### 5. Analytics, Monitoring & Infrastructure
- **[PostHog](./posthog)**: Comprehensive product analytics, event capture, session recording, and feature flags platform with automated runtime preflight patches.
- **[Matomo](./matomo)**: Privacy-first web analytics platform featuring MariaDB storage and Cookieless/GDPR compliant tracking.
- **[Prometheus](./prometheus)**: Industry-standard systems monitoring and time-series database with starter alert rules and Linux Node Exporter.
- **[Grafana](./grafana)**: Rich dashboard visualization suite with automated Prometheus datasource provisioning and starter system boards.
- **[Headscale](./headscale)**: Self-hosted, open-source implementation of Tailscale coordination server with SQLite storage and private VPN routing.
- **[Proxies (Caddy)](./proxies)**: Modern HTTPS reverse proxy manager powered by Caddy with automated Let's Encrypt TLS and token persistence.
- **[Raspberry Pi ARM Toolbox](./raspberry-pi)**: Essential setup suite for single-board computers (Docker, Portainer, memory tuning, swap selector).
- **[WordOps Automated Backup](./wordops)**: Zero-downtime automated backup and restore suite for WordOps LEMP stack with GPG encryption and cron automation.

---

### 🛡️ Gen 4 Architecture Standards
All installers in this repository strictly adhere to:
1. **100% Standalone Execution**: Every `setup.sh` is an authoritative generator embedding its compose files and helper scripts via inline heredocs.
2. **Fault-Tolerant Preflight**: Strict `set -euo pipefail` execution, diagnostic `on_error $LINENO` traps, and RAM/swap guards with LXC/OpenVZ compatibility.
3. **Universal Security Hardening**: Strict `chmod 600 .env` file permissions, `0700` backup directories, and `0600` backup archives.
4. **Standardized Helper CLIs**: `<tool>.sh` with consistent commands (`start`, `stop`, `restart`, `status`, `logs`, `backup`, `restore`, `doctor`, `upgrade`, `uninstall`).
5. **Safe Container UID Preservation**: Host-level ownership resolution (`$SUDO_USER`) ensures root container bind mounts are never overwritten.

---

## Tiếng Việt

Bộ sưu tập đồng nhất gồm **24 trình cài đặt tự động hoá khép kín** (Gen 4 Standalone Gold Standard) được thiết kế cho việc triển khai self-hosted 1-click nhanh chóng, an toàn và ổn định. Mỗi bộ công cụ hoạt động hoàn toàn độc lập (không bắt buộc `git clone` trên máy đích), trang bị cơ chế kiểm tra hệ thống chịu lỗi (`set -euo pipefail` + trap `ERR`), tự động phát hiện và bù đắp RAM/swap (tương thích LXC/OpenVZ), bảo mật phân quyền (`chmod 600 .env`, thư mục backup `0700`), cùng CLI helper quản lý chuẩn hoá.

### 📊 Bảng Tra Cứu Nhanh

| Công cụ | Phân nhóm | Cổng mặc định | RAM tối thiểu | Nền tảng hỗ trợ | Lệnh Helper CLI |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **[OpenClaw + n8n + MCP](./openclaw-n8n-mcp)** | AI & Lập trình | 5678, 18789 | 4 GB | Linux VPS (Ubuntu/Debian) | `openclaw` / `./openclaw.sh` |
| **[LobeHub](./lobehub)** | AI & Lập trình | 3210, 9000 | 2-4 GB | macOS, Pi (4/5), VPS | `lobe` / `./lobe.sh` / `lobehub` |
| **[Mem0 AI Memory](./mem0)** | AI & Lập trình | 3000, 8765 | 2-4 GB | macOS, Pi (4/5), VPS | `./mem0.sh` |
| **[Bolt.diy](./boltdiy)** | AI & Lập trình | 5173 | 2 GB | macOS, Pi (4/5), VPS | `./boltdiy.sh` |
| **[SpaceBot](./spacebot)** | AI & Lập trình | 19898 | 1-2 GB | Linux VPS | `./spacebot.sh` |
| **[n8n](./n8n)** | Tự động hoá | 5678 | 2-4 GB | macOS, Pi (4/5), VPS | `n8n` / `./n8n.sh` |
| **[Supabase](./supabase)** | Tự động hoá | 8000, 5432 | 4-8 GB | macOS, Pi (ARM64), VPS | `supa` / `./supa.sh` / `supabase` |
| **[Firecrawl](./firecrawl)** | Thu thập dữ liệu | 3002 | 4-8 GB | macOS, Pi (4/5), VPS | `fc` / `./fc.sh` / `firecrawl` |
| **[AnyCrawl](./anycrawl)** | Thu thập dữ liệu | 8880, 9000, 8080 | 2-4 GB | macOS, Pi (4/5), VPS | `./anycrawl.sh` |
| **[Crawl4AI](./crawl4ai)** | Thu thập dữ liệu | 11235 | 2-4 GB | macOS, Pi (4/5), VPS | `c4ai` / `./c4ai.sh` / `crawl4ai` |
| **[Scrapling](./scrapling)** | Thu thập dữ liệu | 8000 | 1-2 GB | macOS, Pi (4/5), VPS | `./scrapling.sh` |
| **[Twenty CRM](./twenty)** | Doanh nghiệp & CRM | 3000 | 2-4 GB | macOS, Pi (4/5), VPS | `./twenty.sh` |
| **[EspoCRM](./espocrm)** | Doanh nghiệp & CRM | 8080, 8081 | 2-4 GB | macOS, Pi (4/5), VPS | `espocrm` / `./espocrm.sh` |
| **[Mautic](./mautic)** | Doanh nghiệp & CRM | 8080 | 2-4 GB | macOS, Pi (4/5), VPS | `./mautic.sh` |
| **[Listmonk](./listmonk)** | Doanh nghiệp & CRM | 9000 | 1-2 GB | macOS, Pi (4/5), VPS | `listmonk` / `./listmonk.sh` |
| **[Postiz](./postiz)** | Doanh nghiệp & CRM | 5000, 4200 | 1.5-5 GB | macOS, Pi (4/5), VPS | `./postiz.sh` |
| **[PostHog](./posthog)** | Phân tích & Hạ tầng | 8000 | 4-8 GB | macOS, Pi (4/5), VPS | `hog` / `./hog.sh` / `posthog` |
| **[Matomo](./matomo)** | Phân tích & Hạ tầng | 8080 | 2-4 GB | macOS, Pi (4/5), VPS | `matomo` / `./matomo.sh` |
| **[Prometheus](./prometheus)** | Phân tích & Hạ tầng | 9090 | 1-2 GB | macOS, Pi (4/5), VPS | `prometheus` / `./prometheus.sh` |
| **[Grafana](./grafana)** | Phân tích & Hạ tầng | 3000 | 1-2 GB | macOS, Pi (4/5), VPS | `grafana` / `./grafana.sh` |
| **[Headscale](./headscale)** | Phân tích & Hạ tầng | 8080, 9090 | 1 GB | Linux VPS | `./headscale.sh` |
| **[Proxies (Caddy)](./proxies)** | Phân tích & Hạ tầng | 80, 443 | 512 MB | Linux VPS | `./proxies.sh` |
| **[Raspberry Pi Toolbox](./raspberry-pi)** | Phân tích & Hạ tầng | 9000, 9443 | 1-8 GB | Raspberry Pi (3/4/5) | `./pi-toolbox.sh` |
| **[WordOps Backup](./wordops)** | Phân tích & Hạ tầng | N/A | 1-2 GB | Linux VPS (Ubuntu/Debian) | `wo-backup` / `./wo-backup.sh` |

---

### 📂 Danh Mục Theo Nhóm Chức Năng

#### 1. AI Agents, Bộ Nhớ & Nền Tảng Lập Trình
- **[OpenClaw + n8n + MCP Stack](./openclaw-n8n-mcp)**: Hệ sinh thái AI Agent tự trị hoàn chỉnh kết hợp sức mạnh điều phối luồng của n8n và giao thức công cụ Model Context Protocol (MCP).
- **[LobeHub](./lobehub)**: Giao diện AI Chat hiện đại thay thế ChatGPT/Claude kèm tính năng Knowledge Base (pgvector/ParadeDB), tìm kiếm trực tuyến SearXNG và lưu trữ S3 (RustFS/MinIO).
- **[Mem0 AI Memory](./mem0)**: Lớp lưu trữ bộ nhớ dài hạn đa tầng cho AI agents sử dụng đồng thời cơ sở dữ liệu vector (Qdrant) và đồ thị tri thức (Neo4j).
- **[Bolt.diy](./boltdiy)**: Môi trường lập trình full-stack AI trực tiếp trên trình duyệt web, đóng gói gọn trong Docker với Vite dev server.
- **[SpaceBot](./spacebot)**: Hệ thống bot Telegram tự động tốc độ cao cho các luồng giao dịch, giám sát và cảnh báo.

#### 2. Tự Động Hoá & Backend
- **[n8n Self-Hosted Installer](./n8n)**: Nền tảng tự động hoá quy trình doanh nghiệp hỗ trợ Queue Mode (Redis), Dedicated Worker, PostgreSQL, FFmpeg và Puppeteer.
- **[Supabase Self-Hosted Installer](./supabase)**: Giải pháp backend mã nguồn mở thay thế Firebase gồm Studio dashboard, Auth, PostgREST, Realtime, lưu trữ MinIO và Edge Functions.

#### 3. Thu Thập Dữ Liệu & Web Crawling
- **[Firecrawl](./firecrawl)**: Dịch vụ API chuyên nghiệp biến toàn bộ trang web phức tạp thành dữ liệu Markdown/JSON có cấu trúc cho LLM.
- **[AnyCrawl Stack](./anycrawl)**: Hệ thống cào dữ liệu web đa tầng tích hợp SearXNG, cơ sở dữ liệu PostgreSQL, lưu trữ MinIO và AI MCP Server.
- **[Crawl4AI](./crawl4ai)**: Công cụ cào web bất đồng bộ tốc độ cao trích xuất HTML sang Markdown tối ưu cho mô hình ngôn ngữ lớn.
- **[Scrapling](./scrapling)**: Dịch vụ cào dữ liệu thông minh vượt qua các hệ thống phát hiện bot tự động.

#### 4. CRM, Marketing & Ứng Dụng Doanh Nghiệp
- **[Twenty CRM](./twenty)**: Hệ thống CRM thế hệ mới giao diện tương tự Notion, hỗ trợ GraphQL API, Postgres và hàng đợi Redis.
- **[EspoCRM](./espocrm)**: Nền tảng CRM doanh nghiệp tin cậy với giao diện web responsive, cơ sở dữ liệu MariaDB và thông báo thời gian thực WebSocket.
- **[Mautic](./mautic)**: Nền tảng tự động hoá Marketing hàng đầu hỗ trợ chiến dịch email, phân khúc khách hàng và cron workers.
- **[Listmonk](./listmonk)**: Trình quản lý bản tin (newsletter) và danh sách gửi thư tốc độ cao dùng cơ sở dữ liệu PostgreSQL.
- **[Postiz](./postiz)**: Nền tảng lên lịch và tự động hoá mạng xã hội đa kênh với 2 profile kiến trúc (Bản nhẹ 1.5GB RAM vs Bản đầy đủ).

#### 5. Phân Tích Dữ Liệu, Giám Sát & Hạ Tầng
- **[PostHog](./posthog)**: Nền tảng phân tích sản phẩm toàn diện (event tracking, session replay, feature flags) kèm bản vá runtime preflight tự động.
- **[Matomo](./matomo)**: Nền tảng phân tích lưu lượng web tôn trọng quyền riêng tư, lưu trữ MariaDB và tuân thủ GDPR/không cần cookie.
- **[Prometheus](./prometheus)**: Hệ thống giám sát và cơ sở dữ liệu chuỗi thời gian tiêu chuẩn công nghiệp kèm rules cảnh báo mẫu và Node Exporter.
- **[Grafana](./grafana)**: Bộ bảng điều khiển trực quan hoá dữ liệu với cấu hình tự động datasource Prometheus và dashboard starter.
- **[Headscale](./headscale)**: Triển khai máy chủ điều phối mạng riêng ảo Tailscale tự lưu trữ với SQLite.
- **[Proxies (Caddy)](./proxies)**: Trình quản lý reverse proxy HTTPS hiện đại sử dụng Caddy với chứng chỉ Let's Encrypt tự động.
- **[Raspberry Pi Toolbox](./raspberry-pi)**: Bộ công cụ thiết lập máy tính nhúng (Docker, Portainer, tinh chỉnh RAM và swap).
- **[WordOps Automated Backup](./wordops)**: Hệ thống sao lưu và khôi phục tự động cho máy chủ WordOps LEMP mã hoá GPG và lên lịch cron.

---

### 🚀 Hướng Dẫn Sử Dụng Nhanh

Mỗi công cụ có thể được cài đặt độc lập bằng cách tải trực tiếp script `setup.sh`:

```bash
# Ví dụ: Cài đặt n8n độc lập
mkdir -p ~/self-hosted/n8n && cd ~/self-hosted/n8n
curl -fsSL https://raw.githubusercontent.com/duynghien/auto/main/n8n/setup.sh -o setup.sh
chmod +x setup.sh
./setup.sh
```

Sau khi cài đặt, sử dụng CLI helper tương ứng trong thư mục để quản lý:
```bash
./n8n.sh status       # Xem trạng thái containers
./n8n.sh backup       # Sao lưu database và .env an toàn
./n8n.sh doctor       # Chạy kiểm tra chuẩn đoán sức khoẻ hệ thống
./n8n.sh upgrade      # Kéo images mới nhất và khởi động lại
```

---

### 📜 Kiểm Tra Tính Tương Thích & Đảm Bảo Chất Lượng
Toàn bộ kho lưu trữ được bảo đảm bằng bộ kiểm thử tự động `tests/verify-embedded-sync.sh`:
```bash
bash tests/verify-embedded-sync.sh
```
Bộ kiểm thử xác nhận:
- 100% 24 trình cài đặt `setup.sh` tồn tại và có quyền thực thi.
- 100% tệp cấu hình và CLI helpers đồng bộ với template nhúng.
- 100% các liên kết symlink chuẩn hoá hợp lệ.
- 100% tất cả các script shell trong toàn bộ kho lưu trữ vượt qua kiểm tra cú pháp `bash -n` và đạt chuẩn `shellcheck -S error`.

---

**Tác giả**: [duynghien](https://github.com/duynghien)
