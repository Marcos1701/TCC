import 'package:flutter/material.dart';

import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../admin/presentation/pages/admin_ai_missions_page.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../leaderboard/presentation/pages/leaderboard_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _repository = FinanceRepository();

  void _showEditProfileSheet(BuildContext context, dynamic user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditProfileSheet(
        currentName: user?.name ?? '',
        currentEmail: user?.email ?? '',
        onSave: (name, email) async {
          try {
            await _repository.updateUserProfile(name: name, email: email);
            if (!context.mounted) return;
            final session = SessionScope.of(context);
            await session.refreshSession();
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Perfil atualizado com sucesso!')),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao atualizar perfil: $e')),
            );
          }
        },
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChangePasswordSheet(
        onSave: (currentPassword, newPassword) async {
          try {
            await _repository.changePassword(currentPassword: currentPassword, newPassword: newPassword);
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Senha alterada com sucesso!')),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao alterar senha: $e')),
            );
          }
        },
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _DeleteAccountDialog(
        onConfirm: (password) async {
          try {
            await _repository.deleteAccount(password: password);
            if (!context.mounted) return;
            Navigator.pop(context);
            await SessionScope.of(context).logout();
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
              (route) => false,
            );
          } catch (e) {
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao excluir conta: $e')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final user = session.session?.user;
    final profile = session.session?.profile;
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Configurações',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          // Card de Usuário
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.2),
                  AppColors.primary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: tokens.cardRadius,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Usuário',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Nível',
                        value: '${profile?.level ?? 0}',
                        icon: Icons.star,
                        color: AppColors.highlight,
                        tokens: tokens,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'XP Total',
                        value: '${profile?.experiencePoints ?? 0}',
                        icon: Icons.military_tech,
                        color: AppColors.primary,
                        tokens: tokens,
                        theme: theme,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Seção de Conta
          Text(
            'Conta',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          
          _SettingsTile(
            icon: Icons.edit_outlined,
            title: 'Editar Perfil',
            subtitle: 'Alterar nome e e-mail',
            onTap: () => _showEditProfileSheet(context, user),
            tokens: tokens,
            theme: theme,
          ),
          const SizedBox(height: 12),
          
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Alterar Senha',
            subtitle: 'Atualizar sua senha de acesso',
            onTap: () => _showChangePasswordSheet(context),
            tokens: tokens,
            theme: theme,
          ),
          const SizedBox(height: 12),
          
          _SettingsTile(
            icon: Icons.leaderboard,
            title: 'Ranking',
            subtitle: 'Veja sua posição no ranking',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LeaderboardPage()),
            ),
            tokens: tokens,
            theme: theme,
          ),
          const SizedBox(height: 12),
          
          // Recursos Administrativos (apenas para staff/superuser)
          if (user?.isAdmin == true) ...[
            _SettingsTile(
              icon: Icons.admin_panel_settings,
              title: 'Administração',
              subtitle: 'Gerar missões com IA',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminAiMissionsPage(),
                ),
              ),
              tokens: tokens,
              theme: theme,
            ),
            const SizedBox(height: 12),
          ],
          
          _SettingsTile(
            icon: Icons.delete_forever_outlined,
            title: 'Excluir Conta',
            subtitle: 'Remover permanentemente sua conta',
            onTap: () => _showDeleteAccountDialog(context),
            tokens: tokens,
            theme: theme,
          ),
          const SizedBox(height: 32),

          // Botão de Logout
          ElevatedButton.icon(
            onPressed: () => _confirmLogout(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.alert,
              side: const BorderSide(color: AppColors.alert, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.logout_rounded, size: 22),
            label: Text(
              'Sair da Conta',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.alert,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _confirmLogout(BuildContext context) async {
    final session = SessionScope.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Encerrar sessão?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        content: Text(
          'Você realmente deseja sair da conta?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Sair',
              style: TextStyle(
                color: AppColors.alert,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await session.logout();
      navigator.popUntil((route) => route.isFirst);
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.tokens,
    required this.theme,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final AppDecorations tokens;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[400],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.tokens,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final AppDecorations tokens;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: tokens.cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[600],
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final String currentName;
  final String currentEmail;
  final Function(String name, String email) onSave;

  const _EditProfileSheet({
    required this.currentName,
    required this.currentEmail,
    required this.onSave,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _emailController = TextEditingController(text: widget.currentEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Editar Perfil',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person, color: Colors.white70),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, insira seu nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email, color: Colors.white70),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, insira seu e-mail';
                  }
                  if (!value.contains('@')) {
                    return 'Por favor, insira um e-mail válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      widget.onSave(
                        _nameController.text.trim(),
                        _emailController.text.trim(),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Salvar Alterações'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  final Function(String currentPassword, String newPassword) onSave;

  const _ChangePasswordSheet({required this.onSave});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Alterar Senha',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _currentPasswordController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Senha Atual',
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      setState(() => _obscureCurrentPassword = !_obscureCurrentPassword);
                    },
                  ),
                ),
                obscureText: _obscureCurrentPassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira sua senha atual';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nova Senha',
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      setState(() => _obscureNewPassword = !_obscureNewPassword);
                    },
                  ),
                ),
                obscureText: _obscureNewPassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira a nova senha';
                  }
                  if (value.length < 6) {
                    return 'A senha deve ter pelo menos 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Confirmar Nova Senha',
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                    },
                  ),
                ),
                obscureText: _obscureConfirmPassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, confirme a nova senha';
                  }
                  if (value != _newPasswordController.text) {
                    return 'As senhas não coincidem';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      widget.onSave(
                        _currentPasswordController.text,
                        _newPasswordController.text,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Alterar Senha'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  final Function(String password) onConfirm;

  const _DeleteAccountDialog({required this.onConfirm});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Row(
        children: [
          Icon(Icons.warning, color: Colors.red, size: 28),
          SizedBox(width: 12),
          Text('Excluir Conta', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Esta ação é irreversível!',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 8),
          const Text(
            'Todos os seus dados, incluindo transações, missões e progresso serão permanentemente excluídos.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _passwordController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Digite sua senha para confirmar',
              labelStyle: const TextStyle(color: Colors.white70),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock, color: Colors.white70),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
            obscureText: _obscurePassword,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_passwordController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Por favor, digite sua senha')),
              );
              return;
            }
            widget.onConfirm(_passwordController.text);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Excluir Conta'),
        ),
      ],
    );
  }
}
