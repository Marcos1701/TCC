import 'package:flutter/material.dart';

import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../leaderboard/presentation/pages/leaderboard_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
                      child: Icon(
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
            icon: Icons.person_outline,
            title: 'Editar Perfil',
            subtitle: 'Altere suas informações pessoais',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ),
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
          const SizedBox(height: 24),

          // Seção de Preferências
          Text(
            'Preferências',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notificações',
            subtitle: 'Gerencie suas notificações',
            onTap: () => _showComingSoon(context),
            tokens: tokens,
            theme: theme,
          ),
          const SizedBox(height: 12),
          
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Tema',
            subtitle: 'Modo escuro ativado',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.primary,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Ativo',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            onTap: null,
            tokens: tokens,
            theme: theme,
          ),
          const SizedBox(height: 12),
          
          _SettingsTile(
            icon: Icons.language_outlined,
            title: 'Idioma',
            subtitle: 'Português (Brasil)',
            onTap: () => _showComingSoon(context),
            tokens: tokens,
            theme: theme,
          ),
          const SizedBox(height: 24),

          // Seção de Suporte
          Text(
            'Suporte',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          
          _SettingsTile(
            icon: Icons.help_outline,
            title: 'Central de Ajuda',
            subtitle: 'Encontre respostas para suas dúvidas',
            onTap: () => _showComingSoon(context),
            tokens: tokens,
            theme: theme,
          ),
          const SizedBox(height: 12),
          
          _SettingsTile(
            icon: Icons.bug_report_outlined,
            title: 'Reportar Problema',
            subtitle: 'Nos ajude a melhorar o app',
            onTap: () => _showComingSoon(context),
            tokens: tokens,
            theme: theme,
          ),
          const SizedBox(height: 12),
          
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'Sobre',
            subtitle: 'Versão 1.0.0',
            onTap: () => _showAboutDialog(context),
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

  static void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Funcionalidade em desenvolvimento'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'GenApp',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versão 1.0.0',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[400],
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Um aplicativo de educação financeira gamificado para ajudar você a alcançar seus objetivos financeiros.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[300],
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2025 GenApp',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Fechar',
              style: TextStyle(color: AppColors.primary),
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
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
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
                if (trailing != null)
                  trailing!
                else if (onTap != null)
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
