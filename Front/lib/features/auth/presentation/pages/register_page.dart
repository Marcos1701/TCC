import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.onToggle,
  });

  final VoidCallback onToggle;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
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
      final success = await session.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!success && mounted) {
        _showFeedback('Não foi possível concluir o cadastro.', isError: true);
      }
    } on DioException catch (error) {
      final detail = error.response?.data is Map
          ? error.response!.data['detail'] as String?
          : null;
      if (!mounted) return;
      _showFeedback(detail ?? 'Não foi possível registrar. Tente novamente.',
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

  String? _validateName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Como podemos te chamar?';
    }
    if (trimmed.length < 3) {
      return 'Informe nome e sobrenome.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Email é obrigatório.';
    }
    const pattern = r'^[^@]+@[^@]+\.[^@]+$';
    if (!RegExp(pattern).hasMatch(trimmed)) {
      return 'Use um email válido.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Senha é obrigatória.';
    }
    if (value.length < 6) {
      return 'Utilize ao menos 6 caracteres.';
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
      fillColor: const Color(0xFF111111),
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
                        'Cadastro',
                        style: textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Entre com seu nome, Email e senha',
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Nome',
                        style: textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        cursorColor: Colors.white,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration(hint: 'Nome'),
                        validator: _validateName,
                      ),
                      const SizedBox(height: 24),
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
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => _showFeedback(
                                  'Redefinição de senha disponível em breve.',
                                ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: AppColors.primary,
                          textStyle: textTheme.bodyMedium?.copyWith(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: const Text('Esqueceu a senha?'),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Já possui uma conta? ',
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
                            child: const Text('Entre aqui'),
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
