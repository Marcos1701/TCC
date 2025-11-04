import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/goal.dart';
import '../../../../core/models/transaction.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

/// Página de detalhes de uma meta
class GoalDetailsPage extends StatefulWidget {
  final GoalModel goal;
  final NumberFormat currency;

  const GoalDetailsPage({
    super.key,
    required this.goal,
    required this.currency,
  });

  @override
  State<GoalDetailsPage> createState() => _GoalDetailsPageState();
}

class _GoalDetailsPageState extends State<GoalDetailsPage> {
  final _repository = FinanceRepository();
  List<TransactionModel>? _transactions;
  Map<String, dynamic>? _insights;
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
      final results = await Future.wait([
        _repository.fetchGoalTransactions(widget.goal.id),
        _repository.fetchGoalInsights(widget.goal.id),
      ]);

      setState(() {
        _transactions = results[0] as List<TransactionModel>;
        _insights = results[1] as Map<String, dynamic>;
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
                        if (_insights != null && _insights!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildInsightsCard(theme, tokens),
                        ],
                        if (_transactions != null && _transactions!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildTransactionsSection(theme, tokens),
                        ],
                        const SizedBox(height: 80), // Espaço para o botão flutuante
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context, true),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.edit),
        label: const Text('Editar Meta'),
      ),
    );
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

  Widget _buildInsightsCard(ThemeData theme, AppDecorations tokens) {
    final status = _insights!['status'] as String? ?? '';
    final suggestions = _insights!['suggestions'] as List<dynamic>? ?? [];

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
              Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Insights',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              status,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[300],
              ),
            ),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...suggestions.map((suggestion) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.arrow_right, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          suggestion.toString(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
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
    final isIncome = transaction.type == 'income';
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
