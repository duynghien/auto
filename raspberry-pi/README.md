# Raspberry Pi & ARM Toolbox (by duynghien) 🍓

A collection of optimized scripts for Raspberry Pi (4/5) and ARM-based servers. Helps you set up a Docker environment and container management tools in just a few steps.

## 🚀 Features
- **Docker Engine**: Installs the latest version from Docker Official.
- **Docker Compose**: Supports multi-container management.
- **Portainer CE**: Intuitive, easy-to-use web interface for Docker management.
- **ARM Optimization**: Automatically configures parameters suitable for ARM platforms.

## 📋 Requirements
- Raspberry Pi OS, Ubuntu ARM, or any ARM-based Linux distribution.
- Sudo/Root permissions.

## 🛠️ Installation Guide

You can download the script file directly or clone the entire repository:

### Method 1: Full Installation (Docker + Portainer)
This is the fastest way to get a complete environment.
```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/raspberry-pi/piDockerPortainer.sh
chmod +x piDockerPortainer.sh
sudo ./piDockerPortainer.sh
```

### Method 2: Individual Installation
- **Install Docker Only**: `sudo sh piDocker.sh`
- **Install Portainer Only**: `sudo sh piPortainer.sh`

---

## 🖥️ Accessing Portainer
After installation, you can access Portainer via your browser:
- **HTTP**: `http://<YOUR_PI_IP>:9000`
- **HTTPS**: `https://<YOUR_PI_IP>:9443`

*Tip: Replace `<YOUR_PI_IP>` with the local IP address of your Raspberry Pi.*

## 🤝 Support
- Website: [ai.vnrom.net](https://ai.vnrom.net)
- User: **duynghien**
