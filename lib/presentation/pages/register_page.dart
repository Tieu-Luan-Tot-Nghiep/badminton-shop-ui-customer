import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../manager/auth_controller.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.controller,
    required this.onRegistered,
    required this.onOpenLogin,
    this.onNavigateToHome,
  });

  final AuthController controller;
  final ValueChanged<String> onRegistered;
  final VoidCallback onOpenLogin;
  final VoidCallback? onNavigateToHome;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _acceptTerms = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đồng ý điều khoản trước khi đăng ký.'),
        ),
      );
      return;
    }

    final success = await widget.controller.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phoneNumber: _phoneController.text.trim(),
    );

    if (success && mounted) {
      widget.onRegistered(_emailController.text.trim());
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: widget.onNavigateToHome,
                          child: Text(
                            'SHUTTLE_X',
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  color: AppColors.primaryContainer,
                                  fontSize: 52,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'TẠO TÀI KHOẢN',
                          style: Theme.of(
                            context,
                          ).textTheme.displayLarge?.copyWith(fontSize: 44),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'GIA NHẬP ĐỘI NGŨ VẬN ĐỘNG VIÊN ELITE',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                letterSpacing: 1.4,
                              ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(34),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('HỌ VÀ TÊN'),
                                _input(
                                  _fullNameController,
                                  'Nguyễn Văn A',
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                      ? 'Vui lòng nhập họ và tên'
                                      : null,
                                ),
                                _label('TÊN ĐĂNG NHẬP'),
                                _input(
                                  _usernameController,
                                  'player_one_2024',
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                      ? 'Vui lòng nhập tên đăng nhập'
                                      : null,
                                ),
                                _label('EMAIL'),
                                _input(
                                  _emailController,
                                  'example@shuttlex.com',
                                  validator: (v) {
                                    final value = v?.trim() ?? '';
                                    if (value.isEmpty || !value.contains('@')) {
                                      return 'Email không hợp lệ';
                                    }
                                    return null;
                                  },
                                ),
                                _label('SỐ ĐIỆN THOẠI'),
                                _input(
                                  _phoneController,
                                  '09xxxxxxxx',
                                  validator: (v) {
                                    final value = v?.trim() ?? '';
                                    if (value.length < 9) {
                                      return 'Số điện thoại không hợp lệ';
                                    }
                                    return null;
                                  },
                                ),
                                _label('MẬT KHẨU'),
                                _input(
                                  _passwordController,
                                  '••••••••',
                                  obscure: true,
                                  validator: (v) => v == null || v.length < 6
                                      ? 'Mật khẩu tối thiểu 6 ký tự'
                                      : null,
                                ),
                                _label('XÁC NHẬN'),
                                _input(
                                  _confirmController,
                                  '••••••••',
                                  obscure: true,
                                  validator: (v) {
                                    if (v != _passwordController.text) {
                                      return 'Mật khẩu xác nhận không khớp';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: _acceptTerms,
                                      onChanged: (v) => setState(
                                        () => _acceptTerms = v ?? false,
                                      ),
                                      side: const BorderSide(
                                        color: AppColors.textSecondary,
                                      ),
                                      activeColor: AppColors.primaryContainer,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Text(
                                          'Tôi đồng ý với Điều khoản & Chính sách bảo mật của hệ thống SHUTTLE_X.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: AppColors.textPrimary,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.controller.errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      widget.controller.errorMessage!,
                                      style: TextStyle(
                                        color: Colors.redAccent.shade200,
                                      ),
                                    ),
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
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(40),
                                      ),
                                    ),
                                    child: widget.controller.isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color:
                                                  AppColors.onPrimaryContainer,
                                            ),
                                          )
                                        : Text(
                                            'ĐĂNG KÝ  →',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Đã có tài khoản? '),
                                      GestureDetector(
                                        onTap: widget.onOpenLogin,
                                        child: Text(
                                          'Đăng nhập ngay',
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.secondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String hint, {
    required String? Function(String?) validator,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: const Color(0xFF08182F),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
        ),
        validator: validator,
      ),
    );
  }
}
