import 'package:flutter/material.dart';
import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/admin_widgets.dart';
import '../mixins/admin_page_mixin.dart';

class AdminMissionsManagementPage extends StatefulWidget {
  const AdminMissionsManagementPage({super.key});

  @override
  State<AdminMissionsManagementPage> createState() =>
      _AdminMissionsManagementPageState();
}

class _AdminMissionsManagementPageState
    extends State<AdminMissionsManagementPage> with AdminPageMixin {
  final _apiClient = ApiClient();
  final _searchController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _missions = [];
  String? _error;
  String _filterType = 'ALL';
  String _filterDifficulty = 'ALL';
  final String _filterStatus = 'ALL'; // ALL, ACTIVE, PAUSED
  String _filterQuality = 'ALL'; // ALL, VALID, INVALID
  String _searchQuery = '';
  String _sortBy = 'xp_desc'; // xp_desc, xp_asc, difficulty_desc, difficulty_asc, date_desc, date_asc
  
  // Sele��o m�ltipla para a��es em lote
  final Set<String> _selectedMissions = {};
  bool _isSelectionMode = false;
  
  // Controles para gera��o de miss�es IA
  bool _isGeneratingAI = false;
  String _selectedTier = 'ALL';
  int _generationProgress = 0;
  int _generationTotal = 20;
  String _generationMessage = '';
  
  final _tierOptions = {
    'ALL': 'Todas as Faixas (60 miss�es)',
    'BEGINNER': 'Iniciantes (20 miss�es)',
    'INTERMEDIATE': 'Intermedi�rios (20 miss�es)',
    'ADVANCED': 'Avan�ados (20 miss�es)',
  };

  @override
  void initState() {
    super.initState();
    _loadMissions();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }


  bool _hasPlaceholders(Map<String, dynamic> mission) {
    final placeholderPattern = RegExp(r'\{[^}]+\}');
    final title = mission['title']?.toString() ?? '';
    final description = mission['description']?.toString() ?? '';
    return placeholderPattern.hasMatch(title) || placeholderPattern.hasMatch(description);
  }
  

  List<String> _getPlaceholders(Map<String, dynamic> mission) {
    final placeholderPattern = RegExp(r'\{([^}]+)\}');
    final placeholders = <String>{};
    final title = mission['title']?.toString() ?? '';
    final description = mission['description']?.toString() ?? '';
    
    placeholderPattern.allMatches(title).forEach((match) {
      if (match.group(1) != null) placeholders.add(match.group(1)!);
    });
    placeholderPattern.allMatches(description).forEach((match) {
      if (match.group(1) != null) placeholders.add(match.group(1)!);
    });
    
    return placeholders.toList();
  }
  

  Map<String, int> get _qualityStats {
    int valid = 0;
    int invalid = 0;
    
    for (final mission in _missions) {
      if (_hasPlaceholders(mission)) {
        invalid++;
      } else {
        valid++;
      }
    }
    
    return {'valid': valid, 'invalid': invalid, 'total': _missions.length};
  }

  Future<void> _loadMissions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiClient.client.get(
        '/api/missions/',
      );

      if (response.data != null) {
        final data = response.data is Map<String, dynamic> 
            ? response.data as Map<String, dynamic>
            : json.decode(response.data.toString()) as Map<String, dynamic>;
        
        final results = data['results'] as List?;
        final missions = results?.cast<Map<String, dynamic>>() ?? [];
        
        // Log de miss�es com placeholders
        final invalidMissions = missions.where(_hasPlaceholders).toList();
        if (invalidMissions.isNotEmpty) {
          debugPrint(
            '?? Detectadas ${invalidMissions.length} miss�o(�es) com placeholders no admin'
          );
        }
        
        setState(() {
          _missions = missions;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }


  List<Map<String, dynamic>> get _filteredAndSortedMissions {
    var filtered = _missions.where((mission) {
      // Filtro por tipo
      if (_filterType != 'ALL') {
        final missionType = mission['mission_type']?.toString().toUpperCase() ?? '';
        if (missionType != _filterType) return false;
      }

      // Filtro por dificuldade
      if (_filterDifficulty != 'ALL') {
        // Suporta tanto 'difficulty' quanto 'priority' como fallback
        final difficulty = (mission['difficulty'] ?? mission['priority'])?.toString().toUpperCase() ?? '';
        if (difficulty != _filterDifficulty) return false;
      }

      // Filtro por status
      if (_filterStatus != 'ALL') {
        final isActive = mission['is_active'] == true;
        if (_filterStatus == 'ACTIVE' && !isActive) return false;
        if (_filterStatus == 'PAUSED' && isActive) return false;
      }
      
      // Filtro por qualidade
      if (_filterQuality != 'ALL') {
        final hasPlaceholders = _hasPlaceholders(mission);
        if (_filterQuality == 'VALID' && hasPlaceholders) return false;
        if (_filterQuality == 'INVALID' && !hasPlaceholders) return false;
      }

      // Filtro por busca
      if (_searchQuery.isNotEmpty) {
        final title = mission['title']?.toString().toLowerCase() ?? '';
        final description = mission['description']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        if (!title.contains(query) && !description.contains(query)) return false;
      }

      return true;
    }).toList();

    // Ordena��o
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'xp_desc':
          return (b['xp_reward'] ?? 0).compareTo(a['xp_reward'] ?? 0);
        case 'xp_asc':
          return (a['xp_reward'] ?? 0).compareTo(b['xp_reward'] ?? 0);
        case 'difficulty_desc':
          final diffOrder = {'HARD': 3, 'MEDIUM': 2, 'EASY': 1};
          final aDiff = diffOrder[(a['difficulty'] ?? a['priority'])?.toString().toUpperCase()] ?? 0;
          final bDiff = diffOrder[(b['difficulty'] ?? b['priority'])?.toString().toUpperCase()] ?? 0;
          return bDiff.compareTo(aDiff);
        case 'difficulty_asc':
          final diffOrder = {'HARD': 3, 'MEDIUM': 2, 'EASY': 1};
          final aDiff = diffOrder[(a['difficulty'] ?? a['priority'])?.toString().toUpperCase()] ?? 0;
          final bDiff = diffOrder[(b['difficulty'] ?? b['priority'])?.toString().toUpperCase()] ?? 0;
          return aDiff.compareTo(bDiff);
        case 'date_desc':
          final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
          final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
          if (aDate == null || bDate == null) return 0;
          return bDate.compareTo(aDate);
        case 'date_asc':
          final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
          final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
          if (aDate == null || bDate == null) return 0;
          return aDate.compareTo(bDate);
        default:
          return 0;
      }
    });

    return filtered;
  }


  Future<void> _bulkToggleStatus(bool activate) async {
    if (_selectedMissions.isEmpty) return;
    
    final count = _selectedMissions.length;
    final action = activate ? 'ativar' : 'desativar';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Confirmar a��o em lote',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Deseja $action $count miss�o(�es) selecionada(s)?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: activate ? AppColors.success : Colors.orange,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    int successCount = 0;
    int errorCount = 0;
    
    for (final missionId in _selectedMissions) {
      try {
        await _apiClient.client.patch(
          '/api/missions/$missionId/',
          data: {'is_active': activate},
        );
        successCount++;
      } catch (e) {
        errorCount++;
      }
    }
    
    setState(() {
      _selectedMissions.clear();
      _isSelectionMode = false;
    });
    
    await _loadMissions();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$successCount miss�o(�es) ${activate ? 'ativada(s)' : 'desativada(s)'}${errorCount > 0 ? ' ($errorCount erro(s))' : ''}'
          ),
          backgroundColor: errorCount > 0 ? Colors.orange : AppColors.success,
        ),
      );
    }
  }
  

  Future<void> _bulkDelete() async {
    if (_selectedMissions.isEmpty) return;
    
    final count = _selectedMissions.length;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.alert),
            const SizedBox(width: 12),
            Text(
              'Excluir $count miss�o(�es)?',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'Esta a��o n�o pode ser desfeita. Deseja continuar?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alert,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    int successCount = 0;
    int errorCount = 0;
    
    for (final missionId in _selectedMissions) {
      try {
        await _apiClient.client.delete('/api/missions/$missionId/');
        successCount++;
      } catch (e) {
        errorCount++;
      }
    }
    
    setState(() {
      _selectedMissions.clear();
      _isSelectionMode = false;
    });
    
    await _loadMissions();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$successCount miss�o(�es) exclu�da(s)${errorCount > 0 ? ' ($errorCount erro(s))' : ''}'
          ),
          backgroundColor: errorCount > 0 ? Colors.orange : AppColors.success,
        ),
      );
    }
  }

  Future<void> _toggleMissionStatus(String missionId, bool isActive) async {
    try {
      await _apiClient.client.patch(
        '/api/missions/$missionId/',
        data: {'is_active': !isActive},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isActive ? 'Miss�o desativada' : 'Miss�o ativada',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }

      await _loadMissions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: AppColors.alert,
          ),
        );
      }
    }
  }


  Future<void> _showEditMissionDialog(Map<String, dynamic> mission) async {
    final titleController = TextEditingController(text: mission['title']?.toString() ?? '');
    final descriptionController = TextEditingController(text: mission['description']?.toString() ?? '');
    final xpValue = mission['reward_points'] ?? mission['xp_reward'] ?? 0;
    final xpController = TextEditingController(text: xpValue.toString());
    final durationController = TextEditingController(text: (mission['duration_days'] ?? 30).toString());
    final priorityController = TextEditingController(text: (mission['priority'] ?? 1).toString());
    final targetTPSController = TextEditingController(text: mission['target_tps']?.toString() ?? '');
    final targetRDRController = TextEditingController(text: mission['target_rdr']?.toString() ?? '');
    final minILIController = TextEditingController(text: mission['min_ili']?.toString() ?? '');
    final maxILIController = TextEditingController(text: mission['max_ili']?.toString() ?? '');
    final minTransactionsController = TextEditingController(text: mission['min_transactions']?.toString() ?? '');
    
    String selectedType = mission['mission_type']?.toString().toUpperCase() ?? 'ONBOARDING';
    String selectedDifficulty = (mission['difficulty']?.toString() ?? 'EASY').toUpperCase();
    String selectedValidationType = (mission['validation_type']?.toString() ?? 'SNAPSHOT').toUpperCase();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
              ),
            ),
            title: const Row(
              children: [
                Icon(Icons.edit, color: AppColors.primary),
                SizedBox(width: 12),
                Text(
                  'Editar Miss�o',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Se��o: Informa��es B�sicas
                    const AdminSectionHeader(title: 'Informa��es B�sicas', icon: Icons.info_outline),
                    const SizedBox(height: 12),
                    _buildTextField('T�tulo', titleController),
                    const SizedBox(height: 16),
                    _buildTextField('Descri��o', descriptionController, maxLines: 3),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField('XP Recompensa', xpController, 
                            keyboardType: TextInputType.number),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField('Dura��o (dias)', durationController,
                            keyboardType: TextInputType.number),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('Prioridade (menor = maior)', priorityController,
                      keyboardType: TextInputType.number),
                    
                    const SizedBox(height: 24),
                    // Se��o: Classifica��o
                    const AdminSectionHeader(title: 'Classifica??o', icon: Icons.category),
                    const SizedBox(height: 12),
                    _buildLabeledDropdown(
                      'Tipo de Miss�o',
                      selectedType,
                      [
                        const DropdownMenuItem(value: 'ONBOARDING', child: Text('Integra��o inicial')),
                        const DropdownMenuItem(value: 'TPS_IMPROVEMENT', child: Text('Melhoria de poupan�a')),
                        const DropdownMenuItem(value: 'RDR_REDUCTION', child: Text('Redu��o de d�vidas')),
                        const DropdownMenuItem(value: 'ILI_BUILDING', child: Text('Constru��o de reserva')),
                        const DropdownMenuItem(value: 'ADVANCED', child: Text('Avan�ado')),
                      ],
                      (value) => setDialogState(() => selectedType = value!),
                    ),
                    const SizedBox(height: 16),
                    _buildLabeledDropdown(
                      'Dificuldade',
                      selectedDifficulty,
                      [
                        const DropdownMenuItem(value: 'EASY', child: Text('F�cil')),
                        const DropdownMenuItem(value: 'MEDIUM', child: Text('M�dia')),
                        const DropdownMenuItem(value: 'HARD', child: Text('Dif�cil')),
                      ],
                      (value) => setDialogState(() => selectedDifficulty = value!),
                    ),
                    const SizedBox(height: 16),
                    _buildLabeledDropdown(
                      'Tipo de Valida��o',
                      selectedValidationType,
                      [
                        const DropdownMenuItem(value: 'SNAPSHOT', child: Text('Compara��o pontual')),
                        const DropdownMenuItem(value: 'TEMPORAL', child: Text('Manter crit�rio por per�odo')),
                        const DropdownMenuItem(value: 'CATEGORY_REDUCTION', child: Text('Redu��o de categoria')),
                        const DropdownMenuItem(value: 'CATEGORY_LIMIT', child: Text('Limite de categoria')),
                        const DropdownMenuItem(value: 'SAVINGS_INCREASE', child: Text('Aumento de poupan�a')),
                        const DropdownMenuItem(value: 'CONSISTENCY', child: Text('Consist�ncia')),
                      ],
                      (value) => setDialogState(() => selectedValidationType = value!),
                    ),
                    
                    const SizedBox(height: 24),
                    // Se��o: Crit�rios de Indicadores (Opcional)
                    const AdminSectionHeader(title: 'Classifica??o', icon: Icons.category),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField('TPS Alvo (%)', targetTPSController,
                            keyboardType: TextInputType.number),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField('RDR M�ximo (%)', targetRDRController,
                            keyboardType: TextInputType.number),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField('ILI M�nimo (meses)', minILIController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField('ILI M�ximo (meses)', maxILIController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('Transa��es M�nimas', minTransactionsController,
                      keyboardType: TextInputType.number),
                    
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(                     
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Deixe os campos vazios se n�o forem aplic�veis',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Valida��es
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('O t�tulo � obrigat�rio'),
                        backgroundColor: AppColors.alert,
                      ),
                    );
                    return;
                  }

                  final xpValue = int.tryParse(xpController.text);
                  if (xpValue == null || xpValue <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('XP deve ser um n�mero v�lido maior que zero'),
                        backgroundColor: AppColors.alert,
                      ),
                    );
                    return;
                  }

                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  try {
                    final data = <String, dynamic>{
                      'title': titleController.text.trim(),
                      'description': descriptionController.text.trim(),
                      'reward_points': xpValue,
                      'mission_type': selectedType,
                      'difficulty': selectedDifficulty,
                      'validation_type': selectedValidationType,
                      'duration_days': int.tryParse(durationController.text) ?? 30,
                      'priority': int.tryParse(priorityController.text) ?? 1,
                    };
                    
                    // Adicionar campos opcionais apenas se preenchidos
                    if (targetTPSController.text.isNotEmpty) {
                      data['target_tps'] = int.tryParse(targetTPSController.text);
                    }
                    if (targetRDRController.text.isNotEmpty) {
                      data['target_rdr'] = int.tryParse(targetRDRController.text);
                    }
                    if (minILIController.text.isNotEmpty) {
                      data['min_ili'] = double.tryParse(minILIController.text);
                    }
                    if (maxILIController.text.isNotEmpty) {
                      data['max_ili'] = double.tryParse(maxILIController.text);
                    }
                    if (minTransactionsController.text.isNotEmpty) {
                      data['min_transactions'] = int.tryParse(minTransactionsController.text);
                    }

                    await _apiClient.client.patch(
                      '/api/missions/${mission['id']}/',
                      data: data,
                    );

                    if (!mounted) return;
                    
                    navigator.pop();
                    
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Miss�o atualizada com sucesso!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    
                    await _loadMissions();
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Erro ao atualizar: ${e.toString()}'),
                        backgroundColor: AppColors.alert,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
    
    // Libera os controllers ap�s o frame ser completamente renderizado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      titleController.dispose();
      descriptionController.dispose();
      xpController.dispose();
      durationController.dispose();
      priorityController.dispose();
      targetTPSController.dispose();
      targetRDRController.dispose();
      minILIController.dispose();
      maxILIController.dispose();
      minTransactionsController.dispose();
    });
  }


  Future<void> _showCreateMissionDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final xpController = TextEditingController(text: '100');
    final durationController = TextEditingController(text: '30');
    final priorityController = TextEditingController(text: '50');
    final targetTPSController = TextEditingController();
    final targetRDRController = TextEditingController();
    final minILIController = TextEditingController();
    final maxILIController = TextEditingController();
    final minTransactionsController = TextEditingController();
    
    String selectedType = 'ONBOARDING';
    String selectedDifficulty = 'EASY';
    String selectedValidationType = 'SNAPSHOT';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            title: const Row(
              children: [
                Icon(Icons.add_task, color: AppColors.primary),
                SizedBox(width: 12),
                Text(
                  'Nova Miss�o',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Se��o: Informa��es B�sicas
                    const AdminSectionHeader(title: 'Informa��es B�sicas', icon: Icons.info_outline),
                    const SizedBox(height: 12),
                    _buildTextField('T�tulo', titleController),
                    const SizedBox(height: 16),
                    _buildTextField('Descri��o', descriptionController, maxLines: 3),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField('XP Recompensa', xpController, 
                            keyboardType: TextInputType.number),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField('Dura��o (dias)', durationController,
                            keyboardType: TextInputType.number),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('Prioridade (menor = maior)', priorityController,
                      keyboardType: TextInputType.number),
                    
                    const SizedBox(height: 24),
                    // Se��o: Classifica��o
                    const AdminSectionHeader(title: 'Classifica??o', icon: Icons.category),
                    const SizedBox(height: 12),
                    _buildLabeledDropdown(
                      'Tipo de Miss�o',
                      selectedType,
                      [
                        const DropdownMenuItem(value: 'ONBOARDING', child: Text('Integra��o inicial')),
                        const DropdownMenuItem(value: 'TPS_IMPROVEMENT', child: Text('Melhoria de poupan�a')),
                        const DropdownMenuItem(value: 'RDR_REDUCTION', child: Text('Redu��o de d�vidas')),
                        const DropdownMenuItem(value: 'ILI_BUILDING', child: Text('Constru��o de reserva')),
                        const DropdownMenuItem(value: 'ADVANCED', child: Text('Avan�ado')),
                      ],
                      (value) => setDialogState(() => selectedType = value!),
                    ),
                    const SizedBox(height: 16),
                    _buildLabeledDropdown(
                      'Dificuldade',
                      selectedDifficulty,
                      [
                        const DropdownMenuItem(value: 'EASY', child: Text('F�cil')),
                        const DropdownMenuItem(value: 'MEDIUM', child: Text('M�dia')),
                        const DropdownMenuItem(value: 'HARD', child: Text('Dif�cil')),
                      ],
                      (value) => setDialogState(() => selectedDifficulty = value!),
                    ),
                    const SizedBox(height: 16),
                    _buildLabeledDropdown(
                      'Tipo de Valida��o',
                      selectedValidationType,
                      [
                        const DropdownMenuItem(value: 'SNAPSHOT', child: Text('Compara��o pontual')),
                        const DropdownMenuItem(value: 'TEMPORAL', child: Text('Manter crit�rio por per�odo')),
                        const DropdownMenuItem(value: 'CATEGORY_REDUCTION', child: Text('Redu��o de categoria')),
                        const DropdownMenuItem(value: 'CATEGORY_LIMIT', child: Text('Limite de categoria')),
                        const DropdownMenuItem(value: 'SAVINGS_INCREASE', child: Text('Aumento de poupan�a')),
                        const DropdownMenuItem(value: 'CONSISTENCY', child: Text('Consist�ncia')),
                      ],
                      (value) => setDialogState(() => selectedValidationType = value!),
                    ),
                    
                    const SizedBox(height: 24),
                    // Se��o: Crit�rios de Indicadores (Opcional)
                    const AdminSectionHeader(title: 'Classifica??o', icon: Icons.category),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField('TPS Alvo (%)', targetTPSController,
                            keyboardType: TextInputType.number),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField('RDR M�ximo (%)', targetRDRController,
                            keyboardType: TextInputType.number),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField('ILI M�nimo (meses)', minILIController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField('ILI M�ximo (meses)', maxILIController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('Transa��es M�nimas', minTransactionsController,
                      keyboardType: TextInputType.number),
                    
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Deixe os campos vazios se n�o forem aplic�veis',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Valida��es
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('O t�tulo � obrigat�rio'),
                        backgroundColor: AppColors.alert,
                      ),
                    );
                    return;
                  }

                  final xpValue = int.tryParse(xpController.text);
                  if (xpValue == null || xpValue <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('XP deve ser um n�mero v�lido maior que zero'),
                        backgroundColor: AppColors.alert,
                      ),
                    );
                    return;
                  }

                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  try {
                    final data = <String, dynamic>{
                      'title': titleController.text.trim(),
                      'description': descriptionController.text.trim(),
                      'reward_points': xpValue,
                      'mission_type': selectedType,
                      'difficulty': selectedDifficulty,
                      'validation_type': selectedValidationType,
                      'duration_days': int.tryParse(durationController.text) ?? 30,
                      'priority': int.tryParse(priorityController.text) ?? 50,
                      'is_active': true,
                    };
                    
                    // Adicionar campos opcionais apenas se preenchidos
                    if (targetTPSController.text.isNotEmpty) {
                      data['target_tps'] = int.tryParse(targetTPSController.text);
                    }
                    if (targetRDRController.text.isNotEmpty) {
                      data['target_rdr'] = int.tryParse(targetRDRController.text);
                    }
                    if (minILIController.text.isNotEmpty) {
                      data['min_ili'] = double.tryParse(minILIController.text);
                    }
                    if (maxILIController.text.isNotEmpty) {
                      data['max_ili'] = double.tryParse(maxILIController.text);
                    }
                    if (minTransactionsController.text.isNotEmpty) {
                      data['min_transactions'] = int.tryParse(minTransactionsController.text);
                    }

                    await _apiClient.client.post('/api/missions/', data: data);

                    if (!mounted) return;
                    
                    navigator.pop();
                    
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Miss�o criada com sucesso!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    
                    await _loadMissions();
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Erro ao criar: ${e.toString()}'),
                        backgroundColor: AppColors.alert,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Criar'),
              ),
            ],
          );
        },
      ),
    );
    
    // Libera os controllers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      titleController.dispose();
      descriptionController.dispose();
      xpController.dispose();
      durationController.dispose();
      priorityController.dispose();
      targetTPSController.dispose();
      targetRDRController.dispose();
      minILIController.dispose();
      maxILIController.dispose();
      minTransactionsController.dispose();
    });
  }


  Future<void> _duplicateMission(String missionId, String missionTitle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppColors.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.content_copy, color: AppColors.primary),
            SizedBox(width: 12),
            Text(
              'Duplicar Miss�o',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deseja duplicar a miss�o:',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: Text(
                missionTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'A miss�o duplicada ser� criada como DESATIVADA para que voc� possa revisar antes de ativar.',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Duplicar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiClient.client.post(
        '/api/missions/$missionId/duplicate/',
        data: {},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Miss�o duplicada com sucesso! (Status: Desativada)'),
          backgroundColor: AppColors.success,
        ),
      );

      await _loadMissions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao duplicar: ${e.toString()}'),
          backgroundColor: AppColors.alert,
        ),
      );
    }
  }


  Future<void> _deleteMission(String missionId, String missionTitle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppColors.alert.withOpacity(0.3),
            width: 1,
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.alert),
            SizedBox(width: 12),
            Text(
              'Confirmar Exclus�o',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tem certeza que deseja excluir a miss�o:',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.alert.withOpacity(0.3),
                ),
              ),
              child: Text(
                missionTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Esta a��o n�o pode ser desfeita.',
              style: TextStyle(
                color: AppColors.alert,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alert,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiClient.client.delete('/api/missions/$missionId/');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Miss�o exclu�da com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
          await _loadMissions();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: ${e.toString()}'),
              backgroundColor: AppColors.alert,
            ),
          );
        }
      }
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0D0D0D),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildLabeledDropdown(
    String label,
    String value,
    List<DropdownMenuItem<String>> items,
    void Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: const Color(0xFF2A2A2A),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0D0D0D),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            isDense: true,
          ),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }


  Future<void> _showAIGenerationDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return ScaleTransition(
            scale: CurvedAnimation(
              parent: const AlwaysStoppedAnimation(1.0),
              curve: Curves.easeOutBack,
            ),
            child: AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              contentPadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.15),
                      AppColors.primary.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Carga de Miss�es IA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Utilizando o Google Gemini',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.height * 0.65,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // Informa��es sobre o processo
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Como Funciona a Gera��o Inteligente',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const SizedBox(height: 10),
                          _buildInfoRow(
                            Icons.psychology,
                            'Gera miss�es com base nos padr�es (TPS, RDR, ILI)',
                            Colors.blue,
                          ),
                          const SizedBox(height: 10),
                          _buildInfoRow(
                            Icons.layers,
                            'Cria miss�es em 3 n�veis de dificuldade',
                            Colors.orange,
                          ),
                          const SizedBox(height: 10),
                          _buildInfoRow(
                            Icons.insights,
                            'Ajusta XP e crit�rios automaticamente (fornecidos pela IA)',
                            Colors.green,
                          ),
                          const SizedBox(height: 14),
                          // Indicador de progresso (apenas quando gerando)
                          if (_isGeneratingAI)
                            Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.success.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            AppColors.success,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _generationMessage.isNotEmpty 
                                                ? _generationMessage 
                                                : 'Gerando miss�es...',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$_generationProgress/$_generationTotal miss�es',
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  LinearProgressIndicator(
                                    value: _generationTotal > 0 
                                      ? _generationProgress / _generationTotal 
                                      : 0,
                                    backgroundColor: Colors.grey[800],
                                    valueColor: const AlwaysStoppedAnimation(
                                      AppColors.success,
                                    ),
                                    minHeight: 4,
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'As miss�es s�o criadas DESATIVADAS por padr�o para revis�o',
                                    style: TextStyle(
                                      color: Colors.grey[300],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Card explicativo sobre as faixas de usu�rios
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.groups,
                                color: Colors.blue,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Classifica��o de Usu�rios em Faixas',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildUserTierInfo(
                            '?? Iniciantes',
                            'Usu�rios com menos de 30 transa��es',
                            'Foco em aprendizado e forma��o de h�bitos b�sicos',
                            Colors.green,
                          ),
                          const SizedBox(height: 12),
                          _buildUserTierInfo(
                            '?? Intermedi�rios',
                            'Entre 30 e 100 transa��es registradas',
                            'Desafios para melhorar indicadores e consist�ncia',
                            Colors.blue,
                          ),
                          const SizedBox(height: 12),
                          _buildUserTierInfo(
                            '?? Avan�ados',
                            'Mais de 100 transa��es no hist�rico',
                            'Miss�es complexas com metas financeiras ambiciosas',
                            Colors.orange,
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.lightbulb_outline,
                                  color: Colors.blue,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'A IA ajusta automaticamente a dificuldade e os crit�rios para cada faixa',
                                    style: TextStyle(
                                      color: Colors.grey[300],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Estat�sticas esperadas
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.15),
                            AppColors.primary.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.auto_graph,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Distribui��o de Miss�es',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatChip(
                                  'F�cil',
                                  '40%',
                                  Colors.green,
                                  Icons.sentiment_satisfied_alt,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatChip(
                                  'M�dia',
                                  '40%',
                                  Colors.orange,
                                  Icons.sentiment_neutral,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatChip(
                                  'Dif�cil',
                                  '20%',
                                  Colors.red,
                                  Icons.sentiment_very_dissatisfied,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Sele��o de faixa
                    Row(
                      children: [
                        Icon(
                          Icons.groups,
                          color: Colors.grey[400],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Selecione a Faixa de Usu�rios',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedTier,
                        dropdownColor: const Color(0xFF2A2A2A),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.category,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: Color(0xFF0D0D0D),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        items: _tierOptions.entries.map((entry) {
                          IconData icon;
                          Color color;
                          switch (entry.key) {
                            case 'BEGINNER':
                              icon = Icons.emoji_people;
                              color = Colors.green;
                              break;
                            case 'INTERMEDIATE':
                              icon = Icons.trending_up;
                              color = Colors.blue;
                              break;
                            case 'ADVANCED':
                              icon = Icons.emoji_events;
                              color = Colors.orange;
                              break;
                            default:
                              icon = Icons.all_inclusive;
                              color = AppColors.primary;
                          }
                          
                          return DropdownMenuItem(
                            value: entry.key,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, color: color, size: 18),
                                const SizedBox(width: 10),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: Text(
                                    entry.value,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            _selectedTier = value!;
                          });
                        },
                      ),
                    ),
                    
                    if (_isGeneratingAI) ...[
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Gerando miss�es com IA...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'A IA est� analisando e criando miss�es',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Isso pode levar alguns segundos...',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                  ),
                ),
              ),
              actions: [
                if (!_isGeneratingAI) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _generateMissionsWithAI(setDialogState),
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: const Text(
                      'Gerar Miss�es',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }


  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildStatChip(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  Widget _buildUserTierInfo(String title, String criteria, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: color,
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  criteria,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _generateMissionsWithAI(StateSetter setDialogState) async {
    setDialogState(() {
      _isGeneratingAI = true;
    });

    try {
      // ETAPA 1: Iniciar gera��o ass�ncrona
      final body = {
        if (_selectedTier != 'ALL') 'tier': _selectedTier,
        'async': true,  // Usar modo ass�ncrono
        'count': 20,
      };

      final startResponse = await _apiClient.client.post<Map<String, dynamic>>(
        '/api/missions/generate_ai_missions/',
        data: body,
      );

      if (startResponse.data == null) {
        throw Exception('Resposta vazia do servidor');
      }

      final taskId = startResponse.data!['task_id'] as String?;
      if (taskId == null) {
        throw Exception('task_id n�o retornado pelo servidor');
      }

      // ETAPA 2: Polling de progresso
      bool completed = false;
      int pollCount = 0;
      const maxPolls = 120; // 5 minutos (120 * 2.5s)

      while (!completed && pollCount < maxPolls) {
        await Future.delayed(const Duration(milliseconds: 2500)); // Poll a cada 2.5s
        pollCount++;

        try {
          final statusResponse = await _apiClient.client.get<Map<String, dynamic>>(
            '/api/missions/generation_status/$taskId/',
          );

          if (statusResponse.data != null) {
            final status = statusResponse.data!['status'] as String?;
            final currentProgress = statusResponse.data!['current'] as int? ?? 0;
            final totalMissions = statusResponse.data!['total'] as int? ?? 20;
            final statusMessage = statusResponse.data!['message'] as String? ?? 'Processando...';

            // Atualizar UI do dialog
            setDialogState(() {
              _generationProgress = currentProgress;
              _generationTotal = totalMissions;
              _generationMessage = statusMessage;
            });

            if (status == 'SUCCESS') {
              completed = true;
              final summary = statusResponse.data!['summary'] as Map<String, dynamic>?;
              final totalCreated = summary?['total_created'] as int? ?? currentProgress;

              if (mounted) {
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Sucesso! $totalCreated miss�es criadas com IA',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 4),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );

                await _loadMissions();
              }
            } else if (status == 'FAILURE') {
              completed = true;
              final error = statusResponse.data!['error'] as String? ?? 'Erro desconhecido';
              throw Exception(error);
            }
            // STARTED ou PENDING: continuar polling
          }
        } catch (e) {
          // Erro no polling, mas continuar tentando
        }
      }

      if (!completed) {
        throw Exception('Timeout: gera��o excedeu 5 minutos');
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Erro ao gerar miss�es: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: AppColors.alert,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Gerenciar Miss�es',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Bot�o de Carga IA (apenas em telas maiores)
          if (isLargeScreen)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: _showAIGenerationDialog,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text(
                  'Carga IA',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMissions,
            tooltip: 'Atualizar lista',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                : _error != null
                    ? _buildError()
                    : _buildMissionsList(),
          ),
        ],
      ),
      // FAB com menu para criar miss�o manual ou via IA
      floatingActionButton: !isLargeScreen
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Bot�o Criar Miss�o Manual
                FloatingActionButton.extended(
                  onPressed: _showCreateMissionDialog,
                  heroTag: 'create_mission',
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  icon: const Icon(Icons.add_task),
                  label: const Text(
                    'Nova Miss�o',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                // Bot�o Carga IA
                FloatingActionButton.extended(
                  onPressed: _showAIGenerationDialog,
                  heroTag: 'ai_generation',
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text(
                    'Carga IA',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildFilters() {
    final filteredCount = _filteredAndSortedMissions.length;
    final totalCount = _missions.length;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header com contador
          Row(
            children: [
              const Icon(Icons.filter_list, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Busca e Filtros',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  '$filteredCount de $totalCount miss�es',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Campo de busca
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar por t�tulo ou descri��o...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[600]),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF0D0D0D),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[800]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[800]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Primeira linha: Tipo e Dificuldade
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tipo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _filterType,
                      dropdownColor: const Color(0xFF2A2A2A),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('Todos')),
                        DropdownMenuItem(
                          value: 'SAVINGS',
                          child: Text('Economia'),
                        ),
                        DropdownMenuItem(
                          value: 'EXPENSE_CONTROL',
                          child: Text('Controle'),
                        ),
                        DropdownMenuItem(
                          value: 'DEBT_REDUCTION',
                          child: Text('D�vidas'),
                        ),
                        DropdownMenuItem(
                          value: 'ONBOARDING',
                          child: Text('Onboarding'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterType = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dificuldade',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _filterDifficulty,
                      dropdownColor: const Color(0xFF2A2A2A),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('Todas')),
                        DropdownMenuItem(value: 'EASY', child: Text('F�cil')),
                        DropdownMenuItem(
                          value: 'MEDIUM',
                          child: Text('M�dia'),
                        ),
                        DropdownMenuItem(value: 'HARD', child: Text('Dif�cil')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterDifficulty = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Terceira linha: Qualidade e Ordena��o
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qualidade',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _filterQuality,
                      dropdownColor: const Color(0xFF2A2A2A),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('Todas')),
                        const DropdownMenuItem(value: 'VALID', child: Text('? V�lidas')),
                        DropdownMenuItem(
                          value: 'INVALID',
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                              const SizedBox(width: 6),
                              Text('Placeholders (${_qualityStats['invalid']})'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterQuality = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ordenar por',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _sortBy,
                      dropdownColor: const Color(0xFF2A2A2A),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: const [
                        DropdownMenuItem(value: 'xp_desc', child: Text('XP ?')),
                        DropdownMenuItem(value: 'xp_asc', child: Text('XP ?')),
                        DropdownMenuItem(value: 'difficulty_desc', child: Text('Dificuldade ?')),
                        DropdownMenuItem(value: 'difficulty_asc', child: Text('Dificuldade ?')),
                        DropdownMenuItem(value: 'date_desc', child: Text('Mais recentes')),
                        DropdownMenuItem(value: 'date_asc', child: Text('Mais antigas')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sortBy = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Estat�sticas de qualidade
          if (_qualityStats['invalid']! > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_qualityStats['invalid']} miss�o(�es) com placeholders n�o substitu�dos',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterQuality = 'INVALID';
                      });
                    },
                    child: const Text('Ver', style: TextStyle(color: Colors.orange)),
                  ),
                ],
              ),
            ),
          ],
          
          // Modo de sele��o
          if (_isSelectionMode) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_selectedMissions.length} miss�o(�es) selecionada(s)',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.toggle_on, color: AppColors.success, size: 28),
                    onPressed: () => _bulkToggleStatus(true),
                    tooltip: 'Ativar selecionadas',
                  ),
                  IconButton(
                    icon: const Icon(Icons.toggle_off, color: Colors.orange, size: 28),
                    onPressed: () => _bulkToggleStatus(false),
                    tooltip: 'Desativar selecionadas',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.alert, size: 24),
                    onPressed: _bulkDelete,
                    tooltip: 'Excluir selecionadas',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedMissions.clear();
                        _isSelectionMode = false;
                      });
                    },
                    tooltip: 'Cancelar sele��o',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.alert.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar miss�es',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadMissions,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionsList() {
    if (_filteredAndSortedMissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 64,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nenhuma miss�o encontrada',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajuste os filtros ou use a Carga IA',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAIGenerationDialog,
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: const Text('Gerar Miss�es com IA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Estat�sticas das miss�es filtradas
    final activeMissions = _filteredAndSortedMissions.where((m) => m['is_active'] == true).length;
    final inactiveMissions = _filteredAndSortedMissions.length - activeMissions;

    return Column(
      children: [
        // Card de estat�sticas
        if (_filteredAndSortedMissions.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.15),
                  AppColors.primary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                _StatBadge(
                  icon: Icons.check_circle,
                  label: 'Ativas',
                  count: activeMissions,
                  color: AppColors.success,
                ),
                const SizedBox(width: 12),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.grey[800],
                ),
                const SizedBox(width: 12),
                _StatBadge(
                  icon: Icons.pause_circle,
                  label: 'Pausadas',
                  count: inactiveMissions,
                  color: Colors.grey[600]!,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.inventory_2,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_filteredAndSortedMissions.length} total',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Lista de miss�es
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: _filteredAndSortedMissions.length,
            itemBuilder: (context, index) {
              final mission = _filteredAndSortedMissions[index];
              final missionId = mission['id']?.toString() ?? '';
              final isActive = mission['is_active'] as bool? ?? true;
              final hasPlaceholders = _hasPlaceholders(mission);
              final isSelected = _selectedMissions.contains(missionId);
              
              // Anima��o de entrada suave
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 300 + (index * 50)),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: _MissionCard(
                  mission: mission,
                  isSelected: isSelected,
                  hasPlaceholders: hasPlaceholders,
                  placeholders: hasPlaceholders ? _getPlaceholders(mission) : [],
                  onToggleStatus: () => _toggleMissionStatus(missionId, isActive),
                  onEdit: () => _showEditMissionDialog(mission),
                  onDuplicate: () => _duplicateMission(
                    missionId,
                    mission['title']?.toString() ?? 'Miss�o sem t�tulo',
                  ),
                  onDelete: () => _deleteMission(
                    missionId,
                    mission['title']?.toString() ?? 'Miss�o sem t�tulo',
                  ),
                  onLongPress: () {
                    setState(() {
                      _isSelectionMode = true;
                      if (isSelected) {
                        _selectedMissions.remove(missionId);
                      } else {
                        _selectedMissions.add(missionId);
                      }
                    });
                  },
                  onTap: _isSelectionMode ? () {
                    setState(() {
                      if (isSelected) {
                        _selectedMissions.remove(missionId);
                        if (_selectedMissions.isEmpty) {
                          _isSelectionMode = false;
                        }
                      } else {
                        _selectedMissions.add(missionId);
                      }
                    });
                  } : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.mission,
    required this.isSelected,
    required this.hasPlaceholders,
    required this.placeholders,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onLongPress,
    this.onTap,
  });

  final Map<String, dynamic> mission;
  final bool isSelected;
  final bool hasPlaceholders;
  final List<String> placeholders;
  final VoidCallback onToggleStatus;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = mission['is_active'] as bool? ?? true;
    final type = mission['mission_type'] as String? ?? '';
    final difficulty = mission['difficulty'] as String? ?? mission['priority'] as String? ?? '';
    final xp = mission['reward_points'] ?? mission['xp_reward'] ?? 0;
    final duration = mission['duration_days'] ?? 0;

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (hasPlaceholders
                    ? Colors.orange
                    : (isActive 
                        ? AppColors.primary.withOpacity(0.3)
                        : Colors.grey[800]!)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected || hasPlaceholders ? [
            BoxShadow(
              color: (isSelected ? AppColors.primary : Colors.orange).withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ] : (isActive ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null),
        ),
        child: Card(
          margin: EdgeInsets.zero,
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          child: Opacity(
            opacity: isActive ? 1.0 : 0.5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Alerta de placeholders
                if (hasPlaceholders) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Placeholders n�o substitu�dos: ${placeholders.join(", ")}',
                            style: const TextStyle(color: Colors.orange, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    // Checkbox de sele��o
                    if (isSelected || onTap != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Checkbox(
                          value: isSelected,
                          onChanged: onTap != null ? (_) => onTap!() : null,
                          activeColor: AppColors.primary,
                          checkColor: Colors.white,
                          side: BorderSide(color: Colors.grey[600]!),
                        ),
                      ),
                    // �cone de status
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isActive 
                            ? AppColors.primary.withOpacity(0.2)
                            : Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isActive ? Icons.check_circle : Icons.pause_circle,
                        color: isActive ? AppColors.primary : Colors.grey[600],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mission['title'] as String? ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isActive ? 'Ativa' : 'Pausada',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive 
                                  ? AppColors.primary
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bot�o de editar
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      tooltip: 'Editar miss�o',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: isActive,
                      onChanged: (_) => onToggleStatus(),
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withOpacity(0.3),
                      inactiveThumbColor: Colors.grey[600],
                      inactiveTrackColor: Colors.grey[800],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  mission['description'] as String? ?? '',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.category,
                      label: _getTypeLabel(type),
                      color: _getTypeColor(type),
                    ),
                    _InfoChip(
                      icon: Icons.signal_cellular_alt,
                      label: _getDifficultyLabel(difficulty),
                      color: _getDifficultyColor(difficulty),
                    ),
                    _InfoChip(
                      icon: Icons.star,
                      label: '$xp XP',
                      color: Colors.amber,
                    ),
                    if (duration != null && duration > 0)
                      _InfoChip(
                        icon: Icons.calendar_today,
                        label: '$duration dias',
                        color: Colors.blue,
                      ),
                  ],
                ),
                if (mission['target_tps'] != null ||
                    mission['target_rdr'] != null ||
                    mission['min_ili'] != null) ...[
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey[800]),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (mission['target_tps'] != null)
                        _MetricChip(
                          label: 'TPS: ${mission['target_tps']}%',
                          color: Colors.green,
                        ),
                      if (mission['target_rdr'] != null)
                        _MetricChip(
                          label: 'RDR: ${mission['target_rdr']}%',
                          color: Colors.orange,
                        ),
                      if (mission['min_ili'] != null)
                        _MetricChip(
                          label: 'ILI: ${mission['min_ili']} meses',
                          color: Colors.purple,
                        ),
                    ],
                  ),
                ],
                // Bot�es de a��o
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Bot�o de duplicar
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDuplicate,
                        icon: const Icon(Icons.content_copy, size: 18),
                        label: const Text('Duplicar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bot�o de excluir
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Excluir'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.alert,
                          side: BorderSide(color: AppColors.alert.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'SAVINGS':
        return 'Economia';
      case 'EXPENSE_CONTROL':
        return 'Controle';
      case 'DEBT_REDUCTION':
        return 'D�vidas';
      case 'ONBOARDING':
        return 'Onboarding';
      default:
        return type;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'SAVINGS':
        return Colors.green;
      case 'EXPENSE_CONTROL':
        return Colors.blue;
      case 'DEBT_REDUCTION':
        return Colors.orange;
      case 'ONBOARDING':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getDifficultyLabel(String difficulty) {
    switch (difficulty) {
      case 'EASY':
        return 'F�cil';
      case 'MEDIUM':
        return 'M�dia';
      case 'HARD':
        return 'Dif�cil';
      default:
        return difficulty;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'EASY':
        return Colors.green;
      case 'MEDIUM':
        return Colors.orange;
      case 'HARD':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

