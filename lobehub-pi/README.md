# LobeHub Pi 4 Installer (v2.0+) 🧠

Script cài đặt tự động LobeHub v2.0+ tối ưu riêng cho **Raspberry Pi 4 (8GB RAM)** hoặc các thiết bị ARM64 tương đương. Phiên bản này tích hợp đầy đủ các tính năng mạnh mẽ nhất của LobeHub.

## 🚀 Tính năng nổi bật
- **Kiến trúc Cloud-Native**: Chạy trên Docker với sự phối hợp của 6 dịch vụ.
- **Cơ sở dữ liệu Vector**: Sử dụng PostgreSQL + pgvector để hỗ trợ Knowledge Base và Memory.
- **Lưu trữ S3 nội bộ**: Tích hợp RustFS (S3-compatible) cực nhẹ để lưu trữ file, ảnh và artifacts.
- **Tìm kiếm trực tuyến**: Tích hợp SearXNG giúp Agent cập nhật thông tin thực tế.
- **Bảo mật tối đa**: Tự động sinh `AUTH_SECRET`, `JWKS_KEY` và các secrets bảo mật khác.
- **Better Auth**: Hỗ trợ đăng nhập bằng Email/Password ngay sau khi cài đặt.

## 📋 Yêu cầu hệ thống
- **Thiết bị**: Raspberry Pi 4 (8GB) hoặc Pi 5.
- **Hệ điều hành**: Raspberry Pi OS 64-bit (ARM64).
- **Thẻ nhớ/SSD**: Tối thiểu 16GB trống.
- **Kết nối**: Internet ổn định để tải Docker images.

## 🛠️ Hướng dẫn cài đặt

Bạn chỉ cần chạy một lệnh duy nhất để thiết lập toàn bộ hệ thống:

```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/lobehub-pi/setup.sh
chmod +x setup.sh
./setup.sh
```

## ⚙️ Cấu hình sau khi cài đặt

Script sẽ cài đặt mọi thứ vào thư mục `$HOME/lobehub`.

### 1. Thêm API Keys
Mặc định script chưa có API Key của các nhà cung cấp (OpenAI, Anthropic...). Để thêm key:
1. Mở file `.env`: `nano ~/lobehub/.env`
2. Bỏ ghi chú và điền key của bạn (ví dụ: `OPENAI_API_KEY=sk-xxxx`).
3. Khởi động lại service:
   ```bash
   cd ~/lobehub
   docker compose restart lobe
   ```

### 2. Truy cập hệ thống
- **LobeHub**: `http://<IP-CUA-PI>:3210`
- **RustFS Console**: `http://<IP-CUA-PI>:9001` (User/Pass hiển thị ở cuối script cài đặt).

## 📂 Danh sách dịch vụ (Docker containers)
- `lobehub`: Ứng dụng chính.
- `lobe-postgres`: Database véc-tơ.
- `lobe-redis`: Bộ nhớ đệm và session.
- `lobe-rustfs`: Lưu trữ dữ liệu S3.
- `lobe-searxng`: Công cụ tìm kiếm.
- `lobe-network`: Quản lý mạng và cổng.

## 🤝 Hỗ trợ
- Website: [ai.vnrom.net](https://ai.vnrom.net)
- Tác giả: **duynghien**
- Phiên bản script: 5.3
