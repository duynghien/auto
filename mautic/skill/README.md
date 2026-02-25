# Mautic Skill for OpenClaw — Hướng dẫn chuẩn (chi tiết, dễ làm theo)

README này là bản **thực chiến** cho Mautic 7 + OpenClaw.
Nó xử lý đúng trường hợp phổ biến: trong Mautic Webhook chỉ có **URL + Secret** (không thêm custom header được).

---

## 0) Kiến trúc đúng (đừng bỏ qua)

Mautic không gọi trực tiếp OpenClaw hooks bằng Bearer token được (do UI hạn chế), nên dùng luồng:

1. **Mautic Webhook** gửi payload + `Webhook-Signature` →
2. **Bridge service** (`mautic_webhook_bridge.js`) verify chữ ký bằng secret Mautic →
3. Bridge forward payload sang **OpenClaw hooks** (`/hooks/mautic`) với `Authorization: Bearer <OPENCLAW_HOOK_TOKEN>` →
4. OpenClaw mapping + transform xử lý event

> Nếu bridge không chạy nền, Mautic sẽ bắn webhook thất bại (connection refused/timeout).

---

## 1) Chuẩn bị skill

```bash
mkdir -p ~/.openclaw/workspace/skills
# copy thư mục mautic vào ~/.openclaw/workspace/skills/mautic nếu chưa có
chmod +x ~/.openclaw/workspace/skills/mautic/mautic_action.js
chmod +x ~/.openclaw/workspace/skills/mautic/mautic_webhook_bridge.js
```

---

## 2) Env cho Mautic API actions (chat command)

Set env trong môi trường chạy OpenClaw (hoặc `.env` tương ứng):

```bash
MAUTIC_BASE_URL=http://<mautic-host>:8080
MAUTIC_API_USER=<mautic_api_user>
MAUTIC_API_PASS=<mautic_api_pass>
```

### Quyền user Mautic khuyến nghị
Tạo user riêng cho agent (không dùng admin cá nhân), role gồm:
- API permissions: Granted
- Contacts: Full (hoặc View/Create/Edit)
- Segments: Full
- Tag manager: Full
- Points: Full

---

## 3) Cấu hình OpenClaw hooks + mapping

Mở `~/.openclaw/openclaw.json` và đảm bảo block `hooks` có đầy đủ:

```json
{
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": {
        "boot-md": { "enabled": true },
        "bootstrap-extra-files": { "enabled": true },
        "command-logger": { "enabled": true },
        "session-memory": { "enabled": true }
      }
    },
    "enabled": true,
    "token": "<OPENCLAW_HOOK_TOKEN>",
    "path": "/hooks",
    "transformsDir": "~/.openclaw/hooks/transforms",
    "mappings": [
      {
        "match": { "path": "mautic" },
        "action": "agent",
        "name": "Mautic Webhook",
        "wakeMode": "now",
        "transform": { "module": "mautic_webhook_transform.js" }
      }
    ]
  }
}
```

### Copy transform file đúng chỗ

```bash
mkdir -p ~/.openclaw/hooks/transforms
cp ~/.openclaw/workspace/skills/mautic/mautic_webhook_transform.js ~/.openclaw/hooks/transforms/
```

### Cực kỳ quan trọng
- `hooks.enabled=true` **bắt buộc** phải có `hooks.token`, thiếu sẽ fail startup.
- `mautic_webhook_transform.js` phải export function trực tiếp:
  - ✅ `module.exports = transform;`
  - ❌ `module.exports = { transform };`

Restart gateway:

```bash
openclaw gateway restart
```

Kiểm tra gateway port thực tế:

```bash
openclaw gateway status
```

> Mặc định thường là `18799` trên máy này.

---

## 4) Cấu hình bridge (Mautic Secret -> OpenClaw Bearer)

Set env cho bridge:

```bash
export MAUTIC_WEBHOOK_SECRET='<secret trong webhook Mautic>'
export OPENCLAW_HOOK_TOKEN='<giá trị hooks.token trong openclaw.json>'
export OPENCLAW_HOOK_URL='http://127.0.0.1:18799/hooks/mautic'
export MAUTIC_BRIDGE_HOST='0.0.0.0'
export MAUTIC_BRIDGE_PORT='18889'
export MAUTIC_BRIDGE_PATH='/mautic-webhook'
```

Chạy bridge:

