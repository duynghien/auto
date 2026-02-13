# Raspberry Pi & ARM Toolbox (by duynghien) 🍓

Bộ sưu tập các scripts tối ưu hóa dành cho Raspberry Pi (4/5) và các máy chủ sử dụng kiến trúc ARM. Giúp bạn cài đặt môi trường Docker và công cụ quản lý container chỉ trong một nốt nhạc.

## 🚀 Tính năng
- **Docker Engine**: Cài đặt phiên bản mới nhất từ Docker Official.
- **Docker Compose**: Hỗ trợ quản lý đa container.
- **Portainer CE**: Giao diện web quản lý Docker trực quan, dễ dùng.
- **Tối ưu ARM**: Tự động cấu hình các tham số phù hợp với nền tảng ARM.

## 📋 Yêu cầu
- Raspberry Pi OS, Ubuntu ARM hoặc bất kỳ bản phân phối Linux ARM nào.
- Quyền sudo/root.

## 🛠️ Hướng dẫn cài đặt

Bạn có thể tải trực tiếp file script hoặc clone toàn bộ repository:

### Cách 1: Cài đặt trọn gói (Docker + Portainer)
Đây là cách nhanh nhất để có một môi trường hoàn chỉnh.
```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/raspberry-pi/piDockerPortainer.sh
chmod +x piDockerPortainer.sh
sudo ./piDockerPortainer.sh
```

### Cách 2: Cài đặt riêng lẻ
- **Chỉ cài Docker**: `sudo sh piDocker.sh`
- **Chỉ cài Portainer**: `sudo sh piPortainer.sh`

---

## 🖥️ Truy cập Portainer
Sau khi cài đặt xong, bạn có thể truy cập Portainer qua trình duyệt:
- **HTTP**: `http://<IP-CUA-PI>:9000`
- **HTTPS**: `https://<IP-CUA-PI>:9443`

*Mẹo: Thay `<IP-CUA-PI>` bằng địa chỉ IP IP nội bộ của máy Raspberry Pi.*

## 🤝 Hỗ trợ
- Website: [ai.vnrom.net](https://ai.vnrom.net)
- User: **duynghien**
