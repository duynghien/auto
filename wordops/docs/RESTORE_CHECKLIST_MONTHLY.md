# Checklist Khôi Phục Hàng Tháng (WordOps/WordPress)

## Mục tiêu
Xác nhận backup có thể khôi phục đầy đủ cả files và DB ít nhất 1 lần mỗi tháng.

## Tần suất
- 1 lần/tháng (tuần đầu tháng)
- Lưu lịch sử tối thiểu 3 lần test gần nhất

## Điều kiện trước khi test
- Có server test/staging riêng
- MariaDB/MySQL trên staging tương thích với production
- Chọn 1 bản backup gần nhất đã chạy thành công

## Các bước thực hiện
1. Chọn 1 site đại diện (ưu tiên site lớn hoặc quan trọng).
2. Khôi phục files:
   - `sudo bash /opt/scripts/restore.sh YYYY-MM-DD example.com --files-only --yes`
3. Khôi phục DB:
   - `sudo bash /opt/scripts/restore.sh YYYY-MM-DD example.com --db-only --yes`
4. Smoke test website:
   - Trang chủ tải bình thường
   - Đăng nhập `wp-admin` thành công
   - Mở ngẫu nhiên 3 bài viết/trang
   - Ảnh/media hiển thị đúng
5. Kiểm tra tính toàn vẹn dữ liệu:
   - Đối chiếu số bản ghi `wp_options` trong ngưỡng kỳ vọng
   - Kiểm tra tồn tại các bảng plugin quan trọng
6. Kiểm tra nhanh hiệu năng:
   - Tốc độ phản hồi trang đầu trong ngưỡng chấp nhận
   - Không có PHP fatal lặp lại trong log
7. Ghi kết quả vào nhật ký vận hành:
   - ngày test, ngày backup dùng để restore, site, pass/fail, thời gian restore, lỗi gặp phải

## Tiêu chí đạt
- Restore hoàn tất không cần can thiệp DB/file thủ công
- Site hoạt động bình thường sau smoke test
- Không phát hiện hỏng dữ liệu ở bảng quan trọng

## Nếu thất bại
1. Lưu lại đầy đủ output lệnh và log liên quan.
2. Tạo incident/ticket nêu rõ root cause và ETA khắc phục.
3. Sau khi sửa xong, bắt buộc test lại trong vòng 48 giờ.

## Vệ sinh bảo mật
- Không lưu token Telegram hoặc mật khẩu DB trực tiếp trong script
- Chỉ lưu secret trong `/etc/backup/backup.env` và đặt `chmod 600`
- Nếu script từng bị chia sẻ công khai, phải rotate secret ngay
