import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../manager/auth_controller.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.controller,
    required this.email,
    required this.onBackToLogin,
  });

  final AuthController controller;
  final String email;
  final VoidCallback onBackToLogin;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.verifyEmailFromUri(Uri.base);
  }

  Future<void> _resend() async {
    await widget.controller.resendVerificationEmail(email: widget.email);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final canLogin = widget.controller.canLoginAfterVerification;
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF04152D), AppColors.surfaceDim],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(44),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.18,
                                ),
                                blurRadius: 52,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_rounded,
                            size: 72,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          'XÁC THỰC EMAIL',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                color: AppColors.primaryContainer,
                                fontStyle: FontStyle.italic,
                                fontSize: 54,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Vui lòng kiểm tra email của bạn để hoàn tất đăng ký và gia nhập đội hình SHUTTLE_X.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.alternate_email_rounded,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _maskEmail(widget.email),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(24),
                            border: Border(
                              left: BorderSide(
                                color: AppColors.secondary,
                                width: 4,
                              ),
                            ),
                          ),
                          child: Text(
                            'Chúng tôi đã gửi link kích hoạt. Nếu không thấy, hãy kiểm tra thư mục Spam.',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(height: 1.45),
                          ),
                        ),
                        if (widget.controller.infoMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.controller.infoMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.secondary),
                          ),
                        ],
                        if (widget.controller.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.controller.errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.redAccent.shade200),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: widget.controller.isLoading
                                ? null
                                : _resend,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('GỬI LẠI EMAIL XÁC THỰC'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: BorderSide(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(36),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: canLogin ? widget.onBackToLogin : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: AppColors.onPrimaryContainer,
                              disabledBackgroundColor:
                                  AppColors.surfaceContainer,
                              disabledForegroundColor: AppColors.textSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(36),
                              ),
                            ),
                            child: Text(
                              canLogin ? 'ĐĂNG NHẬP NGAY' : 'ĐĂNG NHẬP NGAY',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _maskEmail(String input) {
    final parts = input.split('@');
    if (parts.length != 2) {
      return input;
    }

    final name = parts.first;
    final domain = parts.last;
    if (name.length <= 3) {
      return '${name[0]}***@$domain';
    }
    return '${name.substring(0, 3)}***@$domain';
  }
}
