import 'package:flutter/material.dart';

import '../../../../core/constants/user_friendly_strings.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../categories/presentation/pages/categories_page.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../widgets/settings_components.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _repository = FinanceRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfileData();
    });
  }

  Future<void> _refreshProfileData() async {
    if (!mounted) return;
    final session = SessionScope.of(context);
    await session.refreshSession();
  }

  void _showEditProfileSheet(BuildContext context, dynamic user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditProfileSheet(
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
              const SnackBar(content: Text('Perfil atualizado com sucesso.')),
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
      builder: (context) => ChangePasswordSheet(
        onSave: (currentPassword, newPassword) async {
          try {
            await _repository.changePassword(currentPassword: currentPassword, newPassword: newPassword);
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Senha alterada com sucesso.')),
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
      builder: (context) => DeleteAccountDialog(
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

  void _showFinancialTargetsSheet(BuildContext context, dynamic profile) {
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar perfil.')),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditFinancialTargetsSheet(
        currentTps: profile.targetTps,
        currentRdr: profile.targetRdr,
        currentIli: profile.targetIli,
        onSave: (tps, rdr, ili) async {
          try {
            await _repository.updateFinancialTargets(
              targetTps: tps,
              targetRdr: rdr,
              targetIli: ili,
            );
            if (!context.mounted) return;
            
            // Invalidar cache de missões para refletir novas metas
            CacheManager().invalidateAfterGoalUpdate();
            
            final session = SessionScope.of(context);
            await session.refreshSession();
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Metas atualizadas com sucesso.')),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao atualizar metas: $e')),
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
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          final session = SessionScope.of(context);
          await session.refreshSession();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.7),
                  ],
                ),
                borderRadius: tokens.cardRadius,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? 'Usuário',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (user?.email != null && user!.email.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      user.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  if (profile != null) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ProfileStatItem(
                          label: 'Nível',
                          value: '${profile.level}',
                          icon: Icons.military_tech,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white30,
                        ),
                        ProfileStatItem(
                          label: UxStrings.points,
                          value: '${profile.experiencePoints}',
                          icon: Icons.star_rounded,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white30,
                        ),
                        ProfileStatItem(
                          label: 'Próximo',
                          value: '${profile.nextLevelThreshold}',
                          icon: Icons.trending_up,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: profile.experiencePoints /
                            profile.nextLevelThreshold,
                        minHeight: 10,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Faltam ${profile.nextLevelThreshold - profile.experiencePoints} pontos para o próximo nível',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Conta',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            
            SettingsTile(
              icon: Icons.edit_outlined,
              title: 'Editar Perfil',
              subtitle: 'Alterar nome e e-mail',
              onTap: () => _showEditProfileSheet(context, user),
              tokens: tokens,
            ),
            const SizedBox(height: 12),
            
            SettingsTile(
              icon: Icons.category_outlined,
              title: 'Minhas Categorias',
              subtitle: 'Gerenciar categorias personalizadas',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CategoriesPage()),
              ),
              tokens: tokens,
            ),
            const SizedBox(height: 12),
            
            SettingsTile(
              icon: Icons.track_changes_outlined,
              title: 'Metas Financeiras',
              subtitle: 'Definir metas de TPS, RDR e reserva',
              onTap: () => _showFinancialTargetsSheet(context, profile),
              tokens: tokens,
            ),
            const SizedBox(height: 12),
            
            SettingsTile(
              icon: Icons.lock_outline,
              title: 'Alterar Senha',
              subtitle: 'Atualizar sua senha de acesso',
              onTap: () => _showChangePasswordSheet(context),
              tokens: tokens,
            ),
            const SizedBox(height: 12),
            

            

            

            
            SettingsTile(
              icon: Icons.delete_forever_outlined,
              title: 'Excluir Conta',
              subtitle: 'Remover permanentemente sua conta',
              onTap: () => _showDeleteAccountDialog(context),
              tokens: tokens,
            ),
            const SizedBox(height: 32),

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
