# Headscale Self-Hosted — Unified Setup / Cài đặt Tự động
> 🇺🇸 **English** | 🇻🇳 **Tiếng Việt** — scroll down for Vietnamese / cuộn xuống để đọc Tiếng Việt
---
## 🇺🇸 English
One-script installer for Headscale (self-hosted Tailscale control server) with Headscale-UI enabled. Auto-detects your platform:
| Platform | Arch | Database | Memory Limits |
|---|---|---|---|
| **macOS** (Apple Silicon) | arm64 | SQLite | None |
| **Raspberry Pi** (4/5) | aarch64 | SQLite | Yes |
| **VPS — ARM64 / AMD64** | aarch64 / x86_64 | SQLite | None |
### Stack
| Component | Purpose |
|---|---|
| **Headscale** | Tailscale control server |
| **Headscale-UI** | Web-based dashboard for managing networks/users |
### Quick Install
```bash
# Create directory and download script
mkdir -p ~/self-hosted/headscale && cd ~/self-hosted/headscale
curl -O https://raw.githubusercontent.com/duynghien/auto/main/headscale/setup.sh
# Run setup
chmod +x setup.sh
./setup.sh
```
The script will:
1. Detect your OS and architecture
2. Install Docker if needed (Linux only)
3. Prompt for Domain configuration (highly recommended over IPs)
4. Ask if you want to include Headscale-UI
5. Create optimized `config.yaml` and `docker-compose.yml`
6. Start the Headscale network server
7. Create a `headscale.sh` helper script
### Features Included
- ✅ **Self-Hosted Mesh VPN** — Drop-in replacement for Tailscale SaaS
- ✅ **Headscale-UI** — Intuitive web interface to manage users and preauthkeys
- ✅ **Bilingual Installer** — Support for English and Vietnamese
### Management
After installation, use the `headscale.sh` helper (it maps directly to the container):
```bash
./headscale.sh start        # Start all services
./headscale.sh stop         # Stop all services
./headscale.sh restart      # Restart all services
./headscale.sh upgrade      # Pull latest images & restart
./headscale.sh logs         # View headscale logs
./headscale.sh status       # Show container status
# Headscale Commands
./headscale.sh users                        # List users
./headscale.sh nodes                        # List nodes
./headscale.sh apikey                       # Generate an API key (valid 90d) for the Web UI
./headscale.sh cmd users create alice       # Create user 'alice'
./headscale.sh cmd preauthkeys create -u alice # Generate an auth key for 'alice'
```
### Platform Notes
#### macOS
- Requires [OrbStack](https://orbstack.dev) or Docker Desktop pre-installed
- Important: Localhost VPN setups usually don't work well due to NAT loopbacks. Recommended to use a tunnel (e.g., ngrok/cloudflared) or public VPS.
#### Raspberry Pi / VPS
- Auto-installs Docker if missing
- Use a reverse proxy (Caddy/Nginx) for HTTPS and direct your public domain to it.
---
## 🇻🇳 Tiếng Việt
Script cài đặt Headscale tự động (máy chủ điều khiển Tailscale tự lưu trữ) kèm Headscale-UI. Tự nhận diện nền tảng:
| Nền tảng | Kiến trúc | Cơ sở dữ liệu | Giới hạn RAM |
|---|---|---|---|
| **macOS** (Apple Silicon) | arm64 | SQLite | Không |
| **Raspberry Pi** (4/5) | aarch64 | SQLite | Có |
| **VPS — ARM64 / AMD64** | aarch64 / x86_64 | SQLite | Không |
### Thành phần
| Thành phần | Mục đích |
|---|---|
| **Headscale** | Máy chủ điều khiển Tailscale (Control Plane) |
| **Headscale-UI** | Giao diện web quản lý user và mạng |
### Cài đặt nhanh
```bash
# Tạo thư mục và tải script
mkdir -p ~/self-hosted/headscale && cd ~/self-hosted/headscale
curl -O https://raw.githubusercontent.com/duynghien/auto/main/headscale/setup.sh
# Chạy script
chmod +x setup.sh
./setup.sh
```
Script sẽ:
1. Nhận diện hệ điều hành và kiến trúc
2. Cài Docker nếu cần (chỉ Linux)
3. Hỏi cấu hình Domain mạng (Khuyến nghị dùng domain có HTTPS)
4. Hỏi có bật Headscale-UI không
5. Tạo file `config.yaml` và `docker-compose.yml` tối ưu
6. Khởi động máy chủ VPN Headscale
7. Tạo script quản lý `headscale.sh`
### Quản lý
Sau khi cài đặt, sử dụng script `headscale.sh`:
```bash
./headscale.sh start        # Khởi động services
./headscale.sh stop         # Dừng services
./headscale.sh restart      # Khởi động lại
./headscale.sh upgrade      # Cập nhật version mới nhất
./headscale.sh logs         # Xem logs container
./headscale.sh status       # Xem trạng thái
# Lệnh Headscale
./headscale.sh users                        # Danh sách users
./headscale.sh nodes                        # Danh sách thiết bị (nodes)
./headscale.sh apikey                       # Tạo API Key cho Web UI (hết hạn 90 ngày)
./headscale.sh cmd users create alice       # Tạo user mới tên 'alice'
./headscale.sh cmd preauthkeys create -u alice # Sinh token kết nối thiết bị cho 'alice'
```
### Lưu ý theo nền tảng
- **Headscale cần chạy trên môi trường có IP public hoặc domain public** (có HTTPS) để các client (điện thoại, máy tính) bên ngoài có thể kết nối vào qua mesh VPN.
- Trên VPS, bạn nên kết hợp dùng Nginx/Caddy Reverse Proxy để trỏ HTTPS (port 443) về nội bộ port 8080.
