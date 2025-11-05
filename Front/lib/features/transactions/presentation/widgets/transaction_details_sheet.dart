import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/category_groups.dart';
import '../../../../core/models/transaction.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import 'edit_transaction_sheet.dart';

/// Sheet que exibe detalhes completos de uma transação
class TransactionDetailsSheet extends StatefulWidget {
  const TransactionDetailsSheet({
    super.key,
    required this.transaction,
    required this.repository,
    required this.onUpdate,
  });

  final TransactionModel transaction;
  final FinanceRepository repository;
  final VoidCallback onUpdate;

  @override
  State<TransactionDetailsSheet> createState() =>
      _TransactionDetailsSheetState();
}

class _TransactionDetailsSheetState extends State<TransactionDetailsSheet> {
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _cacheManager = CacheManager();
  Map<String, dynamic>? _details;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final details =
          await widget.repository.fetchTransactionDetails(widget.transaction.id);

      if (!mounted) return;
      setState(() {
        _details = details;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar detalhes';
        _loading = false;
      });
    }
  }

  Future<void> _editTransaction() async {
    final updated = await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => EditTransactionSheet(
        transaction: widget.transaction,
        repository: widget.repository,
      ),
    );

    if (updated == true) {
      // Invalida cache após editar transação
      _cacheManager.invalidateAfterTransaction(action: 'transaction edited');
      
      widget.onUpdate();
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _deleteTransaction() async {
    final confirm = await FeedbackService.showConfirmationDialog(
      context: context,
      title: 'Excluir transação',
      message: 'Tem certeza que deseja excluir "${widget.transaction.description}"?',
      confirmText: 'Excluir',
      isDangerous: true,
    );

    if (!confirm) return;

    try {
      await widget.repository.deleteTransaction(widget.transaction.id);
      if (!mounted) return;

      // Invalida cache após deletar transação
      _cacheManager.invalidateAfterTransaction(action: 'transaction deleted');

      widget.onUpdate();
      Navigator.pop(context, true);

      FeedbackService.showSuccess(
        context,
        'Transação removida com sucesso!',
      );
    } catch (e) {
      if (!mounted) return;
      FeedbackService.showError(
        context,
        'Erro ao remover transação. Tente novamente.',
      );
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'INCOME':
        return AppColors.support;
      case 'EXPENSE':
        return AppColors.alert;
      case 'DEBT_PAYMENT':
        return AppColors.highlight;
      default:
        return AppColors.primary;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'INCOME':
        return Icons.arrow_upward_rounded;
      case 'EXPENSE':
        return Icons.arrow_downward_rounded;
      case 'DEBT_PAYMENT':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'INCOME':
        return 'Receita';
      case 'EXPENSE':
        return 'Despesa';
      case 'DEBT_PAYMENT':
        return 'Pagamento de Despesa';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    final typeColor = _getTypeColor(widget.transaction.type);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _getTypeIcon(widget.transaction.type),
                      color: typeColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.transaction.description,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTypeLabel(widget.transaction.type),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2A2A2A), height: 1),

            // Conteúdo
            Flexible(
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey[400]),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                  onPressed: _loadDetails,
                                  child: const Text('Tentar novamente'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildValueSection(theme, typeColor, tokens),
                              const SizedBox(height: 24),
                              _buildInfoSection(theme, tokens),
                              if (widget.transaction.isRecurring) ...[
                                const SizedBox(height: 24),
                                _buildRecurrenceSection(theme, tokens),
                              ],
                              if (_details != null &&
                                  _details!['estimated_impact'] != null) ...[
                                const SizedBox(height: 24),
                                _buildImpactSection(theme, tokens),
                              ],
                              if (_details != null &&
                                  _details!['related_stats'] != null) ...[
                                const SizedBox(height: 24),
                                _buildStatsSection(theme, tokens),
                              ],
                              const SizedBox(height: 24),
                              _buildActionsSection(theme),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueSection(
      ThemeData theme, Color typeColor, AppDecorations tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        border: Border.all(color: typeColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Text(
            'Valor',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currency.format(widget.transaction.amount),
            style: theme.textTheme.displaySmall?.copyWith(
              color: typeColor,
              fontWeight: FontWeight.w800,
              fontSize: 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(ThemeData theme, AppDecorations tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
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
          _buildInfoRow(
            theme,
            'Data',
            DateFormat('dd/MM/yyyy', 'pt_BR')
                .format(widget.transaction.date),
            Icons.calendar_today_outlined,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            theme,
            'Categoria',
            widget.transaction.category?.name ?? 'Sem categoria',
            Icons.category_outlined,
          ),
          if (widget.transaction.category?.group != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              theme,
              'Grupo',
              CategoryGroupMetadata
                      .labels[widget.transaction.category!.group!] ??
                  widget.transaction.category!.group!,
              Icons.folder_outlined,
            ),
          ],
          if (_details?['days_since_created'] != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              theme,
              'Registrado há',
              '${_details!['days_since_created']} dias',
              Icons.history_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      ThemeData theme, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
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
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecurrenceSection(ThemeData theme, AppDecorations tokens) {
    final recurrenceLabel = widget.transaction.recurrenceLabel ?? '';
    final endDate = widget.transaction.recurrenceEndDate;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.repeat_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Transação Recorrente',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            recurrenceLabel,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (endDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Término em ${DateFormat('dd/MM/yyyy').format(endDate)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[400],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Sem data de término',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[400],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImpactSection(ThemeData theme, AppDecorations tokens) {
    final impact = _details!['estimated_impact'] as Map<String, dynamic>;
    final tpsImpact = impact['tps_impact'] as num;
    final rdrImpact = impact['rdr_impact'] as num;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Impacto Estimado nos Indicadores',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _buildImpactRow(theme, 'TPS', tpsImpact.toDouble()),
          if (rdrImpact != 0) ...[
            const SizedBox(height: 12),
            _buildImpactRow(theme, 'RDR', rdrImpact.toDouble()),
          ],
        ],
      ),
    );
  }

  Widget _buildImpactRow(ThemeData theme, String indicator, double impact) {
    final isPositive = impact > 0;
    final color = isPositive ? AppColors.support : AppColors.alert;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                indicator,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[400],
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${isPositive ? '+' : ''}${impact.toStringAsFixed(2)}%',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(ThemeData theme, AppDecorations tokens) {
    final stats = _details!['related_stats'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estatísticas Relacionadas',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (stats['category_stats'] != null) ...[
            _buildStatBox(
              theme,
              'Mesma Categoria',
              stats['category_stats'] as Map<String, dynamic>,
            ),
            const SizedBox(height: 12),
          ],
          if (stats['type_stats'] != null)
            _buildStatBox(
              theme,
              'Mesmo Tipo',
              stats['type_stats'] as Map<String, dynamic>,
            ),
        ],
      ),
    );
  }

  Widget _buildStatBox(
      ThemeData theme, String title, Map<String, dynamic> stat) {
    final count = stat['count'] as int;
    final total = stat['total'] as num?;
    final avg = stat['avg'] as num?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[400],
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    _currency.format(total ?? 0),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Média',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    _currency.format(avg ?? 0),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quantidade',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    '$count',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(ThemeData theme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _editTransaction,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar Transação'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _deleteTransaction,
            icon: const Icon(Icons.delete_outline, color: AppColors.alert),
            label: const Text(
              'Excluir Transação',
              style: TextStyle(color: AppColors.alert),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.alert),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
