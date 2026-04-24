import google.generativeai as genai

# Thay bằng Key trong ảnh của bạn
genai.configure(api_key="AIzaSyBDDGbxVZUMLQq5_SNCtr34wm17gmjP90Y") 

# Danh sách các ID model chính xác hiện nay (2026)
# Bạn có thể thử 'gemini-1.5-flash' hoặc 'gemini-2.0-flash-exp'
model = genai.GenerativeModel('gemini-1.5-flash')

try:
    response = model.generate_content("Chào bạn, shop mình có vợt Yonex không?")
    print("AI trả lời:", response.text)
except Exception as e:
    print("Lỗi rồi:", e)