import 'package:flutter/material.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/theme/app_colors.dart';

class DevToolsPage extends StatefulWidget {
  const DevToolsPage({super.key});

  @override
  State<DevToolsPage> createState() => _DevToolsPageState();
}

class _DevToolsPageState extends State<DevToolsPage> {
  final _repository = FinanceRepository();
  bool _isLoading = false;

  Future<void> _executeAction(
    String actionName,
    Future<Map<String, dynamic>> Function() action,
  ) async {
    final confirm = await FeedbackService.showConfirmationDialog(
      context: context,
      title: actionName,
      message: 'Tem certeza que deseja executar esta ação?',
      confirmText: 'Executar',
      isDangerous: true,
    );

    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      final result = await action();
      
      if (!mounted) return;
      
      FeedbackService.showSuccess(
        context,
        result['message'] ?? 'Ação executada com sucesso',
      );
    } catch (e) {
      if (!mounted) return;
      
      FeedbackService.showError(
        context,
        'Erro: ${e.toString()}',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev Tools'),
        backgroundColor: AppColors.alert,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Colors.red.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 48),
                        const SizedBox(height: 8),
                        const Text(
                          'FERRAMENTAS DE DESENVOLVEDOR',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Estas ações são irreversíveis e devem ser usadas apenas para testes.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                _buildSection('Conta', [
                  _DevToolAction(
                    icon: Icons.refresh,
                    title: 'Resetar Conta',
                    description: 'Apaga todas as transações e reseta XP para nível 1',
                    color: AppColors.alert,
                    onTap: () => _executeAction(
                      'Resetar Conta',
                      _repository.devResetAccount,
                    ),
                  ),
                  _DevToolAction(
                    icon: Icons.auto_awesome,
                    title: 'Adicionar 1000 XP',
                    description: 'Adiciona experiência instantaneamente',
                    color: AppColors.primary,
                    onTap: () => _executeAction(
                      'Adicionar XP',
                      () => _repository.devAddXp(1000),
                    ),
                  ),
                ]),
                
                const SizedBox(height: 16),
                
                _buildSection('Missões', [
                  _DevToolAction(
                    icon: Icons.check_circle,
                    title: 'Completar Todas as Missões',
                    description: 'Marca todas as missões ativas como completas',
                    color: AppColors.support,
                    onTap: () => _executeAction(
                      'Completar Missões',
                      _repository.devCompleteMissions,
                    ),
                  ),
                ]),
                
                const SizedBox(height: 16),
                
                _buildSection('Dados', [
                  _DevToolAction(
                    icon: Icons.add,
                    title: 'Adicionar Transações de Teste',
                    description: 'Cria 10 transações aleatórias',
                    color: AppColors.highlight,
                    onTap: () => _executeAction(
                      'Adicionar Dados de Teste',
                      () => _repository.devAddTestData(10),
                    ),
                  ),
                  _DevToolAction(
                    icon: Icons.cleaning_services,
                    title: 'Limpar Cache',
                    description: 'Remove cache de indicadores e dashboard',
                    color: Colors.blue,
                    onTap: () => _executeAction(
                      'Limpar Cache',
                      _repository.devClearCache,
                    ),
                  ),
                ]),
              ],
            ),
    );
  }

  Widget _buildSection(String title, List<_DevToolAction> actions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        ...actions,
      ],
    );
  }
}

class _DevToolAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _DevToolAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
