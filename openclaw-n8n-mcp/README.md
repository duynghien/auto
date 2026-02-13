# OpenClaw + n8n + MCP Stack Setup (by duynghien)

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

Automatic installation script for a secure AI Agent ecosystem, integrated with n8n and workflow management tools via the Model Context Protocol (MCP).

### 🚀 Key Features
- **OpenClaw Stack**: Installs OpenClaw (Gateway + Agent) from source.
- **n8n Automation**: Deploys n8n with a full database stack (Postgres, Redis) and Worker.
- **MCP Integration**: Includes `n8n-custom-mcp` (by duynghien) to allow the Agent to control n8n directly.
- **Security**: Uses Caddy (Reverse Proxy) for SSL/Domain management and isolates services within a private Docker network.
- **Two-Way Communication**: Pre-configured Skills allow the Agent to trigger n8n and n8n to send responses back to the Agent.

### 📋 System Requirements
- **OS**: Ubuntu 22.04 LTS (Recommended).
- **Minimum Specs**: 4GB RAM, 2 vCPUs (DigitalOcean $24/mo Droplet recommended).
- **Permissions**: Must be run as `root`.

### 🛠️ Installation Guide

#### Step 1: Prepare Access Keys
You will need:
1. **Telegram Bot Token**: Get it from `@BotFather`.
2. **Telegram User ID**: Get it from `@userinfobot`.
3. **OpenAI API Key**: From OpenAI Platform.

#### Step 2: Run the Script
Copy and run the following command on your VPS terminal:

```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/openclaw-n8n-mcp/setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### Step 3: Complete MCP Configuration (Important)
Once the script finishes, n8n is running, but the MCP service needs an API Key to allow the Agent to control n8n.
1. Access n8n: `https://n8n.<YOUR_IP>.nip.io`
2. Create your n8n account.
3. Go to **Settings > Personal API Keys > Create New**.
4. Copy the generated key.
5. Back in the terminal, edit the `.env` file:
   ```bash
   nano /opt/openclaw/.env
   ```
6. Replace `REPLACE_ME_LATER` at the `N8N_API_KEY` line with your copied key.
7. Restart the MCP service:
   ```bash
   cd /opt/openclaw
   docker compose up -d n8n-mcp
   ```

### 📂 Directory Structure
- `/opt/openclaw`: Main directory containing Docker Compose and environment config.
- `/root/.openclaw`: Contains Agent data and Skills (n8n-webhook, n8n-mcp).
- `/opt/clawdbot/caddy_config`: Contains Caddyfile for domain management.

### 🤝 Contact & Support
- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
- **Community**: [AI & Automation (vnROM)](https://ai.vnrom.net) - Support for AI & Automation deployment.

### 📜 Credits
This project architecture and setup scripts are inspired by [openclaw-n8n-starter](https://github.com/Barty-Bart/openclaw-n8n-starter).

---

## Tiếng Việt

Script cài đặt tự động hệ sinh thái AI Agent bảo mật, tích hợp với n8n và các công cụ quản lý workflow thông qua Model Context Protocol (MCP).

### 🚀 Tính năng chính
- **OpenClaw Stack**: Cài đặt OpenClaw (Gateway + Agent) từ nguồn.
- **n8n Automation**: Triển khai n8n với đầy đủ database (Postgres, Redis) và Worker.
- **Tích hợp MCP**: Bao gồm `n8n-custom-mcp` (bởi duynghien) cho phép Agent điều khiển trực tiếp n8n.
- **Bảo mật**: Sử dụng Caddy (Reverse Proxy) để quản lý SSL/Domain và cô lập các dịch vụ trong mạng nội bộ Docker.
- **Giao tiếp hai chiều**: Các Skills được cấu hình sẵn cho phép Agent kích hoạt n8n và n8n gửi phản hồi ngược lại cho Agent.

### 📋 Yêu cầu hệ thống
- **Hệ điều hành**: Ubuntu 22.04 LTS (Khuyên dùng).
- **Cấu hình tối thiểu**: 4GB RAM, 2 vCPUs.
- **Quyền hạn**: Phải chạy dưới quyền `root`.

### 🛠️ Hướng dẫn cài đặt

#### Bước 1: Chuẩn bị các khóa truy cập
Bạn cần có:
1. **Telegram Bot Token**: Lấy từ `@BotFather`.
2. **Telegram User ID**: Lấy từ `@userinfobot`.
3. **OpenAI API Key**: Từ OpenAI Platform.

#### Bước 2: Chạy Script
Sao chép và chạy lệnh sau trên terminal của VPS:

```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/openclaw-n8n-mcp/setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### Bước 3: Hoàn tất cấu hình MCP (Quan trọng)
Sau khi script hoàn tất, n8n đã chạy nhưng dịch vụ MCP cần có API Key để Agent có thể điều khiển n8n.
1. Truy cập n8n: `https://n8n.<IP_CUA_BAN>.nip.io`
2. Tạo tài khoản n8n.
3. Vào **Settings > Personal API Keys > Create New**.
4. Copy key vừa tạo.
5. Quay lại terminal, sửa file `.env`:
   ```bash
   nano /opt/openclaw/.env
   ```
6. Thay thế `REPLACE_ME_LATER` tại dòng `N8N_API_KEY` bằng key bạn vừa copy.
7. Khởi động lại dịch vụ MCP:
   ```bash
   cd /opt/openclaw
   docker compose up -d n8n-mcp
   ```

### 📂 Cấu trúc thư mục
- `/opt/openclaw`: Thư mục chính chứa Docker Compose và cấu hình môi trường.
- `/root/.openclaw`: Chứa dữ liệu Agent và các Skills (n8n-webhook, n8n-mcp).
- `/opt/clawdbot/caddy_config`: Chứa file Caddyfile quản lý domain.

### 🤝 Liên hệ & Hỗ trợ
- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
- **Cộng đồng**: [AI & Automation (vnROM)](https://ai.vnrom.net) - Hỗ trợ triển khai AI & Automation.

### 📜 Ghi công
Kiến trúc dự án và các script cài đặt được lấy cảm hứng từ [openclaw-n8n-starter](https://github.com/Barty-Bart/openclaw-n8n-starter).
