# WordOps Backup Kit (WordPress)

Bộ script backup/restore tối ưu cho server WordOps chạy WordPress.

Mục tiêu:
- Chạy ổn định, tránh chồng job.
- Backup local an toàn theo kiểu atomic.
- Backup source theo cấu trúc WordOps: `htdocs`, `conf`, `wp-config.php` (nếu có), bỏ `logs`.
- Dump DB có retry + timeout.
- Upload Google Drive bằng rclone.
- Thông báo Telegram rõ ràng (start + finish).
- Có script restore và checklist test restore hàng tháng.

## Cấu trúc repo

```text
.
├── setup.sh
├── README.md
├── scripts/
│   ├── backup.sh
│   └── restore.sh
├── config/
│   └── backup.env.example
└── docs/
    └── RESTORE_CHECKLIST_MONTHLY.md
```

## Yêu cầu môi trường

- OS Linux (Ubuntu/Debian khuyến nghị)
- Quyền root (`sudo`)
- Đã cài:
  - `bash`, `flock`, `tar`, `gzip`, `timeout`
  - `rclone`
  - `mariadb-dump` (ưu tiên) hoặc `mysqldump`
  - `mariadb`/`mysql` client (để restore DB)

## Cài đặt nhanh (Quick Setup - Standalone)

Bạn có thể chạy trực tiếp standalone hoặc clone repo:

```bash
# Cách 1: Chạy trực tiếp từ GitHub (Standalone)
curl -fsSL https://raw.githubusercontent.com/duynghien/auto/main/wordops/setup.sh | sudo bash

# Cách 2: Clone repository
git clone https://github.com/duynghien/auto.git
cd auto/wordops
sudo bash setup.sh
```

Setup sẽ:
1. Hỏi thông tin cấu hình và lưu vào `backup.env` (chmod 600).
2. Tự động sinh `backup.sh`, `restore.sh`, và CLI quản lý `wo-backup.sh`.
3. Tạo symlink toàn hệ thống: `/usr/local/bin/wo-backup`.
4. Tạo cron tự động (nếu bật).

## Quản lý nhanh với `wo-backup` CLI

Sau khi cài đặt, bạn có thể dùng lệnh `wo-backup` mọi lúc từ terminal:

```bash
# Kiểm tra trạng thái WordOps stack và lịch cron
wo-backup status

# Chạy backup thủ công ngay lập tức
wo-backup run-backup

# Khôi phục toàn bộ (files + DB)
wo-backup restore YYYY-MM-DD domain.com --yes

# Chỉ khôi phục files hoặc DB
wo-backup restore YYYY-MM-DD domain.com --files-only --yes
wo-backup restore YYYY-MM-DD domain.com --db-only --yes

# Kiểm tra sức khoẻ hệ thống, dependencies, quyền file
wo-backup doctor

# Gỡ bỏ cron backup
wo-backup uninstall
```

## Cấu hình

File chính sau setup:

- `/opt/scripts/backup.env` (mặc định, quyền `600`)
- Nếu bạn đổi thư mục cài script khi setup: `<INSTALL_DIR>/backup.env`

Bạn có thể tham khảo mẫu biến tại:

- `config/backup.env.example`

## Chạy backup thủ công (Trực tiếp qua script)

```bash
sudo bash /opt/scripts/backup.sh
```

Log runtime:

```bash
tail -f /var/log/backup-*.log
```

## Restore (Trực tiếp qua script)

Khôi phục full (files + DB):

```bash
sudo bash /opt/scripts/restore.sh YYYY-MM-DD domain.com --yes
```

Chỉ khôi phục files:

```bash
sudo bash /opt/scripts/restore.sh YYYY-MM-DD domain.com --files-only --yes
```

Chỉ khôi phục DB:

```bash
sudo bash /opt/scripts/restore.sh YYYY-MM-DD domain.com --db-only --yes
```

## Checklist restore hàng tháng

Xem file:

- `docs/RESTORE_CHECKLIST_MONTHLY.md`

Khuyến nghị: test restore ít nhất 1 site/tháng trên môi trường staging.

## Lưu ý bảo mật

- Không hardcode secret trong script.
- Chỉ lưu token/password trong `backup.env`.
- Đặt quyền file cấu hình: `chmod 600 /opt/scripts/backup.env`.
- Nếu lộ token/password, phải rotate ngay.
