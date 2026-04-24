# TAI LIEU DAC TA HE THONG

## He thong Thuong mai dien tu Cau long thong minh

Phien ban: 1.0  
Muc dich: Tai lieu dac ta he thong phuc vu tieu luan tot nghiep, duoc bien soan tu hien trang trien khai thuc te cua he thong.

---

## Chuong 1: Tong quan va Muc tieu

### 1.1 Bai toan dat ra

He thong duoc xay dung de giai quyet bai toan van hanh mot nen tang thuong mai dien tu chuyen biet cho san pham cau long, bao gom:

- Ban le truc tuyen danh muc san pham da dang: vot, giay, quan ao, phu kien.
- Quan ly du lieu bien the san pham co dac tinh ky thuat chi tiet (do cung, diem can bang, can nang, size, mau sac).
- Ho tro quy trinh mua hang day du: gio hang, tao don, thanh toan, theo doi giao van, doi tra va hoan tien.
- Nang cao trai nghiem tim kiem va tu van bang ky thuat AI (semantic search, image search, chatbot).

### 1.2 Muc tieu he thong

He thong huong toi cac muc tieu sau:

1. Xay dung kien truc backend tap trung, on dinh, de mo rong theo module nghiep vu.
2. Tich hop da nguon du lieu (quan he, tai lieu, tim kiem vector) de phuc vu ca nghiep vu giao dich va nghiep vu AI.
3. Dam bao an toan xac thuc/phan quyen voi JWT va OAuth2 login.
4. Toi uu kha nang tim kiem san pham bang ket hop lexical search va vector search.
5. Ho tro quy trinh thanh toan, giao hang va xu ly sau ban hang theo huong tu dong hoa.

### 1.3 Pham vi chuc nang

Pham vi hien tai cua he thong bao gom:

- Customer-facing: dang ky, dang nhap, cap nhat ho so, quan ly dia chi, duyet san pham, tim kiem, gio hang, dat hang, theo doi don, danh gia san pham, su dung chatbot.
- Admin-facing: quan ly san pham/thuong hieu/danh muc, quan ly ton kho, quan ly khuyen mai, theo doi dashboard doanh thu.
- AI-facing: semantic search, image-based search, goi y san pham tuong tu, chatbot co bo nho phien.

### 1.4 Tac nhan (Actors)

| Tac nhan | Vai tro nghiep vu | Quyen chinh |
|---|---|---|
| CUSTOMER | Nguoi dung mua hang | Su dung API cong khai va API da xac thuc de mua hang, danh gia, su dung chatbot |
| ADMIN | Quan tri he thong | Truy cap cac API quan tri ton kho, dashboard, khuyen mai va van hanh nghiep vu |

---

## Chuong 2: Kien truc ky thuat

### 2.1 Tong quan kien truc

He thong ap dung mo hinh kien truc backend monolith theo module domain, phoi hop da thanh phan luu tru va tich hop ngoai:

- Lop API: RESTful API cho ung dung client.
- Lop nghiep vu: service xu ly logic dat hang, thanh toan, giao van, AI search va chatbot.
- Lop du lieu: PostgreSQL + Elasticsearch + MongoDB + Redis.
- Lop tich hop: VNPay, GHN, Gemini API, S3, RabbitMQ.

### 2.2 Tech stack va vai tro

