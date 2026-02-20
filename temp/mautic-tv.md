# Hướng Dẫn Triển Khai Mautic 7 "Full-Stack" Xịn Sò Với Một Dòng Lệnh (Tích Hợp Redis, RabbitMQ Trên Docker)

**Mautic** là một nền tảng Marketing Automation (Tự động hoá tiếp thị) mã nguồn mở số 1 thế giới. Phiên bản Mautic 7 mang đến kiến trúc hiện đại, tập trung vào hiệu suất cao khi giải quyết triệt để vấn đề "nghẽn cổ chai" nhờ việc xử lý ngầm (background queue) các chiến dịch gửi email/sms lớn qua Message Broker (RabbitMQ), thay vì bắt Web server xử lý trực tiếp.

Bạn đang mệt mỏi vì cài đặt Mautic quá rườm rà? Bạn bực mình khi Mautic thường xuyên bị "treo" lúc gửi hàng ngàn email campaign? Bạn tìm kiếm một giải pháp self-hosted *Mautic 7* hoàn chỉnh có đầy đủ tính năng tối ưu như Redis (Cache) và RabbitMQ (Hàng đợi)? 

Bài viết này sẽ hướng dẫn bạn cài đặt hệ thống **Mautic 7 Production-Ready** chỉ với đúng 1 script tự động siêu đơn giản!

## Tại Sao Nên Dùng Bản Setup Này?

Khác với các bản cài Mautic Docker sơ sài trên mạng, bản cài này (do vnROM nghiên cứu và tối ưu) mang tới một kiến trúc dành cho hệ thống lớn:
1. **Mautic 7 Mới Nhất**: Tương thích tốt hơn, UI/UX hiện đại.
2. **Tích Hợp Redis Cache**: Thay vì lưu cache chậm chạp trên ổ cứng, Mautic sẽ dùng Redis memory cache giúp các trang tải "nhanh như chớp".
3. **Queue Xử Lý Nền qua RabbitMQ**: Không bắt Web Server phải còng lưng gửi hàng vạn email! Việc gửi mail/cập nhật phân khúc khách hàng sẽ được đẩy vào message queue của RabbitMQ và được xử lý tuần tự qua một **Worker Container** chuyên dụng.
4. **Tự Động Hoá Cron Jobs (Ofelia)**: Quên việc setup crontab thủ công đi. Mọi cron như *segments:update*, *campaigns:trigger* đều tự động chạy mượt mà nhờ container Ofelia.
5. **Auto-Generate Passwords**: Thông minh, an toàn. Tự sinh mật khẩu phức tạp cho Database và cấu hình sẵn Mautic, bạn không cần phải nhức đầu gõ tay.

Script hỗ trợ: Mac Apple Silicon, Raspberry Pi, và Linux VPS (Ubuntu/Debian) cấu trúc cả ARM64 và AMD64.

---

## 🚀 Các Bước Cài Đặt

Chỉ mất chưa đầy 3 phút thao tác:

### Bước 1: Tải Script
Mở Terminal / SSH vào server của bạn và chạy lệnh sau để tải script về máy:

```bash
mkdir -p ~/self-hosted/mautic && cd ~/self-hosted/mautic
curl -O https://raw.githubusercontent.com/duynghien/auto/main/mautic/setup.sh
```

### Bước 2: Chạy Tự Động
Cấp quyền thực thi và khởi chạy Installer:

```bash
chmod +x setup.sh && ./setup.sh
```

Giao diện CLI thân thiện sẽ hiện ra. Bạn chỉ việc:
1. Chọn **Ngôn ngũ** (Tiếng Việt/English).
2. Chọn **Chế độ mạng** (Chạy ở Localhost, trong mạng LAN, hoặc công khai Public Domain).

Vậy là xong! Hãy làm tách cà phê và để Mautic Download + Setup mọi thứ cho bạn.

---

## 🛠 Cấu Hình Kết Nối Lần Đầu

