# Chat + Chatbot Module

## A. CHAT MODULE (REST)
Base path: /api/chat

### 1) getOrCreateMyRoom
- Method name: getOrCreateMyRoom
- Endpoint: GET /api/chat/rooms/me
- Chuc nang: Lay room chat cua customer, neu chua co thi tao.
- Auth: Bearer User
- Response data: ChatRoomResponse
- Code: 200, 401

### 2) getRoomMessages
- Method name: getRoomMessages
- Endpoint: GET /api/chat/rooms/{roomId}/messages
- Chuc nang: Lay lich su tin nhan co phan trang.
- Auth: Bearer User (customer chi room cua minh, admin co the xem tat ca)
- Query: page, size
- Response data: Page<ChatMessageResponse>
- Code: 200, 401, 403, 404

### 3) getMyUnreadCount
- Method name: getMyUnreadCount
- Endpoint: GET /api/chat/unread-count
- Chuc nang: Lay so unread cua user.
- Auth: Bearer User
- Response data: ChatUnreadCountResponse
- Code: 200, 401

### 4) markRoomAsRead
- Method name: markRoomAsRead
- Endpoint: POST /api/chat/rooms/{roomId}/read
- Chuc nang: Danh dau da doc room.
- Auth: Bearer User
- Response data: ChatReadReceiptResponse
- Code: 200, 401, 403, 404

### 5) uploadAttachment
- Method name: uploadAttachment
- Endpoint: POST /api/chat/upload
- Chuc nang: Upload nhieu file dinh kem de gui qua STOMP.
- Auth: Bearer User
- Request: multipart/form-data
  - files[]
- Rule:
  - toi da 10 file/request
  - tong dung luong toi da 5MB/request
- Response data: List<ChatUploadResponse>
- Code: 200, 400, 401

### 6) getAdminInbox
- Method name: getAdminInbox
- Endpoint: GET /api/chat/admin/inbox
- Chuc nang: Inbox room cho admin.
- Auth: ADMIN
- Query: page, size
- Response data: Page<ChatRoomResponse>
- Code: 200, 401, 403

---

## B. CHAT MODULE (WebSocket / STOMP)

### Cau hinh
- Handshake endpoint: /ws-chat
- App destination prefix: /app
- User destination prefix: /user
- STOMP CONNECT header: Authorization: Bearer <access_token>

### 1) sendMessage
- Method name: sendMessage
- Destination: /app/chat.send
- Chuc nang: Gui tin nhan trong room.
- Auth: Bearer User
- Request payload: ChatSendMessageRequest
  - roomId
  - messageType (TEXT|IMAGE|FILE)
  - content
  - fileUrl
  - fileName
- Server push:
  - /user/queue/chat.sent (ack gui)
  - /topic/chat.room.{roomId} (stream room)
- Code/Error:
  - Loi auth: disconnect/forbidden
  - Loi validate payload: reject message

### 2) markRead
- Method name: markRead
- Destination: /app/chat.read
- Chuc nang: Danh dau da doc qua socket.
- Auth: Bearer User
- Request payload: ChatReadRequest { roomId }
- Server push:
  - /topic/chat.room.{roomId}.read

---

## C. CHATBOT MODULE
Base path: /api/chatbot

### 0) Muc tieu UI/UX cho FE
- Chatbot la workflow theo user da dang nhap.
- FE nen render theo 1 chat panel hoac 1 page rieng: nhap cau hoi, hien tra loi, hien danh sach san pham goi y neu co.
- Server khong cung cap API lay full transcript cua session. FE nen giu message list o state local neu muon hien lich su trong cung 1 lan mo trang.
- Khi reload trang, FE chi co the khoi phuc trang thai session thong qua `GET /api/chatbot/session-state`.

### 1) Common response format
Tat ca endpoint tra ve `ApiResponse<T>`:

```json
{
  "message": "Chatbot answered successfully.",
  "status": "success",
  "statusCode": 200,
  "data": {}
}
```

Neu chua dang nhap:

```json
{
  "message": "Vui long dang nhap de su dung chatbot.",
  "status": "error",
  "statusCode": 401,
  "data": null
}
```

### 2) POST /api/chatbot/ask
- Method name: `ask`
- Chuc nang: Gui cau hoi cho chatbot va nhan tra loi tu AI + goi y san pham.
- Auth: Bearer token bat buoc.
- Request body:

```json
{
  "question": "Minh can vot cau long cho nguoi moi, ngan sach 2 trieu"
}
```

- Validation:
  - `question` bat buoc, khong duoc rong.
- Response data: `ChatbotAskResponse`

```json
{
  "answer": "Ban co the chon ...",
  "recoveredFromMemory": true,
  "recoveredMemorySnippet": "Khach da tung hoi ve vot canh cong, uu tien nhe tay...",
  "productSuggestions": [
    {
      "id": 101,
      "name": "Yonex Astrox 77 Play",
      "slug": "yonex-astrox-77-play",
      "basePrice": 1890000,
      "brandName": "Yonex",
      "shortDescription": "Phu hop cho nguoi moi, de dieu khien"
    }
  ],
  "sessionTurnCount": 3,
  "sessionUpdatedAt": "2026-05-21T09:30:00"
}
```

