import 'package:flutter/material.dart';

import '../../../core/state/session_controller.dart';
import '../../../presentation/shell/root_shell.dart';
import '../data/admin_viewmodel.dart';
import 'admin_missions_page.dart';
import 'admin_categories_page.dart';
import 'admin_users_page.dart';

/// Página Principal do Painel Administrativo.
///
/// Esta tela fornece acesso centralizado às funcionalidades de
/// gerenciamento do sistema de educação financeira gamificada,
/// organizada em quatro seções principais:
///
/// 1. Visão Geral: Exibe estatísticas consolidadas do sistema.
/// 2. Missões: Gerenciamento das missões de gamificação.
/// 3. Categorias: Administração das categorias padrão.
/// 4. Usuários: Visualização e gerenciamento de usuários.
///
/// A interface utiliza o componente NavigationRail do Material Design 3
/// para proporcionar uma navegação intuitiva entre as seções.
///
/// Desenvolvido como parte do TCC - Sistema de Educação Financeira Gamificada.
class AdminPanelPage extends StatefulWidget {
  /// Cria uma nova instância da página do painel administrativo.
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final AdminViewModel _viewModel = AdminViewModel();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _viewModel.loadDashboard();
  }

  /// Navega para a tela principal do aplicativo.
  ///
  /// Permite ao administrador alternar para a visão de usuário comum
  /// do aplicativo, mantendo sua sessão autenticada.
  void _navigateToApp(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RootShell()),
    );
  }

  /// Exibe diálogo de confirmação e executa o logout.
  ///
  /// Após confirmação do usuário, encerra a sessão atual
  /// e redireciona para a tela de login.
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja realmente sair do sistema?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await SessionScope.of(context).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel Administrativo'),
        centerTitle: true,
        elevation: 0,
        actions: [
          // Botão para acessar o app como usuário
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Ir para o App',
            onPressed: () => _navigateToApp(context),
          ),
          // Botão de logout
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: Row(
        children: [
          // Menu lateral
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Visão Geral'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                label: Text('Missões'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category),
                label: Text('Categorias'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outlined),
                selectedIcon: Icon(Icons.people),
                label: Text('Usuários'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Conteúdo principal
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _AdminDashboardContent(viewModel: _viewModel);
      case 1:
        return AdminMissionsPage(viewModel: _viewModel);
      case 2:
        return AdminCategoriesPage(viewModel: _viewModel);
      case 3:
        return AdminUsersPage(viewModel: _viewModel);
      default:
        return const Center(child: Text('Página não encontrada'));
    }
  }
}

/// Conteúdo da seção Visão Geral do painel administrativo.
///
/// Exibe estatísticas consolidadas do sistema através de cards
/// informativos e gráficos de distribuição, incluindo:
///
/// - Total de usuários ativos e administradores;
/// - Quantidade de missões ativas no sistema;
/// - Taxa de conclusão das missões pelos usuários;
/// - Distribuição de missões por tipo e dificuldade.
class _AdminDashboardContent extends StatelessWidget {
  /// Cria o conteúdo do dashboard administrativo.
  const _AdminDashboardContent({required this.viewModel});

