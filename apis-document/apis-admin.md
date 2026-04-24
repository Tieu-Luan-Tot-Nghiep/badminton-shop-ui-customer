# Admin API Guide cho FE

Tai lieu nay mo ta API cho man hinh Admin de FE tich hop dung luong nghiep vu hien tai.

## 1. Quy uoc chung

### 1.1 Base URL

- Local: `http://localhost:8081`
- Prefix API: `/api`

### 1.2 Xac thuc

Tat ca API admin yeu cau JWT Bearer token cua tai khoan role `ADMIN`.

Header bat buoc:

```http
Authorization: Bearer <access_token>
Content-Type: application/json
```

Neu token khong hop le/het han:
- `401 Unauthorized`

Neu role khong du quyen:
- `403 Forbidden`

### 1.3 Format response chung

Tat ca API tra theo envelope:

```json
{
  "message": "Get users successful",
  "status": "success",
  "statusCode": 200,
  "data": {}
}
```

### 1.4 Format paging (Spring Page)

Cac API list dang `Page<T>` co `data` nhu sau:

```json
{
  "content": [],
  "pageable": { "pageNumber": 0, "pageSize": 20 },
  "totalPages": 5,
  "totalElements": 97,
  "last": false,
  "size": 20,
  "number": 0,
  "first": true,
  "numberOfElements": 20,
  "empty": false
}
```

---

## 2. Mapping man hinh Admin -> API

| Man hinh FE | API chinh |
|---|---|
| Dashboard | `/api/admin/dashboard/*` |
| Quan ly don hang | `/api/orders/admin/*` |
| Quan ly tra hang/hoan tien | `/api/admin/returns/*` |
| Quan ly nguoi dung | `/api/users/admin/*` |
| Quan ly khuyen mai | `/api/promotions` + `/api/promotions/admin/*` |
| Quan ly san pham | `/api/products/*` (cac route admin) |
| Quan ly thuong hieu | `/api/brands/*` (cac route admin) |
| Quan ly danh muc | `/api/categories/*` (cac route admin) |
| Quan ly ton kho | `/api/inventory/admin/*` |
| Admin chat inbox | `/api/chat/admin/inbox` (real data), `/api/admin/chat/*` (mock) |
| Search index admin | `/api/search/products/reindex` |

---

## 3. Dashboard APIs

### 3.1 Lay doanh thu

- `GET /api/admin/dashboard/revenue`
- Query:
  - `startDate` (yyyy-MM-dd, optional)
  - `endDate` (yyyy-MM-dd, optional)
  - `groupBy` (`DAY` mac dinh)

Response `data`: `RevenueReportResponse[]`

```json
[
  { "period": "2026-04-01", "totalRevenue": 12000000, "totalOrders": 35 }
]
```

### 3.2 Doanh thu theo thuong hieu

- `GET /api/admin/dashboard/revenue-by-brand`
- Query: `startDate`, `endDate`

### 3.3 Top-selling

- `GET /api/admin/dashboard/top-selling`
- Query: `startDate`, `endDate`, `limit` (mac dinh 10)

### 3.4 Gia tri ton kho

- `GET /api/admin/dashboard/inventory-value`

### 3.5 KPI va thong tin nhanh

- `GET /api/admin/dashboard/kpis`
- `GET /api/admin/dashboard/recent-orders`
- `GET /api/admin/dashboard/alerts`

---

## 4. Don hang Admin APIs

## 4.1 Lay danh sach don

- `GET /api/orders/admin`
- Query:
  - `keyword` (optional)
  - `status` (optional, enum `OrderStatus`)
  - `paymentStatus` (optional, enum `PaymentStatus`)
  - `paymentMethod` (optional, enum `PaymentMethod`)
  - `from` (ISO datetime, optional)
  - `to` (ISO datetime, optional)
  - `page` (default 0)
  - `size` (default 20)

Response `data`: `Page<OrderResponse>`

### 4.2 Lay chi tiet don

- `GET /api/orders/admin/{orderCode}`

### 4.3 Cap nhat trang thai don

- `PATCH /api/orders/admin/{orderCode}/status`
- Query:
  - `status` (bat buoc)
  - `note` (optional)

### 4.4 Gan ma van don

