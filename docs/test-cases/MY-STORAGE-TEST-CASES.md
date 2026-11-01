# My Storage / Inventory / SKU — checklist kiểm tra giao diện

Đăng nhập bằng tài khoản customer thử nghiệm rồi mở **Profile → My storage & inventory**. Ghi lại kết quả Đạt/Không đạt và ảnh màn hình khi có lỗi. Dùng môi trường và dữ liệu thử nghiệm phù hợp cho các thao tác ghi.

## Điều hướng và tổng quan

- [ ] **MS-01:** Mở My Storage. Bốn tab Overview, Inventory, Movements và SKUs hiển thị; chuyển qua lại không mất điều hướng.
- [ ] **MS-02:** Overview hiển thị số SKU, số lượng, số hợp đồng active và số phòng đúng với dữ liệu trả về; category và recent movements hiển thị đúng.
- [ ] **MS-03:** Chọn Storage contracts and layouts. Chỉ hợp đồng active/overdue trong trang đang xem được hiển thị; mở hợp đồng có phòng để xem layout.
- [ ] **MS-04:** Với danh sách rỗng hoặc lỗi mạng, giao diện hiển thị thông báo phù hợp; nút thử lại/tải lại hoạt động.

## Tồn kho và sơ đồ

- [ ] **INV-01:** Danh sách hiển thị tên SKU, cơ sở, phòng, available, quantity và status; tìm kiếm và lọc status hoạt động.
- [ ] **INV-02:** Xem bản ghi có hàng chờ xuất: available = max(0, quantity − pending outbound). Chi tiết hiển thị cả ba số.
- [ ] **INV-03:** Mở lần lượt bản ghi normal, temporary_holding, damaged và disputed; trạng thái, holding reason và incident (nếu có) đúng dữ liệu.
- [ ] **INV-04:** Mở storage layout: phòng → kệ → tầng → SKU; hàng không đặt trên kệ hiển thị ở Items without rack.
- [ ] **INV-05:** Với kệ dùng chung, không suy luận kệ không có hàng của người khác từ danh sách hàng đang trống; không hiển thị thông tin hàng của khách khác.
- [ ] **INV-06:** Mở All locations for this SKU; danh sách vị trí và số lượng khớp dữ liệu, SKU chưa có tồn hiển thị rỗng.
- [ ] **INV-07:** Với danh sách trên 20 bản ghi, Previous/Next chuyển trang đúng; tìm kiếm hoặc đổi bộ lọc quay về trang đầu.

## Biến động

- [ ] **MOV-01:** Tab Movements hiển thị mã, loại, SKU, số lượng và thời gian của các biến động.
- [ ] **MOV-02:** Lọc in, out, move, adjust; chỉ các biến động tương ứng hiển thị. Xóa bộ lọc để trở lại đầy đủ.
- [ ] **MOV-03:** Kiểm tra danh sách rỗng, lỗi và chuyển trang; không có nút ghi tồn kho trực tiếp.

## SKU

- [ ] **SKU-01:** Tìm theo tên, SKU code và barcode; lọc active/inactive; xem chi tiết và vị trí.
- [ ] **SKU-02:** Tra barcode đã có; kết quả hiển thị SKU và các vị trí. Barcode không tồn tại hiển thị lỗi, không treo giao diện.
- [ ] **SKU-03:** Tạo SKU với mã và tên; kiểm tra danh sách và chi tiết sau khi lưu. Thử thêm category, barcode, đơn vị, mô tả, cân nặng, đủ ba kích thước và image URL hợp lệ.
- [ ] **SKU-04:** Bỏ trống mã hoặc tên, nhập cân nặng âm, kích thước thiếu/nhỏ hơn 0.1 hoặc URL sai: giao diện không gửi dữ liệu không hợp lệ.
- [ ] **SKU-05:** Nhập mã SKU hoặc barcode trùng: hiển thị thông báo lỗi và messageCode từ backend; dữ liệu nhập không mất.
- [ ] **SKU-06:** Sửa SKU, đổi status active/inactive, quay lại danh sách và xác nhận dữ liệu mới.
- [ ] **SKU-07:** Xóa SKU còn tồn: backend từ chối; SKU vẫn còn. Xóa SKU không tồn: xác nhận xóa và chọn Undo trong 10 giây; SKU được khôi phục và danh sách tải lại.
- [ ] **SKU-08:** Kiểm tra thông báo 401/403 và lỗi kết nối ở môi trường thử nghiệm phù hợp. Kiểm tra quyền dữ liệu với hai tài khoản customer.

## Giới hạn hiện tại

- Tra barcode bằng nhập thủ công; chưa có quét camera.
- Undo khôi phục SKU chỉ hiện trong 10 giây sau khi xóa; backend chưa có danh sách SKU đã xóa cho màn hình khôi phục về sau.
- Kiểm tra lỗi và phân quyền cần môi trường backend cùng dữ liệu thử nghiệm phù hợp.