Trình duyệt của bạn có thể truy cập ngay vào Mautic qua đường dẫn: `http://localhost:8080` (hoặc IP Server của bạn). Nếu cài trên vps thì nhớ dùng Nginx Proxy Manager / Cloudflare Tunnel trỏ domain về `port 8080` nhé.

Khi Mautic hiện bảng cài đặt Database, bạn **BẮT BUỘC** điền đúng thông số sau:
- **Database Driver**: `MySQL/MariaDB`
- **Database Host**: `mautic_db` *(Vô cùng quan trọng, không được điền localhost)*
- **Database Port**: `3306`
- **Database Name**: `mautic`
- **Database Prefix**: *(bỏ trống)*
- **Database User**: `mautic`
- **Database Password**: Xem trên Terminal vừa chạy lệnh cài đặt, hoặc gõ `cat ~/self-hosted/mautic/.env` để lấy mật khẩu.

Hệ thống đã tự động kết nối với Redis và RabbitMQ qua các biến môi trường ngầm định trong file `docker-compose.yml`. Bạn không cần cấu hình gì thêm ở bước này!

---

## 💡 Quản Lý Dịch Vụ Nội Bộ (RabbitMQ)

Bạn muốn xem chi tiết hệ thống gửi email xử lý Queue thế nào? Script đã đính kèm sẵn bảng điều khiển RabbitMQ Control Panel:
- **Truy Cập**: `http://localhost:15672`
- **Username mặc định**: `mautic`
- **Password**: Tìm dòng `RABBITMQ_DEFAULT_PASS` trong file `.env`

---

---

## 🤖 Bonus: Use Cases Kết Hợp OpenClaw Cùng Mautic

Nếu bạn đang sử dụng **OpenClaw (Nền tảng trí tuệ nhân tạo Agentic & N8N Integration)**, tiềm năng hệ thống Automation của bạn là vô tận. OpenClaw đóng vai trò là "Bộ não" đưa ra các nội dung sáng tạo, và Mautic đóng vai trò "Cánh tay" để phân phối nó.

Dưới đây là một vài ý tưởng cực đỉnh:

### 1. Phễu Khách Hàng Thông Minh (AI Lead Scoring)
- **Mautic** thu thập hành vi email (click, mở email, truy cập trang web) của người dùng.
- Dùng Webhook của Mautic gửi thông tin đó sang OpenClaw. OpenClaw dùng LLM để phân tích ngữ nghĩa, tự động chấm điểm khách hàng (Lead Scoring) dựa vào "độ mặn mà" của họ sau đó gán Tag và trả lại về Mautic thông qua API.

### 2. Tự Động Viết Cá Nhân Hoá Email 1-1 Cho Từng Khách Hàng (Hyper-Personalization)
- Khi Mautic đẩy 1 lead vào Phân khúc VIP, Webhook kích hoạt OpenClaw.
- OpenClaw lấy thông tin ngành nghề/lịch sử mua hàng của khách -> Ra lệnh cho OpenAI/Claude viết ra 1 Email tri ân/tư vấn ĐỘC BẢN cho riêng người đó.
- OpenClaw ra lệnh cho Mautic API tạo ngay 1 Email động và bắn cho khách hàng. Không còn những email tự động như robot!

### 3. AI Chăm Sóc Khách Hàng Bỏ Quên Giỏ Hàng Nhạy Bén
- Giỏ hàng bị bỏ quên? Mautic nhận tín hiệu và đợi 24h.
- OpenClaw thu thập dữ liệu giỏ hàng bị bỏ đó, phân tích mức thu nhập/độ tuổi khách hàng. Từ đó, OpenClaw viết tuỳ chọn kịch bản Khuyến Mãi phù hợp (Ví dụ: Gen Z thì hài hước freeship, khách hàng trung niên thì giảm giá %, khách doanh nhân thì tặng gói bảo hành) rồi đẩy tự động vào hệ thống Campaign của Mautic để tung ra chiến dịch Retargeting hiệu quả nhất.

Chúc các bạn thành công cài đặt Mautic hệ thống lớn và tự động hoá Marketing rảnh tay!
