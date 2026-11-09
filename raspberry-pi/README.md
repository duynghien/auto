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

### Management CLI (`pi-toolbox`)

After setup, run `pi-toolbox` (or `./pi-toolbox.sh` in `~/self-hosted/raspberry-pi/`) to manage your Pi:

```bash
pi-toolbox status      # Check Portainer container and system status
pi-toolbox doctor      # Diagnose CPU temperature, throttling, RAM, Swap & disk
pi-toolbox start       # Start Portainer container
pi-toolbox stop        # Stop Portainer container
pi-toolbox restart     # Restart Portainer container
pi-toolbox logs        # View Portainer logs
pi-toolbox update      # Pull latest Portainer CE image and recreate container
pi-toolbox uninstall   # Safely remove Portainer container
```

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

### Lệnh Quản Lý CLI (`pi-toolbox`)

Sau khi cài đặt, bạn có thể chạy lệnh `pi-toolbox` (hoặc file `./pi-toolbox.sh` trong `~/self-hosted/raspberry-pi/`):

```bash
pi-toolbox status      # Kiểm tra trạng thái Portainer và hệ thống
pi-toolbox doctor      # Chẩn đoán nhiệt độ CPU, throttling, RAM, Swap & ổ đĩa
pi-toolbox start       # Khởi động Portainer
pi-toolbox stop        # Dừng Portainer
pi-toolbox restart     # Khởi động lại Portainer
pi-toolbox logs        # Xem log Portainer
pi-toolbox update      # Cập nhật Portainer CE lên bản mới nhất
pi-toolbox uninstall   # Gỡ bỏ container Portainer an toàn
```

---

## Support

- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **Author**: [duynghien](https://github.com/duynghien)
