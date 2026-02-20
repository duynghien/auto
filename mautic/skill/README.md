# Hướng Dẫn Kích Hoạt Mautic Skill Cho OpenClaw

Cấu trúc OpenClaw Mautic Skill đã được tạo sẵn tại: `mautic/skill`.

Để kết nối hệ thống này, bạn cần thực hiện 2 bước cấu hình dưới đây.

## BƯỚC 1: Nạp Skill Vào OpenClaw

OpenClaw quản lý các kỹ năng (Skills) của Agent thông qua thư mục cấu hình chung. Hãy copy thư mục Mautic Skill vào thư mục `skills` của OpenClaw:

```bash
# 1. Tạo thư mục skills trong thư mục cấu hình OpenClaw của bạn (nếu chưa có)
mkdir -p ~/.openclaw/skills

# 2. Copy toàn bộ thư mục mautic/skill vào đó
cp -r ~/self-hosted/auto/mautic/skill ~/.openclaw/skills/mautic

# 3. Cấp quyền thực thi cho script kết nối API
chmod +x ~/.openclaw/skills/mautic/mautic_action.js
```

Sau khi nạp, bạn cần bổ sung biến môi trường xác thực. Mở Terminal nơi định chạy OpenClaw và xuất 3 biến này (hoặc cấu hình thẳng vào `.env` của hệ thống chạy OpenClaw):

```bash
export MAUTIC_BASE_URL="http://192.168.x.x:8080" # (Thay bằng IP/Domain Mautic của bạn)
export MAUTIC_API_USER="admin"                   # Nhập Username API
export MAUTIC_API_PASS="mat-khau-api"            # Nhập Password API
```
> **Mẹo:** Vào Mautic Dashboard 👉 *Configuration* 👉 *API Settings*. Đảm bảo "API enabled" và "Enable HTTP basic auth" đang bật. Sau đó vào biểu tượng Menu Cài đặt góc trên cùng bên phải 👉 *API Credentials* 👉 *New* 👉 Chọn "Basic Auth" để tạo tài khoản API.

## BƯỚC 2: Cấu Hình Webhook Trên Mautic (Đánh thức OpenClaw)

Để Mautic có thể "báo cáo tình hình" cho AI (ví dụ: Khách hàng mới điền form, OpenClaw hãy viết email chăm sóc đi!), bạn cần tạo 1 Webhook trên Mautic.

1. Vào Mautic Dashboard 👉 biểu tượng Settings (bánh răng) 👉 **Webhooks**.
2. Bấm **New** ở góc phải trên.
3. Điền các trường:
   - **Name:** OpenClaw Agent Trigger
   - **Webhook POST Url:** `http://127.0.0.1:18789/webhook/mautic_event` (Đây là cổng Gateway mạng nội bộ của OpenClaw. Hãy trỏ tới đúng IP máy chủ đang chạy OpenClaw nếu không chung host).
4. Ở cột bên phải **Webhook Events**, hãy đánh dấu check vào các sự kiện bạn quan tâm, ví dụ:
   - *Contact Created Event* (Gửi data khi có khách tạo mới)
   - *Contact Identified Event* (Gửi data khi Mautic tra ra khách)
   - *Form Submitted Event* (Gửi data khi khách điền form)
5. Bấm **Save & Close**.

---

### 🎉 Test Thử Nghiệm

Bật OpenClaw lên và mở giao diện chat với LLM (Pi Agent). Hãy thử ra lệnh tự nhiên xem AI có tự gọi Mautic Skill không nhé:

> *"Tìm giúp tôi khách hàng có email alex@example.com trong Mautic xem họ đang có bao nhiêu điểm (points)."*

> *"Tôi có một leads mới tên là Sarah, email sarah@test.com. Hãy tạo contact này trên mautic và cộng cho cô ấy 15 điểm ưu tiên."*

> *"Khách hàng nguyen@gmail.com vừa được team Sale đánh giá cao, hãy vào Mautic thả contact này vào segment ID 5 giúp tôi."*
