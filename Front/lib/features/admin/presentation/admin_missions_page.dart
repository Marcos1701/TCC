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
                              'Gerencie as missões de gamificação do sistema de educação financeira',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            // Indicador de geração em progresso
                            if (_isGenerating) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Gerando missões...',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
                        label: 'Tipo de Missão',
                        value: _filtroTipo,
                        items: const {
                          null: 'Todos os Tipos',
                          'ONBOARDING': 'Primeiros Passos',
                          'TPS_IMPROVEMENT': 'Taxa de Poupança (TPS)',
                          'RDR_REDUCTION': 'Redução de Despesas (RDR)',
                          'ILI_BUILDING': 'Reserva de Emergência (ILI)',
                          'CATEGORY_REDUCTION': 'Controle de Categoria',
                          'GOAL_ACHIEVEMENT': 'Progresso em Meta',
                        },
                        onChanged: (v) {
                          setState(() => _filtroTipo = v);
                          _aplicarFiltros();
                        },
                      ),
                      _FilterDropdown(
                        label: 'Nível de Dificuldade',
                        value: _filtroDificuldade,
                        items: const {
                          null: 'Todas as Dificuldades',
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
                        label: 'Status da Missão',
                        value: _filtroAtivo?.toString(),
                        items: const {
                          null: 'Todos os Status',
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
      actions: [
        // Botão Excluir
        TextButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Excluir'),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
        ),
        const Spacer(),
        // Botão Toggle
        TextButton.icon(
          onPressed: onToggle,
          icon: Icon(
            isActive ? Icons.visibility_off : Icons.visibility,
            size: 18,
          ),
          label: Text(isActive ? 'Desativar' : 'Ativar'),
        ),
        // Botão Editar
        ElevatedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Editar'),
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
class _EditMissionDialog extends StatefulWidget {
  const _EditMissionDialog({
    required this.mission,
    required this.onSave,
  });

  final Map<String, dynamic> mission;
  final Function(Map<String, dynamic>) onSave;

  @override
  State<_EditMissionDialog> createState() => _EditMissionDialogState();
}

class _EditMissionDialogState extends State<_EditMissionDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _rewardController;
  late final TextEditingController _durationController;
  late String _difficulty;
  late String _missionType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.mission['title'] as String? ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.mission['description'] as String? ?? '',
    );
    _rewardController = TextEditingController(
      text: '${widget.mission['reward_points'] ?? 50}',
    );
    _durationController = TextEditingController(
      text: '${widget.mission['duration_days'] ?? 30}',
    );
    _difficulty = widget.mission['difficulty'] as String? ?? 'MEDIUM';
    _missionType = widget.mission['mission_type'] as String? ?? 'ONBOARDING';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rewardController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _salvar() {
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

    final dados = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'reward_points': int.tryParse(_rewardController.text) ?? 50,
      'duration_days': int.tryParse(_durationController.text) ?? 30,
      'difficulty': _difficulty,
      'mission_type': _missionType,
    };

    widget.onSave(dados);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Missão'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Digite o título da missão',
                  border: OutlineInputBorder(),
                ),
                maxLength: 150,
              ),
              const SizedBox(height: 16),

              // Descrição
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Digite a descrição da missão',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 500,
              ),
              const SizedBox(height: 16),

              // Tipo e Dificuldade
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _missionType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ONBOARDING',
                          child: Text('Primeiros Passos'),
                        ),
                        DropdownMenuItem(
                          value: 'TPS_IMPROVEMENT',
                          child: Text('Taxa de Poupança'),
                        ),
                        DropdownMenuItem(
                          value: 'RDR_REDUCTION',
                          child: Text('Redução de Despesas'),
                        ),
                        DropdownMenuItem(
                          value: 'ILI_BUILDING',
                          child: Text('Reserva de Emergência'),
                        ),
                        DropdownMenuItem(
                          value: 'CATEGORY_REDUCTION',
                          child: Text('Controle de Categoria'),
                        ),
                        DropdownMenuItem(
                          value: 'GOAL_ACHIEVEMENT',
                          child: Text('Progresso em Meta'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _missionType = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _difficulty,
                      decoration: const InputDecoration(
                        labelText: 'Dificuldade',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'EASY', child: Text('Fácil')),
                        DropdownMenuItem(value: 'MEDIUM', child: Text('Média')),
                        DropdownMenuItem(value: 'HARD', child: Text('Difícil')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _difficulty = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Recompensa e Duração
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _rewardController,
                      decoration: const InputDecoration(
                        labelText: 'Recompensa (XP)',
                        border: OutlineInputBorder(),
                        suffixText: 'XP',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duração',
                        border: OutlineInputBorder(),
                        suffixText: 'dias',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
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
              : const Text('Salvar'),
        ),
      ],
    );
  }
}