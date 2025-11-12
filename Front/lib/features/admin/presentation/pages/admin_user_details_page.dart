import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/admin_user_service.dart';

/// Página de detalhes e ações administrativas de um usuário
/// 
/// Exibe:
/// - Dados básicos e perfil
/// - Estatísticas (TPS, RDR, ILI)
/// - Transações recentes
/// - Missões ativas
/// - Histórico de ações admin
/// 
/// Permite:
/// - Desativar/Reativar usuário
/// - Ajustar XP
class AdminUserDetailsPage extends StatefulWidget {
  final int userId;

  const AdminUserDetailsPage({
    super.key,
    required this.userId,
  });

  @override
  State<AdminUserDetailsPage> createState() => _AdminUserDetailsPageState();
}

class _AdminUserDetailsPageState extends State<AdminUserDetailsPage> {
  final _service = AdminUserService();

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _userDetails;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final details = await _service.getUserDetails(widget.userId);
      setState(() {
        _userDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deactivateUser() async {
    final reason = await _showReasonDialog(
      context,
      title: 'Desativar Usuário',
      message: 'Informe o motivo da desativação (será registrado no histórico):',
    );

    if (reason == null || reason.isEmpty) return;

    try {
      await _service.deactivateUser(
        userId: widget.userId,
        reason: reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário desativado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUserDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reactivateUser() async {
    final reason = await _showReasonDialog(
      context,
      title: 'Reativar Usuário',
      message: 'Informe o motivo da reativação (será registrado no histórico):',
    );

    if (reason == null || reason.isEmpty) return;

    try {
      await _service.reactivateUser(
        userId: widget.userId,
        reason: reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário reativado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUserDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _adjustXp() async {
    final result = await _showXpAdjustmentDialog(context);
    if (result == null) return;

    final amount = result['amount'] as int;
    final reason = result['reason'] as String;

    try {
      final response = await _service.adjustXp(
        userId: widget.userId,
        amount: amount,
        reason: reason,
      );

      if (mounted) {
        final adjustment = response['adjustment'] as Map<String, dynamic>;
        final levelChanged = adjustment['level_changed'] as bool;
        
        String message = 'XP ajustado com sucesso!';
        if (levelChanged) {
          message += '\nNível: ${adjustment['old_level']} → ${adjustment['new_level']}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        _loadUserDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Detalhes do Usuário',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserDetails,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_userDetails == null) return const SizedBox.shrink();

    final isActive = _userDetails!['is_active'] as bool;

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          _buildActions(isActive),
          const SizedBox(height: 8),
          _buildProfile(),
          const SizedBox(height: 8),
          _buildStatistics(),
          const SizedBox(height: 8),
          _buildRecentTransactions(),
          const SizedBox(height: 8),
          _buildActiveMissions(),
          const SizedBox(height: 8),
          _buildAdminActions(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final username = _userDetails!['username'] as String;
    final email = _userDetails!['email'] as String;
    final firstName = _userDetails!['first_name'] as String? ?? '';
    final lastName = _userDetails!['last_name'] as String? ?? '';
    final isActive = _userDetails!['is_active'] as bool;
    final dateJoined = DateTime.parse(_userDetails!['date_joined'] as String);
    final lastLogin = _userDetails!['last_login'] != null
        ? DateTime.parse(_userDetails!['last_login'] as String)
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      color: AppColors.surface,
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary.withOpacity(0.2),
            child: Text(
              username.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            username,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (firstName.isNotEmpty || lastName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '$firstName $lastName'.trim(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? Colors.green : Colors.red,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.block,
                  size: 16,
                  color: isActive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  isActive ? 'CONTA ATIVA' : 'CONTA DESATIVADA',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildInfoChip(
                Icons.calendar_today,
                'Desde ${DateFormat('dd/MM/yyyy').format(dateJoined)}',
              ),
              if (lastLogin != null) ...[
                const SizedBox(width: 12),
                _buildInfoChip(
                  Icons.login,
                  'Último acesso: ${_formatDate(lastLogin)}',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool isActive) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ações Administrativas',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.stars),
                label: const Text('Ajustar XP'),
                onPressed: _adjustXp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              if (isActive)
                OutlinedButton.icon(
                  icon: const Icon(Icons.block),
                  label: const Text('Desativar'),
                  onPressed: _deactivateUser,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                )
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Reativar'),
                  onPressed: _reactivateUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    final profile = _userDetails!['profile'] as Map<String, dynamic>;
    final level = profile['level'] as int;
    final xp = profile['experience_points'] as int;
    final targetTps = profile['target_tps'] as double;
    final targetRdr = profile['target_rdr'] as double;
    final targetIli = profile['target_ili'] as double;

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Perfil e Metas',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.military_tech,
                  label: 'Nível',
                  value: level.toString(),
                  color: AppColors.highlight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.stars,
                  label: 'XP',
                  value: xp.toString(),
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Metas',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildGoalItem('TPS', targetTps),
          _buildGoalItem('RDR', targetRdr),
          _buildGoalItem('ILI (dias)', targetIli),
        ],
      ),
    );
  }

  Widget _buildGoalItem(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          Text(
            value.toStringAsFixed(1),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    final stats = _userDetails!['statistics'] as Map<String, dynamic>;
    final tps = stats['tps'] as double;
    final rdr = stats['rdr'] as double;
    final ili = stats['ili'] as double;
    final transactionCount = stats['transaction_count'] as int;

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estatísticas',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.trending_up,
                  label: 'TPS',
                  value: tps.toStringAsFixed(1),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.balance,
                  label: 'RDR',
                  value: rdr.toStringAsFixed(1),
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.calendar_today,
                  label: 'ILI',
                  value: ili.toStringAsFixed(1),
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: _buildStatCard(
              icon: Icons.receipt_long,
              label: 'Total de Transações',
              value: transactionCount.toString(),
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    final transactions = _userDetails!['recent_transactions'] as List;

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transações Recentes',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (transactions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nenhuma transação encontrada',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...transactions.take(5).map((t) => _buildTransactionItem(t)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final amount = double.parse(transaction['amount'].toString());
    final isIncome = amount > 0;
    final date = DateTime.parse(transaction['date'] as String);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isIncome ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['description'] as String,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${transaction['category']} • ${DateFormat('dd/MM/yyyy').format(date)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'R\$ ${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: isIncome ? Colors.green : Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMissions() {
    final missions = _userDetails!['active_missions'] as List;

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Missões Ativas',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (missions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nenhuma missão ativa',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...missions.map((m) => _buildMissionItem(m)),
        ],
      ),
    );
  }

  Widget _buildMissionItem(Map<String, dynamic> mission) {
    final progress = mission['progress_percentage'] as int;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mission['title'] as String,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  mission['status'] as String,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 8,
              backgroundColor: AppColors.background,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$progress% concluído',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActions() {
    final actions = _userDetails!['admin_actions'] as List;

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Histórico de Ações Admin',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (actions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nenhuma ação administrativa registrada',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...actions.take(10).map((a) => _buildAdminActionItem(a)),
        ],
      ),
    );
  }

  Widget _buildAdminActionItem(Map<String, dynamic> action) {
    final timestamp = DateTime.parse(action['timestamp'] as String);
    final actionType = action['action_display'] as String;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.highlight.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              size: 16,
              color: AppColors.highlight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actionType,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (action['reason'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    action['reason'] as String,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  'Por ${action['admin']} • ${_formatDate(timestamp)}',
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              onPressed: _loadUserDetails,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return DateFormat('dd/MM/yyyy').format(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d atrás';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h atrás';
    } else {
      return '${difference.inMinutes}min atrás';
    }
  }

  Future<String?> _showReasonDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Digite o motivo...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('O motivo é obrigatório')),
                );
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showXpAdjustmentDialog(
    BuildContext context,
  ) async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajustar XP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informe o valor do ajuste (-500 a +500):'),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                hintText: 'Ex: +100 ou -50',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.stars),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Motivo do ajuste:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ex: Bonus por participação em evento',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final amountText = amountController.text.trim();
              final reason = reasonController.text.trim();

              if (amountText.isEmpty || reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preencha todos os campos')),
                );
                return;
              }

              final amount = int.tryParse(amountText);
              if (amount == null || amount < -500 || amount > 500 || amount == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Valor inválido (-500 a +500, diferente de zero)')),
                );
                return;
              }

              Navigator.pop(context, {
                'amount': amount,
                'reason': reason,
              });
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