- `POST /api/orders/admin/{orderCode}/assign-shipping`
- Query:
  - `shippingCode` (bat buoc)
  - `shippingProvider` (bat buoc)
  - `expectedDeliveryAt` (ISO datetime, optional)

### 4.5 Xac nhan COD

- `POST /api/orders/admin/{orderCode}/confirm-cod`
- Query: `note` (optional)

### 4.6 Field quan trong trong `OrderResponse`

```json
{
  "id": 1,
  "orderCode": "ORD-20260411-0001",
  "receiverName": "Nguyen Van A",
  "receiverPhone": "0909xxxxxx",
  "shippingAddress": "...",
  "status": "PENDING",
  "paymentMethod": "VNPAY",
  "paymentStatus": "AWAITING_PAYMENT",
  "voucherCode": "SALE10",
  "discountAmount": 100000,
  "itemsAmount": 1500000,
  "shippingFee": 30000,
  "totalAmount": 1430000,
  "shippingCode": null,
  "shippingProvider": null,
  "shippingExpectedDeliveryAt": null,
  "paymentUrl": "https://...",
  "createdAt": "2026-04-11T09:00:00",
  "items": [
    {
      "variantId": 12,
      "productName": "Vot Yonex ...",
      "sku": "YNX-4U-G5",
      "quantity": 1,
      "unitPrice": 1500000,
      "lineAmount": 1500000
    }
  ]
}
```

---

## 5. Tra hang / Hoan tien Admin APIs

Khuyen nghi FE su dung nhom route moi:
- `/api/admin/returns/*`

(Luu y: he thong van ton tai route cu trong order module: `/api/orders/admin/returns/*`)

### 5.1 Lay danh sach yeu cau tra

- `GET /api/admin/returns`
- Query: `keyword`, `status`, `page` (default 0), `size` (default 10)

### 5.2 Lay thong ke return

- `GET /api/admin/returns/stats`

### 5.3 Duyet / Tu choi / Nhan hang / Hoan tien

- `POST /api/admin/returns/{returnRequestId}/approve?note=...`
- `POST /api/admin/returns/{returnRequestId}/reject?note=...` (note bat buoc)
- `POST /api/admin/returns/{returnRequestId}/receive` (JSON body)
- `POST /api/admin/returns/{returnRequestId}/refund?note=...`

Body cho endpoint `receive`:

```json
{
  "note": "Hang nhan du",
  "items": [
    { "orderItemId": 101, "quantity": 1, "action": "RESTOCK" },
    { "orderItemId": 102, "quantity": 1, "action": "SCRAP" }
  ]
}
```

Field trong `ReturnRequestResponse`:

```json
{
  "id": 10,
  "orderCode": "ORD-20260411-0001",
  "status": "REQUESTED",
  "reason": "San pham loi",
  "refundMethod": "BANK_TRANSFER",
  "bankAccountName": "...",
  "bankAccountNumber": "...",
  "bankName": "...",
  "evidenceUrls": ["https://..."],
  "adminNote": "...",
  "createdAt": "2026-04-11T09:00:00",
  "updatedAt": "2026-04-11T10:00:00",
  "items": [
    {
      "orderItemId": 101,
      "variantId": 12,
      "productName": "...",
      "sku": "...",
      "requestedQuantity": 1,
      "receivedQuantity": 1,
      "action": "RESTOCK"
    }
  ]
}
```

---

## 6. Quan ly User Admin APIs

### 6.1 Lay danh sach user

- `GET /api/users/admin`
- Query: `keyword`, `role`, `active`, `page` (default 0), `size` (default 10)

### 6.2 Lay chi tiet user

- `GET /api/users/admin/{id}`

### 6.3 Khoa/mo khoa user

- `PATCH /api/users/admin/{id}/status?active=true|false`

### 6.4 Thong ke user

- `GET /api/users/admin/stats`

Field chinh `UserProfileResponse`:

```json
{
  "id": 1,
  "fullName": "...",
  "email": "...",
  "birthDate": "2000-01-01",
  "avatar": "https://...",
  "role": "CUSTOMER",
  "permissions": [],
  "username": "...",
  "phoneNumber": "...",
  "isActive": true,
  "isEmailVerified": true,
  "createdAt": "2026-04-01T11:00:00"
}
```

