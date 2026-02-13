# LobeHub macOS Apple Silicon Setup v3.0 

Bộ cài đặt tự động LobeHub tối ưu nhất dành cho **macOS (M1/M2/M3/M4)**. Tích hợp đầy đủ các tính năng nâng cao: Knowledge Base, Online Search, S3 Storage và Artifacts.

---

## ✨ Điểm nổi bật (v3.0)
- **🚀 Hiệu suất cực đỉnh**: Tối ưu hóa cho Apple Silicon M-series. Chạy mượt mà nhất trên [OrbStack](https://orbstack.dev/) hoặc Docker Desktop.
- **🧠 Knowledge Base (RAG)**: Sử dụng **ParadeDB** (PostgreSQL + pg_search + pgvector) cho khả năng tìm kiếm nhanh và chính xác hơn.
- **🔍 Tìm kiếm trực tuyến**: Tích hợp sẵn **SearXNG** tự host, cung cấp khả năng tìm kiếm web cho LLM mà không cần API key Google/Tavily.
- **📦 S3 Storage tùy chọn**: Lựa chọn giữa **RustFS** (siêu nhẹ, nhanh) hoặc **MinIO** (ổn định, truyền thống) để lưu trữ file và ảnh.
- **🛠️ Lobe Helper (`./lobe.sh`)**: Script quản lý mạnh mẽ, không cần nhớ lệnh Docker Compose phức tạp.
- **🔒 Bảo mật tuyệt đối**: Dữ liệu và secrets lưu hoàn toàn trên máy local của bạn.

---

## 📋 Yêu cầu hệ thống
- **Hardware**: Mac chip M1, M2, M3 hoặc M4.
- **Software**: Khuyên dùng [OrbStack](https://orbstack.dev/) (nhanh hơn, tốn ít RAM/CPU hơn Docker Desktop).
- **Network**: Kết nối internet để tải Docker images và cấu hình ban đầu.

---

## 🛠️ Hướng dẫn cài đặt

Mở Terminal và chạy lệnh duy nhất (tất cả sẽ được tự động cấu hình):

```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/lobehub-mac/setup.sh
chmod +x setup.sh
./setup.sh
```

---

## ⚙️ Quản lý hệ thống với `lobe.sh`

Sau khi cài đặt, bạn sẽ sử dụng file `~/lobehub-mac/lobe.sh` để quản lý mọi thứ.

| Lệnh | Tính năng |
|------|-----------|
| `./lobe.sh start` | Khởi động toàn bộ dịch vụ |
| `./lobe.sh stop` | Dừng toàn bộ dịch vụ |
| `./lobe.sh restart` | Khởi động lại hệ thống |
| `./lobe.sh upgrade` | Cập nhật LobeHub lên bản mới nhất |
| `./lobe.sh logs` | Xem log (mặc định là container `lobe`) |
| `./lobe.sh status` | Kiểm tra trạng thái các container |
| `./lobe.sh search-test` | Kiểm tra tính năng tìm kiếm SearXNG |
| `./lobe.sh secrets` | Hiển thị nội dung file cấu hình `.env` |
| `./lobe.sh s3-login` | Xem thông tin đăng nhập S3 Storage |
| `./lobe.sh reset` | **⚠️ Xóa sạch dữ liệu** (cẩn trọng khi dùng) |

---

## 📁 Cấu trúc thư mục
- `data/`: Dữ liệu database PostgreSQL (ParadeDB).
- `searxng-settings.yml`: Cấu hình cho bộ máy tìm kiếm SearXNG.
- `.env`: Chứa toàn bộ mật khẩu và secrets (KHÔNG chia sẻ file này).
- `lobe.sh`: Script quản lý hệ thống.

---

## 🗺️ Địa chỉ truy cập
- **LobeHub**: [http://localhost:3210](http://localhost:3210)
- **S3 Console**: [http://localhost:9001](http://localhost:9001)

---

## 🤝 Hỗ trợ & Cộng đồng
- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Group**: [VN AI Community](https://facebook.com/groups/vnrom)
- **Tác giả**: [duynghien](https://github.com/duynghien)

---
*Chúc bạn có những trải nghiệm tuyệt vời với LobeHub trên chiếc Mac của mình!*