  final AdminViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        if (viewModel.isLoading && viewModel.dashboardStats == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (viewModel.errorMessage != null && viewModel.dashboardStats == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  viewModel.errorMessage!,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: viewModel.loadDashboard,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }

        final stats = viewModel.dashboardStats;
        if (stats == null) {
          return const Center(child: Text('Nenhum dado disponível'));
        }

        final usuarios = stats['usuarios'] as Map<String, dynamic>? ?? {};
        final missoes = stats['missoes'] as Map<String, dynamic>? ?? {};
        final progresso = stats['progresso'] as Map<String, dynamic>? ?? {};
        final categorias = stats['categorias'] as Map<String, dynamic>? ?? {};

        return RefreshIndicator(
          onRefresh: viewModel.loadDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                Text(
                  'Visão Geral do Sistema',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Estatísticas e métricas do sistema de educação financeira',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // Cards de estatísticas
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _StatCard(
                      title: 'Usuários',
                      value: '${usuarios['total'] ?? 0}',
                      subtitle: '${usuarios['administradores'] ?? 0} administradores',
                      icon: Icons.people,
                      color: Colors.blue,
                    ),
                    _StatCard(
                      title: 'Missões',
                      value: '${missoes['total'] ?? 0}',
                      subtitle: '${missoes['ativas'] ?? 0} ativas',
                      icon: Icons.emoji_events,
                      color: Colors.amber,
                    ),
                    _StatCard(
                      title: 'Taxa de Conclusão',
                      value: '${progresso['taxa_conclusao'] ?? 0}%',
                      subtitle: '${progresso['total_concluidas'] ?? 0} concluídas',
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                    _StatCard(
                      title: 'Categorias',
                      value: '${categorias['total'] ?? 0}',
                      subtitle: '${categorias['sistema'] ?? 0} do sistema',
                      icon: Icons.category,
                      color: Colors.purple,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Distribuição de missões por tipo
                if (missoes['por_tipo'] != null) ...[
                  Text(
                    'Missões por Tipo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MissionTypeChart(data: missoes['por_tipo'] as Map<String, dynamic>),
                ],

                const SizedBox(height: 32),

                // Distribuição por dificuldade
                if (missoes['por_dificuldade'] != null) ...[
                  Text(
                    'Missões por Dificuldade',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DifficultyChart(data: missoes['por_dificuldade'] as Map<String, dynamic>),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Card de estatística para exibição de métricas do sistema.
///
/// Componente reutilizável que apresenta uma métrica numérica
/// com título, valor principal, subtítulo descritivo e ícone
/// representativo, seguindo o padrão visual do Material Design.
class _StatCard extends StatelessWidget {
  /// Cria um card de estatística.
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 200,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gráfico de distribuição de missões por tipo.
///
/// Apresenta visualmente a proporção de missões cadastradas
/// em cada categoria (ONBOARDING, TPS_IMPROVEMENT, etc.),
/// utilizando indicadores coloridos e percentuais.
class _MissionTypeChart extends StatelessWidget {
  /// Cria um gráfico de tipos de missão.
  const _MissionTypeChart({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = data.values.fold<int>(0, (sum, v) => sum + (v as int));

    if (total == 0) {
      return const Text('Nenhuma missão cadastrada');
    }

    final typeLabels = {
      'ONBOARDING': 'Primeiros Passos',
      'TPS_IMPROVEMENT': 'Taxa de Poupança',
      'RDR_REDUCTION': 'Redução de Despesas',
      'ILI_BUILDING': 'Reserva de Emergência',
      'CATEGORY_REDUCTION': 'Controle de Categoria',
      'GOAL_ACHIEVEMENT': 'Progresso em Meta',
    };

    final typeColors = {
      'ONBOARDING': Colors.blue,
      'TPS_IMPROVEMENT': Colors.green,
      'RDR_REDUCTION': Colors.orange,
      'ILI_BUILDING': Colors.purple,
      'CATEGORY_REDUCTION': Colors.teal,
      'GOAL_ACHIEVEMENT': Colors.pink,
    };

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: data.entries.map((entry) {
        final count = entry.value as int;
        final percent = (count / total * 100).toStringAsFixed(1);
        final label = typeLabels[entry.key] ?? entry.key;
        final color = typeColors[entry.key] ?? Colors.grey;

        return SizedBox(
          width: 180,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$count ($percent%)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Gráfico de distribuição de missões por nível de dificuldade.
///
/// Apresenta uma barra horizontal segmentada que ilustra a
/// proporção de missões em cada nível de dificuldade:
/// Fácil (verde), Média (laranja) e Difícil (vermelho).
class _DifficultyChart extends StatelessWidget {
  /// Cria um gráfico de dificuldade.
  const _DifficultyChart({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = data.values.fold<int>(0, (sum, v) => sum + (v as int));

    if (total == 0) {
      return const Text('Nenhuma missão cadastrada');
    }

    final difficultyLabels = {
      'EASY': 'Fácil',
      'MEDIUM': 'Média',
      'HARD': 'Difícil',
    };

    final difficultyColors = {
      'EASY': Colors.green,
      'MEDIUM': Colors.orange,
      'HARD': Colors.red,
    };

    return Row(
      children: data.entries.map((entry) {
        final count = entry.value as int;
        final percent = count / total;
        final label = difficultyLabels[entry.key] ?? entry.key;
        final color = difficultyColors[entry.key] ?? Colors.grey;

        return Expanded(
          flex: count,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '$count (${(percent * 100).toStringAsFixed(0)}%)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
