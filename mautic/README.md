# Mautic 7 Self-Hosted (Automated Installer)

> 🇺🇸 **English** | 🇻🇳 **Tiếng Việt**

---

## 🇺🇸 English

Automated setup script for **Mautic 7** (Open Source Marketing Automation) using Docker Compose. This script deploys a modern, full-featured Mautic stack optimized for high performance and stability.

### Features
- **Full Stack Solution**: Mautic 7 + MariaDB + Redis + RabbitMQ + Cron Jobs (via Ofelia) + Queue Worker.
- **High Performance Caching**: Uses **Redis** for accelerated application cache and session handling.
- **Robust Background Processing**: Uses **RabbitMQ** and a dedicated **Mautic Worker** container to process emails, segment updates, and campaigns asynchronously without blocking the UI.
- **Cron Management**: The `ofelia` sidecar container automatically triggers Mautic's scheduled tasks.
- **Multi-Platform**: Works seamlessly on macOS (Apple Silicon), Raspberry Pi (ARM64), and Linux VPS (AMD64/ARM64).

### Quick Install

```bash
# Method 1: Standalone 1-liner
curl -fsSL https://raw.githubusercontent.com/duynghien/auto/main/mautic/setup.sh | bash

# Method 2: Clone repository
git clone https://github.com/duynghien/auto.git
cd auto/mautic
chmod +x setup.sh && ./setup.sh
```

### Management (`mautic` CLI)

Use the helper CLI `mautic` (or `./mautic.sh`):

```bash
mautic status   # Show container status and health diagnostics
mautic logs     # View live logs (or mautic logs <service>)
mautic start    # Start containers
mautic stop     # Stop containers
mautic restart  # Restart stack
mautic update   # Pull latest images and restart
mautic backup   # Dump MariaDB database and archive configurations
mautic restore <archive.sql.gz> # Safely restore database
mautic doctor   # Run diagnostic health check
mautic uninstall # Stop and remove containers and data volumes
```

### Access
- **URL**: `http://localhost:8080` (or your chosen IP/Domain)
- **RabbitMQ Dashboard**: `http://localhost:15672` (Default User: `mautic`)
- **Setup**: Follow the on-screen Mautic installer.
- **Database Driver**: `MySQL/MariaDB`
- **Database Host**: `mautic_db`
- **Database User**: `mautic`
- **Database / RabbitMQ Passwords**: (Automatically generated, check your terminal output or the `.env` file)

### Automated Background Tasks
The following tasks run automatically:
- **Queue Worker (`messenger:consume`)**: Runs continuously to process messages from RabbitMQ.
- **Segment/Campaign Updates**: Every 5 minutes.
- **Email/Broadcast Triggers**: Every 1 minute.
- **Maintenance/Cleanup**: Daily.

---

## 🇻🇳 Tiếng Việt

Script cài đặt tự động **Mautic 7** (Marketing Automation) tối ưu cho self-hosting, cấu hình chuẩn "Production-Ready" với khả năng chịu tải tốt.

### Tính năng nổi bật
- **Full Stack Hiện Đại**: Mautic 7 + MariaDB + Redis + RabbitMQ + Ofelia Cron + Mautic Worker.
- **Tối Ưu Hiệu Suất Cao**: Tích hợp **Redis** để làm cache backend, tăng tốc độ truy xuất dữ liệu & load trang cực nhanh.
- **Hệ Thống Hàng Đợi Mạnh Mẽ**: Sử dụng **RabbitMQ** và **Mautic Worker** chuyên dụng chạy nền liên tục. Đảm bảo việc gửi hàng ngàn email hay xử lý Campaign phức tạp diễn ra mượt mà, không gây đơ lag hệ thống web.
- **Tự động hóa Cron**: Sử dụng container `ofelia` chạy định kỳ các tác vụ của Mautic mà không cần đụng đến crontab của server.
- **Đa Nền Tảng**: Chạy tốt trên macOS M1/M2/M3, Raspberry Pi 4/5 và VPS Linux (cả AMD64 và ARM64).

### Cài đặt nhanh

```bash
# Cách 1: Cài đặt nhanh 1 dòng lệnh (Standalone)
curl -fsSL https://raw.githubusercontent.com/duynghien/auto/main/mautic/setup.sh | bash

# Cách 2: Clone repository
git clone https://github.com/duynghien/auto.git
cd auto/mautic
chmod +x setup.sh && ./setup.sh
```

### Quản lý nhanh với CLI `mautic`

```bash
mautic status   # Kiểm tra trạng thái containers và sức khỏe dịch vụ
mautic logs     # Xem logs (hoặc mautic logs <service>)
mautic start    # Khởi động hệ thống
mautic stop     # Dừng hệ thống
mautic restart  # Khởi động lại
mautic update   # Kéo image mới nhất và restart
mautic backup   # Sao lưu cơ sở dữ liệu MariaDB và cấu hình
mautic restore <file.sql.gz> # Khôi phục cơ sở dữ liệu
mautic doctor   # Kiểm tra chẩn đoán hệ thống
mautic uninstall # Xóa containers và dữ liệu
```

### Hướng Dẫn Sử Dụng
- **Truy cập web**: `http://localhost:8080` (hoặc IP/Domain bạn chọn)
- **Quản lý RabbitMQ**: `http://localhost:15672` (Tài khoản: `mautic`)
- **Cài đặt lần đầu**: Làm theo các bước trên giao diện Mautic.
- **Database Host**: Nhập `mautic_db`
- **Tên DB / User DB**: Nhập `mautic`
- **Mật khẩu DB & RabbitMQ**: Tự động sinh ra (Hãy xem ở màn hình log lúc chạy xong script hoặc mở file `.env`).

### Hệ thống chạy nền tự động
Mọi thứ đã được lên lịch sẵn cho bạn:
- **Queue Worker (`messenger:consume`)**: Chạy liên tục để bắt sự kiện từ RabbitMQ (Gửi mail, trigger action...).
- **Cập nhật Segment/Campaign**: Mỗi 5 phút.
- **Gửi Email chờ / Broadcast**: Mỗi 1 phút.
- **Dọn dẹp hệ thống**: Chạy vào 00:00 mỗi ngày.

### Proxy (Quan trọng)
Nếu bạn chạy trên VPS với tên miền thật, hãy sử dụng **Unified Proxy** (Cloudflare Tunnel hoặc Nginx Proxy Manager) để có SSL (HTTPS). Cấu hình Proxy trỏ về port `8080`.
