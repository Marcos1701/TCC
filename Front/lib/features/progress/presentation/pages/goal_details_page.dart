import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/goal.dart';
import '../../../../core/repositories/goal_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/utils/currency_input_formatter.dart';
import '../../data/goals_viewmodel.dart';

/// Classe para armazenar estatísticas por categoria
class CategoryStats {
  final int categoryId;
  final String categoryName;
  final String? categoryColor;
  int count;
  double totalAmount;

  CategoryStats({
    required this.categoryId,
    required this.categoryName,
    this.categoryColor,
    required this.count,
    required this.totalAmount,
  });
}

/// Página de detalhes de uma meta
class GoalDetailsPage extends StatefulWidget {
  final GoalModel goal;
  final NumberFormat currency;
  final VoidCallback? onEdit;

  const GoalDetailsPage({
    super.key,
    required this.goal,
    required this.currency,
    this.onEdit,
  });

  @override
  State<GoalDetailsPage> createState() => _GoalDetailsPageState();
}

class _GoalDetailsPageState extends State<GoalDetailsPage> {
  final _repository = GoalRepository();
  late final GoalsViewModel _viewModel;
  late GoalModel _currentGoal;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentGoal = widget.goal;
    _viewModel = GoalsViewModel(repository: _repository);
    _loadData();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Busca a meta atualizada
      final goals = await _repository.fetchGoals();
      final updatedGoal = goals.firstWhere(
        (g) => g.id == widget.goal.id,
        orElse: () => widget.goal,
      );

