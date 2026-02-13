# duynghien auto-scripts 🚀

Tổng hợp các scripts tự động hóa cài đặt và cấu hình hệ thống, từ các thiết bị Raspberry Pi đến hệ sinh thái AI Agent phức tạp. Toàn bộ scripts được thiết kế để triển khai nhanh chóng (1-Click) và bảo mật.

## 📂 Danh mục công cụ

### 1. [OpenClaw + n8n + MCP Stack](./openclaw-n8n-mcp)
Giải pháp triển khai AI Agent (OpenClaw) tích hợp n8n và giao thức MCP (Model Context Protocol).
- **Phù hợp**: VPS (Ubuntu 22.04+).
- **Tính năng**: Cài đặt OpenClaw, n8n, MCP Server, Caddy, Postgres, Redis.

### 2. [LobeHub Mac Installer](./lobehub-mac)
Script tối ưu cho Mac (M1/M2/M3/M4) sử dụng OrbStack để cài đặt LobeHub v2.0+.
- **Phù hợp**: Mac Mini, MacBook (Apple Silicon).
- **Tính năng**: Tối ưu cho OrbStack, PostgreSQL + pgvector, S3 Local.

### 3. [LobeHub Pi 4 Installer](./lobehub-pi)
Script tự động hóa cài đặt LobeHub v2.0+ (phiên bản database) tối ưu cho Raspberry Pi.
- **Phù hợp**: Raspberry Pi 4 (8GB) / Pi 5 (ARM64).
- **Tính năng**: PostgreSQL + pgvector, S3 Storage, Search Engine, Redis.

### 4. [Raspberry Pi ARM Toolbox](./raspberry-pi)
Bộ scripts tối ưu dành riêng cho Raspberry Pi hoặc các thiết bị sử dụng kiến trúc ARM.
- **Phù hợp**: Raspberry Pi 4/5, máy chủ ARM.
- **Tính năng**: Cài đặt Docker, Docker Compose, Portainer.

---

## 🛠️ Cách sử dụng chung

Để bắt đầu, bạn nên clone toàn bộ repository này về máy chủ của mình:

```bash
git clone https://github.com/duynghien/auto.git
cd auto
```

Sau đó, di chuyển vào từng thư mục tương ứng để chạy script cài đặt.

## 🤝 Liên hệ & Hỗ trợ
- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **User**: **duynghien**
- **Cộng đồng**: Hỗ trợ triển khai các giải pháp AI & Tự động hóa.

---
*Lưu ý: Luôn kiểm tra nội dung script trước khi chạy bằng quyền root.*
