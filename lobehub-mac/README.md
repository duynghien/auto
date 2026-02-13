# LobeHub macOS Apple Silicon Setup v3.0 

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

The most optimized automatic installation script for **LobeHub** on **macOS (M1/M2/M3/M4)**. Fully integrated with advanced features: Knowledge Base, Online Search, S3 Storage, and Artifacts.

### ✨ Highlights (v3.0)
- **🚀 Peak Performance**: Optimized for Apple Silicon M-series. Runs best on [OrbStack](https://orbstack.dev/) or Docker Desktop.
- **🧠 Knowledge Base (RAG)**: Powered by **ParadeDB** (PostgreSQL + pg_search + pgvector) for faster and more accurate searching.
- **🔍 Online Search**: Built-in self-hosted **SearXNG**, providing web search capabilities for LLMs without needing Google/Tavily API keys.
- **📦 Versatile S3 Storage**: Choose between **RustFS** (ultra-lightweight, fast) or **MinIO** (stable, traditional) for file and image storage.
- **🛠️ Lobe Helper (`./lobe.sh`)**: A powerful management script—no need to remember complex Docker Compose commands.
- **🔒 Private & Secure**: All data and secrets stay strictly on your local machine.

### 📋 Requirements
- **Hardware**: Mac with M1, M2, M3, or M4 chip.
- **Software**: [OrbStack](https://orbstack.dev/) recommended (faster, lower RAM/CPU footprint than Docker Desktop).
- **Network**: Internet connection required for downloading Docker images and initial configuration.

### 🛠️ Installation Guide

Open your Terminal and run this single command (everything will be auto-configured):

```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/lobehub-mac/setup.sh
chmod +x setup.sh
./setup.sh
```

### ⚙️ System Management with `lobe.sh`

After installation, use the `~/lobehub-mac/lobe.sh` helper to manage your instance.

| Command | Feature |
|------|-----------|
| `./lobe.sh start` | Start all services |
| `./lobe.sh stop` | Stop all services |
| `./lobe.sh restart` | Restart the system |
| `./lobe.sh upgrade` | Upgrade LobeHub to latest version |
| `./lobe.sh logs` | View logs (default: `lobe` container) |
| `./lobe.sh status` | Check container status |
| `./lobe.sh search-test` | Test SearXNG search functionality |
| `./lobe.sh secrets` | Show `.env` configuration |
| `./lobe.sh s3-login` | View S3 Storage credentials |
| `./lobe.sh reset` | **⚠️ Delete ALL data** (use with caution) |

### 📁 Directory Structure
- `data/`: PostgreSQL (ParadeDB) database data.
- `searxng-settings.yml`: Configuration for the SearXNG engine.
- `.env`: Contains all passwords and secrets (DO NOT share).
- `lobe.sh`: System management script.

### 🗺️ Access URLs
- **LobeHub**: [http://localhost:3210](http://localhost:3210)
- **S3 Console**: [http://localhost:9001](http://localhost:9001)

---

## 🤝 Support & Community
- **Website**: [vnrom.net](https://vnrom.net)
- **Community**: [AI & Automation (vnROM)](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)

---

## Tiếng Việt

Bộ cài đặt tự động LobeHub tối ưu nhất dành cho **macOS (M1/M2/M3/M4)**. Tích hợp đầy đủ các tính năng nâng cao: Knowledge Base, Online Search, S3 Storage và Artifacts.

### ✨ Điểm nổi bật (v3.0)
- **🚀 Hiệu suất cực đỉnh**: Tối ưu hóa cho Apple Silicon M-series. Chạy mượt mà nhất trên [OrbStack](https://orbstack.dev/) hoặc Docker Desktop.
- **🧠 Knowledge Base (RAG)**: Sử dụng **ParadeDB** (PostgreSQL + pg_search + pgvector) cho khả năng tìm kiếm nhanh và chính xác hơn.
- **🔍 Tìm kiếm trực tuyến**: Tích hợp sẵn **SearXNG** tự host, cung cấp khả năng tìm kiếm web cho LLM mà không cần API key Google/Tavily.
- **📦 S3 Storage tùy chọn**: Lựa chọn giữa **RustFS** (siêu nhẹ, nhanh) hoặc **MinIO** (ổn định, truyền thống) để lưu trữ file và ảnh.
- **🛠️ Lobe Helper (`./lobe.sh`)**: Script quản lý mạnh mẽ, không cần nhớ lệnh Docker Compose phức tạp.
- **🔒 Bảo mật tuyệt đối**: Dữ liệu và secrets lưu hoàn toàn trên máy local của bạn.

### 📋 Yêu cầu hệ thống
- **Hardware**: Mac chip M1, M2, M3 hoặc M4.
- **Software**: Khuyên dùng [OrbStack](https://orbstack.dev/) (nhanh hơn, tốn ít RAM/CPU hơn Docker Desktop).
- **Network**: Kết nối internet để tải Docker images và cấu hình ban đầu.

### 🛠️ Hướng dẫn cài đặt

Mở Terminal và chạy lệnh duy nhất (tất cả sẽ được tự động cấu hình):

```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/lobehub-mac/setup.sh
chmod +x setup.sh
./setup.sh
```

### ⚙️ Quản lý hệ thống với `lobe.sh`

Sau khi cài đặt, bạn sẽ sử dụng file `~/lobehub-mac/lobe.sh` để quản lý mọi thứ.

| Lệnh | Tính năng |
|------|-----------|
| `./lobe.sh start` | Khởi động toàn bộ dịch vụ |
| `./lobe.sh stop` | Dừng toàn bộ dịch vụ |
| `./lobe.sh restart` | Khởi động lại hệ thống |
| `./lobe.sh upgrade` | Cập nhật LobeHub lên bản mới nhất |
| `./lobe.sh logs` | Xem log (mặc định là container `lobe`) |
| `./lobe.sh status` | Kiểm tra trạng thái các container |
| `./lobe.sh search-test` | Kiểm tra tính năng tìm kiếm SearXNG |
| `./lobe.sh secrets` | Hiển thị nội dung file cấu hình `.env` |
| `./lobe.sh s3-login` | Xem thông tin đăng nhập S3 Storage |
| `./lobe.sh reset` | **⚠️ Xóa sạch dữ liệu** (cẩn trọng khi dùng) |

### 📁 Cấu trúc thư mục
- `data/`: Dữ liệu database PostgreSQL (ParadeDB).
- `searxng-settings.yml`: Cấu hình cho bộ máy tìm kiếm SearXNG.
- `.env`: Chứa toàn bộ mật khẩu và secrets (KHÔNG chia sẻ file này).
- `lobe.sh`: Script quản lý hệ thống.

### 🗺️ Địa chỉ truy cập
- **LobeHub**: [http://localhost:3210](http://localhost:3210)
- **S3 Console**: [http://localhost:9001](http://localhost:9001)

---

## 🤝 Support & Community
- **Website**: [vnrom.net](https://vnrom.net)
- **Community**: [AI & Automation (vnROM)](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