      setState(() {
        _currentGoal = updatedGoal;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar dados: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detalhes da Meta',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProgressCard(theme, tokens),
                        const SizedBox(height: 20),
                        // Informações sobre monitoramento de categorias por tipo
                        _buildGoalTypeInfoCard(theme, tokens),
                        const SizedBox(height: 20),
                        _buildInfoCard(theme, tokens),
                        const SizedBox(height: 80), // Espaço para os botões flutuantes
                      ],
                    ),
                  ),
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botão Editar Valor Atual (só para metas personalizadas)
          if (_currentGoal.goalType.value == 'CUSTOM') ...[
            FloatingActionButton(
              heroTag: 'edit_current',
              onPressed: _showEditCurrentAmountDialog,
              backgroundColor: AppColors.support,
              child: const Icon(Icons.edit_note),
            ),
            const SizedBox(height: 12),
          ],
          // Botão Editar Meta
          FloatingActionButton.extended(
            heroTag: 'edit_goal',
            onPressed: () {
              if (widget.onEdit != null) {
                Navigator.pop(context);
                widget.onEdit!();
              }
            },
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.edit),
            label: const Text('Editar Meta'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditCurrentAmountDialog() async {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final controller = TextEditingController(
      text: CurrencyInputFormatter.format(_currentGoal.currentAmount),
    );

    // Seleciona todo o texto ao abrir
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    double? result;
    try {
      result = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Editar Valor Atual',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meta: ${_currentGoal.title}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Objetivo: ${currencyFormat.format(_currentGoal.targetAmount)}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyInputFormatter(maxDigits: 12),
                  ],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Valor atual',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    prefixText: 'R\$ ',
                    prefixStyle: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    helperText: 'Digite o valor atual da meta',
                    helperStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ],
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
                onPressed: () {
                  final value = CurrencyInputFormatter.parse(controller.text);
                  if (value > 0) {
                    Navigator.pop(context, value);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Por favor, insira um valor válido maior que zero'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Salvar',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && mounted) {
      try {
        // Mostra loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        await _repository.updateGoal(
          goalId: widget.goal.identifier,  // Usar identifier
          currentAmount: result,
        );

        if (mounted) {
          // Remove loading
          Navigator.pop(context);
          
          // Mostra sucesso
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Valor atualizado para ${currencyFormat.format(result)}!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          // Recarrega os dados da meta atualizada
          await _loadData();
        }
      } catch (e) {
        if (mounted) {
          // Remove loading se ainda estiver aberto
          Navigator.pop(context);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Erro ao atualizar: $e'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
    } finally {
      controller.dispose();
    }
  }

  Widget _buildProgressCard(ThemeData theme, AppDecorations tokens) {
    final progressPercent = _currentGoal.progressPercentage;
    final isCompleted = _currentGoal.isCompleted;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
      ),
      child: Column(
        children: [
          // Gráfico circular de progresso
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: _currentGoal.progress,
                    strokeWidth: 16,
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor: AlwaysStoppedAnimation(
                      isCompleted ? AppColors.support : AppColors.primary,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentGoal.goalType.icon,
                      style: const TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${progressPercent.toStringAsFixed(1)}%',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _currentGoal.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_currentGoal.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _currentGoal.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[400],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.currency.format(_currentGoal.currentAmount),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                ' / ${widget.currency.format(_currentGoal.targetAmount)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          if (_currentGoal.amountRemaining > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Faltam ${widget.currency.format(_currentGoal.amountRemaining)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalTypeInfoCard(ThemeData theme, AppDecorations tokens) {
    // Definir cor e ícone baseado no tipo
    Color typeColor;
    IconData typeIcon;
    String typeTitle;
    String trackingDescription;
    
    switch (_currentGoal.goalType) {
      case GoalType.savings:
        typeColor = Colors.green;
        typeIcon = Icons.savings;
        typeTitle = 'Meta de Poupança';
        trackingDescription = 'Monitora transações em categorias de Poupança e Investimentos';
        break;
      case GoalType.emergencyFund:
        typeColor = Colors.purple;
        typeIcon = Icons.shield;
        typeTitle = 'Fundo de Emergência';
        trackingDescription = 'Monitora transações em categorias de Poupança e Investimentos';
        break;
      case GoalType.expenseReduction:
        typeColor = Colors.orange;
        typeIcon = Icons.trending_down;
        typeTitle = 'Meta de Redução de Gastos';
        trackingDescription = 'Monitora gastos na categoria específica selecionada';
        break;
      case GoalType.incomeIncrease:
        typeColor = Colors.blue;
        typeIcon = Icons.trending_up;
        typeTitle = 'Meta de Aumento de Receita';
        trackingDescription = 'Monitora todas as suas transações de receita';
        break;
      case GoalType.custom:
        typeColor = Colors.grey;
        typeIcon = Icons.edit;
        typeTitle = 'Meta Personalizada';
        trackingDescription = 'Atualização manual - você controla o progresso';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
        border: Border.all(
          color: typeColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(typeIcon, color: typeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  typeTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Card informativo sobre monitoramento
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: typeColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_graph, size: 16, color: typeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trackingDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: typeColor.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Informações específicas por tipo
          if (_currentGoal.goalType == GoalType.expenseReduction) ...[
            const SizedBox(height: 16),
            if (_currentGoal.targetCategoryName != null)
              _buildTypeInfoRow(
                Icons.category,
                'Categoria Alvo',
                _currentGoal.targetCategoryName!,
                theme,
              ),
            if (_currentGoal.baselineAmount != null)
              _buildTypeInfoRow(
                Icons.attach_money,
                'Gasto Médio Inicial',
                '${widget.currency.format(_currentGoal.baselineAmount)}/mês',
                theme,
              ),
            _buildTypeInfoRow(
              Icons.emoji_events,
              'Meta de Redução',
              widget.currency.format(_currentGoal.targetAmount),
              theme,
            ),
            _buildTypeInfoRow(
              Icons.check_circle,
              'Redução Alcançada',
              widget.currency.format(_currentGoal.currentAmount),
              theme,
              color: AppColors.support,
            ),
            _buildTypeInfoRow(
              Icons.date_range,
              'Período de Cálculo',
              '${_currentGoal.trackingPeriodMonths} meses',
              theme,
            ),
          ] else if (_currentGoal.goalType == GoalType.incomeIncrease) ...[
            const SizedBox(height: 16),
            if (_currentGoal.baselineAmount != null)
              _buildTypeInfoRow(
                Icons.attach_money,
                'Receita Média Inicial',
                '${widget.currency.format(_currentGoal.baselineAmount)}/mês',
                theme,
              ),
            _buildTypeInfoRow(
              Icons.emoji_events,
              'Meta de Aumento',
              widget.currency.format(_currentGoal.targetAmount),
              theme,
            ),
            _buildTypeInfoRow(
              Icons.check_circle,
              'Aumento Alcançado',
              widget.currency.format(_currentGoal.currentAmount),
              theme,
              color: AppColors.support,
            ),
            _buildTypeInfoRow(
              Icons.date_range,
              'Período de Cálculo',
              '${_currentGoal.trackingPeriodMonths} meses',
              theme,
            ),
          ] else if (_currentGoal.goalType == GoalType.savings || 
                     _currentGoal.goalType == GoalType.emergencyFund) ...[
            const SizedBox(height: 16),
            _buildTypeInfoRow(
              Icons.category,
              'Categorias Monitoradas',
              'Poupança, Investimentos',
              theme,
            ),
            if (_currentGoal.initialAmount > 0)
              _buildTypeInfoRow(
                Icons.start,
                'Valor Inicial',
                widget.currency.format(_currentGoal.initialAmount),
                theme,
              ),
          ] else if (_currentGoal.goalType == GoalType.custom) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade800.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Use o botão de edição para atualizar o progresso manualmente',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeInfoRow(
    IconData icon,
    String label,
    String value,
    ThemeData theme, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color ?? Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, AppDecorations tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informações',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.category, 'Tipo', _currentGoal.goalType.label, theme),
          if (_currentGoal.deadline != null)
            _buildInfoRow(
              Icons.event,
              'Prazo',
              DateFormat('dd/MM/yyyy').format(_currentGoal.deadline!),
              theme,
              subtitle: widget.goal.isExpired
                  ? 'Expirado'
                  : widget.goal.daysRemaining != null
                      ? '${widget.goal.daysRemaining} dias restantes'
                      : null,
              color: widget.goal.isExpired ? AppColors.alert : null,
            ),
          _buildInfoRow(
            Icons.calendar_month,
            'Criada em',
            DateFormat('dd/MM/yyyy').format(_currentGoal.createdAt),
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    ThemeData theme, {
    String? subtitle,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color ?? Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color ?? Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
