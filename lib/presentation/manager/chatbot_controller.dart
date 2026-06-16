import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  Map<String, dynamic> toJson() => {
        'isUser': isUser,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'suggestions': suggestions.map((e) => e.toJson()).toList(),
        'recoveredFromMemory': recoveredFromMemory,
        'memorySnippet': memorySnippet,
      };

  factory ChatbotMessage.fromJson(Map<String, dynamic> json) {
    return ChatbotMessage(
      isUser: json['isUser'] == true,
      text: json['text'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      suggestions: (json['suggestions'] as List?)
              ?.map((e) => ChatbotProductSuggestionModel.fromJson(
                  Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      recoveredFromMemory: json['recoveredFromMemory'] == true,
      memorySnippet: json['memorySnippet'],
    );
  }
}

class ChatbotController extends ChangeNotifier {
  ChatbotController(this._authController,
      {ChatbotRemoteDataSource? remote, FlutterSecureStorage? storage})
      : _remote = remote ?? ChatbotRemoteDataSource(),
        _storage = storage ?? const FlutterSecureStorage() {
    _authController.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final AuthController _authController;
  final ChatbotRemoteDataSource _remote;
  final FlutterSecureStorage _storage;

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

  void _onAuthChanged() async {
    final token = _authController.session?.token;
    if (token == null || token.isEmpty) {
      _messages.clear();
      _sessionState = null;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    if (_sessionState == null && !_isLoading) {
      await _loadLocalMessages();
      loadSessionState();
    }
  }

  Future<void> _loadLocalMessages() async {
    try {
      final username = _authController.session?.username;
      if (username == null) return;
      final data = await _storage.read(key: 'chatbot_msgs_$username');
      if (data != null) {
        final List decoded = jsonDecode(data);
        _messages.clear();
        _messages.addAll(decoded.map(
            (e) => ChatbotMessage.fromJson(Map<String, dynamic>.from(e))));
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveLocalMessages() async {
    try {
      final username = _authController.session?.username;
      if (username == null) return;
      final encoded = jsonEncode(_messages.map((e) => e.toJson()).toList());
      await _storage.write(key: 'chatbot_msgs_$username', value: encoded);
    } catch (_) {}
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
    _saveLocalMessages();
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
      _saveLocalMessages();
    } catch (e) {
      _errorMessage = 'Không thể gửi câu hỏi cho chatbot';
      _messages.removeWhere((message) => message.isUser && message.text == question.trim());
      _saveLocalMessages();
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
