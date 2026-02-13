# Raspberry Pi & ARM Toolbox (by duynghien) 🍓

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

A collection of optimized scripts for Raspberry Pi (4/5) and ARM-based servers. Helps you set up a Docker environment and container management tools in just a few steps.

### 🚀 Features
- **Docker Engine**: Installs the latest version from Docker Official.
- **Docker Compose**: Supports multi-container management.
- **Portainer CE**: Intuitive, easy-to-use web interface for Docker management.
- **ARM Optimization**: Automatically configures parameters suitable for ARM platforms.

### 📋 Requirements
- Raspberry Pi OS, Ubuntu ARM, or any ARM-based Linux distribution.
- Sudo/Root permissions.

### 🛠️ Installation Guide

You can download the script file directly or clone the entire repository:

#### Method 1: Full Installation (Docker + Portainer)
This is the fastest way to get a complete environment.
```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/raspberry-pi/piDockerPortainer.sh
chmod +x piDockerPortainer.sh
sudo ./piDockerPortainer.sh
```

#### Method 2: Individual Installation
- **Install Docker Only**: `sudo sh piDocker.sh`
- **Install Portainer Only**: `sudo sh piPortainer.sh`

---

### 🖥️ Accessing Portainer
After installation, you can access Portainer via your browser:
- **HTTP**: `http://<YOUR_PI_IP>:9000`
- **HTTPS**: `https://<YOUR_PI_IP>:9443`

*Tip: Replace `<YOUR_PI_IP>` with the local IP address of your Raspberry Pi.*

### 🤝 Contact & Support
- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
- **Community**: [AI & Automation (vnROM)](https://ai.vnrom.net) - Support for AI & Automation deployment.

---

## Tiếng Việt

Tập hợp các script tối ưu cho Raspberry Pi (4/5) và các máy chủ chạy ARM. Giúp bạn thiết lập môi trường Docker và các công cụ quản lý container chỉ trong vài bước.

### 🚀 Tính năng
- **Docker Engine**: Cài đặt phiên bản mới nhất từ Docker Official.
- **Docker Compose**: Hỗ trợ quản lý đa container.
- **Portainer CE**: Giao diện web trực quan, dễ sử dụng để quản lý Docker.
- **Tối ưu ARM**: Tự động cấu hình các tham số phù hợp với nền tảng ARM.

### 📋 Yêu cầu
- Raspberry Pi OS, Ubuntu ARM, hoặc bất kỳ bản phân phối Linux ARM nào.
- Quyền Sudo/Root.

### 🛠️ Hướng dẫn cài đặt

Bạn có thể tải trực tiếp các file script hoặc clone toàn bộ repository:

#### Cách 1: Cài đặt đầy đủ (Docker + Portainer)
Đây là cách nhanh nhất để có một môi trường hoàn chỉnh.
```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/raspberry-pi/piDockerPortainer.sh
chmod +x piDockerPortainer.sh
sudo ./piDockerPortainer.sh
```

#### Cách 2: Cài đặt từng phần
- **Chỉ cài Docker**: `sudo sh piDocker.sh`
- **Chỉ cài Portainer**: `sudo sh piPortainer.sh`

---

### 🖥️ Truy cập Portainer
Sau khi cài đặt, bạn có thể truy cập Portainer qua trình duyệt:
- **HTTP**: `http://<IP_CUA_PI>:9000`
- **HTTPS**: `https://<IP_CUA_PI>:9443`

*Mẹo: Thay thế `<IP_CUA_PI>` bằng địa chỉ IP nội bộ của Raspberry Pi.*

### 🤝 Liên hệ & Hỗ trợ
- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
- **Community**: [AI & Automation (vnROM)](https://ai.vnrom.net) - Hỗ trợ triển khai AI & Automation.
