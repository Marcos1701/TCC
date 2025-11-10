import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/finance_repository.dart';
import '../../features/transactions/presentation/pages/bulk_payment_page.dart';

/// Serviço para notificar o usuário sobre despesas pendentes
/// 
/// Mostra alertas no final do mês (após dia 25) se houver despesas não pagas.
/// Respeita preferências do usuário para não exibir notificações repetidas.
class DebtNotificationService {
  static const String _lastCheckKey = 'debt_notification_last_check';
  static const String _dismissedDateKey = 'debt_notification_dismissed_date';
  static const int _notificationStartDay = 25; // Mostrar do dia 25 em diante

  final FinanceRepository _repository;
  
  DebtNotificationService({FinanceRepository? repository})
      : _repository = repository ?? FinanceRepository();

  /// Verifica se deve mostrar a notificação
  Future<bool> shouldShowNotification() async {
    final now = DateTime.now();
    
    // Só mostrar depois do dia 25
    if (now.day < _notificationStartDay) {
      return false;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final dismissedDate = prefs.getString(_dismissedDateKey);
    
    // Se o usuário já dispensou a notificação este mês, não mostrar
    if (dismissedDate != null) {
      final dismissed = DateTime.tryParse(dismissedDate);
      if (dismissed != null && 
          dismissed.year == now.year && 
          dismissed.month == now.month) {
        return false;
      }
    }
    
    // Verificar se já checou hoje
    final lastCheck = prefs.getString(_lastCheckKey);
    if (lastCheck != null) {
      final last = DateTime.tryParse(lastCheck);
      if (last != null && 
          last.year == now.year && 
          last.month == now.month && 
          last.day == now.day) {
        return false; // Já checou hoje
      }
    }
    
    return true;
  }

  /// Verifica as despesas pendentes e retorna informações
  Future<Map<String, dynamic>?> checkPendingDebts() async {
    try {
      final summary = await _repository.fetchPendingSummary(sortBy: 'urgency');
      
      final debts = summary['pending_debts'] as List? ?? [];
      if (debts.isEmpty) {
        return null; // Sem pendências
      }
      
      final urgentDebts = debts.where((debt) {
        final urgency = debt['urgency'] as bool? ?? false;
        return urgency;
      }).toList();
      
      return {
        'total_pending': debts.length,
        'urgent_count': urgentDebts.length,
        'available_income': summary['available_income'] ?? 0.0,
        'coverage_percentage': summary['coverage_percentage'] ?? 0.0,
        'debts': debts,
      };
    } catch (e) {
      debugPrint('Erro ao verificar despesas pendentes: $e');
      return null;
    }
  }

  /// Marca a última checagem
  Future<void> markAsChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
  }

  /// Marca como dispensado (usuário não quer ver mais este mês)
  Future<void> markAsDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedDateKey, DateTime.now().toIso8601String());
  }

  /// Reseta as preferências (útil para testes)
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastCheckKey);
    await prefs.remove(_dismissedDateKey);
  }

  /// Mostra o diálogo de notificação
  static Future<void> showNotificationDialog(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final totalPending = data['total_pending'] as int;
    final urgentCount = data['urgent_count'] as int;
    final coveragePercentage = data['coverage_percentage'] as double;
    
    // Determinar cor e mensagem baseada na cobertura
    Color statusColor;
    String statusMessage;
    IconData statusIcon;
    
    if (coveragePercentage >= 100) {
      statusColor = Colors.green;
      statusMessage = 'Você tem receitas suficientes!';
      statusIcon = Icons.check_circle_outline;
    } else if (coveragePercentage >= 50) {
      statusColor = Colors.orange;
      statusMessage = 'Você pode pagar parcialmente';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = Colors.red;
      statusMessage = 'Receitas insuficientes';
      statusIcon = Icons.error_outline;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: urgentCount > 0 ? Colors.red : Colors.orange,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Despesas Pendentes',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mensagem principal
              Text(
                'Você tem $totalPending despesa${totalPending > 1 ? "s" : ""} pendente${totalPending > 1 ? "s" : ""} de pagamento.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              
              if (urgentCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.priority_high, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$urgentCount despesa${urgentCount > 1 ? "s" : ""} já está${urgentCount > 1 ? "ão" : ""} 80% paga${urgentCount > 1 ? "s" : ""}!',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Status da cobertura
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusMessage,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${coveragePercentage.toStringAsFixed(0)}% de cobertura',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              const Divider(color: Colors.white12),
              
              const SizedBox(height: 12),
              
              // Dica
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Use a tela de pagamento para quitar várias despesas de uma vez!',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                DebtNotificationService().markAsDismissed();
              },
              child: const Text(
                'Não mostrar mais este mês',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                DebtNotificationService().markAsChecked();
                
                // Navegar para página de pagamento
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BulkPaymentPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('Ir para Pagamento'),
            ),
          ],
        );
      },
    );
  }
}
