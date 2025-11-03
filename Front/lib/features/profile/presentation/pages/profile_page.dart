import 'package:flutter/material.dart';

import '../../../../core/models/dashboard.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _repository = FinanceRepository();
  late Future<SummaryMetrics> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
  }

  Future<SummaryMetrics> _loadSummary() async {
    final dashboard = await _repository.fetchDashboard();
    return dashboard.summary;
  }

  Future<void> _refresh() async {
    final future = _loadSummary();
    setState(() {
      _summaryFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final profile = session.profile;
    final user = session.session?.user;
    final userEmail = user?.email;
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Perfil',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: FutureBuilder<SummaryMetrics>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  // Card do usuário
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
                      boxShadow: tokens.deepShadow,
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
                        if (userEmail != null && userEmail.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            userEmail,
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
                              _StatItem(
                                label: 'Nível',
                                value: '${profile.level}',
                                icon: Icons.military_tech,
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white30,
                              ),
                              _StatItem(
                                label: 'XP',
                                value: '${profile.experiencePoints}',
                                icon: Icons.star_rounded,
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white30,
                              ),
                              _StatItem(
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
                            'Faltam ${profile.nextLevelThreshold - profile.experiencePoints} XP para o próximo nível',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Título dos indicadores
                  Text(
                    'Indicadores Financeiros',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Acompanhe seus principais indicadores do mês',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Indicadores
                  _buildIndicatorsCard(snapshot, theme, tokens),

                  const SizedBox(height: 24),

                  // Botão de sair
                  ElevatedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await SessionScope.of(context).logout();
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Você saiu da conta.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sair da Conta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.alert,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildIndicatorsCard(
    AsyncSnapshot<SummaryMetrics> snapshot,
    ThemeData theme,
    AppDecorations tokens,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: tokens.cardRadius,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (snapshot.hasError || !snapshot.hasData) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: tokens.cardRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Não foi possível carregar os indicadores.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _refresh,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    return _IndicatorCards(summary: snapshot.data!);
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _IndicatorCards extends StatelessWidget {
  const _IndicatorCards({required this.summary});

  final SummaryMetrics summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    return Column(
      children: [
        _IndicatorCard(
          label: 'Taxa de Poupança (TPS)',
          value: '${summary.tps.toStringAsFixed(1)}%',
          currentValue: summary.tps,
          description:
              'Percentual da sua renda que você conseguiu poupar este mês',
          color: const Color(0xFF4CAF50),
          icon: Icons.savings_outlined,
          tokens: tokens,
          indicatorType: IndicatorType.tps,
        ),
        const SizedBox(height: 12),
        _IndicatorCard(
          label: 'Razão Dívida/Renda (RDR)',
          value: '${summary.rdr.toStringAsFixed(1)}%',
          currentValue: summary.rdr,
          description:
              'Percentual da sua renda comprometido com dívidas',
          color: const Color(0xFFFF9800),
          icon: Icons.pie_chart_outline,
          tokens: tokens,
          indicatorType: IndicatorType.rdr,
        ),
        const SizedBox(height: 12),
        _IndicatorCard(
          label: 'Índice de Liquidez Imediata (ILI)',
          value: summary.ili < 1
              ? '${summary.ili.toStringAsFixed(1)} mês'
              : '${summary.ili.toStringAsFixed(1)} meses',
          currentValue: summary.ili,
          description:
              'Quantos meses suas reservas cobrem suas despesas essenciais',
          color: const Color(0xFF2196F3),
          icon: Icons.health_and_safety_outlined,
          tokens: tokens,
          indicatorType: IndicatorType.ili,
        ),
      ],
    );
  }
}

enum IndicatorType { tps, rdr, ili }

class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({
    required this.label,
    required this.value,
    required this.currentValue,
    required this.description,
    required this.color,
    required this.icon,
    required this.tokens,
    required this.indicatorType,
  });

  final String label;
  final String value;
  final double currentValue;
  final String description;
  final Color color;
  final IconData icon;
  final AppDecorations tokens;
  final IndicatorType indicatorType;
  
  String _getIdealTarget() {
    switch (indicatorType) {
      case IndicatorType.tps:
        if (currentValue < 20) {
          return '20% ou mais';
        } else {
          final idealTarget = (currentValue + 5).clamp(0, 100);
          return '${idealTarget.toStringAsFixed(1)}% (atual + 5%)';
        }
      case IndicatorType.rdr:
        if (currentValue > 70) {
          return '70% ou menos';
        } else {
          final idealTarget = (currentValue - 5).clamp(0, 100);
          return '${idealTarget.toStringAsFixed(1)}% (atual - 5%)';
        }
      case IndicatorType.ili:
        if (currentValue < 6) {
          return '6 meses ou mais';
        } else {
          final idealTarget = currentValue + 1;
          return '${idealTarget.toStringAsFixed(1)} meses (atual + 1)';
        }
    }
  }

  void _showExplanationDialog(BuildContext context) {
    String title = '';
    String formula = '';
    String explanation = '';
    String example = '';
    final idealTarget = _getIdealTarget();

    if (label.contains('TPS')) {
      title = 'Taxa de Poupança Pessoal (TPS)';
      formula = 'TPS = (Receitas - Despesas) / Receitas × 100';
      explanation = 'A TPS mede quanto da sua renda você consegue poupar. '
          'É calculada dividindo o valor poupado (receitas menos despesas) '
          'pelo total de receitas, multiplicado por 100 para obter a porcentagem.';
      example = 'Se você ganhou R\$ 5.000 e gastou R\$ 4.000:\n'
          'TPS = (5.000 - 4.000) / 5.000 × 100 = 20%\n\n'
          'Meta ideal baseada no seu perfil: $idealTarget';
    } else if (label.contains('RDR')) {
      title = 'Razão Dívida/Renda (RDR)';
      formula = 'RDR = Dívidas / Receitas × 100';
      explanation = 'A RDR indica quanto da sua renda está comprometida com dívidas. '
          'É calculada dividindo o total de dívidas (ou pagamentos de dívida) '
          'pelo total de receitas, multiplicado por 100.';
      example = 'Se você ganhou R\$ 5.000 e tem R\$ 2.000 em dívidas:\n'
          'RDR = 2.000 / 5.000 × 100 = 40%\n\n'
          'Meta ideal baseada no seu perfil: $idealTarget';
    } else if (label.contains('ILI')) {
      title = 'Índice de Liquidez Imediata (ILI)';
      formula = 'ILI = Reservas Líquidas / Despesas Essenciais Mensais';
      explanation = 'O ILI mostra por quantos meses você consegue manter seu padrão de vida '
          'usando apenas suas reservas (poupança), sem nenhuma receita. É calculado dividindo '
          'seu saldo de reservas pela média de despesas essenciais mensais.';
      example = 'Se você tem R\$ 12.000 em reservas e gasta R\$ 3.000/mês em essenciais:\n'
          'ILI = 12.000 / 3.000 = 4 meses\n\n'
          'Meta ideal baseada no seu perfil: $idealTarget';
    }

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
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Valor atual
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Seu $title: ',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[300],
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Fórmula
              Text(
                'Cálculo:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formula,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Explicação
              Text(
                'O que significa?',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                explanation,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[300],
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 16),
              
              // Exemplo
              Text(
                'Exemplo:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  example,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                        height: 1.5,
                      ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Entendi',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showExplanationDialog(context),
        borderRadius: tokens.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: tokens.cardRadius,
            boxShadow: tokens.mediumShadow,
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey[600],
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
