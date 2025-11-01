import 'package:flutter/material.dart';

import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _tpsController = TextEditingController();
  final _rdrController = TextEditingController();
  final _iliController = TextEditingController();
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
      _iliController.text = profile.targetIli.toStringAsFixed(1);
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _tpsController.dispose();
    _rdrController.dispose();
    _iliController.dispose();
    super.dispose();
  }

  Future<void> _saveTargets() async {
    final session = SessionScope.of(context);
    final tps =
        int.tryParse(_tpsController.text) ?? session.profile?.targetTps ?? 15;
    final rdr =
        int.tryParse(_rdrController.text) ?? session.profile?.targetRdr ?? 35;
    final ili = double.tryParse(_iliController.text.replaceAll(',', '.')) ??
        session.profile?.targetIli ?? 6;
    await session.updateTargets(
      targetTps: tps,
      targetRdr: rdr,
      targetIli: ili,
    );
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
    final tokens = theme.extension<AppDecorations>()!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          children: [
            Text(
              'Perfil e ajustes',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Gerencie dados da conta, metas e acesso ao GenApp.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: tokens.heroGradient,
                borderRadius: tokens.sheetRadius,
                boxShadow: tokens.deepShadow,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: tokens.tileRadius,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    child:
                        const Icon(Icons.person, size: 36, color: Colors.white),
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
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
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
                  color: theme.colorScheme.surface,
                  borderRadius: tokens.cardRadius,
                  border: Border.all(color: theme.dividerColor),
                  boxShadow: tokens.mediumShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progresso',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value:
                          profile.experiencePoints / profile.nextLevelThreshold,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${profile.experiencePoints} / ${profile.nextLevelThreshold} XP • Nível ${profile.level}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: tokens.cardRadius,
                  border: Border.all(color: theme.dividerColor),
                  boxShadow: tokens.mediumShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Metas de indicadores',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(
                              () => _editingTargets = !_editingTargets),
                          child: Text(_editingTargets ? 'Cancelar' : 'Editar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_editingTargets) ...[
                      TextField(
                        controller: _tpsController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Meta TPS (%)'),
                      ),
                      TextField(
                        controller: _rdrController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Meta RDR (%)'),
                      ),
                      TextField(
                        controller: _iliController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Meta ILI (meses)',
                        ),
                      ),
                      const SizedBox(height: 16),
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
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Razão dívida/renda alvo: ${profile.targetRdr}%',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Liquidez imediata alvo: ${profile.targetIli.toStringAsFixed(1)} meses',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await SessionScope.of(context).logout();
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Você saiu da conta.')),
                );
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sair do GenApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.alert,
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
