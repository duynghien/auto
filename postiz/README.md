# Postiz Auto Setup (v3.0) | Cài đặt tự động Postiz

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

Automated setup script for **Postiz** — the open-source social media scheduler — on macOS and Ubuntu (ARM64/AMD64).

### 🚀 Stack Overview

| Component | Description |
|---|---|
| **Postiz App** | Next.js frontend & backend (port 5000) |
| **Postgres 17** | Primary database |
| **Redis 7** | Queue & Caching |
| **Temporal** | Workflow engine for scheduling |

> **Note**: A reverse proxy (Caddy, Nginx, or Cloudflare Tunnel) is required separately for HTTPS and public access. See [Reverse Proxy Setup](#-reverse-proxy-setup-required) below.

### 🛠 Installation

```bash
mkdir -p ~/self-hosted/postiz && cd ~/self-hosted/postiz
curl -O https://raw.githubusercontent.com/duynghien/auto/main/postiz/setup.sh
chmod +x setup.sh
./setup.sh
```

The script asks for your **domain name** (e.g., `postiz.example.com`). A public HTTPS domain is required for social media OAuth callbacks to work.

### 🔌 Reverse Proxy Setup (Required)

After installation, Postiz runs on `localhost:5000`. You need a reverse proxy to expose it publicly with HTTPS, because social platforms (X, LinkedIn, Facebook...) require a valid HTTPS callback URL.

<details>
<summary><b>Option A: Caddy (Recommended — auto SSL)</b></summary>

Create a `Caddyfile` in `~/self-hosted/postiz/`:

```
postiz.example.com {
    reverse_proxy localhost:5000
}
```

Add Caddy to your `docker-compose.yml`:

```yaml
  caddy:
    image: caddy:2-alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - caddy_data:/data
      - caddy_config:/config
      - ./Caddyfile:/etc/caddy/Caddyfile
    network_mode: host

volumes:
  caddy_data:
  caddy_config:
```

Then run:
```bash
docker compose up -d caddy
```
</details>

<details>
<summary><b>Option B: Cloudflare Tunnel (No open ports)</b></summary>

1. Create a tunnel at [Cloudflare Dashboard](https://one.dash.cloudflare.com) → Networks → Tunnels
2. Install cloudflared:
   ```bash
   # macOS
   brew install cloudflared

   # Linux
   curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg
   echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
   sudo apt update && sudo apt install cloudflared
   ```
3. Configure the tunnel to route your domain to `http://localhost:5000`
4. Run:
   ```bash
   cloudflared tunnel run <your-tunnel-name>
   ```
</details>

<details>
<summary><b>Option C: Nginx</b></summary>

```nginx
server {
    listen 80;
    server_name postiz.example.com;

    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Then use Certbot for SSL:
```bash
sudo certbot --nginx -d postiz.example.com
```
</details>

### 📋 Post-Install & Configuration

#### 1. Create Admin Account
- Open your domain (e.g., `https://postiz.yourdomain.com`).
- Click **"Sign up"** to create the first admin account.

#### 2. Configure Social Media APIs
To post to Twitter/X, LinkedIn, Facebook, etc., create developer apps on each platform and add the keys to `.env`.

**Callback URL format:** `https://your-domain.com/integrations/social/<platform>`

**Official Guides:**
- [Twitter / X Setup](https://docs.postiz.com/platforms/twitter)
- [LinkedIn Setup](https://docs.postiz.com/platforms/linkedin)
- [Facebook / Instagram Setup](https://docs.postiz.com/platforms/facebook)
- [Other Platforms](https://docs.postiz.com/platforms/introduction)

**How to add keys:**
```bash
cd ~/self-hosted/postiz
nano .env
```
Find the `Social Media` section and paste your keys:
```bash
X_API_KEY="your_api_key"
X_API_SECRET="your_api_secret"
LINKEDIN_CLIENT_ID="your_client_id"
LINKEDIN_CLIENT_SECRET="your_client_secret"
```
Save (`Ctrl+O`, `Enter`) and Exit (`Ctrl+X`).

#### 3. Restart Application
```bash
./postiz.sh restart
```

### 🛠 Management

Use the included helper script `./postiz.sh`:
```bash
./postiz.sh status   # Check containers
./postiz.sh logs     # View live logs
./postiz.sh restart  # Restart stack
./postiz.sh update   # Pull latest images
```

---

## Tiếng Việt

Script cài đặt tự động **Postiz** — công cụ lập lịch đăng bài mạng xã hội mã nguồn mở — trên macOS và Ubuntu.

### 🚀 Hệ thống gồm

| Thành phần | Mô tả |
|---|---|
| **Postiz App** | Ứng dụng chính (Next.js, port 5000) |
| **Postgres 17** | Cơ sở dữ liệu chính |
| **Redis 7** | Bộ nhớ đệm & hàng đợi |
| **Temporal** | Engine quản lý quy trình lập lịch |

> **Lưu ý**: Cần cài thêm Reverse Proxy (Caddy, Nginx, hoặc Cloudflare Tunnel) riêng để có HTTPS. Xem [hướng dẫn bên dưới](#-cài-reverse-proxy-bắt-buộc).

### 🛠 Cài đặt nhanh

```bash
mkdir -p ~/self-hosted/postiz && cd ~/self-hosted/postiz
curl -O https://raw.githubusercontent.com/duynghien/auto/main/postiz/setup.sh
chmod +x setup.sh
./setup.sh
```

Script sẽ hỏi **tên miền** (ví dụ `postiz.example.com`). Bắt buộc phải có domain public HTTPS để OAuth callback từ các nền tảng social hoạt động.

### 🔌 Cài Reverse Proxy (Bắt buộc)

Sau khi cài, Postiz chạy trên `localhost:5000`. Bạn cần reverse proxy để expose ra domain HTTPS, vì các nền tảng (X, LinkedIn, Facebook...) yêu cầu callback URL phải là HTTPS domain hợp lệ.

**Xem 3 tùy chọn:** Caddy (tự động SSL), Cloudflare Tunnel (không cần mở port), hoặc Nginx — tại [phần English ở trên](#-reverse-proxy-setup-required).

### 📋 Hướng dẫn sau cài đặt

#### 1. Tạo tài khoản Admin
- Truy cập domain (vd: `https://postiz.yourdomain.com`).
- Bấm **"Sign up"** để tạo tài khoản quản trị đầu tiên.

#### 2. Cấu hình API Mạng xã hội
Để đăng bài lên X (Twitter), LinkedIn, Facebook..., bạn cần tạo App trên trang Developer của từng nền tảng và lấy API Key.

**Callback URL:** `https://domain-cua-ban.com/integrations/social/<platform>`

**Tài liệu hướng dẫn:**
- [Twitter / X](https://docs.postiz.com/platforms/twitter)
- [LinkedIn](https://docs.postiz.com/platforms/linkedin)
- [Facebook / Instagram](https://docs.postiz.com/platforms/facebook)
- [Các nền tảng khác](https://docs.postiz.com/platforms/introduction)

**Cách thêm Key vào Postiz:**
```bash
cd ~/self-hosted/postiz
nano .env
```
Tìm đến mục `Social Media` và điền key:
```bash
X_API_KEY="điền_key_vào_đây"
X_API_SECRET="điền_secret_vào_đây"
```
Lưu file (`Ctrl+O`, `Enter`) và thoát (`Ctrl+X`).

#### 3. Khởi động lại
```bash
./postiz.sh restart
```

### 🛠 Quản lý

Sử dụng script `./postiz.sh`:
```bash
./postiz.sh status   # Xem trạng thái
./postiz.sh logs     # Xem logs thời gian thực
./postiz.sh restart  # Khởi động lại
./postiz.sh update   # Cập nhật phiên bản mới
```

### 📂 Cấu trúc thư mục
- `.env` — Cấu hình chính + API Keys
- `docker-compose.yml` — Cấu hình Docker
- `dynamicconfig/` — Temporal config
- `postiz.sh` — Script quản lý nhanh

### ⚠️ Lưu ý về Tài nguyên
Postiz yêu cầu **Temporal Stack** (gồm ElasticSearch + Postgres riêng) nên khá nặng.
- **RAM tối thiểu**: 4GB (8GB khuyến nghị)
- **CPU**: 2 vCPU+

## Troubleshooting

### Error: Authentication failed (P1000) khi cài lại
Khi cài lại mà không xóa Docker volumes, password cũ vẫn còn trong database.
**Fix:**
```bash
cd ~/self-hosted/postiz
docker compose down -v   # Xóa volumes cũ
./setup.sh               # Cài lại
```
> **Lưu ý**: Script v3.0 tự động `docker compose down -v` trước khi start.

### Port 5000 bị chiếm (macOS)
Trên macOS, AirPlay Receiver chiếm port 5000. Tắt AirPlay Receiver:
> **System Settings → AirDrop & Handoff → AirPlay Receiver → OFF**

## 🤝 Support & Community

- **Website**: [vnrom.net](https://vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
- **Community**: [AI & Automation (vnROM)](https://ai.vnrom.net)
- **Postiz**: [postiz.com](https://postiz.com)