import 'package:flutter/material.dart';

import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _tpsController = TextEditingController();
  final _rdrController = TextEditingController();
  bool _editingTargets = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final session = SessionScope.of(context);
    final profile = session.profile;
    if (profile != null) {
      _tpsController.text = profile.targetTps.toString();
      _rdrController.text = profile.targetRdr.toString();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _tpsController.dispose();
    _rdrController.dispose();
    super.dispose();
  }

  Future<void> _saveTargets() async {
    final session = SessionScope.of(context);
    final tps = int.tryParse(_tpsController.text) ?? session.profile?.targetTps ?? 15;
    final rdr = int.tryParse(_rdrController.text) ?? session.profile?.targetRdr ?? 35;
    await session.updateTargets(targetTps: tps, targetRdr: rdr);
    if (!mounted) return;
    setState(() => _editingTargets = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Metas atualizadas.')), 
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final profile = session.profile;
    final user = session.session?.user;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          children: [
            Text(
              'Perfil e ajustes',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D6FFF), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: Colors.white.withOpacity(0.18),
                    ),
                    child: const Icon(Icons.person, size: 36, color: Colors.white),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Usuário',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          user?.email ?? '',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (profile != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progresso',
                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: profile.experiencePoints / profile.nextLevelThreshold,
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${profile.experiencePoints} / ${profile.nextLevelThreshold} XP • Nível ${profile.level}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Metas de indicadores',
                          style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _editingTargets = !_editingTargets),
                          child: Text(_editingTargets ? 'Cancelar' : 'Editar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_editingTargets) ...[
                      TextField(
                        controller: _tpsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Meta TPS (%)'),
                      ),
                      TextField(
                        controller: _rdrController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Meta RDR (%)'),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveTargets,
                          child: const Text('Salvar metas'),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Taxa de poupança alvo: ${profile.targetTps}%',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Razão dívida/renda alvo: ${profile.targetRdr}%',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await SessionScope.of(context).logout();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Você saiu da conta.')), 
                );
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sair do GenApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
