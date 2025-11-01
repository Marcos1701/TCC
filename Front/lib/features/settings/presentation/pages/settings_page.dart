import 'package:flutter/material.dart';

import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/pages/profile_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final user = session.session?.user;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Configurações',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  child: const Icon(Icons.person_outline, color: Colors.white),
                ),
                title: Text(
                  user?.name ?? 'Perfil',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                      ),
                ),
                subtitle: Text(
                  'Editar perfil',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                        fontFamily: 'Montserrat',
                      ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Colors.white54),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => _confirmLogout(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.alert,
              side: const BorderSide(color: AppColors.alert),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: Text(
              'Sair da conta',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.alert,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
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
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Encerrar sessão?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
              ),
        ),
        content: Text(
          'Você realmente deseja sair da conta?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                fontFamily: 'Montserrat',
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Sair',
              style: TextStyle(color: AppColors.alert),
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
