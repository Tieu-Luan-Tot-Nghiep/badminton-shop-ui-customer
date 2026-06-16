import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/chatbot_model.dart';
import '../manager/chatbot_controller.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key, required this.controller});

  final ChatbotController controller;

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendQuestion() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    widget.controller.ask(text);
    _textController.clear();
    Future.delayed(const Duration(milliseconds: 80), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final messages = widget.controller.messages;
            return Column(
              children: [
                _buildHeader(context),
                if (widget.controller.sessionState != null)
                  _buildSessionStrip(context, widget.controller.sessionState!),
                if (widget.controller.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _InfoBanner(text: widget.controller.errorMessage!),
                  ),
                Expanded(
                  child: widget.controller.isLoading && messages.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryContainer,
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                          itemCount: messages.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            if (index == messages.length) {
                              return const SizedBox(height: 1);
                            }
                            final message = messages[messages.length - 1 - index];
                            return _buildMessage(context, message);
                          },
                        ),
                ),
                _buildComposer(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHighest, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryContainer,
            child: const Icon(
              Icons.smart_toy_rounded,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHUTTLE_X AI',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryContainer,
                  ),
                ),
                Text(
                  'Hỏi về vợt, giày, phụ kiện, combo phù hợp',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.controller.isClosingSession
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final result = await widget.controller.closeSession();
                    if (!mounted || result == null) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text(result.summary.isEmpty ? 'Đã đóng phiên chatbot' : result.summary)),
                    );
                  },
            icon: widget.controller.isClosingSession
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.stop_circle_outlined, color: AppColors.textSecondary),
            tooltip: 'Đóng phiên',
          ),
        ],
      ),
    );
  }

  Widget _buildSessionStrip(BuildContext context, ChatbotSessionStateModel sessionState) {
    if (!sessionState.active) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.4),
        child: Text(
          'Hãy nhập câu hỏi để bắt đầu trò chuyện',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    final updatedAt = sessionState.updatedAt;
    final updatedText = updatedAt == null ? 'Vừa cập nhật' : DateFormat('HH:mm').format(updatedAt.toLocal());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.surfaceContainerHighest.withValues(alpha: 0.25),
      child: Row(
        children: [
          const Icon(Icons.psychology_alt_rounded, size: 16, color: AppColors.primaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Phiên: ${sessionState.turnCount} lượt • $updatedText',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(BuildContext context, ChatbotMessage message) {
    final timeText = DateFormat('HH:mm').format(message.createdAt.toLocal());
    final isUser = message.isUser;

    return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isUser) ...[
          const CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.surfaceContainerHighest,
            child: Icon(Icons.smart_toy_rounded, size: 16, color: AppColors.primaryContainer),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser ? AppColors.primaryContainer : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 20),
                  ),
                ),
                child: Text(
                  message.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isUser ? AppColors.onPrimaryContainer : AppColors.textPrimary,
                  ),
                ),
              ),
              if (!isUser && message.recoveredFromMemory) ...[
                const SizedBox(height: 6),
                _MemoryBadge(text: message.memorySnippet ?? 'Đã khớp với dữ liệu trước đó'),
              ],
              if (!isUser && message.suggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 130,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: message.suggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final suggestion = message.suggestions[index];
                      return _SuggestionCard(suggestion: suggestion);
                    },
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                timeText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComposer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDim,
        border: Border(
          top: BorderSide(color: AppColors.surfaceContainerHighest, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Nhập câu hỏi cho chatbot...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _sendQuestion(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.onPrimaryContainer),
              onPressed: widget.controller.isLoading ? null : _sendQuestion,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryBadge extends StatelessWidget {
  const _MemoryBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.primaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion});

  final ChatbotProductSuggestionModel suggestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestion.brandName.isEmpty ? 'Sản phẩm gợi ý' : suggestion.brandName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.primaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            suggestion.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            suggestion.shortDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            suggestion.basePrice.toStringAsFixed(0),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.onPrimaryContainer,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.primaryContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