- Y nghia cac field:
  - `answer`: noi dung tra loi chinh cua chatbot.
  - `recoveredFromMemory`: `true` neu server tim thay memory cu phu hop.
  - `recoveredMemorySnippet`: doan tom tat memory, co the `null`.
  - `productSuggestions`: danh sach san pham goi y, toi da 3 item.
  - `sessionTurnCount`: tong so turn trong phien hien tai.
  - `sessionUpdatedAt`: thoi diem cap nhat phien gan nhat.
- FE nen:
  - append cau hoi vao local state truoc khi goi API.
  - render `answer` ngay khi nhan response.
  - hien card san pham neu `productSuggestions` khong rong.
  - co the hien badge neu `recoveredFromMemory = true`.
- Status codes:
  - `200`: thanh cong
  - `400`: `question` khong hop le
  - `401`: chua dang nhap

### 3) GET /api/chatbot/session-state
- Method name: `sessionState`
- Chuc nang: Lay trang thai session cua user hien tai.
- Auth: Bearer token bat buoc.
- Response data: `ChatbotSessionStateResponse`

```json
{
  "active": true,
  "turnCount": 3,
  "startedAt": "2026-05-21T09:20:00",
  "updatedAt": "2026-05-21T09:30:00",
  "recommendedProducts": [
    "Yonex Astrox 77 Play",
    "Victor Auraspeed 30H"
  ]
}
```

- Y nghia cac field:
  - `active`: phien dang mo hay khong.
  - `turnCount`: so luot hoi dap trong phien.
  - `startedAt`: thoi diem bat dau phien.
  - `updatedAt`: thoi diem cap nhat cuoi cung.
  - `recommendedProducts`: danh sach ten san pham da duoc goi y trong phien.
- Neu khong co phien active:

```json
{
  "active": false,
  "turnCount": 0,
  "startedAt": null,
  "updatedAt": null,
  "recommendedProducts": []
}
```

- FE nen goi API nay:
  - khi vao man hinh chatbot
  - sau khi refresh trang
  - sau khi close session de dong bo UI
- Status codes:
  - `200`: thanh cong
  - `401`: chua dang nhap

### 4) POST /api/chatbot/close-session
- Method name: `closeSession`
- Chuc nang: Dong phien hien tai va luu tom tat session.
- Auth: Bearer token bat buoc.
- Khong can request body.
- Response data: `ChatbotCloseSessionResponse`

```json
{
  "persisted": true,
  "summary": "Khach hoi ve vot cho nguoi moi ...",
  "recommendedProducts": [
    "Yonex Astrox 77 Play",
    "Victor Auraspeed 30H"
  ],
  "persistedAt": "2026-05-21T09:35:00"
}
```

- Y nghia cac field:
  - `persisted`: `true` neu session da duoc luu lai.
  - `summary`: tom tat noi dung tuong tac.
  - `recommendedProducts`: danh sach san pham da duoc ghi nhan.
  - `persistedAt`: thoi diem luu session.
- Neu khong co session active:

```json
{
  "persisted": false,
  "summary": "No active chatbot session to close.",
  "recommendedProducts": [],
  "persistedAt": "2026-05-21T09:35:00"
}
```

- FE nen:
  - reset local chat list sau khi close session neu muon bat dau tu dau.
  - goi lai `session-state` de cap nhat trang thai.
- Status codes:
  - `200`: thanh cong
  - `401`: chua dang nhap

### 5) DTO contract for FE

#### ChatbotAskRequest

```json
{
  "question": "..."
}
```

#### ChatbotAskResponse

- `answer`: string
- `recoveredFromMemory`: boolean
- `recoveredMemorySnippet`: string | null
- `productSuggestions`: array of:
  - `id`: number
  - `name`: string
  - `slug`: string
  - `basePrice`: number
  - `brandName`: string | null
  - `shortDescription`: string | null
- `sessionTurnCount`: number
- `sessionUpdatedAt`: datetime string

#### ChatbotSessionStateResponse

- `active`: boolean
- `turnCount`: number
- `startedAt`: datetime string | null
- `updatedAt`: datetime string | null
- `recommendedProducts`: string[]

#### ChatbotCloseSessionResponse

- `persisted`: boolean
- `summary`: string
- `recommendedProducts`: string[]
- `persistedAt`: datetime string

### 6) Suggested FE flow

1. User vao man hinh `/assistant`.
2. FE goi `GET /api/chatbot/session-state`.
3. Neu `active = true`, hien badge trang thai phien va danh sach san pham da goi y.
4. User nhap cau hoi va bam gui.
5. FE goi `POST /api/chatbot/ask`.
6. FE append `answer` vao chat list va render `productSuggestions` neu co.
7. Khi user thoat hoac bam `Ket thuc phien`, FE goi `POST /api/chatbot/close-session`.
8. FE lam moi session-state va reset UI neu can.

### 7) Notes cho FE

- Chatbot nay khong dung STOMP/WebSocket.
- Session hien tai la theo user dang nhap, nen cac tab/trang co the chia se cung mot session.
- Neu backend restart, session trong memory co the mat.
- `productSuggestions.slug` co the dung de navigate sang trang chi tiet san pham neu FE co route tuong ung.
