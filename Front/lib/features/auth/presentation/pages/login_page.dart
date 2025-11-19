import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/services/feedback_service.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';

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
      await session.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            FeedbackService.showSuccess(
              context,
              'Login realizado com sucesso.',
            );
          }
        });
      }
    } catch (error) {
      if (!mounted) return;
      
      String message;
      FeedbackType type = FeedbackType.error;
      
      if (error is DioException) {
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout) {
          message = 'Tempo de conexão esgotado. Verifique sua internet.';
          type = FeedbackType.warning;
        } else if (error.type == DioExceptionType.connectionError) {
          message = 'Servidor offline. Tente novamente mais tarde.';
          type = FeedbackType.offline;
        } else if (error.response?.statusCode == 401) {
          message = 'Email ou senha incorretos.';
        } else if (error.response?.statusCode == 400) {
          final detail = error.response?.data is Map
              ? error.response!.data['detail'] as String?
              : null;
          message = detail ?? 'Dados inválidos.';
        } else if (error.response?.statusCode != null && 
                   error.response!.statusCode! >= 500) {
          message = 'Problema no servidor. Tente novamente em instantes.';
          type = FeedbackType.serverError;
        } else {
          final detail = error.response?.data is Map
              ? error.response!.data['detail'] as String?
              : null;
          message = detail ?? 'Erro ao conectar. Verifique sua conexão.';
        }
      } else if (error is FormatException) {
        message = 'Email ou senha incorretos.';
      } else {
        message = 'Erro inesperado. Tente novamente.';
      }
      
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FeedbackService.show(context, message, type: type);
        }
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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

  InputDecoration _buildInputDecoration({
    required String hint,
    Widget? suffix,
  }) {
    const baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: Colors.white24, width: 1.2),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.alert, width: 1.4),
      ),
      focusedErrorBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.alert, width: 1.4),
      ),
      suffixIcon: suffix,
      suffixIconColor: Colors.white70,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Login',
                        style: textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Entre com seu email e senha.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Email',
                        style: textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        cursorColor: Colors.white,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration(hint: 'Email'),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Senha',
                        style: textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        textInputAction: TextInputAction.done,
                        cursorColor: Colors.white,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration(
                          hint: 'senha',
                          suffix: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
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
                      const SizedBox(height: 36),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _isSubmitting
                                ? const SizedBox(
                                    key: ValueKey('loading'),
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : Text(
                                    'Entrar',
                                    key: const ValueKey('label'),
                                    style: textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Não possui conta? ',
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.white60,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          TextButton(
                            onPressed:
                                _isSubmitting ? null : widget.onToggle,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: AppColors.primary,
                              textStyle: textTheme.bodyMedium?.copyWith(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Registre-se'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
