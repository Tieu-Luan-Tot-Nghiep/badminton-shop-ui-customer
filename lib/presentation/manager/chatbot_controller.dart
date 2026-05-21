import 'package:flutter/foundation.dart';

import '../../data/datasources/chatbot_remote_data_source.dart';
import '../../data/models/chatbot_model.dart';
import 'auth_controller.dart';

class ChatbotMessage {
  const ChatbotMessage({
    required this.isUser,
    required this.text,
    required this.createdAt,
    this.suggestions = const [],
    this.recoveredFromMemory = false,
    this.memorySnippet,
  });

  final bool isUser;
  final String text;
  final DateTime createdAt;
  final List<ChatbotProductSuggestionModel> suggestions;
  final bool recoveredFromMemory;
  final String? memorySnippet;
}

class ChatbotController extends ChangeNotifier {
  ChatbotController(this._authController, {ChatbotRemoteDataSource? remote})
      : _remote = remote ?? ChatbotRemoteDataSource() {
    _authController.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final AuthController _authController;
  final ChatbotRemoteDataSource _remote;

  final List<ChatbotMessage> _messages = [];

  bool _isLoading = false;
  bool _isClosingSession = false;
  String? _errorMessage;
  ChatbotSessionStateModel? _sessionState;

  List<ChatbotMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isClosingSession => _isClosingSession;
  String? get errorMessage => _errorMessage;
  ChatbotSessionStateModel? get sessionState => _sessionState;

  @override
  void dispose() {
    _authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final token = _authController.session?.token;
    if (token == null || token.isEmpty) {
      _messages.clear();
      _sessionState = null;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    if (_sessionState == null && !_isLoading) {
      loadSessionState();
    }
  }

  Future<void> loadSessionState() async {
    final token = _authController.session?.token;
    if (token == null || token.isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _sessionState = await _remote.sessionState();
    } catch (_) {
      _errorMessage = 'Không tải được trạng thái chatbot';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> ask(String question) async {
    final token = _authController.session?.token;
    if (token == null || token.isEmpty || question.trim().isEmpty) return;

    _messages.add(
      ChatbotMessage(
        isUser: true,
        text: question.trim(),
        createdAt: DateTime.now(),
      ),
    );
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _remote.ask(question.trim());
      _messages.add(
        ChatbotMessage(
          isUser: false,
          text: response.answer,
          createdAt: response.sessionUpdatedAt ?? DateTime.now(),
          suggestions: response.productSuggestions,
          recoveredFromMemory: response.recoveredFromMemory,
          memorySnippet: response.recoveredMemorySnippet,
        ),
      );
      _sessionState = ChatbotSessionStateModel(
        active: true,
        turnCount: response.sessionTurnCount,
        startedAt: _sessionState?.startedAt,
        updatedAt: response.sessionUpdatedAt,
        recommendedProducts: _sessionState?.recommendedProducts ?? const [],
      );
    } catch (e) {
      _errorMessage = 'Không thể gửi câu hỏi cho chatbot';
      _messages.removeWhere((message) => message.isUser && message.text == question.trim());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ChatbotCloseSessionModel?> closeSession() async {
    final token = _authController.session?.token;
    if (token == null || token.isEmpty) return null;

    _isClosingSession = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _remote.closeSession();
      _sessionState = ChatbotSessionStateModel(
        active: false,
        turnCount: 0,
        startedAt: null,
        updatedAt: response.persistedAt,
        recommendedProducts: response.recommendedProducts,
      );
      return response;
    } catch (_) {
      _errorMessage = 'Không thể đóng phiên chatbot';
      return null;
    } finally {
      _isClosingSession = false;
      notifyListeners();
    }
  }
}
