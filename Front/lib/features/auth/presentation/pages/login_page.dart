import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onToggle,
  });

  final VoidCallback onToggle;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final session = SessionScope.of(context);
    try {
      final success = await session.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!success && mounted) {
        _showFeedback('Falha no login. Confira os dados informados.',
            isError: true);
      }
    } on DioException catch (error) {
      final detail = error.response?.data is Map
          ? error.response!.data['detail'] as String?
          : null;
      if (!mounted) return;
      _showFeedback(detail ?? 'Não foi possível entrar. Tente novamente.',
          isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showFeedback(String message, {bool isError = false}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.alert : theme.colorScheme.primary,
      ),
    );
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Informe seu email.';
    }
    const pattern = r'^[^@]+@[^@]+\.[^@]+$';
    if (!RegExp(pattern).hasMatch(trimmed)) {
      return 'Email inválido. Utilize um endereço válido.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Senha é obrigatória.';
    }
    if (value.length < 6) {
      return 'Use pelo menos 6 caracteres.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final tokens = theme.extension<AppDecorations>()!;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            const _AuthBackground(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1, end: 0),
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Transform.translate(
                        offset: Offset(0, 40 * value),
                        child: Opacity(opacity: 1 - value, child: child),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: tokens.sheetRadius,
                          boxShadow: tokens.deepShadow,
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
                          child: Form(
                            key: _formKey,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: AppColors.highlight,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Bem-vindo de volta',
                                      style: textTheme.labelLarge?.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Login',
                                  style: textTheme.headlineMedium?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Entre com seu email e senha para continuar acompanhando suas finanças.',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.mail_outline),
                                  ),
                                  validator: _validateEmail,
                                ),
                                const SizedBox(height: 18),
                                TextFormField(
                                  controller: _passwordController,
                                  textInputAction: TextInputAction.done,
                                  decoration: InputDecoration(
                                    labelText: 'Senha',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                    ),
                                  ),
                                  obscureText: _obscurePassword,
                                  onFieldSubmitted: (_) => _submit(),
                                  validator: _validatePassword,
                                ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting ? null : _submit,
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              key: ValueKey('loading'),
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                              ),
                                            )
                                          : const Text(
                                              'Entrar',
                                              key: ValueKey('label'),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Center(
                                  child: TextButton(
                                    onPressed:
                                        _isSubmitting ? null : widget.onToggle,
                                    child: const Text(
                                        'Não possui conta? Registre-se'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppDecorations>()!;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: tokens.backgroundGradient),
      child: const SizedBox.expand(),
    );
  }
}
