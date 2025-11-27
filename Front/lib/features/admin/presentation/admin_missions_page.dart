import 'package:flutter/material.dart';

import '../data/admin_viewmodel.dart';

/// Página de gerenciamento de missões.
/// 
/// Permite visualizar, filtrar, ativar/desativar e gerar novas missões.
class AdminMissionsPage extends StatefulWidget {
  const AdminMissionsPage({super.key, required this.viewModel});

  final AdminViewModel viewModel;

  @override
  State<AdminMissionsPage> createState() => _AdminMissionsPageState();
}

class _AdminMissionsPageState extends State<AdminMissionsPage> {
  String? _filtroTipo;
  String? _filtroDificuldade;
  bool? _filtroAtivo;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    widget.viewModel.loadMissions();
  }

  void _aplicarFiltros() {
    widget.viewModel.loadMissions(
      tipo: _filtroTipo,
      dificuldade: _filtroDificuldade,
      ativo: _filtroAtivo,
    );
  }

  Future<void> _gerarMissoes(int quantidade, bool usarIA) async {
    setState(() => _isGenerating = true);

    final resultado = await widget.viewModel.generateMissions(
      quantidade: quantidade,
      usarIA: usarIA,
    );

    setState(() => _isGenerating = false);

    if (mounted) {
      final sucesso = resultado['sucesso'] == true;
      final mensagem = sucesso
          ? resultado['mensagem'] ?? 'Missões geradas com sucesso!'
          : resultado['erro'] ?? 'Erro ao gerar missões';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: sucesso ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gerenciamento de Missões',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Visualize, edite e gere novas missões para o sistema',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Botões de geração
                      _GenerateButton(
                        label: 'Gerar 10',
                        isLoading: _isGenerating,
                        onPressed: () => _showGenerateDialog(10),
                      ),
                      const SizedBox(width: 8),
                      _GenerateButton(
                        label: 'Gerar 20',
                        isLoading: _isGenerating,
                        onPressed: () => _showGenerateDialog(20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Filtros
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _FilterDropdown(
                        label: 'Tipo',
                        value: _filtroTipo,
                        items: const {
                          null: 'Todos',
                          'ONBOARDING': 'Primeiros Passos',
                          'TPS_IMPROVEMENT': 'Taxa de Poupança',
                          'RDR_REDUCTION': 'Redução de Despesas',
                          'ILI_BUILDING': 'Reserva de Emergência',
                          'CATEGORY_REDUCTION': 'Controle de Categoria',
                        },
                        onChanged: (v) {
                          setState(() => _filtroTipo = v);
                          _aplicarFiltros();
                        },
                      ),
                      _FilterDropdown(
                        label: 'Dificuldade',
                        value: _filtroDificuldade,
                        items: const {
                          null: 'Todas',
                          'EASY': 'Fácil',
                          'MEDIUM': 'Média',
                          'HARD': 'Difícil',
                        },
                        onChanged: (v) {
                          setState(() => _filtroDificuldade = v);
                          _aplicarFiltros();
                        },
                      ),
                      _FilterDropdown(
                        label: 'Status',
                        value: _filtroAtivo?.toString(),
                        items: const {
                          null: 'Todos',
                          'true': 'Ativas',
                          'false': 'Inativas',
                        },
                        onChanged: (v) {
                          setState(() {
                            _filtroAtivo = v == null ? null : v == 'true';
                          });
                          _aplicarFiltros();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Lista de missões
            Expanded(
              child: _buildMissionsList(),
            ),

            // Paginação
            if (widget.viewModel.missionsTotalPages > 1)
              _Pagination(
                currentPage: widget.viewModel.missionsCurrentPage,
                totalPages: widget.viewModel.missionsTotalPages,
                onPageChanged: (page) {
                  widget.viewModel.loadMissions(
                    tipo: _filtroTipo,
                    dificuldade: _filtroDificuldade,
                    ativo: _filtroAtivo,
                    pagina: page,
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildMissionsList() {
    final viewModel = widget.viewModel;

    if (viewModel.isLoading && viewModel.missions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.errorMessage != null && viewModel.missions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(viewModel.errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _aplicarFiltros,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (viewModel.missions.isEmpty) {
      return const Center(
        child: Text('Nenhuma missão encontrada'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: viewModel.missions.length,
      itemBuilder: (context, index) {
        final mission = viewModel.missions[index];
        return _MissionCard(
          mission: mission,
          onToggle: () => _toggleMission(mission),
        );
      },
    );
  }

  Future<void> _toggleMission(Map<String, dynamic> mission) async {
    final id = mission['id'] as int;
    final sucesso = await widget.viewModel.toggleMission(id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sucesso ? 'Missão atualizada!' : 'Erro ao atualizar missão',
          ),
          backgroundColor: sucesso ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showGenerateDialog(int quantidade) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Gerar $quantidade Missões'),
        content: const Text(
          'Escolha o método de geração:\n\n'
          '• Templates: Mais rápido, usa modelos pré-definidos\n'
          '• IA: Mais variado, usa inteligência artificial (mais lento)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _gerarMissoes(quantidade, false);
            },
            child: const Text('Usar Templates'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _gerarMissoes(quantidade, true);
            },
            child: const Text('Usar IA'),
          ),
        ],
      ),
    );
  }
}

/// Botão de geração de missões.
class _GenerateButton extends StatelessWidget {
  const _GenerateButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add),
      label: Text(label),
    );
  }
}

/// Dropdown de filtro.
class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final Map<String?, String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String?>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: const OutlineInputBorder(),
        ),
        items: items.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

/// Card de missão individual.
class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.mission,
    required this.onToggle,
  });

  final Map<String, dynamic> mission;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isActive = mission['is_active'] as bool? ?? true;
    final difficulty = mission['difficulty'] as String? ?? 'MEDIUM';
    final missionType = mission['mission_type'] as String? ?? 'ONBOARDING';

    final difficultyColors = {
      'EASY': Colors.green,
      'MEDIUM': Colors.orange,
      'HARD': Colors.red,
    };

    final difficultyLabels = {
      'EASY': 'Fácil',
      'MEDIUM': 'Média',
      'HARD': 'Difícil',
    };

    final typeLabels = {
      'ONBOARDING': 'Primeiros Passos',
      'TPS_IMPROVEMENT': 'Taxa de Poupança',
      'RDR_REDUCTION': 'Redução de Despesas',
      'ILI_BUILDING': 'Reserva de Emergência',
      'CATEGORY_REDUCTION': 'Controle de Categoria',
      'GOAL_ACHIEVEMENT': 'Progresso em Meta',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Indicador de status
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                color: isActive ? Colors.green : Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            // Conteúdo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mission['title'] as String? ?? 'Sem título',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Badge de dificuldade
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: difficultyColors[difficulty]?.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          difficultyLabels[difficulty] ?? difficulty,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: difficultyColors[difficulty],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    typeLabels[missionType] ?? missionType,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mission['description'] as String? ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.stars,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${mission['reward_points'] ?? 0} XP',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${mission['duration_days'] ?? 0} dias',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Botão de toggle
            const SizedBox(width: 16),
            Switch(
              value: isActive,
              onChanged: (_) => onToggle(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Componente de paginação.
class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
          ),
          const SizedBox(width: 16),
          Text('Página $currentPage de $totalPages'),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
          ),
        ],
      ),
    );
  }
}
