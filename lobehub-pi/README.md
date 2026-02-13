# LobeHub Pi 4 Installer (v2.0+) 🧠

Automatic installation script for LobeHub v2.0+, specifically optimized for **Raspberry Pi 4 (8GB RAM)** or equivalent ARM64 devices. This version integrates the most powerful features of LobeHub.

## 🚀 Key Features
- **Cloud-Native Architecture**: Runs on Docker with a 6-service orchestration.
- **Vector Database**: Uses PostgreSQL + pgvector to support Knowledge Base and Memory.
- **Local S3 Storage**: Integrates RustFS (S3-compatible), which is extremely lightweight for storing files, images, and artifacts.
- **Online Search**: Integrated SearXNG allows Agents to update with real-time information.
- **Maximum Security**: Automatically generates `AUTH_SECRET`, `JWKS_KEY`, and other security secrets.
- **Better Auth**: Supports Email/Password login immediately after installation.

## 📋 System Requirements
- **Device**: Raspberry Pi 4 (8GB) or Pi 5.
- **OS**: Raspberry Pi OS 64-bit (ARM64).
- **Storage**: Minimum 16GB free space (SD Card or SSD).
- **Connection**: Stable internet to pull Docker images.

## 🛠️ Installation Guide

You only need to run a single command to set up the entire system:

```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/lobehub-pi/setup.sh
chmod +x setup.sh
./setup.sh
```

## ⚙️ Post-Installation Configuration

The script installs everything in the `$HOME/lobehub` directory.

### 1. Add API Keys
By default, the script does not include API Keys for providers (OpenAI, Anthropic...). To add a key:
1. Open the `.env` file: `nano ~/lobehub/.env`
2. Uncomment and fill in your key (e.g., `OPENAI_API_KEY=sk-xxxx`).
3. Restart the service:
   ```bash
   cd ~/lobehub
   docker compose restart lobe
   ```

### 2. Access the System
- **LobeHub**: `http://<YOUR_PI_IP>:3210`
- **RustFS Console**: `http://<YOUR_PI_IP>:9001` (User/Pass displayed at the end of the installation script).

## 📂 Service List (Docker containers)
- `lobehub`: Main application.
- `lobe-postgres`: Vector database.
- `lobe-redis`: Cache and session storage.
- `lobe-rustfs`: S3 data storage.
- `lobe-searxng`: Search engine.
- `lobe-network`: Gateway and network management.

## 🤝 Support
- Website: [ai.vnrom.net](https://ai.vnrom.net)
- User: **duynghien**
- Script Version: 5.3
