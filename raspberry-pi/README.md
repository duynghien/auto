# Raspberry Pi Toolset

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

## English

A unified toolkit for setting up **Docker**, **Portainer**, and **System Optimizations** on Raspberry Pi 4/5 (64-bit OS).

### Installation

```bash
# Create directory and download script
mkdir -p ~/self-hosted/raspberry-pi && cd ~/self-hosted/raspberry-pi
curl -O https://raw.githubusercontent.com/duynghien/auto/main/raspberry-pi/setup.sh

# Run setup
chmod +x setup.sh
sudo ./setup.sh
```

### Menu Options

1. **Install Docker & Compose**: Installs Docker engine and Docker Compose plugin (official method).
2. **Install Portainer CE**: Deploys Portainer for container management on port `9443`.
3. **Install Full Stack**: Installs both Docker and Portainer.
4. **System Optimization**:
   - Updates all packages (`apt update && upgrade`).
   - Installs useful tools: `htop`, `btop`, `neofetch`, `git`, `curl`.
   - **Auto-Swap**: Adds 2GB swap file if RAM < 3GB (essential for compiling/heavy loads).

---

## Tiếng Việt

Bộ công cụ cài đặt tự động cho **Raspberry Pi 4/5** (hệ điều hành 64-bit).

### Cài đặt

```bash
# Tạo thư mục và tải script
mkdir -p ~/self-hosted/raspberry-pi && cd ~/self-hosted/raspberry-pi
curl -O https://raw.githubusercontent.com/duynghien/auto/main/raspberry-pi/setup.sh

# Chạy script
chmod +x setup.sh
sudo ./setup.sh
```

### Các tùy chọn

1. **Cài Docker & Compose**: Cài đặt Docker engine và plugin Docker Compose (theo chuẩn mới nhất).
2. **Cài Portainer CE**: Cài giao diện quản lý Portainer (cổng `9443`).
3. **Cài Full Stack**: Cài cả Docker và Portainer cùng lúc.
4. **Tối ưu hệ thống**:
   - Cập nhật hệ thống (`apt update && upgrade`).
   - Cài các công cụ quản lý: `htop`, `btop`, `neofetch`...
   - **Tự động Swap**: Tạo 2GB Root Swap nếu RAM < 3GB (quan trọng để tránh treo máy khi tải nặng).

---

## Support

- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
