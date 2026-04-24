import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../manager/auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.controller,
    required this.onLoginSuccess,
    required this.onOpenForgotPassword,
    required this.onOpenRegister,
    this.onNavigateToHome,
  });

  final AuthController controller;
  final VoidCallback onLoginSuccess;
  final VoidCallback onOpenForgotPassword;
  final VoidCallback onOpenRegister;
  final VoidCallback? onNavigateToHome;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    widget.controller.verifyEmailFromUri(Uri.base);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await widget.controller.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      widget.onLoginSuccess();
    }
  }

  Future<void> _socialLogin(SocialProvider provider) async {
    final success = await widget.controller.loginWithSocial(provider);
    if (success && mounted) {
      widget.onLoginSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
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
                    horizontal: 22,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: GestureDetector(
                              onTap: widget.onNavigateToHome,
                              child: Text(
                                'SHUTTLE_X',
                                style: Theme.of(context).textTheme.displayLarge
                                    ?.copyWith(
                                      color: AppColors.primaryContainer,
                                      fontSize: 48,
                                      fontStyle: FontStyle.italic,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ĐĂNG NHẬP',
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                fontSize: 48,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'CHÀO MỪNG VẬN ĐỘNG VIÊN CHUYÊN NGHIỆP',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                letterSpacing: 2,
                              ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(36),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TÊN ĐĂNG NHẬP',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        letterSpacing: 1.5,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                _buildInput(
                                  controller: _usernameController,
                                  hint: 'elite123',
                                  suffix: const Icon(
                                    Icons.alternate_email_rounded,
                                    color: AppColors.textSecondary,
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                      ? 'Vui lòng nhập username hoặc email'
                                      : null,
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Text(
                                      'MẬT KHẨU',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                            letterSpacing: 1.5,
                                          ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: widget.onOpenForgotPassword,
                                      child: Text(
                                        'QUÊN MẬT KHẨU?',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppColors.secondary,
                                              fontSize: 12,
                                              letterSpacing: 1.4,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _buildInput(
                                  controller: _passwordController,
                                  hint: '••••••••••',
                                  obscure: _obscure,
                                  suffix: IconButton(
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  validator: (v) => v == null || v.length < 6
                                      ? 'Mật khẩu tối thiểu 6 ký tự'
                                      : null,
                                ),
                                const SizedBox(height: 22),
                                if (widget.controller.infoMessage != null)
                                  _statusText(
                                    widget.controller.infoMessage!,
                                    false,
                                  ),
                                if (widget.controller.errorMessage != null)
                                  _statusText(
                                    widget.controller.errorMessage!,
                                    true,
                                  ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: widget.controller.isLoading
                                        ? null
                                        : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppColors.primaryContainer,
                                      foregroundColor:
                                          AppColors.onPrimaryContainer,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(40),
                                      ),
                                    ),
                                    child: widget.controller.isLoading
                                        ? const SizedBox(
                                            width: 17,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color:
                                                  AppColors.onPrimaryContainer,
                                            ),
                                          )
                                        : const Text('ĐĂNG NHẬP ⚡'),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Divider(
                                        color: Color(0xFF1B3558),
                                        thickness: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'HOẶC TIẾP TỤC VỚI',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                              fontSize: 12,
                                              letterSpacing: 1.6,
                                            ),
                                      ),
                                    ),
                                    const Expanded(
                                      child: Divider(
                                        color: Color(0xFF1B3558),
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _socialButton(
                                        label: 'GOOGLE',
                                        icon: Icons.g_mobiledata_rounded,
                                        onTap: widget.controller.isLoading
                                            ? null
                                            : () => _socialLogin(
                                                SocialProvider.google,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _socialButton(
                                        label: 'FACEBOOK',
                                        icon: Icons.facebook_rounded,
                                        onTap: widget.controller.isLoading
                                            ? null
                                            : () => _socialLogin(
                                                SocialProvider.facebook,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Chưa có tài khoản? '),
                                      GestureDetector(
                                        onTap: widget.onOpenRegister,
                                        child: Text(
                                          'Đăng ký ngay',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                color:
                                                    AppColors.primaryContainer,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
    Widget? suffix,
    bool obscure = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: const Color(0xFF050D1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        suffixIcon: suffix,
      ),
      validator: validator,
    );
  }

  Widget _statusText(String message, bool isError) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? Colors.redAccent.shade200 : AppColors.secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _socialButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: const Color(0xFF173256),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
