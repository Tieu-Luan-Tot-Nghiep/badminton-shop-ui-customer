class ChatbotProductSuggestionModel {
  const ChatbotProductSuggestionModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.basePrice,
    required this.brandName,
    required this.shortDescription,
  });

  final int id;
  final String name;
  final String slug;
  final num basePrice;
  final String brandName;
  final String shortDescription;

  factory ChatbotProductSuggestionModel.fromJson(Map<String, dynamic> json) {
    return ChatbotProductSuggestionModel(
      id: _toIntSafe(json['id']),
      name: '${json['name'] ?? ''}',
      slug: '${json['slug'] ?? ''}',
      basePrice: json['basePrice'] ?? 0,
      brandName: '${json['brandName'] ?? ''}',
      shortDescription: '${json['shortDescription'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'basePrice': basePrice,
        'brandName': brandName,
        'shortDescription': shortDescription,
      };
}

class ChatbotAskResponseModel {
  const ChatbotAskResponseModel({
    required this.answer,
    required this.recoveredFromMemory,
    required this.recoveredMemorySnippet,
    required this.productSuggestions,
    required this.sessionTurnCount,
    required this.sessionUpdatedAt,
  });

  final String answer;
  final bool recoveredFromMemory;
  final String? recoveredMemorySnippet;
  final List<ChatbotProductSuggestionModel> productSuggestions;
  final int sessionTurnCount;
  final DateTime? sessionUpdatedAt;

  factory ChatbotAskResponseModel.fromJson(Map<String, dynamic> json) {
    final suggestions = json['productSuggestions'];
    return ChatbotAskResponseModel(
      answer: '${json['answer'] ?? ''}',
      recoveredFromMemory: json['recoveredFromMemory'] == true,
      recoveredMemorySnippet: json['recoveredMemorySnippet']?.toString(),
      productSuggestions: suggestions is List
          ? suggestions
              .whereType<Map<String, dynamic>>()
              .map(ChatbotProductSuggestionModel.fromJson)
              .toList()
          : const [],
      sessionTurnCount: _toIntSafe(json['sessionTurnCount']),
      sessionUpdatedAt: _parseDateOrNull(json['sessionUpdatedAt']),
    );
  }
}

class ChatbotSessionStateModel {
  const ChatbotSessionStateModel({
    required this.active,
    required this.turnCount,
    required this.startedAt,
    required this.updatedAt,
    required this.recommendedProducts,
  });

  final bool active;
  final int turnCount;
  final DateTime? startedAt;
  final DateTime? updatedAt;
  final List<String> recommendedProducts;

  factory ChatbotSessionStateModel.fromJson(Map<String, dynamic> json) {
    final recommended = json['recommendedProducts'];
    return ChatbotSessionStateModel(
      active: json['active'] == true,
      turnCount: _toIntSafe(json['turnCount']),
      startedAt: _parseDateOrNull(json['startedAt']),
      updatedAt: _parseDateOrNull(json['updatedAt']),
      recommendedProducts: recommended is List
          ? recommended.map((item) => item.toString()).toList()
          : const [],
    );
  }
}

class ChatbotCloseSessionModel {
  const ChatbotCloseSessionModel({
    required this.persisted,
    required this.summary,
    required this.recommendedProducts,
    required this.persistedAt,
  });

  final bool persisted;
  final String summary;
  final List<String> recommendedProducts;
  final DateTime? persistedAt;

  factory ChatbotCloseSessionModel.fromJson(Map<String, dynamic> json) {
    final recommended = json['recommendedProducts'];
    return ChatbotCloseSessionModel(
      persisted: json['persisted'] == true,
      summary: '${json['summary'] ?? ''}',
      recommendedProducts: recommended is List
          ? recommended.map((item) => item.toString()).toList()
          : const [],
      persistedAt: _parseDateOrNull(json['persistedAt']),
    );
  }
}

Map<String, dynamic> pickChatbotEnvelope(dynamic payload) {
  if (payload is Map<String, dynamic>) {
    if (payload['data'] is Map<String, dynamic>) {
      return payload['data'] as Map<String, dynamic>;
    }
    if (payload['data'] != null && payload['data'] is! List) {
      return payload['data'] as Map<String, dynamic>;
    }
    return payload;
  }
  return {};
}

int _toIntSafe(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

DateTime? _parseDateOrNull(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse('$value');
}
