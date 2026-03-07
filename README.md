# duynghien auto-scripts 🚀

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

A collection of automation scripts for system installation and configuration, ranging from Raspberry Pi devices to complex AI Agent ecosystems. All scripts are designed for rapid (1-Click) deployment and security.

### 📂 Tool Directory

#### 1. [OpenClaw + n8n + MCP Stack](./openclaw-n8n-mcp)
Deployment solution for AI Agents (OpenClaw) integrated with n8n and the Model Context Protocol (MCP).
- **Target**: VPS (Ubuntu 22.04+).
- **Features**: Installs OpenClaw, n8n, MCP Server, Caddy, Postgres, Redis.

#### 2. [n8n Self-Hosted Installer](./n8n)
Unified script for n8n via Docker Compose with optional advanced modules.
- **Target**: macOS, Raspberry Pi, VPS (AMD64/ARM64).
- **Features**: Optional Worker, Queue Mode, PostgreSQL, Redis, FFmpeg, Puppeteer dependencies, Task Runners.

#### 3. [LobeHub Mac Installer](./lobehub-mac)
Optimized script for Mac (M1/M2/M3/M4) using OrbStack or Docker Desktop to install LobeHub v3.0+.
- **Target**: Mac Mini, MacBook (Apple Silicon).
- **Features**: Optimized for M-series, ParadeDB (PostgreSQL + pg_search + pgvector), Local S3 (RustFS/MinIO), SearXNG Search.

#### 4. [AnyCrawl "Max Option" Stack](./anycrawl)
Bilingual deployment script for AnyCrawl with PostgreSQL, MinIO, Redis, and MCP integration.
- **Target**: Mac (M1/M2/M3/M4), Raspberry Pi (4/5), VPS.
- **Features**: PostgreSQL 17, MinIO S3, SearXNG, MCP Server (AI Interface).

#### 5. [LobeHub Pi Installer](./lobehub-pi)
Automation script for installing LobeHub v2.0+ (database version) optimized for Raspberry Pi.
- **Target**: Raspberry Pi 4 (8GB) / Pi 5 (ARM64).
- **Features**: PostgreSQL + pgvector, S3 Storage, Search Engine, Redis.

#### 6. [Raspberry Pi ARM Toolbox](./raspberry-pi)
A set of optimized scripts specifically for Raspberry Pi or ARM-based devices.
- **Target**: Raspberry Pi 4/5, ARM servers.
- **Features**: Installs Docker, Docker Compose, Portainer.

#### 7. [Prometheus Self-Hosted Installer](./prometheus)
Unified script for Prometheus monitoring via Docker Compose with bilingual onboarding.
- **Target**: macOS, Raspberry Pi, VPS (AMD64/ARM64).
- **Features**: Prometheus server, starter alert rules, Linux node-exporter, helper commands.

#### 8. [Grafana Self-Hosted Installer](./grafana)
Unified script for Grafana dashboards with pre-provisioned Prometheus integration.
- **Target**: macOS, Raspberry Pi, VPS (AMD64/ARM64).
- **Features**: Grafana server, Prometheus datasource provisioning, starter dashboard, helper commands.

---

### 🛠️ General Usage

To get started, clone this entire repository to your local machine or server:

```bash
git clone https://github.com/duynghien/auto.git
cd auto
```

Then, navigate to the corresponding directory to run the installation script.

---