---

## 7. Quan ly Khuyen mai Admin APIs

## 7.1 CRUD chinh (route chung promotions)

- `POST /api/promotions` (ADMIN)
- `PUT /api/promotions/{id}` (ADMIN)
- `PATCH /api/promotions/{id}/active?active=true|false` (ADMIN)
- `GET /api/promotions` (ADMIN list, query: `page`, `size`, `activeOnly`)

Body `PromotionRequest`:

```json
{
  "code": "SALE10",
  "discountType": "PERCENT",
  "discountValue": 10,
  "minOrderValue": 500000,
  "maxDiscountAmount": 100000,
  "maxUsage": 100,
  "startDate": "2026-04-11T00:00:00",
  "expiryDate": "2026-04-30T23:59:59",
  "isActive": true
}
```

### 7.2 API admin bo sung

- `GET /api/promotions/admin/{id}`
- `DELETE /api/promotions/admin/{id}`
- `GET /api/promotions/admin/stats`
- `GET /api/promotions/admin/{id}/usages?page=0&size=10`

Field `PromotionResponse`:

```json
{
  "id": 1,
  "code": "SALE10",
  "discountType": "PERCENT",
  "discountValue": 10,
  "minOrderValue": 500000,
  "maxDiscountAmount": 100000,
  "maxUsage": 100,
  "currentUsage": 12,
  "startDate": "2026-04-11T00:00:00",
  "expiryDate": "2026-04-30T23:59:59",
  "isActive": true
}
```

---

## 8. Quan ly San pham / Brand / Category (Admin)

## 8.1 Product admin routes

- `GET /api/products/admin`
  - Query:
    - `category`, `brand`, `minPrice`, `maxPrice`, `keyword` (optional)
    - `isActive` (optional, true/false)
    - `isDeleted` (optional, true/false)
    - `page`, `size`, `sortBy`, `sortDir`
  - Response `data.content[]` bo sung:
    - `isActive`: trang thai dang kinh doanh
    - `isDeleted`: trang thai da xoa mem

- `POST /api/products`
- `POST /api/products/bulk`
- `PUT /api/products/{id}`
- `POST /api/products/{id}/thumbnail` (multipart, field `file`)
- `PATCH /api/products/{id}/status`
- `DELETE /api/products/{id}`

Variants:
- `GET /api/products/{productId}/variants`
- `POST /api/products/{productId}/variants`
- `POST /api/products/{productId}/variants/bulk`
- `PUT /api/products/{productId}/variants/{variantId}`
- `DELETE /api/products/{productId}/variants/{variantId}`

Images:
- `GET /api/products/{productId}/images`
- `POST /api/products/{productId}/images` (multipart, fields: `file`, `color`, `isMain`)
- `POST /api/products/{productId}/images/bulk` (multipart, fields: `metadata` json array + `files`)
- `PUT /api/products/{productId}/images/{imageId}`
- `DELETE /api/products/{productId}/images/{imageId}`

Body `ProductRequest`:

```json
{
  "name": "Vot Yonex Astrox ...",
  "shortDescription": "...",
  "description": "...",
  "basePrice": 1500000,
  "categoryId": 2,
  "brandId": 1
}
```

Body `ProductVariantRequest`:

```json
{
  "sku": "YNX-AX77-4U-G5",
  "weight": "4U",
  "gripSize": "G5",
  "stiffness": "Medium",
  "balancePoint": "Head Heavy",
  "size": "Default",
  "color": "Black/Blue",
  "price": 1500000,
  "stock": 30,
  "shippingWeightGrams": 90,
  "shippingLengthCm": 68,
  "shippingWidthCm": 25,
  "shippingHeightCm": 5
}
```

## 8.2 Brand admin routes

- `POST /api/brands`
- `PUT /api/brands/{id}`
- `POST /api/brands/{id}/logo` (multipart `file`)
- `DELETE /api/brands/{id}`

Body `BrandRequest`:

```json
{ "name": "Yonex", "description": "..." }
```

## 8.3 Category admin routes

- `POST /api/categories`
- `POST /api/categories/bulk`
- `PUT /api/categories/{id}`
- `DELETE /api/categories/{id}`

