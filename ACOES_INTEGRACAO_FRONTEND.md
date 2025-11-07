# Ações para Integração Frontend-Backend

## Objetivo

Conectar o dashboard e visualizações do frontend Flutter com os dados reais calculados pelo backend Django.

---

## 1. INTEGRAR DASHBOARD COM API

### Problema Atual

O arquivo `dashboard_page.dart` exibe valores hardcoded:

```dart
_IndicatorCard(
  title: 'Taxa de Poupança Pessoal',
  value: '18,4%',  // ❌ HARDCODED
  subtitle: 'Meta ideal: 20% - continue avançando!',
  // ...
),
```

### Solução

#### Passo 1: Criar Provider/Service para Dashboard

Criar arquivo `lib/features/dashboard/data/dashboard_service.dart`:

```dart
import 'package:dio/dio.dart';
import '../../../core/models/dashboard.dart';

class DashboardService {
  final Dio _dio;

  DashboardService(this._dio);

  Future<DashboardData> getDashboard() async {
    try {
      final response = await _dio.get('/api/dashboard/');
      return DashboardData.fromMap(response.data);
    } catch (e) {
      throw Exception('Erro ao carregar dashboard: $e');
    }
  }
}
```

#### Passo 2: Atualizar DashboardPage para Stateful

```dart
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<DashboardData> _dashboardFuture;
  final _dashboardService = DashboardService(/* inject dio */);

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _dashboardService.getDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ...
      body: FutureBuilder<DashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Text('Erro: ${snapshot.error}'),
            );
          }
          
          final data = snapshot.data!;
          return _buildDashboardContent(data);
        },
      ),
    );
  }

  Widget _buildDashboardContent(DashboardData data) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumo do Mês', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          
          // ✅ DADOS REAIS
          _IndicatorCard(
            title: 'Taxa de Poupança Pessoal',
            value: '${data.summary.tps.toStringAsFixed(1)}%',
            subtitle: _getTpsSubtitle(data.summary.tps, data.insights['tps']!),
            icon: Icons.savings_outlined,
            color: _getColorBySeverity(data.insights['tps']!.severity),
            tokens: tokens,
            theme: theme,
          ),
          const SizedBox(height: 12),
          
          _IndicatorCard(
            title: 'Razão Dívida-Renda',
            value: '${data.summary.rdr.toStringAsFixed(1)}%',
            subtitle: data.insights['rdr']!.message,
            icon: Icons.account_balance_outlined,
            color: _getColorBySeverity(data.insights['rdr']!.severity),
            tokens: tokens,
            theme: theme,
          ),
          const SizedBox(height: 12),
          
          _IndicatorCard(
            title: 'Índice de Liquidez Imediata',
            value: '${data.summary.ili.toStringAsFixed(1)} meses',
            subtitle: data.insights['ili']!.message,
            icon: Icons.shield_outlined,
            color: _getColorBySeverity(data.insights['ili']!.severity),
            tokens: tokens,
            theme: theme,
          ),
          
          const SizedBox(height: 32),
          
          // Gráficos com dados reais
          Text('Evolução dos Indicadores', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          _IndicatorsEvolutionChart(
            cashflowData: data.cashflow,
            tokens: tokens,
            theme: theme,
          ),
        ],
      ),
    );
  }

  String _getTpsSubtitle(double tps, IndicatorInsight insight) {
    return insight.message;
  }

  Color _getColorBySeverity(String severity) {
    switch (severity) {
      case 'good':
        return AppColors.support;  // Verde
      case 'attention':
        return AppColors.highlight;  // Amarelo
      case 'warning':
        return Colors.orange;
      case 'critical':
        return AppColors.error;  // Vermelho
      default:
        return AppColors.primary;
    }
  }
}
```

#### Passo 3: Atualizar Gráficos com Dados Reais

```dart
class _IndicatorsEvolutionChart extends StatelessWidget {
  const _IndicatorsEvolutionChart({
    required this.cashflowData,
    required this.tokens,
    required this.theme,
  });

  final List<CashflowPoint> cashflowData;
  final AppDecorations tokens;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
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
            'TPS e RDR',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (cashflowData.length - 1).toDouble(),
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[800]!,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: 20,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < cashflowData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              cashflowData[index].month,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Linha TPS
                  LineChartBarData(
                    isCurved: true,
                    color: AppColors.support,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    spots: cashflowData.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value.tps,
                      );
                    }).toList(),
                  ),
                  // Linha RDR
                  LineChartBarData(
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    spots: cashflowData.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value.rdr,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legenda
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('TPS', AppColors.support),
              const SizedBox(width: 24),
              _buildLegendItem('RDR', AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
```

---

## 2. POPULAR BANCO COM MISSÕES

### Script para Gerar Missões por Faixa

Criar arquivo `Api/populate_missions.py`:

```python
import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django.setup()

from finance.ai_services import batch_generate_missions_for_scenario

# Gerar missões para todos os cenários
scenarios_to_generate = [
    'BEGINNER_ONBOARDING',
    'TPS_LOW',
    'TPS_MEDIUM',
    'TPS_HIGH',
    'RDR_HIGH',
    'RDR_MEDIUM',
    'RDR_LOW',
    'ILI_LOW',
    'ILI_MEDIUM',
    'ILI_HIGH',
    'MIXED_BALANCED',
    'MIXED_RECOVERY',
    'MIXED_OPTIMIZATION',
]

print("Iniciando geração de missões...")
for scenario in scenarios_to_generate:
    print(f"\n{'='*50}")
    print(f"Gerando missões para: {scenario}")
    print(f"{'='*50}")
    
    try:
        missions = batch_generate_missions_for_scenario(
            scenario_key=scenario,
            user_tier='INTERMEDIATE'  # ou 'BEGINNER' / 'ADVANCED'
        )
        print(f"✅ {len(missions)} missões geradas com sucesso!")
        
        for mission in missions:
            print(f"  - {mission.title} ({mission.difficulty})")
    except Exception as e:
        print(f"❌ Erro: {e}")

print("\n" + "="*50)
print("Geração concluída!")
print("="*50)
```

