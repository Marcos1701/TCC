import 'package:flutter/material.dart';

import '../data/admin_viewmodel.dart';

/// Página de Gerenciamento de Missões do Painel Administrativo.
///
/// Esta tela permite ao administrador do sistema realizar operações
/// de gerenciamento das missões de gamificação financeira, incluindo:
/// - Visualização de todas as missões cadastradas no sistema;
/// - Filtragem por tipo, dificuldade e status de ativação;
/// - Ativação e desativação de missões individuais;
/// - Geração em lote de novas missões via templates ou IA.
///
/// Desenvolvido como parte do TCC - Sistema de Educação Financeira Gamificada.
class AdminMissionsPage extends StatefulWidget {
  /// Cria uma nova instância da página de gerenciamento de missões.
  ///
  /// Requer um [viewModel] para gerenciar o estado e comunicação com a API.
  const AdminMissionsPage({super.key, required this.viewModel});

  /// ViewModel responsável pelo gerenciamento de estado das missões.
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

    try {
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
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            // Cabeçalho compacto - fixo no topo
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Missões',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isGenerating) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Botões compactos
                  IconButton.filled(
                    onPressed: () => _showCreateMissionDialog(),
                    icon: const Icon(Icons.add, size: 20),
                    tooltip: 'Nova Missão',
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _GenerateButton(
                    label: '+10',
                    isLoading: _isGenerating,
                    onPressed: () => _showGenerateDialog(10),
                  ),
                  const SizedBox(width: 4),
                  _GenerateButton(
                    label: '+20',
                    isLoading: _isGenerating,
                    onPressed: () => _showGenerateDialog(20),
                  ),
                ],
              ),
            ),
            // Filtros compactos
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterDropdown(
                      label: 'Tipo',
                      value: _filtroTipo,
                      items: const {
                        null: 'Todos',
                        'ONBOARDING': 'Onboarding',
                        'TPS_IMPROVEMENT': 'TPS',
                        'RDR_REDUCTION': 'RDR',
                        'ILI_BUILDING': 'ILI',
                        'CATEGORY_REDUCTION': 'Categoria',
                        'GOAL_ACHIEVEMENT': 'Meta',
                      },
                      onChanged: (v) {
                        setState(() => _filtroTipo = v);
                        _aplicarFiltros();
                      },
                    ),
                    const SizedBox(width: 8),
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
                    const SizedBox(width: 8),
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
              ),
            ),
            const SizedBox(height: 8),

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
          onTap: () => _showMissionDetails(mission),
          onEdit: () => _showEditMissionDialog(mission),
          onDelete: () => _confirmDeleteMission(mission),
        );
      },
    );
  }

  /// Exibe detalhes completos de uma missão em um diálogo.
  void _showMissionDetails(Map<String, dynamic> mission) {
    showDialog(
      context: context,
      builder: (context) => _MissionDetailsDialog(
        mission: mission,
        onEdit: () {
          Navigator.pop(context);
          _showEditMissionDialog(mission);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDeleteMission(mission);
        },
        onToggle: () async {
          await _toggleMission(mission);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  /// Exibe diálogo para edição de uma missão.
  void _showEditMissionDialog(Map<String, dynamic> mission) {
    showDialog(
      context: context,
      builder: (context) => _EditMissionDialog(
        mission: mission,
        viewModel: widget.viewModel,
        onSave: (dados) async {
          final id = mission['id'] as int;
          final resultado = await widget.viewModel.updateMission(id, dados);

          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  resultado['sucesso'] == true
                      ? 'Missão atualizada com sucesso!'
                      : resultado['erro'] ?? 'Erro ao atualizar missão',
                ),
                backgroundColor:
                    resultado['sucesso'] == true ? Colors.green : Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  /// Exibe diálogo para criar uma nova missão.
  void _showCreateMissionDialog() {
    showDialog(
      context: context,
      builder: (context) => _EditMissionDialog(
        mission: null,
        viewModel: widget.viewModel,
        isCreating: true,
        onSave: (dados) async {
          final resultado = await widget.viewModel.createMission(dados);

          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  resultado['sucesso'] == true
                      ? 'Missão criada com sucesso!'
                      : resultado['erro'] ?? 'Erro ao criar missão',
                ),
                backgroundColor:
                    resultado['sucesso'] == true ? Colors.green : Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  /// Exibe confirmação antes de excluir uma missão.
  void _confirmDeleteMission(Map<String, dynamic> mission) {
    final titulo = mission['title'] as String? ?? 'esta missão';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Missão'),
        content: Text(
          'Tem certeza que deseja excluir a missão "$titulo"?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final id = mission['id'] as int;
              final sucesso = await widget.viewModel.deleteMission(id);

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      sucesso
                          ? 'Missão excluída com sucesso!'
                          : 'Erro ao excluir missão',
                    ),
                    backgroundColor: sucesso ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
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

  /// Exibe diálogo para seleção do método de geração de missões.
  ///
  /// O administrador pode escolher entre dois métodos:
  /// - Templates: Utiliza modelos pré-definidos (execução rápida);
  /// - Inteligência Artificial: Gera missões mais variadas (execução mais lenta).
  void _showGenerateDialog(int quantidade) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Gerar $quantidade Missões'),
        content: const Text(
          'Selecione o método de geração das missões:\n\n'
          '• Templates: Geração rápida utilizando modelos pré-definidos '
          'com variações nos parâmetros.\n\n'
          '• Inteligência Artificial: Geração mais diversificada através '
          'de modelo de linguagem (processamento mais demorado).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _gerarMissoes(quantidade, false);
            },
            child: const Text('Templates'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _gerarMissoes(quantidade, true);
            },
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('IA'),
          ),
        ],
      ),
    );
  }
}

/// Botão para iniciar o processo de geração de missões em lote.
///
/// Exibe um indicador de carregamento durante o processamento
/// e desabilita interações enquanto a operação está em andamento.
class _GenerateButton extends StatelessWidget {
  /// Cria um botão de geração de missões.
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

/// Componente de seleção para filtragem de missões.
///
/// Permite ao administrador selecionar critérios de filtragem
/// através de um menu suspenso com opções pré-definidas.
class _FilterDropdown extends StatelessWidget {
  /// Cria um dropdown de filtro.
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
      width: 200,
      child: DropdownButtonFormField<String?>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: const OutlineInputBorder(),
        ),
        items: items.entries
            .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(
                    e.value,
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

/// Cartão de apresentação de uma missão individual.
///
/// Exibe as informações principais da missão de forma organizada:
/// - Indicador visual de status (ativa/inativa);
/// - Título e tipo da missão;
/// - Descrição resumida;
/// - Recompensa em pontos de experiência (XP);
/// - Duração em dias;
/// - Controle de ativação/desativação.
class _MissionCard extends StatelessWidget {
  /// Cria um cartão de missão.
  const _MissionCard({
    required this.mission,
    required this.onToggle,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> mission;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
      ),
    );
  }
}

/// Componente de navegação entre páginas da listagem.
///
/// Permite ao administrador navegar entre as páginas de resultados
/// quando há mais missões do que o limite por página permite exibir.
class _Pagination extends StatelessWidget {
  /// Cria um componente de paginação.
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

/// Diálogo de detalhamento de uma missão.
///
/// Exibe todas as informações da missão de forma organizada,
/// incluindo opções para editar, excluir ou alterar o status.
class _MissionDetailsDialog extends StatelessWidget {
  const _MissionDetailsDialog({
    required this.mission,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final Map<String, dynamic> mission;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isActive = mission['is_active'] as bool? ?? true;
    final difficulty = mission['difficulty'] as String? ?? 'MEDIUM';
    final missionType = mission['mission_type'] as String? ?? 'ONBOARDING';
    final validationType = mission['validation_type'] as String? ?? '';

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

    final typeLabels = {
      'ONBOARDING': 'Primeiros Passos',
      'TPS_IMPROVEMENT': 'Taxa de Poupança (TPS)',
      'RDR_REDUCTION': 'Redução de Despesas (RDR)',
      'ILI_BUILDING': 'Reserva de Emergência (ILI)',
      'CATEGORY_REDUCTION': 'Controle de Categoria',
      'GOAL_ACHIEVEMENT': 'Progresso em Meta',
    };

    final validationLabels = {
      'TRANSACTION_COUNT': 'Contagem de Transações',
      'INDICATOR_THRESHOLD': 'Limite de Indicador',
      'CATEGORY_REDUCTION': 'Redução em Categoria',
      'GOAL_PROGRESS': 'Progresso em Meta',
      'TEMPORAL': 'Período de Tempo',
    };

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              mission['title'] as String? ?? 'Detalhes da Missão',
              style: theme.textTheme.titleLarge,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isActive ? 'Ativa' : 'Inativa',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isActive ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Descrição
              Text(
                mission['description'] as String? ?? 'Sem descrição',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // Informações principais
              _DetailRow(
                label: 'Tipo',
                value: typeLabels[missionType] ?? missionType,
                icon: Icons.category,
              ),
              _DetailRow(
                label: 'Dificuldade',
                value: difficultyLabels[difficulty] ?? difficulty,
                icon: Icons.trending_up,
                valueColor: difficultyColors[difficulty],
              ),
              _DetailRow(
                label: 'Validação',
                value: validationLabels[validationType] ?? validationType,
                icon: Icons.verified,
              ),
              _DetailRow(
                label: 'Recompensa',
                value: '${mission['reward_points'] ?? 0} XP',
                icon: Icons.stars,
                valueColor: Colors.amber,
              ),
              _DetailRow(
                label: 'Duração',
                value: '${mission['duration_days'] ?? 0} dias',
                icon: Icons.schedule,
              ),
              _DetailRow(
                label: 'Prioridade',
                value: '${mission['priority'] ?? 1}',
                icon: Icons.low_priority,
              ),

              // Campos específicos por tipo
              if (mission['target_tps'] != null)
                _DetailRow(
                  label: 'Meta TPS',
                  value: '${mission['target_tps']}%',
                  icon: Icons.savings,
                ),
              if (mission['target_rdr'] != null)
                _DetailRow(
                  label: 'Meta RDR',
                  value: '${mission['target_rdr']}%',
                  icon: Icons.money_off,
                ),
              if (mission['min_ili'] != null)
                _DetailRow(
                  label: 'ILI Mínimo',
                  value: '${mission['min_ili']} meses',
                  icon: Icons.shield,
                ),
              if (mission['min_transactions'] != null)
                _DetailRow(
                  label: 'Transações Mínimas',
                  value: '${mission['min_transactions']}',
                  icon: Icons.receipt_long,
                ),
              if (mission['target_reduction_percent'] != null)
                _DetailRow(
                  label: 'Redução Alvo',
                  value: '${mission['target_reduction_percent']}%',
                  icon: Icons.trending_down,
                ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Informações do sistema
              Text(
                'Informações do Sistema',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _DetailRow(
                label: 'ID',
                value: '${mission['id'] ?? '-'}',
                icon: Icons.tag,
              ),
              if (mission['created_at'] != null)
                _DetailRow(
                  label: 'Criada em',
                  value: _formatDate(mission['created_at'] as String),
                  icon: Icons.calendar_today,
                ),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        // Botão Excluir (lado esquerdo)
        TextButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Excluir'),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
        ),
        // Botões do lado direito
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botão Toggle
            TextButton.icon(
              onPressed: onToggle,
              icon: Icon(
                isActive ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              label: Text(isActive ? 'Desativar' : 'Ativar'),
            ),
            const SizedBox(width: 8),
            // Botão Editar
            ElevatedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Editar'),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return isoDate;
    }
  }
}

/// Linha de detalhe para o diálogo de detalhes da missão.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo de edição de missão.
///
/// Permite ao administrador modificar os campos principais da missão.
/// Os campos exibidos são dinâmicos de acordo com o tipo de missão selecionado.
class _EditMissionDialog extends StatefulWidget {
  const _EditMissionDialog({
    required this.mission,
    required this.onSave,
    required this.viewModel,
    this.isCreating = false,
  });

  final Map<String, dynamic>? mission;
  final Function(Map<String, dynamic>) onSave;
  final AdminViewModel viewModel;
  final bool isCreating;

  @override
  State<_EditMissionDialog> createState() => _EditMissionDialogState();
}

class _EditMissionDialogState extends State<_EditMissionDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _rewardController;
  late final TextEditingController _durationController;
  late final TextEditingController _priorityController;
  late String _difficulty;
  late String _missionType;
  bool _isLoading = false;
  
  // Controladores para campos específicos de cada tipo
  final Map<String, TextEditingController> _typeSpecificControllers = {};
  final Map<String, bool> _booleanFields = {};
  
  // Seleções de FK (categorias e metas)
  int? _selectedCategoryId;
  int? _selectedGoalId;
  List<int> _selectedCategoriesIds = [];
  List<int> _selectedGoalsIds = [];

  @override
  void initState() {
    super.initState();
    
    // Carregar schemas após o build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.viewModel.loadMissionTypeSchemas();
      widget.viewModel.loadMissionSelectOptions();
    });
    
    final mission = widget.mission;
    
    _titleController = TextEditingController(
      text: mission?['title'] as String? ?? '',
    );
    _descriptionController = TextEditingController(
      text: mission?['description'] as String? ?? '',
    );
    _rewardController = TextEditingController(
      text: '${mission?['reward_points'] ?? 50}',
    );
    _durationController = TextEditingController(
      text: '${mission?['duration_days'] ?? 30}',
    );
    _priorityController = TextEditingController(
      text: '${mission?['priority'] ?? 50}',
    );
    _difficulty = mission?['difficulty'] as String? ?? 'MEDIUM';
    _missionType = mission?['mission_type'] as String? ?? 'ONBOARDING';
    
    // Inicializar campos específicos do tipo
    _initTypeSpecificFields();
  }

  void _initTypeSpecificFields() {
    final mission = widget.mission;
    
    // Campos numéricos comuns
    final numericFields = [
      'min_transactions',
      'target_tps',
      'target_rdr',
      'min_ili',
      'max_ili',
      'target_reduction_percent',
      'category_spending_limit',
      'goal_progress_target',
      'savings_increase_amount',
      'min_consecutive_days',
    ];
    
    for (final field in numericFields) {
      final value = mission?[field];
      _typeSpecificControllers[field] = TextEditingController(
        text: value != null ? '$value' : '',
      );
    }
    
    // Campos booleanos
    _booleanFields['requires_consecutive_days'] = 
        mission?['requires_consecutive_days'] as bool? ?? false;
    _booleanFields['requires_daily_action'] = 
        mission?['requires_daily_action'] as bool? ?? false;
    _booleanFields['is_active'] = 
        mission?['is_active'] as bool? ?? true;
    
    // Inicializar seleções de FK
    final targetCategory = mission?['target_category'] as Map<String, dynamic>?;
    _selectedCategoryId = targetCategory?['id'] as int?;
    
    final targetGoal = mission?['target_goal'] as Map<String, dynamic>?;
    _selectedGoalId = targetGoal?['id'] as int?;
    
    // Multi-seleções (se disponíveis)
    final targetCategories = mission?['target_categories'] as List<dynamic>?;
    if (targetCategories != null) {
      _selectedCategoriesIds = targetCategories
          .map((c) => (c as Map<String, dynamic>)['id'] as int)
          .toList();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rewardController.dispose();
    _durationController.dispose();
    _priorityController.dispose();
    
    for (final controller in _typeSpecificControllers.values) {
      controller.dispose();
    }
    
    super.dispose();
  }

  void _onTypeChanged(String? value) {
    if (value != null && value != _missionType) {
      setState(() {
        _missionType = value;
        // Atualizar valores padrão baseados no tipo
        _updateDefaultsForType();
      });
    }
  }

  void _updateDefaultsForType() {
    final schema = widget.viewModel.getSchemaForType(_missionType);
    if (schema == null) return;
    
    // Atualizar dificuldade recomendada
    final recommendedDifficulty = schema['recommended_difficulty'] as String?;
    if (recommendedDifficulty != null && widget.isCreating) {
      _difficulty = recommendedDifficulty;
    }
    
    // Atualizar duração recomendada
    final recommendedDuration = schema['recommended_duration'] as int?;
    if (recommendedDuration != null && widget.isCreating) {
      _durationController.text = '$recommendedDuration';
    }
    
    // Atualizar recompensa recomendada
    final recommendedReward = schema['recommended_reward'] as Map<String, dynamic>?;
    if (recommendedReward != null && widget.isCreating) {
      final reward = recommendedReward[_difficulty] as int? ?? 100;
      _rewardController.text = '$reward';
    }
  }

  void _salvar() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O título é obrigatório'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final dados = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'reward_points': int.tryParse(_rewardController.text) ?? 50,
      'duration_days': int.tryParse(_durationController.text) ?? 30,
      'priority': int.tryParse(_priorityController.text) ?? 50,
      'difficulty': _difficulty,
      'mission_type': _missionType,
      'is_active': _booleanFields['is_active'] ?? true,
    };
    
    // Adicionar campos específicos do tipo
    _addTypeSpecificData(dados);
    
    // Validar no servidor
    final validation = await widget.viewModel.validateMissionData(dados);
    
    if (validation['valido'] != true) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        final erros = (validation['erros'] as List<dynamic>?)?.join('\n') ?? 'Erro de validação';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(erros),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    widget.onSave(dados);
  }

  void _addTypeSpecificData(Map<String, dynamic> dados) {
    final schema = widget.viewModel.getSchemaForType(_missionType);
    
    if (schema == null) {
      // Fallback: adicionar campos básicos quando schema não disponível
      _addFallbackFields(dados);
      return;
    }
    
    // Adicionar campos obrigatórios
    final requiredFields = schema['required_fields'] as List<dynamic>? ?? [];
    for (final field in requiredFields) {
      final fieldMap = field as Map<String, dynamic>;
      final key = fieldMap['key'] as String;
      _addFieldValue(dados, key, fieldMap);
    }
    
    // Adicionar campos opcionais se preenchidos
    final optionalFields = schema['optional_fields'] as List<dynamic>? ?? [];
    for (final field in optionalFields) {
      final fieldMap = field as Map<String, dynamic>;
      final key = fieldMap['key'] as String;
      _addFieldValue(dados, key, fieldMap);
    }
    
    // Adicionar campos booleanos
    dados['requires_consecutive_days'] = _booleanFields['requires_consecutive_days'] ?? false;
    dados['requires_daily_action'] = _booleanFields['requires_daily_action'] ?? false;
    
    // Adicionar campos de FK com sufixo _id
    if (_selectedCategoryId != null) {
      dados['target_category_id'] = _selectedCategoryId;
    }
    if (_selectedGoalId != null) {
      dados['target_goal_id'] = _selectedGoalId;
    }
    if (_selectedCategoriesIds.isNotEmpty) {
      dados['target_categories_ids'] = _selectedCategoriesIds;
    }
    if (_selectedGoalsIds.isNotEmpty) {
      dados['target_goals_ids'] = _selectedGoalsIds;
    }
  }

  void _addFallbackFields(Map<String, dynamic> dados) {
    // Campos obrigatórios por tipo
    final typeFields = {
      'ONBOARDING': ['min_transactions'],
      'TPS_IMPROVEMENT': ['target_tps'],
      'RDR_REDUCTION': ['target_rdr'],
      'ILI_BUILDING': ['min_ili'],
      'CATEGORY_REDUCTION': ['target_reduction_percent'],
      'GOAL_ACHIEVEMENT': ['goal_progress_target'],
    };
    
    final fields = typeFields[_missionType] ?? [];
    
    for (final field in fields) {
      if (_typeSpecificControllers.containsKey(field)) {
        final text = _typeSpecificControllers[field]!.text.trim();
        if (text.isNotEmpty) {
          // Campos de ILI são decimais, outros são inteiros
          if (field == 'min_ili' || field == 'target_reduction_percent' || field == 'goal_progress_target') {
            dados[field] = double.tryParse(text);
          } else {
            dados[field] = int.tryParse(text);
          }
        }
      }
    }
    
    // Campos booleanos
    dados['requires_consecutive_days'] = _booleanFields['requires_consecutive_days'] ?? false;
    dados['requires_daily_action'] = _booleanFields['requires_daily_action'] ?? false;
    
    // Dias consecutivos se aplicável
    if (_booleanFields['requires_consecutive_days'] == true) {
      final daysText = _typeSpecificControllers['min_consecutive_days']?.text.trim() ?? '';
      if (daysText.isNotEmpty) {
        dados['min_consecutive_days'] = int.tryParse(daysText);
      }
    }
  }

  void _addFieldValue(Map<String, dynamic> dados, String key, Map<String, dynamic> fieldDef) {
    final type = fieldDef['type'] as String?;
    
    if (type == 'boolean') {
      dados[key] = _booleanFields[key] ?? false;
    } else if (type == 'category_select') {
      // Tratado separadamente em _addTypeSpecificData
      return;
    } else if (type == 'goal_select') {
      // Tratado separadamente em _addTypeSpecificData
      return;
    } else if (type == 'multi_select') {
      // Tratado separadamente em _addTypeSpecificData
      return;
    } else if (_typeSpecificControllers.containsKey(key)) {
      final text = _typeSpecificControllers[key]!.text.trim();
      if (text.isNotEmpty) {
        if (type == 'integer') {
          dados[key] = int.tryParse(text);
        } else if (type == 'decimal' || type == 'percentage') {
          dados[key] = double.tryParse(text);
        } else {
          dados[key] = text;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final isLoadingData = widget.viewModel.loadingSchemas || 
                              widget.viewModel.loadingSelectOptions;
        
        return AlertDialog(
          title: Text(widget.isCreating ? 'Nova Missão' : 'Editar Missão'),
          content: SizedBox(
            width: 600,
            height: 500,
            child: isLoadingData
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tipo de Missão (no topo para campos dinâmicos)
                        _buildTypeSelector(theme, colorScheme),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        
                        // Campos Básicos
                        _buildBasicFields(theme),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        
                        // Campos Específicos do Tipo
                        _buildTypeSpecificFields(theme, colorScheme),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _salvar,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isCreating ? 'Criar' : 'Salvar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeSelector(ThemeData theme, ColorScheme colorScheme) {
    final typesList = widget.viewModel.missionTypesList;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de Missão',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _missionType,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: typesList.isEmpty
              ? _getDefaultTypeItems()
              : typesList.map((type) {
                  return DropdownMenuItem(
                    value: type['value'] as String,
                    child: Row(
                      children: [
                        Text(
                          type['icon'] as String? ?? '📌',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            type['label'] as String? ?? type['value'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          onChanged: widget.isCreating ? _onTypeChanged : null,
        ),
        // Descrição do tipo
        if (widget.viewModel.getSchemaForType(_missionType) != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.viewModel.getSchemaForType(_missionType)?['description'] as String? ?? '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        // Guia rápido de tipos (apenas na criação)
        if (widget.isCreating) ...[
          const SizedBox(height: 12),
          _buildTypesQuickGuide(theme, colorScheme),
        ],
      ],
    );
  }
  
  /// Constrói guia rápido dos tipos de missão
  Widget _buildTypesQuickGuide(ThemeData theme, ColorScheme colorScheme) {
    final guia = {
      'ONBOARDING': {
        'icon': '📝',
        'nome': 'Primeiros Passos',
        'uso': 'Registrar transações',
        'campo': 'Qtd. transações',
      },
      'TPS_IMPROVEMENT': {
        'icon': '💰',
        'nome': 'Taxa Poupança',
        'uso': 'Aumentar poupança',
        'campo': 'Meta TPS %',
      },
      'RDR_REDUCTION': {
        'icon': '📉',
        'nome': 'Reduzir Gastos',
        'uso': 'Diminuir despesas',
        'campo': 'Meta RDR %',
      },
      'ILI_BUILDING': {
        'icon': '🛡️',
        'nome': 'Reserva Emergência',
        'uso': 'Construir reserva',
        'campo': 'ILI meses',
      },
      'CATEGORY_REDUCTION': {
        'icon': '📁',
        'nome': 'Ctrl. Categoria',
        'uso': 'Reduzir em categoria',
        'campo': 'Categoria (opcional)',
      },
      'GOAL_ACHIEVEMENT': {
        'icon': '🎯',
        'nome': 'Progresso Meta',
        'uso': 'Progredir em meta',
        'campo': 'Automático',
      },
    };
    
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Row(
        children: [
          Icon(
            Icons.help_outline,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'Guia Rápido dos Tipos',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(0.8),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      'Tipo',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      'Objetivo',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      'Campo Principal',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              ...guia.entries.map((e) {
                final isSelected = e.key == _missionType;
                return TableRow(
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(e.value['icon'] as String),
                          const SizedBox(width: 2),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        e.value['uso'] as String,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        e.value['campo'] as String,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _getDefaultTypeItems() {
    return const [
      DropdownMenuItem(value: 'ONBOARDING', child: Text('📝 Primeiros Passos')),
      DropdownMenuItem(value: 'TPS_IMPROVEMENT', child: Text('💰 Taxa de Poupança')),
      DropdownMenuItem(value: 'RDR_REDUCTION', child: Text('📉 Redução Despesas')),
      DropdownMenuItem(value: 'ILI_BUILDING', child: Text('🛡️ Reserva Emergência')),
      DropdownMenuItem(value: 'CATEGORY_REDUCTION', child: Text('📁 Ctrl. Categoria')),
      DropdownMenuItem(value: 'GOAL_ACHIEVEMENT', child: Text('🎯 Progresso Meta')),
    ];
  }

  Widget _buildBasicFields(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informações Básicas',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Título
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Título *',
            hintText: 'Digite o título da missão',
            border: OutlineInputBorder(),
          ),
          maxLength: 150,
        ),
        const SizedBox(height: 12),

        // Descrição
        TextField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Descrição *',
            hintText: 'Digite a descrição da missão',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          maxLength: 500,
        ),
        const SizedBox(height: 12),

        // Dificuldade, Recompensa e Duração
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _difficulty,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Dificuldade',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'EASY', child: Text('Fácil')),
                  DropdownMenuItem(value: 'MEDIUM', child: Text('Média')),
                  DropdownMenuItem(value: 'HARD', child: Text('Difícil')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _difficulty = value);
                    _updateDefaultsForType();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _rewardController,
                decoration: const InputDecoration(
                  labelText: 'XP',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Dias',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Prioridade e Status
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _priorityController,
                decoration: const InputDecoration(
                  labelText: 'Prioridade',
                  border: OutlineInputBorder(),
                  helperText: 'Menor = mais prioritário',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SwitchListTile(
                title: const Text('Ativa'),
                subtitle: const Text('Visível para usuários'),
                value: _booleanFields['is_active'] ?? true,
                onChanged: (value) {
                  setState(() => _booleanFields['is_active'] = value);
                },
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeSpecificFields(ThemeData theme, ColorScheme colorScheme) {
    final schema = widget.viewModel.getSchemaForType(_missionType);
    
    if (schema == null) {
      return _buildFallbackTypeFields(theme);
    }
    
    final requiredFields = schema['required_fields'] as List<dynamic>? ?? [];
    final optionalFields = schema['optional_fields'] as List<dynamic>? ?? [];
    final tips = schema['tips'] as List<dynamic>? ?? [];
    
    // Obter dica contextual do servidor
    final dicaContextual = widget.viewModel.getDicaParaTipo(_missionType);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              schema['icon'] as String? ?? '📌',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'Campos de ${schema['name']}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Dica contextual do tipo de missão
        if (dicaContextual != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.secondary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.tips_and_updates,
                  size: 18,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dicaContextual['dica'] as String? ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Campos obrigatórios
        if (requiredFields.isNotEmpty) ...[
          Text(
            'Campos Obrigatórios',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          ...requiredFields.map((field) => _buildDynamicField(
            field as Map<String, dynamic>,
            theme,
            colorScheme,
            isRequired: true,
          )),
        ],
        
        // Campos opcionais
        if (optionalFields.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Campos Opcionais',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...optionalFields.map((field) => _buildDynamicField(
            field as Map<String, dynamic>,
            theme,
            colorScheme,
            isRequired: false,
          )),
        ],
        
        // Dicas
        if (tips.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, 
                      size: 18, 
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dicas',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...tips.map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          tip as String,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDynamicField(
    Map<String, dynamic> fieldDef,
    ThemeData theme,
    ColorScheme colorScheme, {
    required bool isRequired,
  }) {
    final key = fieldDef['key'] as String;
    final label = fieldDef['label'] as String;
    final description = fieldDef['description'] as String?;
    final type = fieldDef['type'] as String;
    final hint = fieldDef['hint'] as String?;
    final unit = fieldDef['unit'] as String?;
    final dependsOn = fieldDef['depends_on'] as String?;
    
    // Verificar dependência
    if (dependsOn != null && _booleanFields[dependsOn] != true) {
      return const SizedBox.shrink();
    }
    
    Widget fieldWidget;
    
    switch (type) {
      case 'boolean':
        fieldWidget = SwitchListTile(
          title: Text(label),
          subtitle: description != null ? Text(description) : null,
          value: _booleanFields[key] ?? false,
          onChanged: (value) {
            setState(() => _booleanFields[key] = value);
          },
          contentPadding: EdgeInsets.zero,
        );
        break;
        
      case 'integer':
      case 'decimal':
      case 'percentage':
        final min = fieldDef['min'];
        final max = fieldDef['max'];
        
        fieldWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _typeSpecificControllers[key],
              decoration: InputDecoration(
                labelText: isRequired ? '$label *' : label,
                border: const OutlineInputBorder(),
                helperText: hint ?? description,
                suffixText: unit,
              ),
              keyboardType: type == 'integer'
                  ? TextInputType.number
                  : const TextInputType.numberWithOptions(decimal: true),
            ),
            if (min != null || max != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  'Valor: ${min ?? ''}${min != null && max != null ? ' - ' : ''}${max ?? ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        );
        break;
      
      case 'category_select':
        fieldWidget = _buildCategorySelectField(
          label: label,
          description: description,
          hint: hint,
          isRequired: isRequired,
          theme: theme,
          colorScheme: colorScheme,
        );
        break;
        
      case 'goal_select':
        fieldWidget = _buildGoalSelectField(
          label: label,
          description: description,
          hint: hint,
          isRequired: isRequired,
          theme: theme,
          colorScheme: colorScheme,
        );
        break;
        
      case 'multi_select':
        final entity = fieldDef['entity'] as String?;
        if (entity == 'category') {
          fieldWidget = _buildCategoryMultiSelectField(
            label: label,
            description: description,
            theme: theme,
            colorScheme: colorScheme,
          );
        } else if (entity == 'goal') {
          fieldWidget = _buildGoalMultiSelectField(
            label: label,
            description: description,
            theme: theme,
            colorScheme: colorScheme,
          );
        } else {
          fieldWidget = Text('Multi-seleção não suportada: $entity');
        }
        break;
        
      default:
        fieldWidget = TextField(
          controller: _typeSpecificControllers[key],
          decoration: InputDecoration(
            labelText: isRequired ? '$label *' : label,
            border: const OutlineInputBorder(),
            helperText: description,
          ),
        );
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: fieldWidget,
    );
  }

  Widget _buildFallbackTypeFields(ThemeData theme) {
    // Campos fallback quando schemas não estão disponíveis
    final typeFields = {
      'ONBOARDING': ['min_transactions'],
      'TPS_IMPROVEMENT': ['target_tps'],
      'RDR_REDUCTION': ['target_rdr'],
      'ILI_BUILDING': ['min_ili'],
      'CATEGORY_REDUCTION': ['target_reduction_percent'],
      'GOAL_ACHIEVEMENT': ['goal_progress_target'],
    };
    
    final labels = {
      'min_transactions': 'Transações Mínimas',
      'target_tps': 'Meta TPS (%)',
      'target_rdr': 'Meta RDR Máximo (%)',
      'min_ili': 'ILI Mínimo (meses)',
      'target_reduction_percent': 'Redução Alvo (%)',
      'goal_progress_target': 'Progresso Alvo (%)',
    };
    
    final fields = typeFields[_missionType] ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Campos Específicos',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...fields.map((field) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _typeSpecificControllers[field],
            decoration: InputDecoration(
              labelText: labels[field] ?? field,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        )),
        
        // Campos temporais (opcionais)
        SwitchListTile(
          title: const Text('Requer dias consecutivos'),
          value: _booleanFields['requires_consecutive_days'] ?? false,
          onChanged: (value) {
            setState(() => _booleanFields['requires_consecutive_days'] = value);
          },
          contentPadding: EdgeInsets.zero,
        ),
        if (_booleanFields['requires_consecutive_days'] == true)
          TextField(
            controller: _typeSpecificControllers['min_consecutive_days'],
            decoration: const InputDecoration(
              labelText: 'Dias Consecutivos',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
      ],
    );
  }

  /// Constrói campo de seleção de categoria única
  Widget _buildCategorySelectField({
    required String label,
    String? description,
    String? hint,
    required bool isRequired,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final categorias = widget.viewModel.getCategoriesForSelect(tipo: 'EXPENSE');
    
    if (categorias.isEmpty) {
      // Fallback para entrada manual se categorias não carregaram
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: TextEditingController(
              text: _selectedCategoryId?.toString() ?? '',
            ),
            decoration: InputDecoration(
              labelText: isRequired ? '$label * (ID)' : '$label (ID)',
              border: const OutlineInputBorder(),
              helperText: 'Carregando categorias...',
              suffixIcon: const SizedBox(
                width: 20,
                height: 20,
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              _selectedCategoryId = int.tryParse(value);
            },
          ),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int?>(
          value: _selectedCategoryId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: isRequired ? '$label *' : label,
            border: const OutlineInputBorder(),
            helperText: hint ?? description,
            helperMaxLines: 2,
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Automático (maior gasto)',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
            ...categorias.map((cat) {
              return DropdownMenuItem<int?>(
                value: cat['id'] as int,
                child: Row(
                  children: [
                    Text(
                      cat['icon'] as String? ?? '📁',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cat['name'] as String? ?? 'Categoria',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedCategoryId = value;
            });
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 12),
          child: Text(
            _selectedCategoryId == null
                ? '💡 O sistema selecionará a categoria com maior gasto do usuário'
                : '📌 Missão vinculada a esta categoria específica',
            style: theme.textTheme.bodySmall?.copyWith(
              color: _selectedCategoryId == null 
                  ? Colors.amber.shade700 
                  : colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  /// Constrói campo de seleção de meta única
  Widget _buildGoalSelectField({
    required String label,
    String? description,
    String? hint,
    required bool isRequired,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    // Nota: Metas são vinculadas automaticamente às metas ativas do usuário
    // Não é necessário selecionar uma meta específica ao criar a missão
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vinculação Automática',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Esta missão será vinculada automaticamente às metas ativas '
            'de cada usuário quando for atribuída. Não é necessário '
            'selecionar uma meta específica.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 16,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'O campo "Progresso Alvo (%)" define a meta de progresso',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Constrói campo de multi-seleção de categorias
  Widget _buildCategoryMultiSelectField({
    required String label,
    String? description,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final categorias = widget.viewModel.getCategoriesForSelect(tipo: 'EXPENSE');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        if (categorias.isEmpty)
          const Text('Carregando categorias...')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categorias.map((cat) {
              final catId = cat['id'] as int;
              final isSelected = _selectedCategoriesIds.contains(catId);
              
              return FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cat['icon'] as String? ?? '📁',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Text(cat['name'] as String? ?? 'Categoria'),
                  ],
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCategoriesIds.add(catId);
                    } else {
                      _selectedCategoriesIds.remove(catId);
                    }
                  });
                },
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.primary,
              );
            }).toList(),
          ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// Constrói campo de multi-seleção de metas
  Widget _buildGoalMultiSelectField({
    required String label,
    String? description,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    // Nota: Metas são vinculadas automaticamente
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'As metas são vinculadas automaticamente com base nas metas '
            'ativas de cada usuário. Este campo é informativo.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}