```bash
cd ~/.openclaw/workspace/skills/mautic
node mautic_webhook_bridge.js
```

URL bridge để điền vào Mautic:

```text
http://<ip-openclaw-host>:18889/mautic-webhook
```

Ví dụ LAN:

```text
http://192.168.1.145:18889/mautic-webhook
```

---

## 5) Cấu hình webhook trong Mautic

Mautic → Settings → Webhooks → New:
- Name: `OpenClaw Trigger (AI Agent)`
- Webhook URL: `http://192.168.1.145:18889/mautic-webhook` (ví dụ)
- Secret: nhập secret mạnh (dùng lại cho `MAUTIC_WEBHOOK_SECRET` ở bridge)

Events nên bật (tránh spam):
- Form Submit Event
- Contact Identified Event
- Contact Segment Membership Change Event (optional)
- Contact Points Changed Event (optional)

---

## 6) Test nhanh từng lớp

## 6.1 Test OpenClaw hooks trực tiếp

```bash
curl -X POST http://127.0.0.1:18799/hooks/mautic \
  -H "Authorization: Bearer <OPENCLAW_HOOK_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"source":"mautic","lead":{"email":"test@example.com"}}'
```

Kỳ vọng: HTTP `202` + JSON có `runId`.

## 6.2 Test bridge bằng payload giả lập Mautic

Bridge yêu cầu header `Webhook-Signature` hợp lệ (HMAC SHA256 base64 theo raw body).

Nếu signature đúng:
- Bridge trả `200`
- `forwardedStatus` nên là `202`

## 6.3 Test script action Mautic

```bash
cd ~/.openclaw/workspace/skills/mautic
node mautic_action.js get_contact '{"email":"test@example.com"}'
```

---

## 7) Chạy bridge dưới dạng service (khuyến nghị)

### macOS launchd (gợi ý)
Tạo plist riêng để bridge tự chạy khi boot.

Ví dụ ProgramArguments:
- `/opt/homebrew/bin/node`
- `/Users/<user>/.openclaw/workspace/skills/mautic/mautic_webhook_bridge.js`

Nhớ set đủ env trong plist:
- `MAUTIC_WEBHOOK_SECRET`
- `OPENCLAW_HOOK_TOKEN`
- `OPENCLAW_HOOK_URL`
- `MAUTIC_BRIDGE_HOST`
- `MAUTIC_BRIDGE_PORT`
- `MAUTIC_BRIDGE_PATH`

> Nếu chỉ chạy bridge bằng terminal tạm thời rồi đóng terminal, bridge sẽ chết.

---

## 8) Troubleshooting

### A) Mautic báo private IP URL not allowed
- Mautic đang chặn URL private/LAN theo mặc định.
- Cần bật whitelist/allow private URL trong system settings của Mautic, hoặc dùng URL public/tunnel.

### B) Hook trả `401 Unauthorized`
- Sai `OPENCLAW_HOOK_TOKEN` hoặc bridge forward sai token.

### C) Hook trả `500 hook mapping failed`
- Transform module sai path hoặc export sai kiểu.

### D) Mautic action trả `403 You do not have access`
- Role API user chưa đủ quyền Contacts/Segments/Tags/Points.

### E) Restart gateway không lỗi nhưng webhook không chạy
- Gateway sống, nhưng mapping/hook chưa đúng hoặc bridge không chạy nền.
- Kiểm tra lại:
  - `openclaw gateway status`
  - `hooks.enabled/token/path/mappings`
  - bridge process còn sống không

### F) Thấy log `Exec failed ... SIGTERM` khi test bridge
- Bình thường nếu bạn chủ động kill process test.
- Không phải bug chức năng, chỉ là process bị dừng.

---

## 9) Security best-practices

- Dùng user Mautic riêng cho agent.
- Không hardcode secrets vào source code.
- Secret Mautic webhook và OpenClaw hook token nên là 2 giá trị mạnh, quản lý rõ ràng.
- Nếu mở ra ngoài LAN: reverse proxy + TLS + IP allowlist.

---

## 10) Lệnh chat mẫu

- "Tìm contact theo email abc@xyz.com trong Mautic"
- "Tạo contact mới email a@b.com tên A B"
- "Gắn tag VIP cho contact id 12"
- "Cộng 10 điểm cho contact id 12"
- "Đưa contact id 12 vào segment id 5"
