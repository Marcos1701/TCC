import 'package:flutter/material.dart';

import '../../../core/constants/mission_constants.dart';
import '../data/admin_viewmodel.dart';

class AdminMissionsPage extends StatefulWidget {
  const AdminMissionsPage({super.key, required this.viewModel});

  final AdminViewModel viewModel;

  @override
  State<AdminMissionsPage> createState() => _AdminMissionsPageState();
}

class _AdminMissionsPageState extends State<AdminMissionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _filtroTipo;
  String? _filtroDificuldade;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadMissionsForCurrentTab();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _loadMissionsForCurrentTab();
    }
  }

  void _loadMissionsForCurrentTab() {
    final isActiveTab = _tabController.index == 0;
    widget.viewModel.loadMissions(
      tipo: _filtroTipo,
      dificuldade: _filtroDificuldade,
      ativo: isActiveTab,
    );
  }

  void _aplicarFiltros() {
    _loadMissionsForCurrentTab();
  }

  Future<void> _gerarMissoes(int quantidade, String? tier) async {
    setState(() => _isGenerating = true);

    try {
      final resultado = await widget.viewModel.generateMissions(
        quantidade: quantidade,
        tier: tier,
      );

      setState(() => _isGenerating = false);

      if (mounted) {
        final sucesso = resultado['sucesso'] == true;
        final pendentes = resultado['pendentes'] == true;
        final totalCriadas = resultado['total_criadas'] ?? 0;
        final fonte = resultado['fonte'] as String?;
        
        final fonteTexto = switch (fonte) {
          'gemini_ai' => ' (via IA)',
          'hybrid' => ' (IA + templates)',
          'template' => ' (templates)',
          _ => '',
        };
        
        String mensagem;
        if (sucesso && pendentes) {
          mensagem = '$totalCriadas missões geradas$fonteTexto! Acesse a aba "Pendentes" para revisar e ativar.';
        } else if (sucesso) {
          mensagem = resultado['mensagem'] ?? 'Missões geradas com sucesso!';
        } else {
          mensagem = resultado['erro'] ?? 'Erro ao gerar missões';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensagem),
            backgroundColor: sucesso ? Colors.green : Colors.red,
            duration: const Duration(seconds: 4),
            action: sucesso && pendentes
                ? SnackBarAction(
                    label: 'Ver Pendentes',
                    textColor: Colors.white,
                    onPressed: () {
                      _tabController.animateTo(1);
                    },
                  )
                : null,
          ),
        );

        if (sucesso && pendentes && _tabController.index == 0) {
          _tabController.animateTo(1);
        }
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Missões',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isGenerating) ...[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton.filled(
                    onPressed: () => _showCreateMissionDialog(),
                    icon: const Icon(Icons.add, size: 20),
                    tooltip: 'Nova Missão',
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isGenerating ? null : () => _showGenerateDialog(),
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome, size: 20),
                    tooltip: 'Gerar com IA',
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.secondary,
                      foregroundColor: colorScheme.onSecondary,
                    ),
                  ),
                ],
              ),
            ),

            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 350;
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: colorScheme.onPrimary,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    tabs: [
                      Tab(
                        child: isNarrow
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 18),
                                  _buildBadgeCount(true),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 18),
                                  const SizedBox(width: 8),
                                  const Text('Ativas'),
                                  _buildBadgeCount(true),
                                ],
                              ),
                      ),
                      Tab(
                        child: isNarrow
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.pending_outlined, size: 18),
                                  _buildBadgeCount(false),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.pending_outlined, size: 18),
                                  const SizedBox(width: 8),
                                  const Text('Pendentes'),
                                  _buildBadgeCount(false),
                                ],
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMissionsList(isActiveTab: true),
                  _buildMissionsList(isActiveTab: false),
                ],
              ),
            ),

            if (widget.viewModel.missionsTotalPages > 1)
              _Pagination(
                currentPage: widget.viewModel.missionsCurrentPage,
                totalPages: widget.viewModel.missionsTotalPages,
                onPageChanged: (page) {
                  final isActiveTab = _tabController.index == 0;
                  widget.viewModel.loadMissions(
                    tipo: _filtroTipo,
                    dificuldade: _filtroDificuldade,
                    ativo: isActiveTab,
                    pagina: page,
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildBadgeCount(bool isActive) {
    final count = widget.viewModel.missions
        .where((m) => (m['is_active'] as bool? ?? true) == isActive)
        .length;
    
    if (count == 0) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  Widget _buildMissionsList({required bool isActiveTab}) {
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActiveTab ? Icons.check_circle_outline : Icons.pending_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isActiveTab
                  ? 'Nenhuma missão ativa encontrada'
                  : 'Nenhuma missão pendente de validação',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (!isActiveTab) ...[
              const SizedBox(height: 8),
              Text(
                'Use o botão "Gerar com IA" para criar novas missões',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ],
        ),
      );
    }

    final pendingCount = viewModel.missions
        .where((m) => (m['is_active'] as bool? ?? false) == false)
        .length;

    return Column(
      children: [
        // Botão "Excluir Todas Pendentes" apenas na aba de pendentes
        if (!isActiveTab && pendingCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _confirmDeleteAllPending(),
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: Text('Excluir Todas ($pendingCount)'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: viewModel.missions.length,
            itemBuilder: (context, index) {
              final mission = viewModel.missions[index];
              return _MissionCard(
                mission: mission,
                isPending: !isActiveTab,
                onToggle: () => _toggleMission(mission),
                onTap: () => _showMissionDetails(mission),
                onEdit: () => _showEditMissionDialog(mission),
                onDelete: () => _confirmDeleteMission(mission),
                onApprove: !isActiveTab ? () => _approveMission(mission) : null,
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmDeleteAllPending() {
    final pendingCount = widget.viewModel.missions
        .where((m) => (m['is_active'] as bool? ?? false) == false)
        .length;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir Todas Pendentes'),
        content: Text(
          'Tem certeza que deseja excluir $pendingCount missão(ões) pendente(s)?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              final resultado = await widget.viewModel.deleteAllPendingMissions();

              if (mounted) {
                final sucesso = resultado['sucesso'] == true;
                final excluidas = resultado['excluidas'] ?? 0;
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      sucesso
                          ? '$excluidas missão(ões) excluída(s)!'
                          : resultado['erro'] ?? 'Erro ao excluir missões',
                    ),
                    backgroundColor: sucesso ? Colors.green : Colors.red,
                  ),
                );
                
                if (sucesso) {
                  _aplicarFiltros();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir Todas'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveMission(Map<String, dynamic> mission) async {
    final id = mission['id'] as int;
    final resultado = await widget.viewModel.updateMission(id, {'is_active': true});

    if (mounted) {
      final sucesso = resultado['sucesso'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sucesso ? 'Missão ativada com sucesso!' : 'Erro ao ativar missão',
          ),
          backgroundColor: sucesso ? Colors.green : Colors.red,
        ),
      );
      
      if (sucesso) {
        _loadMissionsForCurrentTab();
      }
    }
  }

  void _showMissionDetails(Map<String, dynamic> mission) {
    showDialog(
      context: context,
      builder: (dialogContext) => _MissionDetailsDialog(
        mission: mission,
        onEdit: () {
          Navigator.pop(dialogContext);
          _showEditMissionDialog(mission);
        },
        onDelete: () {
          Navigator.pop(dialogContext);
          _confirmDeleteMission(mission);
        },
        onToggle: () async {
          await _toggleMission(mission);
          if (mounted) Navigator.pop(dialogContext);
        },
      ),
    );
  }

  void _showEditMissionDialog(Map<String, dynamic> mission) {
    final parentContext = context;
    showDialog(
      context: parentContext,
      builder: (dialogContext) => _EditMissionDialog(
        mission: mission,
        viewModel: widget.viewModel,
        onSave: (dados) async {
          final id = mission['id'] as int;
          final resultado = await widget.viewModel.updateMission(id, dados);

          if (mounted) {
            Navigator.pop(dialogContext);
            if (mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
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
          }
        },
      ),
    );
  }

  void _showCreateMissionDialog() {
    final parentContext = context;
    showDialog(
      context: parentContext,
      builder: (dialogContext) => _EditMissionDialog(
        mission: null,
        viewModel: widget.viewModel,
        isCreating: true,
        onSave: (dados) async {
          final resultado = await widget.viewModel.createMission(dados);

          if (mounted) {
            Navigator.pop(dialogContext);
            if (mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
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
          }
        },
      ),
    );
  }

  void _confirmDeleteMission(Map<String, dynamic> mission) {
    final titulo = mission['title'] as String? ?? 'esta missão';
    final parentContext = context;

    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir Missão'),
        content: Text(
          'Tem certeza que deseja excluir a missão "$titulo"?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final id = mission['id'] as int;
              final sucesso = await widget.viewModel.deleteMission(id);

              if (mounted) {
                Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
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

  void _showGenerateDialog() {
    String? selectedTier;
    int selectedQuantidade = 10;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(width: 8),
              const Text('Gerar Missões com IA'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'As missões geradas ficarão pendentes de validação antes de serem ativadas.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                'Quantidade de missões',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _QuantityOption(
                    value: 5,
                    isSelected: selectedQuantidade == 5,
                    onTap: () => setDialogState(() => selectedQuantidade = 5),
                  ),
                  const SizedBox(width: 8),
                  _QuantityOption(
                    value: 10,
                    isSelected: selectedQuantidade == 10,
                    onTap: () => setDialogState(() => selectedQuantidade = 10),
                  ),
                  const SizedBox(width: 8),
                  _QuantityOption(
                    value: 20,
                    isSelected: selectedQuantidade == 20,
                    onTap: () => setDialogState(() => selectedQuantidade = 20),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              DropdownButtonFormField<String>(
                value: selectedTier,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Nível dos Usuários',
                  helperText: 'Define o público-alvo das missões',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todos os níveis')),
                  DropdownMenuItem(value: 'BEGINNER', child: Text('Iniciante (1-5)')),
                  DropdownMenuItem(value: 'INTERMEDIATE', child: Text('Intermediário (6-15)')),
                  DropdownMenuItem(value: 'ADVANCED', child: Text('Avançado (16+)')),
                ],
                onChanged: (value) => setDialogState(() => selectedTier = value),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'O sistema irá:',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              const _GenerationFeature(icon: Icons.check, text: 'Validar viabilidade das missões'),
              const _GenerationFeature(icon: Icons.check, text: 'Distribuir entre os 6 tipos de missão'),
              const _GenerationFeature(icon: Icons.check, text: 'Ajustar dificuldade ao nível selecionado'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _gerarMissoes(selectedQuantidade, selectedTier);
              },
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text('Gerar $selectedQuantidade Missões'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerationFeature extends StatelessWidget {
  const _GenerationFeature({required this.icon, required this.text});
  
  final IconData icon;
  final String text;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.green),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityOption extends StatelessWidget {
  const _QuantityOption({
    required this.value,
    required this.isSelected,
    required this.onTap,
  });
  
  final int value;
  final bool isSelected;
  final VoidCallback onTap;
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? colorScheme.primary 
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? colorScheme.primary : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$value',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                    ),
              ),
              Text(
                'missões',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected 
                          ? colorScheme.onPrimary.withValues(alpha: 0.8) 
                          : colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.mission,
    required this.onToggle,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.isPending = false,
    this.onApprove,
  });

  final Map<String, dynamic> mission;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isPending;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isActive = mission['is_active'] as bool? ?? true;
    final difficulty = mission['difficulty'] as String? ?? 'MEDIUM';
    final missionType = mission['mission_type'] as String? ?? 'ONBOARDING';
    final isSystemGenerated = mission['is_system_generated'] as bool? ?? false;


    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 70,
                decoration: BoxDecoration(
                  color: isPending ? Colors.orange : (isActive ? Colors.green : Colors.grey),
                  borderRadius: BorderRadius.circular(2),
                ),
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
                            mission['title'] as String? ?? 'Sem título',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        ),
                      ),
                      if (isPending) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.pending, size: 12, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text(
                                'Pendente',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: DifficultyColors.get(difficulty).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          DifficultyLabels.get(difficulty),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: DifficultyColors.get(difficulty),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          MissionTypeLabels.getShort(missionType),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSystemGenerated) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: colorScheme.secondary,
                        ),
                      ],
                    ],
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${mission['reward_points'] ?? 0} XP',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isPending && onApprove != null)
              Column(
                children: [
                  IconButton.filled(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 20),
                    tooltip: 'Aprovar e Ativar',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton.outlined(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Excluir',
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              )
            else
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

    final validationLabels = {
      'TRANSACTION_COUNT': 'Contagem de Transações',
      'INDICATOR_THRESHOLD': 'Atingir Indicador',
      'CATEGORY_REDUCTION': 'Redução em Categoria',
      'CATEGORY_LIMIT': 'Limite de Categoria',
      'SAVINGS_INCREASE': 'Aumentar Poupança',
      'MULTI_CRITERIA': 'Critérios Combinados',
      // Legados
      'TEMPORAL': 'Período (legado)',
      'SNAPSHOT': 'Comparação (legado)',
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
              Text(
                mission['description'] as String? ?? 'Sem descrição',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              _DetailRow(
                label: 'Tipo',
                value: MissionTypeLabels.getDescriptive(missionType),
                icon: Icons.category,
              ),
              _DetailRow(
                label: 'Dificuldade',
                value: DifficultyLabels.get(difficulty),
                icon: Icons.trending_up,
                valueColor: DifficultyColors.get(difficulty),
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
        TextButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Excluir'),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: onToggle,
              icon: Icon(
                isActive ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              label: Text(isActive ? 'Desativar' : 'Ativar'),
            ),
            const SizedBox(width: 8),
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
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  late final TextEditingController _targetValueController;
  late final TextEditingController _priorityController;
  late String _difficulty;
  late String _missionType;
  bool _isLoading = false;
  String? _formError;
  
  // Para CATEGORY_REDUCTION
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  bool _loadingCategories = false;

  // Usa as novas classes de configuração
  MissionTypeFieldConfig? get _currentFieldConfig => MissionTypeFields.get(_missionType);
  DifficultyPreset? get _currentDifficultyPreset => DifficultyPresets.get(_difficulty);
  List<String> get _currentTips => MissionTypeTips.get(_missionType);
  String get _currentDescription => MissionTypeDescriptions.get(_missionType);

  // Helper para obter dados legados para validação (compatibilidade)
  Map<String, dynamic> get _currentConfig {
    final config = _currentFieldConfig;
    if (config == null) {
      return {
        'field': 'target_tps',
        'label': 'Meta TPS (%)',
        'hint': 'Ex: 15 para 15%',
        'validation_type': 'INDICATOR_THRESHOLD',
        'defaultValue': 15,
        'description': 'Taxa de Poupança Pessoal mínima a atingir',
      };
    }
    return {
      'field': config.fieldKey,
      'label': config.unit != null ? '${config.label} (${config.unit})' : config.label,
      'hint': config.hint,
      'validation_type': config.validationType,
      'defaultValue': config.defaultValue,
      'description': config.hint,
    };
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _rewardController = TextEditingController(text: '100');
    _durationController = TextEditingController(text: '30');
    _targetValueController = TextEditingController();
    _priorityController = TextEditingController(text: '50');
    _difficulty = 'MEDIUM';
    _missionType = 'TPS_IMPROVEMENT';
    
    if (widget.mission != null) {
      _titleController.text = widget.mission!['title'] ?? '';
      _descriptionController.text = widget.mission!['description'] ?? '';
      _rewardController.text = (widget.mission!['reward_points'] ?? 100).toString();
      _durationController.text = (widget.mission!['duration_days'] ?? 30).toString();
      _priorityController.text = (widget.mission!['priority'] ?? 50).toString();
      _difficulty = widget.mission!['difficulty'] ?? 'MEDIUM';
      _missionType = widget.mission!['mission_type'] ?? 'TPS_IMPROVEMENT';
      
      // Carrega categoria existente se for CATEGORY_REDUCTION
      if (_missionType == 'CATEGORY_REDUCTION') {
        final targetCategory = widget.mission!['target_category'];
        if (targetCategory != null && targetCategory is Map) {
          _selectedCategoryId = targetCategory['id'] as int?;
        } else if (widget.mission!['target_category_id'] != null) {
          _selectedCategoryId = widget.mission!['target_category_id'] as int;
        }
      }
      
      // Carrega o valor do campo específico do tipo
      _loadTargetValue();
    } else {
      // Para nova missão, usar valor padrão do tipo
      _targetValueController.text = _currentConfig['defaultValue'].toString();
    }
    
    // Carrega categorias se necessário
    if (_missionType == 'CATEGORY_REDUCTION') {
      _loadCategories();
    }
  }

  void _loadTargetValue() {
    final config = _currentFieldConfig;
    if (config != null && widget.mission != null) {
      final value = widget.mission![config.fieldKey];
      _targetValueController.text = value?.toString() ?? config.defaultValue.toString();
    }
  }

  Future<void> _loadCategories() async {
    if (_categories.isNotEmpty) return; // Já carregou
    
    setState(() => _loadingCategories = true);
    
    try {
      await widget.viewModel.loadCategories();
      if (mounted) {
        // O endpoint já retorna apenas categorias do sistema (is_system_default=True)
        final allCategories = widget.viewModel.categories;
        setState(() {
          _categories = List<Map<String, dynamic>>.from(allCategories);
          _loadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar categorias: $e');
      if (mounted) {
        setState(() => _loadingCategories = false);
      }
    }
  }

  void _onMissionTypeChanged(String? newType) {
    if (newType != null && newType != _missionType) {
      setState(() {
        _missionType = newType;
        // Atualiza o valor padrão para o novo tipo
        final config = MissionTypeFields.get(newType);
        if (config != null) {
          _targetValueController.text = config.defaultValue.toString();
        }
        _formError = null;
        _selectedCategoryId = null;
      });
      
      // Carrega categorias se mudou para CATEGORY_REDUCTION
      if (newType == 'CATEGORY_REDUCTION') {
        _loadCategories();
      }
    }
  }

  /// Aplica os valores recomendados baseados na dificuldade selecionada
  void _applyDifficultyPreset() {
    final preset = _currentDifficultyPreset;
    if (preset != null) {
      setState(() {
        _rewardController.text = preset.xpDefault.toString();
        _durationController.text = preset.durationDefault.toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Valores aplicados: ${preset.xpDefault} XP, ${preset.durationDefault} dias',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Retorna o status de validação de um valor (para feedback visual)
  /// Retorna: 'valid', 'warning', 'error'
  String _getValueValidationStatus(num? value, num min, num max, num recMin, num recMax) {
    if (value == null) return 'error';
    if (value < min || value > max) return 'error';
    if (value >= recMin && value <= recMax) return 'valid';
    return 'warning';
  }

  Color _getValidationColor(String status) {
    switch (status) {
      case 'valid':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getValidationIcon(String status) {
    switch (status) {
      case 'valid':
        return Icons.check_circle;
      case 'warning':
        return Icons.warning_amber;
      case 'error':
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }

  String? _validateForm() {
    if (_titleController.text.trim().isEmpty) {
      return 'O título é obrigatório';
    }
    if (_titleController.text.trim().length > 150) {
      return 'O título não pode ter mais de 150 caracteres';
    }
    if (_descriptionController.text.trim().isEmpty) {
      return 'A descrição é obrigatória';
    }
    
    final reward = int.tryParse(_rewardController.text);
    if (reward == null || reward < 10 || reward > 1000) {
      return 'A recompensa deve ser entre 10 e 1000 XP';
    }
    
    final duration = int.tryParse(_durationController.text);
    if (duration == null || duration < 1 || duration > 365) {
      return 'A duração deve ser entre 1 e 365 dias';
    }
    
    final targetValue = num.tryParse(_targetValueController.text);
    if (targetValue == null || targetValue <= 0) {
      return 'O valor da meta é obrigatório e deve ser maior que zero';
    }
    
    // Validação específica por tipo
    if (_missionType == 'TPS_IMPROVEMENT' && (targetValue < 1 || targetValue > 80)) {
      return 'A meta TPS deve ser entre 1% e 80%';
    }
    if (_missionType == 'RDR_REDUCTION' && (targetValue < 5 || targetValue > 95)) {
      return 'A meta RDR deve ser entre 5% e 95%';
    }
    if (_missionType == 'ILI_BUILDING' && (targetValue < 0.5 || targetValue > 24)) {
      return 'O ILI mínimo deve ser entre 0.5 e 24 meses';
    }
    if (_missionType == 'ONBOARDING' && (targetValue < 1 || targetValue > 100)) {
      return 'O número de transações deve ser entre 1 e 100';
    }
    if (_missionType == 'CATEGORY_REDUCTION' && (targetValue < 5 || targetValue > 80)) {
      return 'A redução alvo deve ser entre 5% e 80%';
    }
    
    // Validação de categoria obrigatória para CATEGORY_REDUCTION
    if (_missionType == 'CATEGORY_REDUCTION' && _selectedCategoryId == null) {
      return 'A categoria é obrigatória para missões de redução de gastos';
    }
    
    return null;
  }

  void _saveMission() {
    final error = _validateForm();
    if (error != null) {
      setState(() => _formError = error);
      return;
    }

    setState(() {
      _isLoading = true;
      _formError = null;
    });

    final config = _currentConfig;
    final fieldName = config['field'] as String;
    final validationType = config['validation_type'] as String;
    
    // Determina o valor numérico correto
    num targetValue = num.tryParse(_targetValueController.text) ?? config['defaultValue'];
    // Para ILI, aceita decimal; para outros, usa int
    final dynamic fieldValue = (_missionType == 'ILI_BUILDING') 
        ? targetValue.toDouble() 
        : targetValue.toInt();

    final missionData = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'reward_points': int.tryParse(_rewardController.text) ?? 100,
      'duration_days': int.tryParse(_durationController.text) ?? 30,
      'difficulty': _difficulty,
      'mission_type': _missionType,
      'validation_type': validationType,
      'priority': int.tryParse(_priorityController.text) ?? 50,
      'is_active': true,
      fieldName: fieldValue,
    };
    
    // Adiciona categoria se for CATEGORY_REDUCTION
    if (_missionType == 'CATEGORY_REDUCTION' && _selectedCategoryId != null) {
      missionData['target_category_id'] = _selectedCategoryId;
    }

    // Se for edição, mantém o ID
    if (widget.mission != null && widget.mission!['id'] != null) {
      missionData['id'] = widget.mission!['id'];
    }

    widget.onSave(missionData);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rewardController.dispose();
    _durationController.dispose();
    _targetValueController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 850),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.isCreating ? Icons.add_task : Icons.edit_note,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.isCreating ? 'Nova Missão' : 'Editar Missão',
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            if (_formError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SEÇÃO 1: Tipo de Missão com Cards Visuais
                    Text(
                      'Tipo de Missão *',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: MissionTypes.all.map((type) {
                        final isSelected = _missionType == type;
                        final typeColor = MissionTypeColors.get(type);
                        final typeIcon = MissionTypeIcons.get(type);
                        
                        return InkWell(
                          onTap: () => _onMissionTypeChanged(type),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 105,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? typeColor.withValues(alpha: 0.15)
                                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? typeColor : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  typeIcon,
                                  size: 28,
                                  color: isSelected ? typeColor : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  MissionTypeLabels.getShort(type),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isSelected ? typeColor : colorScheme.onSurfaceVariant,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    
                    // Descrição do tipo selecionado
                    Text(
                      _currentDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // SEÇÃO 2: Dicas Contextuais
                    if (_currentTips.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue[700]),
                                const SizedBox(width: 6),
                                Text(
                                  'Dicas',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ..._currentTips.map((tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('• ', style: TextStyle(color: Colors.blue[700])),
                                  Expanded(
                                    child: Text(
                                      tip,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    
                    // SEÇÃO 3: Título e Descrição
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        border: OutlineInputBorder(),
                        hintText: 'Ex: Alcance 15% de economia',
                      ),
                      maxLength: 150,
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição *',
                        border: OutlineInputBorder(),
                        hintText: 'Descreva o objetivo da missão',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    
                    // SEÇÃO 4: Meta da Missão com Validação Visual
                    if (_currentFieldConfig != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: MissionTypeColors.get(_missionType).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: MissionTypeColors.get(_missionType).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.track_changes,
                                  size: 18,
                                  color: MissionTypeColors.get(_missionType),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Meta da Missão',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: MissionTypeColors.get(_missionType),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currentFieldConfig!.hint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Campo com validação visual
                            StatefulBuilder(
                              builder: (context, setFieldState) {
                                final valueText = _targetValueController.text;
                                final value = num.tryParse(valueText);
                                final config = _currentFieldConfig!;
                                final status = _getValueValidationStatus(
                                  value,
                                  config.min,
                                  config.max,
                                  config.recommendedMin,
                                  config.recommendedMax,
                                );
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: _targetValueController,
                                      decoration: InputDecoration(
                                        labelText: config.unit != null 
                                            ? '${config.label} (${config.unit}) *' 
                                            : '${config.label} *',
                                        border: const OutlineInputBorder(),
                                        filled: true,
                                        fillColor: colorScheme.surface,
                                        suffixIcon: value != null
                                            ? Icon(
                                                _getValidationIcon(status),
                                                color: _getValidationColor(status),
                                              )
                                            : null,
                                      ),
                                      keyboardType: TextInputType.numberWithOptions(
                                        decimal: config.isDecimal,
                                      ),
                                      onChanged: (_) => setFieldState(() {}),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          'Válido: ${config.min}-${config.max}',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Recomendado: ${config.recommendedMin}-${config.recommendedMax}',
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                            
                            // Seletor de categoria para CATEGORY_REDUCTION
                            if (_missionType == 'CATEGORY_REDUCTION') ...[
                              const SizedBox(height: 16),
                              if (_loadingCategories)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              else if (_categories.isEmpty)
                                Text(
                                  'Nenhuma categoria global encontrada',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.error,
                                  ),
                                )
                              else
                                DropdownButtonFormField<int>(
                                  value: _selectedCategoryId,
                                  decoration: InputDecoration(
                                    labelText: 'Categoria Alvo *',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: colorScheme.surface,
                                    prefixIcon: const Icon(Icons.folder_outlined),
                                  ),
                                  isExpanded: true,
                                  hint: const Text('Selecione a categoria'),
                                  items: _categories.map<DropdownMenuItem<int>>((cat) {
                                    final catId = cat['id'];
                                    final catName = cat['name']?.toString() ?? 'Sem nome';
                                    final catColor = cat['color']?.toString();
                                    
                                    Color? displayColor;
                                    if (catColor != null && catColor.isNotEmpty) {
                                      try {
                                        final colorHex = catColor.replaceAll('#', '');
                                        displayColor = Color(int.parse('0xFF$colorHex'));
                                      } catch (_) {
                                        displayColor = null;
                                      }
                                    }
                                    
                                    return DropdownMenuItem<int>(
                                      value: catId is int ? catId : int.tryParse(catId.toString()),
                                      child: Row(
                                        children: [
                                          if (displayColor != null)
                                            Container(
                                              width: 12,
                                              height: 12,
                                              margin: const EdgeInsets.only(right: 8),
                                              decoration: BoxDecoration(
                                                color: displayColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          Flexible(
                                            child: Text(
                                              catName,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedCategoryId = value);
                                  },
                                ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    
                    // SEÇÃO 5: Dificuldade com Presets
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _difficulty,
                            decoration: InputDecoration(
                              labelText: 'Dificuldade',
                              border: const OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.trending_up,
                                color: DifficultyColors.get(_difficulty),
                              ),
                            ),
                            items: MissionDifficulties.all.map((d) {
                              return DropdownMenuItem(
                                value: d,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: DifficultyColors.get(d),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Text(DifficultyLabels.get(d)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _difficulty = value ?? 'MEDIUM');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Aplicar valores recomendados de XP e duração',
                          child: IconButton.filled(
                            onPressed: _applyDifficultyPreset,
                            icon: const Icon(Icons.auto_fix_high, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme.secondaryContainer,
                              foregroundColor: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // SEÇÃO 6: Duração e Recompensa com hints
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _durationController,
                                decoration: InputDecoration(
                                  labelText: 'Duração (dias)',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.schedule),
                                  helperText: _currentDifficultyPreset != null
                                      ? 'Recomendado: ${_currentDifficultyPreset!.durationMin}-${_currentDifficultyPreset!.durationMax}'
                                      : null,
                                  helperStyle: TextStyle(color: Colors.green[700]),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _rewardController,
                            decoration: InputDecoration(
                              labelText: 'Recompensa (XP)',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.stars, color: Colors.amber),
                              helperText: _currentDifficultyPreset != null
                                  ? 'Recomendado: ${_currentDifficultyPreset!.xpMin}-${_currentDifficultyPreset!.xpMax}'
                                  : null,
                              helperStyle: TextStyle(color: Colors.green[700]),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // SEÇÃO 7: Prioridade
                    TextField(
                      controller: _priorityController,
                      decoration: const InputDecoration(
                        labelText: 'Prioridade',
                        border: OutlineInputBorder(),
                        hintText: '1-100 (menor = mais prioritário)',
                        prefixIcon: Icon(Icons.low_priority),
                        helperText: '1-10: Alta prioridade | 50: Normal | 90+: Sistema',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _saveMission,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(widget.isCreating ? 'Criar' : 'Salvar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}