### 🤝 Contact & Support
- **Website**: [vnrom.net](https://vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
- **Community**: [AI & Automation (vnROM)](https://ai.vnrom.net) - Support for AI & Automation deployment.

---

## Tiếng Việt

Tập hợp các script tự động hóa cho việc cài đặt và cấu hình hệ thống, từ các thiết bị Raspberry Pi đến hệ sinh thái AI Agent phức tạp. Tất cả các script được thiết kế để triển khai nhanh chóng (1-Click) và bảo mật.

### 📂 Danh mục công cụ

#### 1. [OpenClaw + n8n + MCP Stack](./openclaw-n8n-mcp)
Giải pháp triển khai AI Agents (OpenClaw) tích hợp với n8n và Model Context Protocol (MCP).
- **Đối tượng**: VPS (Ubuntu 22.04+).
- **Tính năng**: Cài đặt OpenClaw, n8n, MCP Server, Caddy, Postgres, Redis.

#### 2. [n8n Self-Hosted Installer](./n8n)
Script thống nhất triển khai n8n bằng Docker Compose với nhiều tùy chọn mở rộng.
- **Đối tượng**: macOS, Raspberry Pi, VPS (AMD64/ARM64).
- **Tính năng**: Tùy chọn Worker, Queue Mode, PostgreSQL, Redis, FFmpeg, Puppeteer dependencies, Task Runners.

#### 3. [LobeHub Mac Installer](./lobehub-mac)
Script tối ưu cho Mac (M1/M2/M3/M4) sử dụng OrbStack hoặc Docker Desktop để cài đặt LobeHub v3.0+.
- **Đối tượng**: Mac Mini, MacBook (Apple Silicon).
- **Tính năng**: Tối ưu cho chip M, ParadeDB (PostgreSQL + pg_search + pgvector), Local S3 (RustFS/MinIO), SearXNG Search.

#### 4. [AnyCrawl "Max Option" Stack](./anycrawl)
Script triển khai AnyCrawl với PostgreSQL, MinIO, Redis và tích hợp MCP.
- **Đối tượng**: Mac (M1/M2/M3/M4), Raspberry Pi (4/5), VPS.
- **Tính năng**: PostgreSQL 17, MinIO S3, SearXNG, MCP Server (AI Interface).

#### 5. [LobeHub Pi Installer](./lobehub-pi)
Script tự động cài đặt LobeHub v2.0+ (bản database) tối ưu cho Raspberry Pi.
- **Đối tượng**: Raspberry Pi 4 (8GB) / Pi 5 (ARM64).
- **Tính năng**: PostgreSQL + pgvector, S3 Storage, Search Engine, Redis.

#### 6. [Raspberry Pi ARM Toolbox](./raspberry-pi)
Tập hợp các script tối ưu riêng cho Raspberry Pi hoặc các thiết bị chạy ARM.
- **Đối tượng**: Raspberry Pi 4/5, ARM servers.
- **Tính năng**: Cài đặt Docker, Docker Compose, Portainer.

#### 7. [Prometheus Self-Hosted Installer](./prometheus)
Script thống nhất triển khai Prometheus bằng Docker Compose với trải nghiệm song ngữ.
- **Đối tượng**: macOS, Raspberry Pi, VPS (AMD64/ARM64).
- **Tính năng**: Prometheus server, rule cảnh báo mẫu, Linux node-exporter, helper commands.

#### 8. [Grafana Self-Hosted Installer](./grafana)
Script thống nhất triển khai Grafana với datasource Prometheus được provision sẵn.
- **Đối tượng**: macOS, Raspberry Pi, VPS (AMD64/ARM64).
- **Tính năng**: Grafana server, provisioning datasource Prometheus, dashboard khởi đầu, helper commands.

---

### 🛠️ Hướng dẫn sử dụng chung

Để bắt đầu, hãy clone toàn bộ repository này về máy hoặc server của bạn:

```bash
git clone https://github.com/duynghien/auto.git
cd auto
```

Sau đó, truy cập vào thư mục tương ứng để chạy script cài đặt.

---

### 🤝 Liên hệ & Hỗ trợ
- **Website**: [vnrom.net](https://vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
- **Community**: [AI & Automation (vnROM)](https://ai.vnrom.net) - Hỗ trợ triển khai AI & Automation.

---
*Lưu ý: Luôn kiểm tra nội dung script trước khi chạy với quyền root.*
