import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

/// Página de administração para gerar missões com IA
/// 
/// Acessível apenas para usuários com is_staff ou is_superuser = true
class AdminAiMissionsPage extends StatefulWidget {
  const AdminAiMissionsPage({super.key});

  @override
  State<AdminAiMissionsPage> createState() => _AdminAiMissionsPageState();
}

class _AdminAiMissionsPageState extends State<AdminAiMissionsPage> {
  final _apiClient = ApiClient();
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _lastResult;
  String _selectedTier = 'ALL';

  final _tierOptions = {
    'ALL': 'Todas as Faixas (60 missões)',
    'BEGINNER': 'Iniciantes (20 missões)',
    'INTERMEDIATE': 'Intermediários (20 missões)',
    'ADVANCED': 'Avançados (20 missões)',
  };

  Future<void> _generateMissions() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _lastResult = null;
    });

    try {
      final body = _selectedTier == 'ALL' ? {} : {'tier': _selectedTier};

      final response = await _apiClient.client.post<Map<String, dynamic>>(
        '/api/missions/generate_ai_missions/',
        data: body,
      );

      if (response.data == null) {
        throw Exception('Resposta vazia do servidor');
      }

      setState(() {
        _lastResult = response.data!;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sucesso! ${response.data!['total_created']} missões criadas',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: AppColors.alert,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Gerar Missões com IA',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card de informações
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Geração de Missões com IA',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Este recurso usa Google Gemini 2.5 Flash para gerar '
                      'missões personalizadas por faixa de usuário.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• BEGINNER: Níveis 1-5 (hábitos básicos)\n'
                      '• INTERMEDIATE: Níveis 6-15 (otimização)\n'
                      '• ADVANCED: Níveis 16+ (metas avançadas)',
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Seleção de faixa
              const Text(
                'Faixa de Usuários',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedTier,
                dropdownColor: const Color(0xFF2A2A2A),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
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
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  prefixIcon: Icon(Icons.category, color: Colors.grey[500]),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                ),
                items: _tierOptions.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTier = value!;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Botão de geração
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _generateMissions,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Gerar Missões'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              // Resultados
              if (_lastResult != null) ...[
                const SizedBox(height: 24),
                _buildResultsCard(),
              ],

              // Erro
              if (_error != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.alert.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.alert.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.error_outline, color: AppColors.alert),
                          SizedBox(width: 8),
                          Text(
                            'Erro',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              _buildInfoCard(),
            ],
          ),
        ),
          if (_isLoading)
            Container(
              color: Colors.black87,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Gerando missões com IA...',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Isso pode levar alguns segundos',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    final results = _lastResult!['results'] as Map<String, dynamic>;
    final totalCreated = _lastResult!['total_created'] as int;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.success.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppColors.success),
              SizedBox(width: 8),
              Text(
                'Missões Geradas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Total: $totalCreated missões criadas',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Detalhes por faixa
          ...results.entries.map((entry) {
            final tier = entry.key;
            final data = entry.value as Map<String, dynamic>;
            final created = data['created'] as int;
            final missions = data['missions'] as List?;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(color: Colors.grey[700]),
                const SizedBox(height: 8),
                Text(
                  _getTierName(tier),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$created missões criadas',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                if (missions != null && missions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Exemplos:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[300],
                    ),
                  ),
                  ...missions.take(3).map((m) {
                    final mission = m as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Text(
                        '• ${mission['title']} (${mission['difficulty']}, ${mission['xp']} XP)',
                        style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      ),
                    );
                  }),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Como funciona',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoItem(
            Icons.people,
            'Faixas de Usuários',
            'Missões são geradas especificamente para cada nível de experiência',
          ),
          _buildInfoItem(
            Icons.calendar_today,
            'Contexto Sazonal',
            'Leva em conta o período do ano (Janeiro, Black Friday, etc)',
          ),
          _buildInfoItem(
            Icons.trending_up,
            'Distribuição',
            '40% EASY, 40% MEDIUM, 20% HARD',
          ),
          _buildInfoItem(
            Icons.attach_money,
            'Custo',
            'Tier gratuito do Gemini (até 1500 req/dia)',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTierName(String tier) {
    switch (tier) {
      case 'BEGINNER':
        return '👶 Iniciantes';
      case 'INTERMEDIATE':
        return '📈 Intermediários';
      case 'ADVANCED':
        return '🏆 Avançados';
      default:
        return tier;
    }
  }
}