Body `CategoryRequest`:

```json
{ "name": "Vot cau long", "description": "...", "parentId": null }
```

---

## 9. Quan ly Ton kho (Admin)

## 9.1 API thao tac ton kho

- `POST /api/inventory/admin/stock-in`
- `POST /api/inventory/admin/stock-out`
- `POST /api/inventory/admin/stocktake-adjustment`
- `GET /api/inventory/admin/ledger/{variantId}?page=0&size=20`
- `GET /api/inventory/admin/low-stock?threshold=10`

Body mau:

`stock-in`
```json
{ "variantId": 12, "quantity": 20, "unitCost": 900000, "note": "Nhap lo thang 4" }
```

`stock-out`
```json
{ "variantId": 12, "quantity": 2, "note": "Hu hong" }
```

`stocktake-adjustment`
```json
{ "variantId": 12, "actualAvailableQuantity": 17, "note": "Kiem ke cuoi ngay" }
```

Response snapshot:

```json
{
  "variantId": 12,
  "sku": "YNX-AX77-4U-G5",
  "productName": "Vot Yonex ...",
  "availableQuantity": 17,
  "reservedQuantity": 0,
  "lowStockThreshold": 5
}
```

---

## 10. Search admin

- `POST /api/search/products/reindex`

Dung khi FE admin can trigger dong bo lai index search sau khi cap nhat du lieu lon.

---

## 11. Admin Chat APIs

## 11.1 Route co du lieu that (khuyen nghi)

- `GET /api/chat/admin/inbox?page=0&size=20`

## 11.2 Route mock cho UI demo

- `GET /api/admin/chat/inbox`
- `GET /api/admin/chat/rooms/{roomId}/messages?page=0&size=20`
- `POST /api/admin/chat/messages`
- `POST /api/admin/chat/rooms/{roomId}/read`
- `GET /api/admin/chat/unread-summary`

Khuyen nghi FE production:
- Su dung route that trong module chat (`/api/chat/...`) de lay du lieu thuc.
- Chi dung `/api/admin/chat/*` khi can mock UI.

---

## 12. Enum reference cho FE

### 12.1 OrderStatus

`PENDING, AWAITING_PAYMENT, CONFIRMED, PROCESSING, SHIPPING, DELIVERED, RETURN_REQUESTED, AWAITING_RETURN, RETURN_RECEIVED, REFUNDED, CANCELLED, RETURNED`

### 12.2 PaymentStatus

`AWAITING_PAYMENT, PENDING, COMPLETED, FAILED, REFUNDED`

### 12.3 PaymentMethod

`COD, VNPAY, MOMO, CREDIT_CARD`

### 12.4 ReturnRequestStatus

`REQUESTED, AWAITING_RETURN, REJECTED, RECEIVED, REFUNDED`

### 12.5 ReturnItemAction

`RESTOCK, SCRAP`

---

## 13. Goi y luong call FE

### 13.1 Don hang admin page

1. Call `GET /api/orders/admin` de render table.
2. Click detail -> `GET /api/orders/admin/{orderCode}`.
3. Action update status -> `PATCH /api/orders/admin/{orderCode}/status`.
4. Neu co van don -> `POST /api/orders/admin/{orderCode}/assign-shipping`.

### 13.2 Return management page

1. Call `GET /api/admin/returns`.
2. Tab thong ke -> `GET /api/admin/returns/stats`.
3. Action theo trang thai -> approve/reject/receive/refund APIs.

### 13.3 Promotion page

1. List -> `GET /api/promotions`.
2. Create/Update -> `POST/PUT /api/promotions`.
3. Toggle active -> `PATCH /api/promotions/{id}/active`.
4. Stats/usages -> `GET /api/promotions/admin/stats`, `GET /api/promotions/admin/{id}/usages`.

---

## 14. Luu y tich hop

1. `DateTime` query phai gui theo ISO-8601, vi du: `2026-04-11T09:30:00`.
2. Khi upload file, su dung `multipart/form-data`.
3. Cac endpoint list dang `Page<T>`, FE can map `content` + `totalElements` + `totalPages`.
4. Neu nhan `status = error`, hien thi `message` tu backend.
5. Nen thong nhat route return admin moi: `/api/admin/returns/*`.
