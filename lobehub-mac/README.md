# LobeHub Mac Installer (M1/M2/M3/M4) 

Script cài đặt tự động LobeHub v2.0+ tối ưu riêng cho người dùng **Mac (Apple Silicon)** sử dụng **OrbStack**. 

## 🚀 Tại sao nên chạy trên Mac Mini M4?
- **Sức mạnh Apple Silicon**: Chip M4 xử lý các tác vụ AI và vector database cực nhanh và tiết kiệm điện.
- **OrbStack**: Hiệu năng vượt trội hơn Docker Desktop, khởi chạy container chỉ trong vài giây và tốn cực ít tài nguyên.
- **Tính riêng tư**: Toàn bộ dữ liệu của bạn nằm trên máy cá nhân, không lo rò rỉ thông tin lên cloud.

## 📋 Yêu cầu
- Máy Mac chip M1, M2, M3 hoặc M4.
- Đã cài đặt [OrbStack](https://orbstack.dev/).
- Quyền Admin để chạy script.

## 🛠️ Hướng dẫn cài đặt

Bạn chỉ cần mở Terminal và chạy lệnh sau:

```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/lobehub-mac/setup.sh
chmod +x setup.sh
./setup.sh
```

## ⚙️ Cấu hình sau cài đặt

Script cài đặt mọi thứ vào thư mục `~/lobehub-mac`.

### 1. Thêm API Keys
1. Mở file `.env`: `nano ~/lobehub-mac/.env`
2. Điền API Key của bạn (ví dụ: `OPENAI_API_KEY=sk-xxxx`).
3. Khởi động lại service:
   ```bash
   cd ~/lobehub-mac
   docker compose restart lobe
   ```

### 2. Truy cập
- **LobeHub**: `http://<IP-CUA-MAC>:3210`
- **RustFS Console**: `http://<IP-CUA-MAC>:9001`

## 🤝 Hỗ trợ
- Website: [ai.vnrom.net](https://ai.vnrom.net)
- Tác giả: **duynghien**
