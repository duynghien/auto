# duynghien auto-scripts 🚀

A collection of automation scripts for system installation and configuration, ranging from Raspberry Pi devices to complex AI Agent ecosystems. All scripts are designed for rapid (1-Click) deployment and security.

## 📂 Tool Directory

### 1. [OpenClaw + n8n + MCP Stack](./openclaw-n8n-mcp)
Deployment solution for AI Agents (OpenClaw) integrated with n8n and the Model Context Protocol (MCP).
- **Target**: VPS (Ubuntu 22.04+).
- **Features**: Installs OpenClaw, n8n, MCP Server, Caddy, Postgres, Redis.

### 2. [LobeHub Mac Installer](./lobehub-mac)
Optimized script for Mac (M1/M2/M3/M4) using OrbStack to install LobeHub v2.0+.
- **Target**: Mac Mini, MacBook (Apple Silicon).
- **Features**: Optimized for OrbStack, PostgreSQL + pgvector, Local S3.

### 3. [LobeHub Pi 4 Installer](./lobehub-pi)
Automation script for installing LobeHub v2.0+ (database version) optimized for Raspberry Pi.
- **Target**: Raspberry Pi 4 (8GB) / Pi 5 (ARM64).
- **Features**: PostgreSQL + pgvector, S3 Storage, Search Engine, Redis.

### 4. [Raspberry Pi ARM Toolbox](./raspberry-pi)
A set of optimized scripts specifically for Raspberry Pi or ARM-based devices.
- **Target**: Raspberry Pi 4/5, ARM servers.
- **Features**: Installs Docker, Docker Compose, Portainer.

---

## 🛠️ General Usage

To get started, clone this entire repository to your server:

```bash
git clone https://github.com/duynghien/auto.git
cd auto
```

Then, navigate to the corresponding directory to run the installation script.

## 🤝 Contact & Support
- **Website**: [ai.vnrom.net](https://ai.vnrom.net)
- **User**: **duynghien**
- **Community**: Support for AI & Automation deployment.

---
*Note: Always check the script content before running it as root.*
