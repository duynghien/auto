# LobeHub Mac Installer (M1/M2/M3/M4) 

Automatic installation script for LobeHub v2.0+, specifically optimized for **Mac (Apple Silicon)** users using **OrbStack**.

## 🚀 Why run it on Mac Mini M4?
- **Apple Silicon Power**: The M4 chip handles AI tasks and vector databases extremely fast and efficiently.
- **OrbStack**: Superior performance compared to Docker Desktop, launching containers in seconds with minimal resource usage.
- **Privacy**: All your data stays on your local machine, ensuring no data leaks to the cloud.

## 📋 Requirements
- Mac with M1, M2, M3, or M4 chip.
- [OrbStack](https://orbstack.dev/) installed.
- Admin permissions to run the script.

## 🛠️ Installation Guide

Open your Terminal and run the following command:

```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/lobehub-mac/setup.sh
chmod +x setup.sh
./setup.sh
```

## ⚙️ Post-Installation Configuration

The script installs everything in the `~/lobehub-mac` directory.

### 1. Add API Keys
1. Open the `.env` file: `nano ~/lobehub-mac/.env`
2. Fill in your API Key (e.g., `OPENAI_API_KEY=sk-xxxx`).
3. Restart the service:
   ```bash
   cd ~/lobehub-mac
   docker compose restart lobe
   ```

### 2. Access
- **LobeHub**: `http://<YOUR_MAC_IP>:3210`
- **RustFS Console**: `http://<YOUR_MAC_IP>:9001`

## 🤝 Support
- Website: [ai.vnrom.net](https://ai.vnrom.net)
- User: **duynghien**
