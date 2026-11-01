# Hợp đồng tích hợp FE–BE: Contract Renewal qua Addendum

**Phạm vi:** Task gia hạn hợp đồng trong Flutter app khách hàng. Tài liệu mô tả API và quy tắc backend để FE/BE đối chiếu; không quy định cấu trúc Flutter, state management, model/schema hay format sẵn có của FE.

**Nguồn đối chiếu:** [Swagger backend deploy](https://self-storage-system-be.onrender.com/api-docs/) và source trong `src/modules/contract/`. Swagger deploy có đủ các route addendum nhưng hiện không khai báo `security` cho các operation này. Trong code Flutter hiện tại, `ContractRepository.renew()` vẫn gọi endpoint renew cũ; xem mục 8.

> Các endpoint được mount từ root, ví dụ `/contracts/{id}/addendums`; không thêm `/api/v1`.

## 1. Phạm vi nghiệp vụ

Customer gửi yêu cầu gia hạn hợp đồng bằng phụ lục loại `renew`, theo dõi kết quả duyệt, đồng ý/ký bước customer, và có thể hủy trước khi phụ lục được kích hoạt. Quản lý cơ sở hoặc nhóm vận hành xử lý duyệt và ký bước nội bộ qua hệ thống phù hợp.

Các operation đổi kho (`unit_change`) dùng chung API addendum nhưng nằm ngoài phạm vi task gia hạn này.

## 2. Trạng thái và luồng xử lý

Các enum gửi/nhận từ API là chuỗi chữ thường:

| Trạng thái         | Ý nghĩa cho luồng customer                                                                             |
| ------------------ | ------------------------------------------------------------------------------------------------------ |
| `pending_approval` | Customer đã gửi yêu cầu, chờ người có quyền duyệt. Customer chưa thể ký.                               |
| `draft`            | Đã được duyệt hoặc được quản lý tạo trực tiếp; chờ chữ ký của các bên. Customer có thể ký nếu chưa ký. |
| `active`           | Hai bên đã ký; gia hạn được áp dụng vào hợp đồng.                                                      |
| `rejected`         | Quản lý từ chối; hiển thị `rejectionReason` nếu có.                                                    |
| `cancelled`        | Addendum đã bị hủy; không còn thao tác ký/duyệt.                                                       |

Luồng customer thông thường:

```text
POST addendum → pending_approval → manager approve → draft
→ customer-sign → draft (customerSigned=true)
→ staff-sign → active; contract.endDate được cập nhật
```

Quản lý có thể tạo addendum `renew` trực tiếp ở `draft`, khi đó luồng bắt đầu từ bước customer ký. Quyền duyệt/từ chối và chữ ký staff không thuộc thao tác của customer mobile.

## 3. API customer sử dụng

| Method và endpoint                                          | Mục đích                                       | Request/response đáng chú ý                                                                                                              |
| ----------------------------------------------------------- | ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `GET /contracts`                                            | Danh sách hợp đồng của customer                | Response phân trang trong `data.items` và `data.pagination`. Swagger deploy đánh dấu `page`, `limit`, `sortBy`, `sortOrder` là required. |
| `GET /contracts/{id}`                                       | Chi tiết hợp đồng và addendums                 | Addendum nằm trong `data.addendums[]`; không có endpoint GET riêng cho addendum.                                                         |
| `POST /contracts/{id}/addendums`                            | Tạo yêu cầu gia hạn                            | Body xem ví dụ bên dưới. Thành công trả về toàn bộ `ContractResponse`, gồm danh sách `addendums[]`. HTTP `201`.                          |
| `POST /contracts/{id}/addendums/{addendumId}/customer-sign` | Customer chấp thuận/ký addendum đang ở `draft` | Body gồm `termsAccepted` (nên gửi `true`) và `notes` tùy chọn. Response là Contract đã cập nhật.                                         |
| `POST /contracts/{id}/addendums/{addendumId}/cancel`        | Hủy addendum ở `pending_approval` hoặc `draft` | Body bắt buộc có `cancellationReason`. Response là Contract đã cập nhật.                                                                 |

### Tạo yêu cầu gia hạn

```http
POST /contracts/{contractId}/addendums
Authorization: Bearer <accessToken>
Content-Type: application/json
```

```json
{
  "type": "renew",
  "newEndDate": "2027-12-31T00:00:00.000Z",
  "notes": "Xin gia hạn hợp đồng"
}
```

`type` phải là `renew`. `newEndDate` bắt buộc theo nghiệp vụ RENEW và phải sau `contract.endDate` hiện tại. `notes` tối đa 1000 ký tự. Backend chỉ so sánh với ngày kết thúc hiện tại; service không kiểm tra riêng rằng ngày mới phải sau ngày hiện tại.

### Customer ký

```http
POST /contracts/{contractId}/addendums/{addendumId}/customer-sign
```

```json
{
  "termsAccepted": true,
  "notes": "Tôi đồng ý gia hạn"
}
```

`termsAccepted` mặc định là `true` trong schema; truyền `false` bị từ chối với `MESSAGE_CODE_411`. `signedAddendumFileUrls` là tùy chọn cho customer theo schema hiện tại. Sau chữ ký customer, addendum vẫn `draft`; ngày hết hạn hợp đồng chưa đổi cho tới khi phía staff ký thành công.

### Customer hủy

```http
POST /contracts/{contractId}/addendums/{addendumId}/cancel
```

```json
{
  "cancellationReason": "Tôi không tiếp tục gia hạn"
}
```

`cancellationReason` bắt buộc, 1–1000 ký tự. Chỉ cho hủy khi addendum còn `pending_approval` hoặc `draft`.

## 4. API xử lý phía cơ sở

Các route dưới đây thuộc hệ thống quản lý cơ sở/vận hành, không phải thao tác của customer mobile:

| Method và endpoint                                       | Điều kiện/trạng thái                                                                                                                                                                    |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `POST /contracts/{id}/addendums/{addendumId}/approve`    | Quản lý/Ops/Admin duyệt `pending_approval` → `draft`. Body có thể gồm `assignedStaffId`, `notes`.                                                                                       |
| `POST /contracts/{id}/addendums/{addendumId}/reject`     | Quản lý/Ops/Admin từ chối `pending_approval` → `rejected`. Body bắt buộc `rejectionReason`.                                                                                             |
| `POST /contracts/{id}/addendums/{addendumId}/staff-sign` | Quản lý/Ops/Admin ký sau customer; khi đủ chữ ký, addendum thành `active` và thay đổi hợp đồng được áp dụng. Có thể cần `signedAddendumFileUrls` nếu cấu hình backend yêu cầu bản scan. |

API approve/reject/staff-sign cũng trả về `ContractResponse`, không phải một object Addendum độc lập. Quyền staff và phạm vi cơ sở được kiểm tra trong service; `FACILITY_STAFF` không được ký addendum.

## 5. Response và cách hiểu dữ liệu

Response thành công dùng envelope chung:

```json
{
  "success": true,
  "statusCode": 200,
  "messageCode": "...",
  "message": "...",
  "data": { "id": "...", "endDate": "...", "addendums": [] }
}
```

Các trường chính trong từng phần tử `data.addendums[]` gồm:

- `id`, `addendumCode`, `type`, `status`
- `previousEndDate`, `newEndDate`
- `requestedAt`, `requestedBy`, `approvedAt`, `approvedBy`
- `customerSigned`, `customerSignedAt`, `staffSigned`, `staffSignedAt`, `completedAt`
- `rejectionReason`, `cancellationReason`, `notes`

Khi hai bên đã ký addendum `renew`, backend:

- Đặt addendum thành `active`.
- Cập nhật `contract.endDate` thành `newEndDate`.
- Đặt `contract.status` thành `active`.
- Tăng `renewalCount` và thêm bản ghi vào `contract.renewals[]`.
- Giữ nguyên `rentalPrice` hiện có; luồng gia hạn hiện chưa lấy giá mới hoặc tạo payment/invoice mới.

Sau create, customer-sign hoặc cancel, response đã chứa contract cập nhật. Khi màn hình được mở lại hoặc cần đồng bộ mới, dùng `GET /contracts/{id}` và đọc `addendums[]`; không dựng trạng thái từ kết quả cũ trên client.

## 6. Quyền và điều kiện backend

- Customer tạo RENEW phải là chủ hợp đồng (`caller.userId === contract.customerId`).
- Hợp đồng phải ở `active` hoặc `overdue` để tạo/ký RENEW.
- `newEndDate` phải sau `contract.endDate` hiện tại; ngày bằng hoặc trước ngày kết thúc bị từ chối.
- Customer chỉ ký addendum `draft` và chỉ ký một lần. Staff chỉ ký sau khi customer đã ký.
- Hợp đồng `overdue` được backend chấp nhận cho RENEW. Code Flutter hiện chỉ hiện nút gia hạn với `status == active`; cần xác nhận phạm vi sản phẩm cho `overdue`.
- Các endpoint addendum trong Swagger deploy không khai báo `security`; source controller cũng đang comment `@Security`. Controller vẫn lấy caller từ Bearer JWT và service kiểm tra owner/role. Đây là thiếu sót metadata/contract cần BE xác nhận; app cần dùng access token thật.
- Backend chỉ lưu `termsAccepted` và thời điểm ký; hiện không có nội dung điều khoản addendum được trả từ API, không có PDF addendum hay chữ ký số tích hợp. Nếu mobile cần hiển thị văn bản pháp lý, nội dung/nguồn hiển thị cần được thống nhất riêng.

## 7. Lỗi nghiệp vụ quan trọng

| HTTP / message code      | Ý nghĩa trong flow                                       |
| ------------------------ | -------------------------------------------------------- |
| `401`                    | Thiếu hoặc token không hợp lệ.                           |
| `403 / MESSAGE_CODE_103` | Customer không phải chủ hợp đồng hoặc không có quyền.    |
| `400 / MESSAGE_CODE_401` | Hợp đồng không ở trạng thái cho phép thao tác.           |
| `400 / MESSAGE_CODE_404` | Ngày gia hạn không sau `contract.endDate` hiện tại.      |
| `404 / MESSAGE_CODE_400` | Không tìm thấy hợp đồng.                                 |
| `404 / MESSAGE_CODE_409` | Không tìm thấy addendum trong hợp đồng.                  |
| `400 / MESSAGE_CODE_410` | Addendum không ở trạng thái cho thao tác hiện tại.       |
| `400 / MESSAGE_CODE_411` | Điều khoản chưa được chấp thuận (`termsAccepted=false`). |
| `400 / MESSAGE_CODE_412` | Bên gọi đã ký trước đó.                                  |
| `400 / MESSAGE_CODE_415` | Staff ký trước khi customer ký.                          |
| `400 / MESSAGE_CODE_416` | Endpoint gia hạn trực tiếp cũ đã bị vô hiệu hóa.         |

## 8. Code Flutter hiện tại và điểm cần chuyển

Trong work-tree `self-storage-system-app-flutter` hiện có:

- `ContractRepository.renew()` gọi `POST /contracts/{id}/renew`, gửi `{newEndDate, note}`.
- `ContractScreen` chỉ hiển thị “Request renewal” khi hợp đồng `active` và chưa đọc/render `addendums[]`.
- Backend vẫn để route cũ trong Swagger nhưng service luôn ném `MESSAGE_CODE_416`; body mới dùng `notes` (số nhiều), không dùng `note`.

Vì vậy hợp đồng FE–BE cho task này là chuyển renewal sang addendum flow, lấy trạng thái từ `contract.addendums[]` và không coi việc tạo request là đã gia hạn. Điểm `overdue` và nội dung điều khoản cần được xác nhận với BE/product trước khi chốt hành vi.

## 9. Các điểm cần BE xác nhận

1. Swagger deploy thiếu `security` trên addendum endpoints dù controller/service dùng caller và role. Xác nhận việc khôi phục `@Security`/cập nhật OpenAPI.
2. `GET /contracts` trong Swagger đánh dấu `sortBy` và `sortOrder` bắt buộc; Flutter `ContractRepository.list()` hiện chỉ gửi `page` và `limit`. Xác nhận API thực tế có từ chối request này không.
3. Backend cho RENEW với contract `overdue`; xác nhận customer app có hiển thị action này không.
4. Backend chỉ yêu cầu `newEndDate > contract.endDate`, không yêu cầu phải sau ngày hiện tại. Xác nhận rule ngày gia hạn mong muốn.
5. API chỉ lưu cờ đồng ý; xác nhận nguồn văn bản pháp lý mà customer cần đọc trước khi ký.

## Tham chiếu source

- `src/modules/contract/contract.controller.ts`
- `src/modules/contract/contract.service.ts`
- `src/modules/contract/schemas/contract.request.schema.ts`
- `src/modules/contract/schemas/contract.response.schema.ts`
- `src/common/enums/contract.enum.ts`
- Flutter hiện tại: `apps/flutter_mobile/lib/features/contracts/data/contract_repository.dart`, `apps/flutter_mobile/lib/features/contracts/presentation/contracts_screen.dart`
