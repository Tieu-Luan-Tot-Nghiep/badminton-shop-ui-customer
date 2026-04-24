# Agent Skill API Docs - BadmintonShop

Muc tieu: cung cap tai lieu endpoint de AI Agent co the generate giao dien frontend/chuc nang nhanh va dung context backend.

## Quy uoc chung

- Tat ca endpoint REST (tru mot so endpoint dac biet nhu VNPAY IPN) su dung wrapper:

{
  "message": "...",
  "status": "success|error",
  "statusCode": 200,
  "data": {}
}

- Auth:
  - Public: khong can token.
  - Bearer User: can header Authorization: Bearer <access_token>.
  - ADMIN: can token role ADMIN.

- Error chung:
  - 400: du lieu request khong hop le / business rule fail.
  - 401: chua dang nhap hoac token khong hop le.
  - 403: khong du quyen.
  - 404: khong tim thay resource.
  - 500: loi he thong.

## Danh sach tai lieu theo module

1. 01-auth-address.md
- Auth module
- Address module

2. 02-product-search.md
- Product module
- Brand module
- Category module
- Search module

3. 03-order-cart.md
- Cart module
- Order module
- Return/Refund flow

4. 04-promotion-review-membership.md
- Promotion module
- Review module
- Membership module

5. 05-chat-chatbot.md
- Chat REST + STOMP module
- Chatbot module

6. 06-inventory-shipping-dashboard.md
- Inventory module
- Shipping module
- Dashboard module

7. 07-frontend-screen-mapping.md
- Frontend screen mapping goi y theo endpoint
- Nhom List/Detail/Create/Update/Workflow

8. 08-frontend-api-priority.md
- Thu tu trien khai frontend theo phase (MVP -> nang cao)
- Endpoint priority + Definition of Done moi phase

## Luu y cho AI Agent generate UI

- Uu tien map field theo ten trong request/response body tai tung endpoint.
- Su dung statusCode + message de hien thi toast/noti.
- Neu endpoint co phan trang, can map page/size/totalElements/totalPages.
- Voi endpoint upload file (multipart/form-data), dung form-data thay vi JSON body.
- Voi endpoint can role ADMIN, UI can co guard route + role guard o component/action.
