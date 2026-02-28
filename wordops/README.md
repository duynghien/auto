# WordOps Backup Kit (WordPress)

Bộ script backup/restore tối ưu cho server WordOps chạy WordPress.

Mục tiêu:
- Chạy ổn định, tránh chồng job.
- Backup local an toàn theo kiểu atomic.
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

## Cài đặt nhanh (lần đầu)

Repo này nằm trong project tổng hợp `auto`, bạn cần clone về:

```bash
git clone https://github.com/duynghien/auto.git
cd auto/wordops
sudo bash setup.sh
```

Setup sẽ:
1. Hỏi thông tin cấu hình và lưu vào `backup.env`.
2. Cài script vào `/opt/scripts` (hoặc đường dẫn bạn nhập).
3. Tạo symlink `backup.env` cạnh script.
4. Tạo cron tự động (nếu bạn bật).

## Cấu hình

File chính sau setup:

- `/etc/backup/backup.env` (quyền `600`)

Bạn có thể tham khảo mẫu biến tại:

- `config/backup.env.example`

## Chạy backup thủ công

```bash
sudo bash /opt/scripts/backup.sh
```

Log runtime:

```bash
tail -f /var/log/backup-*.log
```

## Restore

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
- Đặt quyền file cấu hình: `chmod 600 /etc/backup/backup.env`.
- Nếu lộ token/password, phải rotate ngay.
