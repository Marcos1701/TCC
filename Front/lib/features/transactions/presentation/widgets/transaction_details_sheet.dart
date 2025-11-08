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
          await widget.repository.fetchTransactionDetails(widget.transaction.identifier);  // Usar identifier

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
      await widget.repository.deleteTransaction(widget.transaction.identifier);  // Usar identifier
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
  
  /// Parse a cor da categoria do formato HEX (#RRGGBB)
  Color? _parseCategoryColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) return null;
    try {
      final hexColor = colorString.replaceAll('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      }
    } catch (e) {
      // Retorna null se falhar ao parsear
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    final typeColor = _getTypeColor(widget.transaction.type);
    
    // Parsear cor da categoria
    final categoryColor = _parseCategoryColor(widget.transaction.category?.color);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black,
            const Color(0xFF0A0A0A),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabeçalho aprimorado
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    typeColor.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: typeColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Ícone grande com categoria
                      Stack(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  typeColor.withOpacity(0.3),
                                  typeColor.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: typeColor.withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              _getTypeIcon(widget.transaction.type),
                              color: typeColor,
                              size: 32,
                            ),
                          ),
                          // Badge de categoria
                          if (categoryColor != null)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: categoryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: categoryColor.withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badge do tipo
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: typeColor.withOpacity(0.4),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _getTypeLabel(widget.transaction.type).toUpperCase(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: typeColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.transaction.description,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

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
    final categoryColor = _parseCategoryColor(widget.transaction.category?.color);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            typeColor.withOpacity(0.15),
            typeColor.withOpacity(0.05),
          ],
        ),
        borderRadius: tokens.cardRadius,
        border: Border.all(
          color: typeColor.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: typeColor.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.attach_money_rounded,
                color: typeColor.withOpacity(0.7),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'VALOR DA TRANSAÇÃO',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: typeColor.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currency.format(widget.transaction.amount),
            style: theme.textTheme.displaySmall?.copyWith(
              color: typeColor,
              fontWeight: FontWeight.w900,
              fontSize: 42,
              letterSpacing: -1,
              shadows: [
                Shadow(
                  color: typeColor.withOpacity(0.3),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          // Indicador de categoria (se disponível)
          if (categoryColor != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: categoryColor.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.transaction.category?.name ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: categoryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
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

  Widget _buildInfoSection(ThemeData theme, AppDecorations tokens) {
    final categoryColor = _parseCategoryColor(widget.transaction.category?.color);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: tokens.cardRadius,
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header da seção
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(tokens.cardRadius.topLeft.x),
                topRight: Radius.circular(tokens.cardRadius.topRight.x),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Informações Detalhadas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // Conteúdo
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(
                  theme,
                  'Data da Transação',
                  DateFormat('EEEE, dd/MM/yyyy', 'pt_BR')
                      .format(widget.transaction.date),
                  Icons.calendar_month_rounded,
                  AppColors.primary,
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  theme,
                  'Categoria',
                  widget.transaction.category?.name ?? 'Sem categoria',
                  Icons.label_rounded,
                  categoryColor ?? Colors.grey,
                  categoryColor: categoryColor,
                ),
                if (widget.transaction.category?.group != null) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    theme,
                    'Grupo Financeiro',
                    CategoryGroupMetadata
                            .labels[widget.transaction.category!.group!] ??
                        widget.transaction.category!.group!,
                    Icons.folder_rounded,
                    AppColors.highlight,
                  ),
                ],
                if (_details?['days_since_created'] != null) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    theme,
                    'Registrado há',
                    '${_details!['days_since_created']} dias',
                    Icons.access_time_rounded,
                    Colors.grey,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color iconColor, {
    Color? categoryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  iconColor.withOpacity(0.2),
                  iconColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (categoryColor != null) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: categoryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurrenceSection(ThemeData theme, AppDecorations tokens) {
    final recurrenceLabel = widget.transaction.recurrenceLabel ?? '';
    final endDate = widget.transaction.recurrenceEndDate;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: tokens.cardRadius,
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com ícone animado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(tokens.cardRadius.topLeft.x),
                topRight: Radius.circular(tokens.cardRadius.topRight.x),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.repeat_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRANSAÇÃO RECORRENTE',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary.withOpacity(0.8),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recurrenceLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.autorenew_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ATIVA',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Informação de término
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    endDate != null
                        ? Icons.event_available_rounded
                        : Icons.all_inclusive_rounded,
                    color: AppColors.primary.withOpacity(0.7),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          endDate != null ? 'Data de Término' : 'Duração',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          endDate != null
                              ? DateFormat('dd/MM/yyyy').format(endDate)
                              : 'Sem data de término',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: endDate != null
                                ? AppColors.primary
                                : Colors.grey[400],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactSection(ThemeData theme, AppDecorations tokens) {
    final impact = _details!['estimated_impact'] as Map<String, dynamic>;
    final tpsImpact = impact['tps_impact'] as num;
    final rdrImpact = impact['rdr_impact'] as num;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.highlight.withOpacity(0.15),
            AppColors.highlight.withOpacity(0.05),
          ],
        ),
        borderRadius: tokens.cardRadius,
        border: Border.all(
          color: AppColors.highlight.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.highlight.withOpacity(0.15),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(tokens.cardRadius.topLeft.x),
                topRight: Radius.circular(tokens.cardRadius.topRight.x),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.highlight.withOpacity(0.3),
                        AppColors.highlight.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.analytics_rounded,
                    color: AppColors.highlight,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'IMPACTO NOS INDICADORES',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.highlight,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          // Conteúdo
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildImpactRow(theme, 'TPS', tpsImpact.toDouble()),
                if (rdrImpact != 0) ...[
                  const SizedBox(height: 12),
                  _buildImpactRow(theme, 'RDR', rdrImpact.toDouble()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactRow(ThemeData theme, String indicator, double impact) {
    final isPositive = impact > 0;
    final color = isPositive ? AppColors.support : AppColors.alert;
    final icon = isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    
    // Determinar explicação baseada no indicador e tipo de impacto
    final explanation = _getImpactExplanation(indicator, isPositive);
    final indicatorFullName = indicator == 'TPS' ? 'Taxa de Poupança' : 'Relação Dívida-Renda';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Indicador',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: color.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            indicator,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isPositive ? '+' : ''}${impact.toStringAsFixed(2)}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w900,
                            fontSize: 36,
                            height: 1,
                            shadows: [
                              Shadow(
                                color: color.withOpacity(0.3),
                                offset: const Offset(0, 2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 2),
                          child: Text(
                            '%',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: color.withOpacity(0.7),
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Ícone de direção
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPositive
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: color,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Explicação contextual
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: color.withOpacity(0.7),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      indicatorFullName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  explanation,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getImpactExplanation(String indicator, bool isPositive) {
    if (indicator == 'TPS') {
      if (isPositive) {
        return 'Esta transação contribuiu para aumentar sua capacidade de poupança mensal, melhorando sua saúde financeira ao destinar mais recursos para reservas.';
      } else {
        return 'Esta transação reduziu sua capacidade de poupança mensal, diminuindo o percentual da renda disponível para formar reservas financeiras.';
      }
    } else { // RDR
      if (isPositive) {
        return 'Esta transação aumentou o comprometimento da sua renda com dívidas e parcelas. Valores altos podem indicar sobrecarga financeira.';
      } else {
        return 'Esta transação reduziu o comprometimento da sua renda com dívidas, melhorando sua capacidade de assumir novos compromissos financeiros.';
      }
    }
  }

  Widget _buildStatsSection(ThemeData theme, AppDecorations tokens) {
    final stats = _details!['related_stats'] as Map<String, dynamic>;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.12),
            AppColors.primary.withOpacity(0.04),
          ],
        ),
        borderRadius: tokens.cardRadius,
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(tokens.cardRadius.topLeft.x),
                topRight: Radius.circular(tokens.cardRadius.topRight.x),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.25),
                        AppColors.primary.withOpacity(0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'ESTATÍSTICAS RELACIONADAS',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          // Conteúdo
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (stats['category_stats'] != null) ...[
                  _buildStatBox(
                    theme,
                    'Mesma Categoria',
                    stats['category_stats'] as Map<String, dynamic>,
                    Icons.category_rounded,
                    AppColors.highlight,
                  ),
                  const SizedBox(height: 12),
                ],
                if (stats['type_stats'] != null)
                  _buildStatBox(
                    theme,
                    'Mesmo Tipo',
                    stats['type_stats'] as Map<String, dynamic>,
                    Icons.swap_vert_rounded,
                    AppColors.primary,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(
    ThemeData theme,
    String title,
    Map<String, dynamic> stat,
    IconData icon,
    Color color,
  ) {
    final count = stat['count'] as int;
    final total = stat['total'] as num?;
    final avg = stat['avg'] as num?;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.12),
            color.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Stats
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Quantidade
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: color.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.numbers_rounded,
                          color: color.withOpacity(0.7),
                          size: 18,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          count.toString(),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Transações',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Total
                if (total != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: color.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            color: color.withOpacity(0.7),
                            size: 18,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'R\$ ${total.toStringAsFixed(0)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                // Média
                if (avg != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: color.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.show_chart_rounded,
                            color: color.withOpacity(0.7),
                            size: 18,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'R\$ ${avg.toStringAsFixed(0)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Média',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(ThemeData theme) {
    return Column(
      children: [
        // Botão de Editar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _editTransaction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
              shadowColor: AppColors.primary.withOpacity(0.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Editar Transação',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Botão de Excluir
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _deleteTransaction,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.alert,
              side: BorderSide(
                color: AppColors.alert.withOpacity(0.5),
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: AppColors.alert.withOpacity(0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.alert.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.delete_rounded,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Excluir Transação',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
