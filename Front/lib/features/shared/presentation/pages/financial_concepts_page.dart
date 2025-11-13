import 'package:flutter/material.dart';

import '../../../../core/constants/user_friendly_strings.dart';
import '../../../../core/theme/app_colors.dart';

/// Página de ajuda e explicação de conceitos financeiros
class FinancialConceptsPage extends StatelessWidget {
  const FinancialConceptsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Guia Financeiro',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Introdução
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.2),
                  Colors.purple.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.school_outlined,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Conceitos Financeiros',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Entenda os principais conceitos da aplicação.',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Conceitos Básicos
          _buildSectionTitle(
            icon: Icons.account_balance_wallet,
            title: 'Conceitos Básicos',
            color: Colors.green,
          ),
          const SizedBox(height: 16),

          const _ConceptCard(
            icon: Icons.arrow_upward,
            iconColor: AppColors.support,
            title: UxStrings.income,
            subtitle: 'Dinheiro que entra',
            description:
                'Receita é todo dinheiro que você recebe, como salário, '
                'freelances, vendas, mesada, ou qualquer outra fonte de entrada. '
                'É importante registrar todas as suas receitas para ter uma visão '
                'clara de quanto dinheiro está entrando.',
            examples: [
              '💼 Salário do mês',
              '🎨 Trabalho freelance',
              '🏪 Venda de produtos',
              '💰 Investimentos',
              '🎁 Presentes em dinheiro',
            ],
            tips: [
              'Registre todas as receitas, até as menores',
              'Separe receitas fixas (salário) de variáveis (freelance)',
              'Acompanhe de onde vem seu dinheiro',
            ],
          ),

          const _ConceptCard(
            icon: Icons.arrow_downward,
            iconColor: AppColors.alert,
            title: UxStrings.expense,
            subtitle: 'Dinheiro que sai',
            description:
                'Despesa é todo gasto que você faz para comprar produtos, '
                'pagar contas ou serviços. Podem ser fixas (todo mês) ou '
                'variáveis (esporádicas). Controlar despesas é essencial '
                'para evitar gastar mais do que ganha.',
            examples: [
              '🏠 Aluguel e condomínio',
              '🍕 Alimentação e restaurantes',
              '🚗 Transporte e combustível',
              '📱 Internet e telefone',
              '🎮 Lazer e entretenimento',
            ],
            tips: [
              'Categorize suas despesas para identificar onde gasta mais',
              'Diferencie despesas essenciais de supérfluas',
              'Procure formas de reduzir gastos desnecessários',
            ],
          ),

          const _ConceptCard(
            icon: Icons.account_balance,
            iconColor: Colors.blue,
            title: UxStrings.balance,
            subtitle: 'Seu dinheiro disponível',
            description:
                'O saldo é a diferença entre suas receitas e despesas. '
                'Saldo positivo significa que você gastou menos do que ganhou '
                '(bom!). Saldo negativo significa que gastou mais do que ganhou '
                '(atenção!). O objetivo é sempre manter um saldo positivo.',
            formula: 'Saldo = ${UxStrings.income} - ${UxStrings.expense}',
            examples: [
              '✅ ${UxStrings.income}: R\$ 3.000, ${UxStrings.expense}: R\$ 2.500 = ${UxStrings.balance}: +R\$ 500',
              '⚠️ ${UxStrings.income}: R\$ 2.000, ${UxStrings.expense}: R\$ 2.300 = ${UxStrings.balance}: -R\$ 300',
            ],
            tips: [
              'Mantenha sempre um saldo positivo',
              'Reserve parte do saldo para emergências',
              'Acompanhe seu saldo diariamente',
            ],
          ),

          const SizedBox(height: 24),

          // Conceitos Avançados
          _buildSectionTitle(
            icon: Icons.trending_up,
            title: 'Conceitos Avançados',
            color: Colors.purple,
          ),
          const SizedBox(height: 16),

          const _ConceptCard(
            icon: Icons.swap_horiz,
            iconColor: AppColors.primary,
            title: 'Pagamentos',
            subtitle: 'Vincular receitas e despesas',
            description:
                'Pagamentos permitem vincular uma receita específica a uma '
                'ou mais despesas, mostrando para onde seu dinheiro está indo. '
                'É útil para organizar os pagamentos e ver quanto de cada receita '
                'ainda está disponível.',
            examples: [
              '💰 Vincular salário → pagamento de contas',
              '🏦 Vincular receita extra → investimento',
              '💳 Vincular freelance → compra específica',
            ],
            tips: [
              'Use Pagamentos para organizar suas finanças',
              'Vincule receitas a despesas fixas no início do mês',
              'Acompanhe quanto sobrou de cada receita',
            ],
          ),

          const _ConceptCard(
            icon: Icons.flag_outlined,
            iconColor: Colors.amber,
            title: UxStrings.goals,
            subtitle: 'Objetivos financeiros',
            description:
                'Metas ajudam você a definir objetivos financeiros e '
                'acompanhar seu progresso. Podem ser para juntar dinheiro '
                '(viagem, celular) ou reduzir gastos (delivery, roupas). '
                'Ter metas claras aumenta sua motivação.',
            examples: [
              '✈️ Juntar R\$ 5.000 para viagem',
              '📱 Economizar R\$ 2.000 para celular novo',
              '🍕 Reduzir gastos com delivery em 30%',
              '🏠 Economizar para entrada do apartamento',
            ],
            tips: [
              'Defina metas realistas e com prazo',
              'Divida metas grandes em etapas menores',
              'Comemore cada conquista!',
            ],
          ),

          const _ConceptCard(
            icon: Icons.emoji_events_outlined,
            iconColor: Colors.orange,
            title: UxStrings.challenges,
            subtitle: 'Conquiste XP e melhore seus hábitos',
            description:
                'Desafios são tarefas que te ajudam a criar bons hábitos '
                'financeiros. Complete desafios para ganhar pontos de experiência '
                '(XP), subir de nível e desbloquear conquistas. É uma forma '
                'divertida de aprender a cuidar do seu dinheiro!',
            examples: [
              '🎯 Registrar 5 transações na semana',
              '📊 Manter saldo positivo por 30 dias',
              '💪 Cumprir uma meta de economia',
              '📈 Melhorar seus indicadores',
            ],
            tips: [
              'Complete desafios para ganhar pontos extras',
              'Use dicas dos desafios para melhorar seus hábitos',
              'Acompanhe seu progresso e nível.',
            ],
          ),

          const SizedBox(height: 24),

          // Indicadores Financeiros
          _buildSectionTitle(
            icon: Icons.analytics_outlined,
            title: 'Indicadores Financeiros',
            color: Colors.cyan,
          ),
          const SizedBox(height: 16),

          const _ConceptCard(
            icon: Icons.pie_chart_outline,
            iconColor: Colors.teal,
            title: 'RDR - Receitas vs Despesas Recorrentes',
            subtitle: 'Equilíbrio financeiro',
            description:
                'O RDR mostra quanto % das suas receitas fixas está '
                'comprometido com despesas fixas. Idealmente, deve ficar '
                'entre 30-50%. Quanto menor, mais flexibilidade você tem.',
            formula: 'RDR = (Despesas Recorrentes ÷ Receitas Recorrentes) × 100',
            examples: [
              '✅ 35% - Excelente! Muita margem de manobra',
              '⚠️ 70% - Atenção! Pouca folga no orçamento',
              '❌ 90% - Crítico! Revise suas despesas fixas',
            ],
            tips: [
              'Mantenha RDR abaixo de 50%',
              'Reduza despesas fixas desnecessárias',
              'Busque aumentar receitas recorrentes',
            ],
          ),

          const _ConceptCard(
            icon: Icons.savings_outlined,
            iconColor: Colors.green,
            title: 'ILI - Índice de Liquidez Imediata',
            subtitle: 'Sua reserva de emergência',
            description:
                'O ILI mostra quantos meses você consegue se manter sem '
                'receitas usando apenas seu saldo atual. É sua rede de '
                'segurança financeira. O ideal é ter no mínimo 3 meses.',
            formula: 'ILI = Saldo Atual ÷ Média Mensal de Despesas',
            examples: [
              '✅ 6 meses - Muito bom! Reserva saudável',
              '⚠️ 2 meses - Razoável, mas pode melhorar',
              '❌ 0,5 mês - Crítico! Construa sua reserva',
            ],
            tips: [
              'Meta mínima: 3 meses de despesas',
              'Meta ideal: 6-12 meses de despesas',
              'Use para emergências, não para gastos comuns',
            ],
          ),

          const _ConceptCard(
            icon: Icons.trending_up,
            iconColor: Colors.purple,
            title: 'Taxa de Poupança',
            subtitle: 'Quanto você guarda',
            description:
                'Indica qual percentual da sua receita você consegue poupar. '
                'Quanto maior, melhor! Especialistas recomendam poupar no '
                'mínimo 10-20% da receita mensal.',
            formula: 'Taxa de Poupança = (${UxStrings.income} - ${UxStrings.expense}) ÷ ${UxStrings.income} × 100',
            examples: [
              '🌟 30% - Excelente! Você está no caminho certo',
              '👍 15% - Bom! Continue assim',
              '⚠️ 5% - Baixo, tente aumentar',
            ],
            tips: [
              'Comece guardando 10% da receita',
              'Aumente gradualmente ao longo do tempo',
              'Automatize transferências para poupança',
            ],
          ),

          const SizedBox(height: 24),

          // Dicas Finais
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.amber.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.amber, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Dicas Extras 💡',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTip('Registre TODAS as transações, até as pequenas'),
                _buildTip('Revise seus gastos semanalmente'),
                _buildTip('Defina metas realistas e alcançáveis'),
                _buildTip('Celebre suas conquistas financeiras'),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Botão de voltar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                'Entendi!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✓ ',
            style: TextStyle(color: Colors.amber, fontSize: 18),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card expansível para cada conceito
class _ConceptCard extends StatefulWidget {
  const _ConceptCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.description,
    this.formula,
    required this.examples,
    required this.tips,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String description;
  final String? formula;
  final List<String> examples;
  final List<String> tips;

  @override
  State<_ConceptCard> createState() => _ConceptCardState();
}

class _ConceptCardState extends State<_ConceptCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.iconColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.iconColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.iconColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(color: Colors.grey, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Descrição
                  Text(
                    widget.description,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),

                  // Fórmula (se houver)
                  if (widget.formula != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.iconColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calculate_outlined,
                            color: widget.iconColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.formula!,
                              style: TextStyle(
                                color: widget.iconColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Exemplos
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: widget.iconColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Exemplos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...widget.examples.map((example) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                color: widget.iconColor,
                                fontSize: 16,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                example,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),

                  // Dicas
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.tips_and_updates_outlined,
                        color: widget.iconColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Dicas',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...widget.tips.map((tip) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: widget.iconColor,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tip,
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
