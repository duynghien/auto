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
# Clone repo
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git
cd auto/proxies

# Run setup
chmod +x setup.sh
./setup.sh
```

**Note**: The script will automatically install everything into `~/self-hosted/proxies`, regardless of where you run it from.

### Features
- **OS Detection**: Auto-installs Docker on Linux/Pi if missing.
- **Interactive Menu**: Choose your preferred proxy.
- **Dynamic Config**: Generates `docker-compose.yml` based on selection.
- **Network Ready**: Creates a `proxy-network` for other containers to join.

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
# Tải mã nguồn
mkdir -p ~/self-hosted
cd ~/self-hosted
git clone https://github.com/duynghien/auto.git
cd auto/proxies

# Chạy cài đặt
chmod +x setup.sh
./setup.sh
```

**Lưu ý**: Script sẽ tự động cài đặt mọi thứ vào thư mục `~/self-hosted/proxies`, bất kể bạn chạy script từ đâu.

### Tính năng
- **Tự nhận diện OS**: Tự cài Docker trên Linux/Pi nếu chưa có.
- **Menu lựa chọn**: Chọn loại proxy bạn muốn dùng.
- **Cấu hình động**: Tự tạo `docker-compose.yml` theo lựa chọn.
- **Mạng Proxy**: Tạo sẵn `proxy-network` để các container khác kết nối vào.

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
