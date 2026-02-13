# OpenClaw + n8n + MCP Stack Setup (by duynghien)

Script cài đặt tự động hệ sinh thái AI Agent bảo mật, tích hợp sẵn n8n và các công cụ quản lý workflow qua giao thức MCP (Model Context Protocol).

## 🚀 Tính năng chính
- **OpenClaw Stack**: Cài đặt OpenClaw (Gateway + Agent) từ mã nguồn.
- **n8n Automation**: Triển khai n8n với đầy đủ cơ sở dữ liệu (Postgres, Redis) và Worker.
- **MCP Integration**: Tích hợp sẵn `n8n-custom-mcp` (by duynghien) giúp Agent điều khiển n8n trực tiếp.
- **Bảo mật**: Sử dụng Caddy (Reverse Proxy) để quản lý SSL/Domain và cô lập các dịch vụ trong mạng nội bộ Docker.
- **Giao tiếp 2 chiều**: Cấu hình sẵn Skill để Agent có thể gọi n8n và n8n có thể gửi phản hồi ngược lại Agent.

## 📋 Yêu cầu hệ thống
- **Hệ điều hành**: Ubuntu 22.04 LTS (khuyên dùng).
- **Cấu hình tối thiểu**: 4GB RAM, 2 vCPUs (Droplet DigitalOcean gói $24/tháng).
- **Quyền hạn**: Chạy dưới quyền `root`.

## 🛠️ Hướng dẫn cài đặt

### Bước 1: Chuẩn bị các khóa truy cập
Bạn cần chuẩn bị sẵn:
1. **Telegram Bot Token**: Lấy từ `@BotFather`.
2. **Telegram User ID**: Lấy từ `@userinfobot`.
3. **OpenAI API Key**: Từ OpenAI Platform.

### Bước 2: Chạy Script
Sao chép và chạy lệnh sau trên terminal của VPS:

```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/openclaw-n8n-mcp/setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

### Bước 3: Hoàn tất cấu hình MCP (Quan trọng)
Khi script chạy xong, n8n đã hoạt động nhưng dịch vụ MCP cần API Key để Agent có thể điều khiển n8n.
1. Truy cập n8n: `https://n8n.<YOUR_IP>.nip.io`
2. Tạo tài khoản n8n.
3. Vào **Settings > Personal API Keys > Create New**.
4. Sao chép khóa vừa tạo.
5. Quay lại terminal, chỉnh sửa file `.env`:
   ```bash
   nano /opt/openclaw/.env
   ```
6. Thay `REPLACE_ME_LATER` tại dòng `N8N_API_KEY` bằng khóa bạn vừa copy.
7. Khởi động lại dịch vụ MCP:
   ```bash
   cd /opt/openclaw
   docker compose up -d n8n-mcp
   ```

## 📂 Cấu trúc thư mục
- `/opt/openclaw`: Thư mục chính chứa Docker Compose và cấu hình môi trường.
- `/root/.openclaw`: Chứa dữ liệu Agent và các Skills (n8n-webhook, n8n-mcp).
- `/opt/clawdbot/caddy_config`: Chứa file Caddyfile để quản lý Domain.

## 🤝 Hỗ trợ
- Website: [https://ai.vnrom.net](https://ai.vnrom.net)
- Thương hiệu: **duynghien**

## 📜 Credits
This project architecture and setup scripts are inspired by [openclaw-n8n-starter](https://github.com/Barty-Bart/openclaw-n8n-starter).
