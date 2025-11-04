import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/goal.dart';
import '../../../../core/models/transaction.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

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
  List<TransactionModel>? _transactions;
  Map<int, CategoryStats>? _categoryStats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
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
          if (widget.goal.autoUpdate)
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
          if (widget.goal.goalType.value == 'CUSTOM') ...[
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
    final controller = TextEditingController(
      text: widget.goal.currentAmount.toStringAsFixed(2),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Editar Valor Atual',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Valor atual',
            labelStyle: TextStyle(color: Colors.grey[400]),
            prefixText: 'R\$ ',
            prefixStyle: const TextStyle(color: Colors.white),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.3),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final newAmount = double.tryParse(controller.text.replaceAll(',', '.'));
      if (newAmount != null) {
        try {
          await _repository.updateGoal(
            goalId: widget.goal.id,
            currentAmount: newAmount,
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Valor atualizado com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
            // Recarrega os dados
            _loadData();
            // Invalida cache
            CacheManager().invalidateAfterGoalUpdate();
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
    }
  }

  Widget _buildProgressCard(ThemeData theme, AppDecorations tokens) {
    final progressPercent = widget.goal.progressPercentage;
    final isCompleted = widget.goal.isCompleted;

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
                    value: widget.goal.progress,
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
                      widget.goal.goalType.icon,
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
            widget.goal.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.goal.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.goal.description,
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
                widget.currency.format(widget.goal.currentAmount),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                ' / ${widget.currency.format(widget.goal.targetAmount)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          if (widget.goal.amountRemaining > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Faltam ${widget.currency.format(widget.goal.amountRemaining)}',
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
          _buildInfoRow(Icons.category, 'Tipo', widget.goal.goalType.label, theme),
          if (widget.goal.categoryName != null)
            _buildInfoRow(Icons.label, 'Categoria', widget.goal.categoryName!, theme),
          if (widget.goal.trackedCategories.isNotEmpty)
            _buildInfoRow(
              Icons.folder_special,
              'Categorias monitoradas',
              '${widget.goal.trackedCategories.length} selecionada${widget.goal.trackedCategories.length > 1 ? "s" : ""}',
              theme,
              subtitle: widget.goal.trackedCategories.map((c) => c.name).join(', '),
              color: AppColors.primary,
            ),
          _buildInfoRow(
            Icons.sync,
            'Atualização',
            widget.goal.autoUpdate ? 'Automática' : 'Manual',
            theme,
            color: widget.goal.autoUpdate ? AppColors.support : null,
          ),
          if (widget.goal.trackingPeriod != TrackingPeriod.total)
            _buildInfoRow(Icons.calendar_today, 'Período', widget.goal.trackingPeriod.label, theme),
          if (widget.goal.deadline != null)
            _buildInfoRow(
              Icons.event,
              'Prazo',
              DateFormat('dd/MM/yyyy').format(widget.goal.deadline!),
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
            DateFormat('dd/MM/yyyy').format(widget.goal.createdAt),
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
                  color: AppColors.primary.withValues(alpha: 0.2),
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
              color: (isIncome ? AppColors.support : AppColors.alert).withValues(alpha: 0.2),
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
