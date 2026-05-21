import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../models/chatbot_model.dart';

class ChatbotRemoteDataSource {
  ChatbotRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  Future<ChatbotAskResponseModel> ask(String question) async {
    final response = await _dio.post(
      '/api/chatbot/ask',
      data: {'question': question},
    );
    return ChatbotAskResponseModel.fromJson(
      pickChatbotEnvelope(response.data),
    );
  }

  Future<ChatbotSessionStateModel> sessionState() async {
    final response = await _dio.get('/api/chatbot/session-state');
    return ChatbotSessionStateModel.fromJson(
      pickChatbotEnvelope(response.data),
    );
  }

  Future<ChatbotCloseSessionModel> closeSession() async {
    final response = await _dio.post('/api/chatbot/close-session');
    return ChatbotCloseSessionModel.fromJson(
      pickChatbotEnvelope(response.data),
    );
  }
}