| Nhom cong nghe | Cong nghe cu the | Vai tro trong he thong |
|---|---|---|
| Runtime | Java 21 | Nen thuc thi chinh cua backend |
| Framework | Spring Boot 3.4.x | To chuc ung dung, quan ly bean, cau hinh va lifecycle |
| API | Spring Web | Xay dung REST API |
| Bao mat | Spring Security, JWT, OAuth2 Client | Xac thuc JWT, social login, phan quyen vai tro |
| ORM | Spring Data JPA/Hibernate | Mapping doi tuong nghiep vu sang bang quan he |
| RDBMS | PostgreSQL | Luu giao dich cot loi (user, san pham, don hang, ton kho, khuyen mai...) |
| Search | Elasticsearch | Full-text search, faceted search, semantic search, vector index |
| NoSQL | MongoDB | Luu du lieu chat room va chat message |
| Cache | Redis | Ho tro cache/TTL cho mot so ngữ canh nghiep vu |
| Messaging | RabbitMQ (AMQP) | Trao doi su kien nghiep vu bat dong bo |
| AI Embedding | DJL + PyTorch engine + tokenizers | Sinh text embedding phuc vu semantic retrieval |
| LLM | Gemini API | Sinh cau tra loi chatbot theo ngữ canh |
| Image infra | CLIP embedding HTTP service | Sinh image vector phuc vu tim kiem theo anh |
| Object storage | AWS S3 | Luu tru file/anh |
| API docs | OpenAPI/Swagger UI | Cong bo va kiem thu API |
| DevOps | Docker, Docker Compose, Jenkins, AWS ECR | Dong goi, CI/CD, trien khai |

### 2.3 Bao mat va kiem soat truy cap

Co che bao mat duoc trien khai theo nguyen tac stateless:

- JWT duoc dung cho cac endpoint can xac thuc.
- OAuth2 login duoc ho tro cho nguoi dung dang nhap bang tai khoan xa hoi.
- Endpoint public duoc mo cho cac ngữ canh can thiet (dang nhap, dang ky, callback thanh toan, tra cuu san pham cong khai...).
- Endpoint quan tri ton kho va nghiep vu admin duoc gioi han theo role ADMIN.

### 2.4 Tich hop he thong ngoai

| Dich vu ngoai | Muc dich tich hop |
|---|---|
| VNPay | Khoi tao URL thanh toan, xu ly callback return/IPN, doi soat ket qua giao dich |
| GHN | Tinh toan/tra cuu thong tin giao van, dong bo trang thai giao hang qua webhook |
| Gemini API | Tao cau tra loi tu van san pham cho chatbot |
| CLIP service | Tra vector anh de tim kiem san pham bang hinh anh |
| AWS S3 | Luu tru media (anh san pham, avatar...) |

---

## Chuong 3: Dac ta chuc nang

### 3.1 Phan he Customer

#### 3.1.1 Xac thuc va tai khoan

He thong cung cap day du cac nghiep vu tai khoan:

- Dang ky tai khoan, dang nhap, cap moi token, dang xuat.
- Xac minh email, quen mat khau, dat lai mat khau, doi mat khau.
- Dang nhap xa hoi qua OAuth2.
- Xem va cap nhat thong tin ca nhan, cap nhat avatar.
- Quan ly dia chi giao hang (them/sua/xoa/chon mac dinh).

#### 3.1.2 Duyet san pham va tim kiem

Nguoi dung co the:

- Truy van danh sach san pham kem phan trang.
- Loc theo danh muc, thuong hieu, khoang gia.
- Sap xep theo tieu chi (ngay tao, gia tri...).
- Xem san pham noi bat, san pham moi.
- So sanh san pham va su dung wishlist.

#### 3.1.3 Gio hang va dat hang

Quy trinh dat hang gom cac buoc:

1. Them san pham bien the vao gio hang.
2. Dieu chinh so luong, xoa san pham khoi gio.
3. Lay thong tin checkout context.
4. Tao preview don de uoc tinh tong tien, phi giao hang, giam gia.
5. Xac nhan dat don va ghi nhan payment method.

#### 3.1.4 Thanh toan

He thong ho tro cac hinh thuc thanh toan sau:

- COD (thu tien khi giao hang).
- VNPay (da tich hop flow giao dich day du).
- MOMO (duoc khai bao trong kieu phuong thuc thanh toan; pham vi xu ly chinh hien tai tap trung vao VNPay).

#### 3.1.5 Theo doi don hang, huy don, doi tra

