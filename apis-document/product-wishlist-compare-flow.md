# Product Module - Wishlist & Compare Flow

## 1) Wishlist Flow

### Muc tieu
Luu san pham yeu thich de xem lai sau khi chua du ngan sach mua.

### Luong xu ly backend
1. Client goi `POST /api/products/wishlist/{productId}` voi Bearer token.
2. Controller lay principal email, goi service `addToWishlist(principalName, productId)`.
3. Service:
   - Tim user theo email.
   - Tim product theo `productId` va kiem tra product dang active.
   - Kiem tra da ton tai wishlist (`user_id + product_id`) hay chua.
   - Neu chua co thi tao moi `product_wishlists`.
4. Tra ve `WishlistItemResponse`.

### Lay danh sach wishlist
1. Client goi `GET /api/products/wishlist`.
2. Service query `product_wishlists` theo user, sort `createdAt DESC`.
3. Tra ve danh sach `WishlistItemResponse`.

### Bo khoi wishlist
1. Client goi `DELETE /api/products/wishlist/{productId}`.
2. Service tim item theo user + product va xoa neu ton tai.
3. Tra ve 200 voi `data = null`.

### Kiem tra ton tai
1. Client goi `GET /api/products/wishlist/{productId}/exists`.
2. Service check exists theo user + product.
3. Tra ve `{ "exists": true/false }`.

## 2) Product Compare Flow

### Muc tieu
So sanh 2 cay vot theo thong so ky thuat de ra quyet dinh mua nhanh hon.

### Luong xu ly backend
1. Client goi `GET /api/products/compare?variantIds=101&variantIds=202`.
2. Service validate:
   - Co dung 2 id.
   - 2 id khac nhau.
3. Service load 2 variant, kiem tra ton tai day du va thuoc product active.
4. Service map du lieu so sanh:
   - Product info: ten, slug, thumbnail, brand.
   - Variant specs: SKU, gia, weight (3U/4U), gripSize, stiffness, balancePoint.
5. Tra ve `ProductCompareResponse` gom 2 item.

## 3) Data Model Bo sung

### Bang `product_wishlists`
- `id` (PK)
- `user_id` (FK -> users)
- `product_id` (FK -> products)
- `created_at`
- Unique key: (`user_id`, `product_id`)

### Bo sung cho `product_variants`
- `weight`
- `grip_size`
- `stiffness`
- `balance_point`

## 4) Rule nghiep vu chinh
- Wishlist chi cho phep voi user da dang nhap.
- Khong cho them san pham inactive vao wishlist.
- Compare yeu cau dung 2 variant va khong trung lap.
- Compare chi nhan variant thuoc san pham active.
