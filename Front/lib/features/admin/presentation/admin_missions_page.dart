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
                  ElevatedButton.icon(
                    onPressed: _isGenerating ? null : () => _showGenerateDialog(),
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Gerar com IA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.secondary,
                      foregroundColor: colorScheme.onSecondary,
                    ),
                  ),
                ],
              ),
            ),

            Container(
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18),
                        const SizedBox(width: 8),
                        const Text('Ativas'),
                        _buildBadgeCount(true),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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

    return ListView.builder(
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
    final parentContext = context;
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
                decoration: const InputDecoration(
                  labelText: 'Nível dos Usuários',
                  helperText: 'Define o público-alvo das missões',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todos os níveis (distribuição equilibrada)')),
                  DropdownMenuItem(value: 'BEGINNER', child: Text('Iniciante (níveis 1-5)')),
                  DropdownMenuItem(value: 'INTERMEDIATE', child: Text('Intermediário (níveis 6-15)')),
                  DropdownMenuItem(value: 'ADVANCED', child: Text('Avançado (níveis 16+)')),
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
        children: [
          Icon(icon, size: 14, color: Colors.green),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      Text(
                        MissionTypeLabels.getShort(missionType),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
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
                  Row(
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
      'INDICATOR_THRESHOLD': 'Limite de Indicador',
      'CATEGORY_REDUCTION': 'Redução em Categoria',
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
  late String _difficulty;
  late String _missionType;
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _rewardController = TextEditingController();
    _durationController = TextEditingController();
    _difficulty = 'MEDIUM';
    _missionType = 'TPS_IMPROVEMENT';
    
    if (widget.mission != null) {
      _titleController.text = widget.mission!['title'] ?? '';
      _descriptionController.text = widget.mission!['description'] ?? '';
      _rewardController.text = widget.mission!['xp_reward']?.toString() ?? '';
      _durationController.text = widget.mission!['duration_days']?.toString() ?? '';
      _difficulty = widget.mission!['difficulty'] ?? 'MEDIUM';
      _missionType = widget.mission!['type'] ?? 'TPS_IMPROVEMENT';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rewardController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isCreating ? 'Nova Missão' : 'Editar Missão',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _difficulty,
                            decoration: const InputDecoration(
                              labelText: 'Dificuldade',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'EASY', child: Text('Fácil')),
                              DropdownMenuItem(value: 'MEDIUM', child: Text('Médio')),
                              DropdownMenuItem(value: 'HARD', child: Text('Difícil')),
                            ],
                            onChanged: (value) {
                              setState(() => _difficulty = value ?? 'MEDIUM');
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _missionType,
                            decoration: const InputDecoration(
                              labelText: 'Tipo',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'TPS_IMPROVEMENT', child: Text('TPS')),
                              DropdownMenuItem(value: 'RDR_REDUCTION', child: Text('RDR')),
                              DropdownMenuItem(value: 'ILI_BUILDING', child: Text('ILI')),
                            ],
                            onChanged: (value) {
                              setState(() => _missionType = value ?? 'TPS_IMPROVEMENT');
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          final missionData = {
                            'title': _titleController.text,
                            'description': _descriptionController.text,
                            'xp_reward': int.tryParse(_rewardController.text) ?? 100,
                            'duration_days': int.tryParse(_durationController.text) ?? 7,
                            'difficulty': _difficulty,
                            'type': _missionType,
                          };
                          widget.onSave(missionData);
                          Navigator.pop(context);
                        },
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}