Executar:

```bash
cd Api
python populate_missions.py
```

---

## 3. MELHORIAS VISUAIS DE FAIXAS

### Adicionar Badges de Faixa

No `DashboardPage`, adicionar indicador visual da faixa atual:

```dart
Widget _buildTierBadge(DashboardData data) {
  final tps = data.summary.tps;
  final rdr = data.summary.rdr;
  final ili = data.summary.ili;
  
  String tier;
  Color color;
  IconData icon;
  
  // Determinar tier baseado em ILI (similar à lógica do backend)
  if (ili >= 6 && tps > 25 && rdr < 20) {
    tier = 'AVANÇADO';
    color = Colors.purple;
    icon = Icons.star;
  } else if (ili >= 3 && ili < 6) {
    tier = 'INTERMEDIÁRIO';
    color = AppColors.primary;
    icon = Icons.trending_up;
  } else {
    tier = 'INICIANTE';
    color = AppColors.highlight;
    icon = Icons.rocket_launch;
  }
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color, width: 1.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          tier,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );
}
```

Usar no dashboard:

```dart
Column(
  children: [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Resumo do Mês', style: theme.textTheme.titleLarge),
        _buildTierBadge(data),
      ],
    ),
    const SizedBox(height: 16),
    // ... cards de indicadores
  ],
)
```

---

## 4. ADICIONAR REFRESH MANUAL

```dart
class _DashboardPageState extends State<DashboardPage> {
  Future<void> _refreshDashboard() async {
    setState(() {
      _dashboardFuture = _dashboardService.getDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: FutureBuilder<DashboardData>(
          // ... mesmo código
        ),
      ),
    );
  }
}
```

---

## 5. TRATAMENTO DE ERROS APRIMORADO

```dart
Widget _buildErrorState(Object error) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar dados',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshDashboard,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar Novamente'),
          ),
        ],
      ),
    ),
  );
}

// Usar no FutureBuilder
if (snapshot.hasError) {
  return _buildErrorState(snapshot.error!);
}
```

---

## 6. ADICIONAR LOADING SKELETON

Para melhor UX durante carregamento:

```dart
Widget _buildLoadingSkeleton() {
  return SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
    child: Column(
      children: [
        _buildSkeletonCard(),
        const SizedBox(height: 12),
        _buildSkeletonCard(),
        const SizedBox(height: 12),
        _buildSkeletonCard(),
      ],
    ),
  );
}

Widget _buildSkeletonCard() {
  return Container(
    height: 100,
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 20,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// Usar no FutureBuilder
if (snapshot.connectionState == ConnectionState.waiting) {
  return _buildLoadingSkeleton();
}
```

---

## 7. CHECKLIST DE IMPLEMENTAÇÃO

### Fase 1: Básico
- [ ] Criar `DashboardService` com método `getDashboard()`
- [ ] Converter `DashboardPage` para `StatefulWidget`
- [ ] Adicionar `FutureBuilder` com loading e erro
- [ ] Substituir valores hardcoded por `data.summary.tps/rdr/ili`
- [ ] Testar no emulador/dispositivo

### Fase 2: Gráficos
- [ ] Atualizar `_IndicatorsEvolutionChart` para receber `cashflowData`
- [ ] Mapear `cashflowData` para `FlSpot` no gráfico
- [ ] Adicionar legenda dinâmica
- [ ] Testar com dados reais

### Fase 3: UX
- [ ] Implementar `RefreshIndicator`
- [ ] Adicionar loading skeleton
- [ ] Melhorar tratamento de erros
- [ ] Adicionar badge de tier
- [ ] Testar pull-to-refresh

### Fase 4: Missões
- [ ] Executar script `populate_missions.py`
- [ ] Verificar no admin Django que missões foram criadas
- [ ] Testar atribuição automática
- [ ] Validar diferentes faixas de usuários

---

## 8. TESTES

### Testar Diferentes Cenários

1. **Usuário Iniciante** (TPS=5%, RDR=60%, ILI=1):
   - Deve receber missões ILI_BUILDING e RDR_REDUCTION
   - Badge: INICIANTE
   - Cores: Vermelho/Laranja (critical/warning)

2. **Usuário Intermediário** (TPS=18%, RDR=35%, ILI=4):
   - Deve receber missões TPS_IMPROVEMENT e ILI_BUILDING
   - Badge: INTERMEDIÁRIO
   - Cores: Amarelo/Verde (attention/good)

3. **Usuário Avançado** (TPS=30%, RDR=15%, ILI=8):
   - Deve receber missões ADVANCED
   - Badge: AVANÇADO
   - Cores: Verde (good)

---

## RESULTADO ESPERADO

Após implementação completa:

✅ Dashboard exibe dados reais do backend
✅ Gráficos mostram evolução temporal real
✅ Cores e mensagens refletem faixas corretas
✅ Usuário vê seu tier atual (badge)
✅ Missões adequadas são atribuídas automaticamente
✅ Sistema é educativo e motivacional
✅ Performance otimizada com cache

**Estimativa de Implementação**: 6-8 horas
