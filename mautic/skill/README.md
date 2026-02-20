# Hướng Dẫn Kích Hoạt Mautic Skill Cho OpenClaw

Cấu trúc OpenClaw Mautic Skill đã được tạo sẵn tại: `mautic/skill`.

Để kết nối hệ thống này, bạn cần thực hiện 2 bước cấu hình dưới đây.

## BƯỚC 1: Nạp Skill Vào OpenClaw

OpenClaw quản lý các kỹ năng (Skills) của Agent thông qua thư mục cấu hình chung. Hãy copy thư mục Mautic Skill vào thư mục `skills` của OpenClaw:

```bash
# 1. Tạo thư mục skills trong thư mục cấu hình OpenClaw của bạn (nếu chưa có)
mkdir -p ~/.openclaw/workspace/skills

# 2. Copy toàn bộ thư mục mautic/skill vào đó
cp -r ~/self-hosted/auto/mautic/skill ~/.openclaw/workspace/skills/mautic

# 3. Cấp quyền thực thi cho script kết nối API
chmod +x ~/.openclaw/workspace/skills/mautic/mautic_action.js
```

Sau khi nạp, bạn cần bổ sung biến môi trường xác thực. Mở Terminal nơi định chạy OpenClaw và xuất 3 biến này (hoặc cấu hình thẳng vào `.env` của hệ thống chạy OpenClaw):

```bash
export MAUTIC_BASE_URL="http://192.168.x.x:8080" # (Thay bằng IP/Domain Mautic của bạn)
export MAUTIC_API_USER="admin"                   # Nhập Username API
export MAUTIC_API_PASS="mat-khau-api"            # Nhập Password API
```
> **Xác Thực (Rất Quan Trọng):** 
> Kịch bản của OpenClaw đang sử dụng **Basic Auth** vì nó phù hợp nhất cho các tập lệnh chạy ngầm không có giao diện trình duyệt.
> 1. Vào Mautic Settings 👉 *Configuration* 👉 *API Settings*. Bật **"API enabled"** và **"Enable HTTP basic auth"**, sau đó Save lại.
> 3. Đối với Basic Auth, Mautic sử dụng chình **Username và Password đăng nhập** của người dùng. **LỜI KHUYÊN (Bảo Mật & Theo Dõi Lịch Sử):** Bạn **KHÔNG NÊN** dùng chung tài khoản Administrator cá nhân của bạn cho OpenClaw vì sẽ không thể phân biệt rạch ròi lịch sử hành động do bạn làm hay do AI làm, cũng như rất nguy hiểm nếu lộ mật khẩu. Thay vào đó:
>    * Tạo một chức vụ mới (Role) trong Mautic. Cấp các quyền sau:
>      - **API Permissions:** Đánh dấu *Granted*.
>      - **Contact Permissions:** Khuyên dùng check mục **Full** (Hoặc ít nhất là **View (Others)**, **Edit (Others)** và **Create**) cho thiết lập `Contacts` và `Segments`.
>      - **Point Permissions:** Tick chọn **Full**.
>      - **Tag manager permissions:** Tick chọn **Full**.
>    * Đi tới mục **Settings** ở góc phải trên cùng 👉 *Users* 👉 **New** để tạo một User mới (VD: Username là `openclaw_agent`, password ngẫu nhiên). Gán Role vừa tạo cho User này.
>    * Điền tài khoản `openclaw_agent` bạn vừa tạo vào 2 biến `MAUTIC_API_USER` và `MAUTIC_API_PASS` phía trên.

## BƯỚC 2: Cấu Hình Webhook Trong OpenClaw

Mautic thường gửi lượng lớn dữ liệu rất rắc rối qua Webhook. OpenClaw lại yêu cầu một cấu trúc JSON đơn giản. Vì vậy, ta cần "phiên dịch" dữ liệu từ Mautic sang cho LLM qua hệ thống "Transform" của OpenClaw.

Bạn cần thực hiện các thao tác trên máy chủ đang chạy OpenClaw:

1. **Khởi tạo thư mục Transform:**
   ```bash
   mkdir -p ~/.openclaw/hooks/transforms
   ```
2. **Copy file phiên dịch dữ liệu:**
   Tôi đã chuẩn bị sẵn file `mautic_webhook_transform.js` trong thư mục cài đặt (`mautic/skill`). Hãy copy nó qua OpenClaw:
   ```bash
   cp ~/self-hosted/auto/mautic/skill/mautic_webhook_transform.js ~/.openclaw/hooks/transforms/
   ```

3. **Khai báo cổng mở trong cấu hình OpenClaw:**
   Dùng lệnh `nano ~/.openclaw/openclaw.json` (hoặc mở file này trong VSCode) và bổ sung mảng `hooks` như dưới đây vào cấp cao nhất của file JSON.
   
   ```json
   {
     "hooks": {
       "enabled": true,
       "path": "/hooks",
       "mappings": [
         {
           "match": {
             "source": "mautic"
           },
           "action": "agent",
           "transform": {
             "module": "mautic_webhook_transform.js"
           }
         }
       ]
     },
     // Các cấu hình cũ của OpenClaw (gateway, agents...) giữ nguyên.
   }
   ```
   Sau khi lưu file, lệnh cho OpenClaw restart lại để nó nhận webhook: `/restart` trong cửa sổ chat hoặc chạy lại Gateway.

---

## BƯỚC 3: Tạo Webhook Trên Mautic 7

Cuối cùng, vào giao diện Mautic Dashboard để ra lệnh cho Mautic bắn tín hiệu qua OpenClaw.

1. Vào Mautic Dashboard 👉 biểu tượng Settings (bánh răng) 👉 **Webhooks**.
2. Bấm **New** ở góc phải trên.
3. Điền các trường:
   - **Name:** OpenClaw Trigger (AI Agent)
   - **Webhook POST Url:** `http://127.0.0.1:18789/hooks/mautic` (Đây là cổng Gateway mặc định của OpenClaw vừa mở ở bước trên. Đổi IP nếu Mautic và OpenClaw khác máy chủ).
4. Ở cột bên phải **Webhook Events**, đánh dấu check vào các sự kiện sau (Tránh rác!):
   - **Form Submit Event:** (Rất quan trọng) Báo động có khách tìm đến.
   - **Contact Identified Event:** Báo tên khách.
   - **Contact Segment Membership Change Event:** (Tuỳ chọn)
   - **Contact Points Changed Event:** (Tuỳ chọn)
5. Bấm **Save & Close**.

---

### 🎉 Test Thử Nghiệm

Mở một channel OpenClaw lên (VD: Telegram hoặc Discord) và chat với nó. Hãy thử ra lệnh tự nhiên xem OpenClaw có tự gọi Mautic Skill không nhé:

> *"Tìm giúp tôi khách hàng có email alex@example.com trong Mautic xem họ đang có bao nhiêu điểm (points)."*

> *"Tôi có một leads mới tên là Sarah, email sarah@test.com. Hãy tạo contact này trên mautic và cộng cho cô ấy 15 điểm ưu tiên."*

> *"Khách hàng nguyen@gmail.com vừa được team Sale đánh giá cao, hãy vào Mautic thả contact này vào segment ID 5 giúp tôi."*
