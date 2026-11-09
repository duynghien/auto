# Universal Proxy Setup

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

A unified setup script for managing Reverse Proxies on **macOS**, **Raspberry Pi**, and **Linux VPS**. Supports 3 popular solutions:

### Supported Proxies

| Option | Proxy | Best For | Ports |
|---|---|---|---|
| **1** | **Nginx Proxy Manager** (NPM) | GUI management, Auto SSL | 80, 443, 81 |
| **2** | **Cloudflare Tunnel** | Secure remote access, no open ports | None |
| **3** | **Caddy** | Simple configuration via Caddyfile | 80, 443 |

### Installation

```bash
# Create directory and download script
mkdir -p ~/self-hosted/proxies && cd ~/self-hosted/proxies
curl -O https://raw.githubusercontent.com/duynghien/auto/main/proxies/setup.sh

# Run setup
chmod +x setup.sh
./setup.sh
```

**Note**: The script will automatically install everything into `~/self-hosted/proxies`, regardless of where you run it from.

### Management CLI (`./proxies.sh`)

Navigate to your install directory (`cd ~/self-hosted/proxies`) to manage the proxy stack:

```bash
./proxies.sh status      # View running proxy containers and active ports
./proxies.sh start       # Start proxy containers
./proxies.sh stop        # Stop proxy containers
./proxies.sh restart     # Restart proxy containers
./proxies.sh reload      # Hot-reload Caddyfile or restart proxy
./proxies.sh logs        # Follow container logs
./proxies.sh update      # Pull latest container images and restart
./proxies.sh backup      # Archive configs, certificates and .env to ./backups/ (chmod 700)
./proxies.sh restore <f> # Verify archive integrity (gzip -t), snapshot, and restore
./proxies.sh doctor      # Diagnostic check on Docker, ports 80/443/81, and permissions
./proxies.sh uninstall   # Safely stop and remove containers
```

### Connecting Other Services

To expose other Docker containers (like LobeHub, Portainer) through this proxy, add them to the `proxy-network`:

```yaml
services:
  myapp:
    image: myapp
    networks:
      - proxy-network

networks:
  proxy-network:
    external: true
```

Then in Nginx Proxy Manager, point the host to `http://myapp:port`.

---

## Tiếng Việt

Script cài đặt Proxy đa năng cho **macOS**, **Raspberry Pi**, và **VPS**. Hỗ trợ 3 loại proxy phổ biến nhất:

### Các lựa chọn

| Số | Proxy | Ưu điểm | Ports |
|---|---|---|---|
| **1** | **Nginx Proxy Manager** (NPM) | Giao diện quản lý trực quan, tự động SSL | 80, 443, 81 |
| **2** | **Cloudflare Tunnel** | Truy cập từ xa bảo mật, không cần mở port | Không |
| **3** | **Caddy** | Cấu hình đơn giản qua file text | 80, 443 |

### Cài đặt

```bash
# Tạo thư mục và tải script
mkdir -p ~/self-hosted/proxies && cd ~/self-hosted/proxies
curl -O https://raw.githubusercontent.com/duynghien/auto/main/proxies/setup.sh

# Chạy cài đặt
chmod +x setup.sh
./setup.sh
```

**Lưu ý**: Script sẽ tự động cài đặt mọi thứ vào thư mục `~/self-hosted/proxies`, bất kể bạn chạy script từ đâu.

### Lệnh Quản Lý (`./proxies.sh`)

Di chuyển vào thư mục cài đặt (`cd ~/self-hosted/proxies`):

```bash
./proxies.sh status      # Kiểm tra trạng thái container và cổng kết nối
./proxies.sh start       # Khởi động dịch vụ proxy
./proxies.sh stop        # Dừng dịch vụ proxy
./proxies.sh restart     # Khởi động lại dịch vụ
./proxies.sh reload      # Tải lại cấu hình Caddyfile không gián đoạn hoặc restart
./proxies.sh logs        # Xem log thời gian thực
./proxies.sh update      # Cập nhật image mới nhất
./proxies.sh backup      # Sao lưu cấu hình và chứng chỉ SSL vào ./backups/ (phân quyền an toàn)
./proxies.sh restore <f> # Kiểm tra file backup, tạo snapshot an toàn rồi khôi phục
./proxies.sh doctor      # Chẩn đoán trạng thái Docker, cổng 80/443/81 và quyền file
./proxies.sh uninstall   # Gỡ cài đặt và dọn dẹp an toàn
```

### Hướng dẫn kết nối

Để đưa các dịch vụ khác (như LobeHub, Portainer) ra ngoài internet qua Proxy này, hãy thêm chúng vào mạng `proxy-network`:

```yaml
services:
  myapp:
    image: myapp
    networks:
      - proxy-network

networks:
  proxy-network:
    external: true
```

Sau đó trong Nginx Proxy Manager, trỏ host về `http://myapp:port`.

---

## Support

- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