- Nguoi dung co the xem danh sach don cua minh.
- He thong cho phep huy don trong nhom trang thai hop le.
- Co quy trinh tra hang/hoan tien nhieu buoc: tao yeu cau, duyet/tu choi, nhan hang tra, thuc hien hoan tien.

#### 3.1.6 Danh gia san pham

Nguoi dung sau mua hang co the tao, sua, xoa review; tra cuu review theo san pham va xem tong hop diem danh gia.

### 3.2 Phan he Admin

#### 3.2.1 Quan tri danh muc kinh doanh

Admin co the quan ly:

- San pham va bien the san pham.
- Thuong hieu va danh muc.
- Anh va metadata san pham.
- Chuong trinh khuyen mai.

#### 3.2.2 Quan tri ton kho

He thong ton kho ho tro:

- Kiem tra kha dung ton kho.
- Reserve, commit, rollback theo giao dich don hang.
- Nhat ky bien dong ton kho (ledger).
- Cac thao tac stock-in, stock-out, stocktake-adjustment.
- Canh bao low-stock.

#### 3.2.3 Dashboard van hanh

Admin co dashboard theo dõi:

- Doanh thu.
- Doanh thu theo thuong hieu.
- San pham ban chay.
- Gia tri ton kho.

### 3.3 Luong nghiep vu trong tam

#### 3.3.1 Luong Dat hang

1. Khach hang tao gio hang.
2. He thong reserve ton kho tam thoi cho cac bien the.
3. Nguoi dung gui yeu cau dat hang.
4. He thong tao ban ghi don hang va cac order item.
5. He thong xac dinh trang thai don ban dau theo payment method.

#### 3.3.2 Luong Thanh toan VNPay

1. He thong tao URL thanh toan va dieu huong nguoi dung sang cong VNPay.
2. VNPay goi return va IPN voi bo tham so giao dich.
3. He thong xac thuc chu ky giao dich.
4. Neu thanh cong: cap nhat payment status thanh cong, commit nghiep vu lien quan.
5. Neu that bai/het han: cap nhat trang thai that bai va thuc hien huy don theo quy tac nghiep vu.
6. He thong co tac vu dinh ky auto-cancel don VNPay pending qua han.

#### 3.3.3 Luong Giao hang GHN

1. He thong lay du lieu dia gioi hanh chinh (tinh/huyen/xa) tu GHN de phuc vu checkout.
2. Sau khi tao don, he thong dong bo thong tin van don va shipping code.
3. GHN webhook gui cap nhat trang thai giao hang.
4. He thong map trang thai van chuyen sang trang thai don hang noi bo va xu ly nghiep vu tiep theo.

---

## Chuong 4: Giai phap Tri tue nhan tao (AI)

### 4.1 Tong quan AI trong he thong

He thong AI duoc trien khai theo huong ket hop retrieval va generation:

- Retrieval: Elasticsearch + vector search lay ngữ canh san pham/chu de lien quan.
- Generation: Gemini tong hop cau tra loi tu van.
- Memory: Luu va recall ngữ canh phien chat de tang tinh lien tuc hoi dap.

### 4.2 Semantic Search

#### 4.2.1 Quy trinh xu ly

Quy trinh semantic search duoc mo ta theo chuoi xu ly:

1. Tien xu ly truy van nguoi dung.
2. Tao text embedding (vector 384 chieu) tu cau truy van.
3. Truy van KNN tren chi muc vector san pham.
4. Ket hop bo loc nghiep vu (isActive/isDeleted, khoang gia, danh muc, thuong hieu).
5. Tra ve ket qua kem facet (brand, category, price range) cho UI loc nang cao.

#### 4.2.2 Y nghia nghiep vu

Semantic search giai quyet han che cua tim kiem tu khoa don thuan, giup he thong hieu y dinh truy van tu nhien vi du:

- “vot nhe cho nguoi moi”
- “vot cong thu, dau vot nang”

Ngay ca khi mo ta cua nguoi dung khong trung khop chinh xac ten san pham, he thong van co the truy xuat ket qua lien quan nhờ do do tuong dong vector.

