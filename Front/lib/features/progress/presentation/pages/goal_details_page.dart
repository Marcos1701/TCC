import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/goal.dart';
import '../../../../core/models/transaction.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/utils/currency_input_formatter.dart';

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
  final _repository = FinanceRepository();
  late GoalModel _currentGoal;
  List<TransactionModel>? _transactions;
  Map<int, CategoryStats>? _categoryStats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentGoal = widget.goal;
    _loadData();
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

      final transactions = await _repository.fetchGoalTransactions(widget.goal.id);

      // Calcular estatísticas por categoria
      final stats = <int, CategoryStats>{};
      for (final transaction in transactions) {
        if (transaction.category != null) {
          final catId = transaction.category!.id;
          if (!stats.containsKey(catId)) {
            stats[catId] = CategoryStats(
              categoryId: catId,
              categoryName: transaction.category!.name,
              categoryColor: transaction.category!.color,
              count: 0,
              totalAmount: 0,
            );
          }
          stats[catId]!.count++;
          stats[catId]!.totalAmount += transaction.amount;
        }
      }

      setState(() {
        _currentGoal = updatedGoal;
        _transactions = transactions;
        _categoryStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar dados: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshProgress() async {
    try {
      await _repository.refreshGoalProgress(widget.goal.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progresso atualizado!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Invalida cache e recarrega
        CacheManager().invalidateAfterGoalUpdate();
        Navigator.pop(context, true); // Retorna true para indicar atualização
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        actions: [
          if (_currentGoal.autoUpdate)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Atualizar progresso',
              onPressed: _refreshProgress,
            ),
        ],
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
                        _buildInfoCard(theme, tokens),
                        if (_categoryStats != null && _categoryStats!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildCategoryStatsCard(theme, tokens),
                        ],
                        if (_transactions != null && _transactions!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildTransactionsSection(theme, tokens),
                        ],
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

    final result = await showDialog<double>(
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
          goalId: widget.goal.id,
          currentAmount: result,
        );

        // Invalida cache
        CacheManager().invalidateAfterGoalUpdate();

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
          if (_currentGoal.categoryName != null)
            _buildInfoRow(Icons.label, 'Categoria', _currentGoal.categoryName!, theme),
          if (_currentGoal.trackedCategories.isNotEmpty)
            _buildInfoRow(
              Icons.folder_special,
              'Categorias monitoradas',
              '${_currentGoal.trackedCategories.length} selecionada${_currentGoal.trackedCategories.length > 1 ? "s" : ""}',
              theme,
              subtitle: _currentGoal.trackedCategories.map((c) => c.name).join(', '),
              color: AppColors.primary,
            ),
          _buildInfoRow(
            Icons.sync,
            'Atualização',
            _currentGoal.autoUpdate ? 'Automática' : 'Manual',
            theme,
            color: _currentGoal.autoUpdate ? AppColors.support : null,
          ),
          if (widget.goal.trackingPeriod != TrackingPeriod.total)
            _buildInfoRow(Icons.calendar_today, 'Período', widget.goal.trackingPeriod.label, theme),
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

  Widget _buildCategoryStatsCard(ThemeData theme, AppDecorations tokens) {
    final sortedStats = _categoryStats!.values.toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

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
          Row(
            children: [
              Icon(Icons.pie_chart, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Transações por Categoria',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sortedStats.map((stat) => _buildCategoryStatRow(stat, theme)),
        ],
      ),
    );
  }

  Widget _buildCategoryStatRow(CategoryStats stat, ThemeData theme) {
    Color categoryColor = Colors.grey;
    if (stat.categoryColor != null && stat.categoryColor!.isNotEmpty) {
      try {
        final hexColor = stat.categoryColor!.replaceAll('#', '');
        if (hexColor.length == 6) {
          categoryColor = Color(int.parse('FF$hexColor', radix: 16));
        }
      } catch (e) {
        // Mantém cor padrão se falhar
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: categoryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stat.categoryName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                widget.currency.format(stat.totalAmount),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 24),
              Icon(Icons.receipt, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                '${stat.count} transaç${stat.count == 1 ? "ão" : "ões"}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.trending_up, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                'Média: ${widget.currency.format(stat.totalAmount / stat.count)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsSection(ThemeData theme, AppDecorations tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.grey[400], size: 20),
              const SizedBox(width: 8),
              Text(
                'Transações Relacionadas',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_transactions!.length}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        ..._transactions!.map((transaction) => _buildTransactionCard(transaction, theme, tokens)),
      ],
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction, ThemeData theme, AppDecorations tokens) {
    final isIncome = transaction.type.toUpperCase() == 'INCOME';
    final amount = transaction.amount;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isIncome ? AppColors.support : AppColors.alert).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? AppColors.support : AppColors.alert,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM/yyyy').format(transaction.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'} ${widget.currency.format(amount)}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isIncome ? AppColors.support : AppColors.alert,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