### 4.3 Image Search voi CLIP

#### 4.3.1 Quy trinh xu ly

1. Nguoi dung tai anh san pham mau.
2. He thong gui byte anh den dich vu CLIP embedding qua HTTP.
3. Dich vu tra ve vector anh (512 chieu).
4. He thong thuc hien KNN tren truong vector anh cua chi muc san pham.
5. Tra ve danh sach san pham tuong dong ve dac trung hinh anh.

#### 4.3.2 Gia tri ung dung

Tinh nang nay ho tro nguoi dung tim san pham theo hinh mau thay vi mo ta van ban, phu hop ngữ canh thuong mai thuc te khi khach hang khong nho ten model.

### 4.4 Chatbot tu van tich hop Gemini

#### 4.4.1 Kien truc chatbot

Chatbot duoc xay dung theo mo hinh Retrieval-Augmented Generation:

- B1: Thu thap cau hoi user.
- B2: Truy xuat bo nho phien va bo nho lich su bang vector recall.
- B3: Truy xuat ung vien san pham tu he thong search.
- B4: Dung prompt co cau truc gom cau hoi + memory + du lieu san pham.
- B5: Goi Gemini sinh cau tra loi.
- B6: Neu dich vu LLM khong kha dung, su dung co che fallback noi bo.

#### 4.4.2 Co che memory

- Session memory: luu ngữ canh hoi dap trong phien dang hoat dong.
- Persistent memory: khi dong phien, he thong tong ket va luu ban ghi memory vao kho tim kiem vector.
- Recall memory: o lan hoi dap tiep theo, he thong tim memory gan nhat theo do tuong dong vector de bo sung ngữ canh.

### 4.5 Similar Products va Suggestion

Ngoai semantic search, he thong con cung cap:

- Goi y san pham tuong tu dua tren vector cua san pham nguon.
- Goi y tu khoa tim kiem va thong ke truy van thinh hanh.

---

## Chuong 5: Thiet ke Co so du lieu

### 5.1 Nguyen tac mo hinh du lieu

He thong su dung mo hinh polyglot persistence:

- Co so du lieu quan he luu giao dich cot loi.
- Co so du lieu tim kiem luu chi muc full-text va vector.
- Co so du lieu tai lieu luu ngữ canh chat realtime.

### 5.2 Thuc the quan he chinh va y nghia

#### 5.2.1 Nhom tai khoan va ho so

| Bang | Y nghia nghiep vu | Truong quan trong |
|---|---|---|
| users | Luu thong tin tai khoan nguoi dung va quyen | id, username, email, role, isActive, isEmailVerified, createdAt |
| user_addresses | Luu dia chi giao hang cua nguoi dung | receiverName, phoneNumber, province, district, ward, specificAddress, isDefault |

#### 5.2.2 Nhom danh muc san pham

| Bang | Y nghia nghiep vu | Truong quan trong |
|---|---|---|
| brands | Danh muc thuong hieu | name, slug, logo |
| categories | Danh muc loai san pham | name, slug |
| products | Thong tin san pham tong quat | name, slug, shortDescription, description, basePrice, brand_id, category_id, isActive |
| product_variants | Bien the ban hang va thong so ky thuat | sku, weight, gripSize, stiffness, balancePoint, size, color, price, stock |
| product_images | Tap hinh anh hien thi cho san pham | product_id, imageUrl, sortOrder |
| product_wishlists | Danh sach yeu thich cua user | user_id, product_id, createdAt |

Luu y nghiep vu quan trong:  
Bang product_variants la thanh phan cot loi cho nghiep vu AI va nghiep vu tim kiem ky thuat, vi chua cac thuoc tinh nhu stiffness, balance point, weight de phan loai san pham theo phong cach choi.

#### 5.2.3 Nhom gio hang, don hang va hau mai

| Bang | Y nghia nghiep vu | Truong quan trong |
|---|---|---|
| carts | Gio hang theo tung user | user_id, updatedAt |
| cart_items | Chi tiet mat hang trong gio | cart_id, variant_id, quantity |
| orders | Header don hang | orderCode, user_id, status, paymentMethod, paymentStatus, shippingFee, totalAmount |
| order_items | Chi tiet san pham trong don | order_id, variant_id, quantity, unitPrice |
| order_histories | Lich su chuyen trang thai don | order_id, status, note, changedBy, createdAt |
| order_return_requests | Yeu cau tra hang/hoan tien | order_id, status, reason, requestedAt |
| order_return_items | Chi tiet san pham yeu cau tra | return_request_id, order_item_id, quantity |

#### 5.2.4 Nhom ton kho, khuyen mai, danh gia, thanh vien

| Bang | Y nghia nghiep vu | Truong quan trong |
|---|---|---|
| inventories | So du ton kho theo bien the | variant_id, availableQty, reservedQty |
| inventory_transactions | Nhat ky bien dong ton kho | variant_id, type, quantity, note, createdAt |
| promotions | Cau hinh khuyen mai | code, discountType, discountValue, active, startAt, endAt |
| reviews | Danh gia sau mua hang | user_id, product_id, order_item_id, rating, comment |
| membership_tiers | Cau hinh hang thanh vien | name, minPoints, maxPoints, benefits |
| user_memberships | Trang thai thanh vien cua user | user_id, tier_id, points |
| point_histories | Lich su cong/tru diem | user_membership_id, deltaPoints, reason, createdAt |

### 5.3 Thiet ke du lieu tim kiem va chat

#### 5.3.1 Elasticsearch

| Chi muc | Muc dich | Truong quan trong |
|---|---|---|
| products | Tim kiem san pham da che do | name, categoryName, brandName, basePrice, my_vector, clip_image_vector |
| search_query_logs | Ghi nhan hanh vi tim kiem | queryText, createdAt |
| chat_history | Luu memory chatbot | userId, content, recommendedProducts, memory_vector, createdAt |

#### 5.3.2 MongoDB

| Collection | Muc dich | Truong quan trong |
|---|---|---|
| chat_rooms | Quan ly phong chat customer-admin | roomId, customerId, updatedAt |
| chat_messages | Luu chi tiet tin nhan | roomId, senderId, content, messageType, sentAt |

### 5.4 Quan he nghiep vu chinh

| Quan he | Mo ta |
|---|---|
| User - Address | 1-n: mot nguoi dung co nhieu dia chi |
| Brand/Category - Product | 1-n: moi san pham thuoc mot thuong hieu va mot danh muc |
| Product - ProductVariant | 1-n: moi san pham co nhieu bien the ban hang |
| User - Cart | 1-1: moi nguoi dung co mot gio hang |
| Cart - CartItem | 1-n: gio hang chua nhieu dong san pham |
| User - Order | 1-n: nguoi dung co nhieu don hang |
| Order - OrderItem | 1-n: don hang chua nhieu mat hang |
| Order - OrderHistory | 1-n: lich su bien doi trang thai don |
| Order - ReturnRequest - ReturnItem | 1-n-n: quan ly quy trinh tra hang chi tiet |
| Product/User - Review | n-n qua bang review: nguoi dung danh gia san pham da mua |

---

## Ket luan

Tai lieu dac ta nay mo ta day du he thong thuong mai dien tu cau long thong minh tren 3 truc chinh:

1. Nghiep vu thuong mai dien tu day du va kha nang van hanh admin.
2. Kien truc ky thuat da nguon du lieu, de mo rong va tich hop.
3. AI ung dung thuc te cho tim kiem, goi y va tu van ngu canh.

Cach thiet ke hien tai phu hop cho muc tieu tieu luan tot nghiep theo huong ung dung AI trong thuong mai dien tu, dong thoi du kha nang phat trien tiep theo thanh he thong production-scale.
