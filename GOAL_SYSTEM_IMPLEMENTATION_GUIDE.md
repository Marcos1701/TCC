# 🤖 Guia de Implementação - Sistema de Metas

> **Objetivo**: Este documento fornece instruções detalhadas e precisas para que um agente de IA possa implementar todas as fases da refatoração do sistema de metas.
> 
> **Referência**: `GOAL_SYSTEM_REFACTOR.md` contém a análise completa e justificativas.

---

## 📋 Resumo Executivo

### O que será feito:
1. Consolidar 5 tipos de metas em 4 tipos (remover EMERGENCY_FUND)
2. Implementar cálculo automático de `initial_amount` baseado no mês atual
3. Corrigir signals para atualizar TODAS as metas automaticamente (exceto CUSTOM)
4. Criar endpoint para resumo mensal de transações
5. Atualizar frontend para exibir contexto ao criar metas

### Ordem de Execução:
```
FASE 1 → FASE 2 → FASE 3 → FASE 4 → FASE 5 → FASE 6 → FASE 7
```

**⚠️ IMPORTANTE**: Cada fase deve ser completada e testada antes de prosseguir para a próxima.

---

## 🔧 FASE 1: Backend - Services

### Arquivo: `Api/finance/services/goals.py`

#### Tarefa 1.1: Adicionar função `calculate_initial_amount`

**Localização**: Após os imports existentes, antes da função `update_goal_progress`

**Código a inserir**:

```python
def calculate_initial_amount(
    user,
    goal_type: str,
    category_ids: list = None
) -> Decimal:
    """
    Calcula o valor inicial da meta baseado nas transações do mês atual.
    
    Args:
        user: Usuário dono da meta
        goal_type: Tipo da meta (SAVINGS, EXPENSE_REDUCTION, INCOME_INCREASE, CUSTOM)
        category_ids: Lista de IDs das categorias selecionadas (opcional)
    
    Returns:
        Decimal: Valor total das transações do mês atual nas categorias relevantes
    """
    from datetime import date
    from django.db.models import Sum
    from django.db.models.functions import Coalesce
    
    today = date.today()
    month_start = today.replace(day=1)
    
    if goal_type == 'CUSTOM':
        return Decimal('0')
    
    base_query = Transaction.objects.filter(
        user=user,
        date__gte=month_start,
        date__lte=today
    )
    
    if goal_type == 'SAVINGS':
        if category_ids:
            query = base_query.filter(category_id__in=category_ids)
        else:
            from ..models import Category
            query = base_query.filter(
                category__group__in=[
                    Category.CategoryGroup.SAVINGS,
                    Category.CategoryGroup.INVESTMENT
                ]
            )
    
    elif goal_type == 'EXPENSE_REDUCTION':
        if not category_ids:
            return Decimal('0')
        query = base_query.filter(
            type=Transaction.TransactionType.EXPENSE,
            category_id__in=category_ids
        )
    
    elif goal_type == 'INCOME_INCREASE':
        if category_ids:
            query = base_query.filter(
                type=Transaction.TransactionType.INCOME,
                category_id__in=category_ids
            )
        else:
            query = base_query.filter(type=Transaction.TransactionType.INCOME)
    
    else:
        return Decimal('0')
    
    total = query.aggregate(
        total=Coalesce(Sum('amount'), Decimal('0'))
    )['total']
    
    return _decimal(total)
```

#### Tarefa 1.2: Atualizar função `_update_savings_goal`

**Localização**: Função existente `_update_savings_goal` em `Api/finance/services/goals.py`

**Modificação**: A função deve considerar `target_categories` se existirem, caso contrário usar SAVINGS/INVESTMENT.

**Substituir a função existente por**:

```python
def _update_savings_goal(goal) -> None:
    """
    Atualiza metas de poupança (SAVINGS).
    
    Lógica:
    - Se target_categories definido: soma transações nessas categorias
    - Senão: soma transações em categorias SAVINGS/INVESTMENT
    - Adiciona initial_amount ao total
    """
    from ..models import Category
    
    if goal.target_categories.exists():
        # Usar categorias específicas definidas pelo usuário
        transactions = Transaction.objects.filter(
            user=goal.user,
            category__in=goal.target_categories.all()
        )
    else:
        # Usar categorias padrão: SAVINGS e INVESTMENT
        transactions = Transaction.objects.filter(
            user=goal.user,
            category__group__in=[
                Category.CategoryGroup.SAVINGS,
                Category.CategoryGroup.INVESTMENT
            ]
        )
    
    total = _decimal(
        transactions.aggregate(total=Coalesce(Sum('amount'), Decimal('0')))['total']
    )
    
    total_with_initial = total + goal.initial_amount
    goal.current_amount = total_with_initial
    
    goal.save(update_fields=['current_amount', 'updated_at'])
```

#### Tarefa 1.3: Verificar função `_update_expense_reduction_goal`

**Localização**: Função existente em `Api/finance/services/goals.py`

**Verificação**: A função já usa `goal.target_categories.all()`. Confirmar que está correto.

**Comportamento esperado**:
- Busca transações EXPENSE nas categorias monitoradas
- Calcula média mensal no período de tracking
- current_amount = baseline_amount - média_atual (redução alcançada)

#### Tarefa 1.4: Verificar função `_update_income_increase_goal`

**Localização**: Função existente em `Api/finance/services/goals.py`

**Modificação necessária**: Adicionar suporte a `target_categories`

**Substituir por**:

```python
def _update_income_increase_goal(goal) -> None:
    """
    Atualiza meta de aumento de receita.
    
    Lógica:
    - Se target_categories definido: soma receitas nessas categorias
    - Senão: soma todas as receitas
    - Calcula receitas médias mensais nos últimos X meses
    - Compara com baseline_amount
    - Aumento = receitas_atuais - baseline
    - current_amount = aumento alcançado
    """
    if not goal.baseline_amount:
        return
    
    from dateutil.relativedelta import relativedelta
    from django.utils import timezone
    
    today = timezone.now().date()
    period_start = today - relativedelta(months=goal.tracking_period_months)
    
    # Base query: receitas do usuário no período
    query = Transaction.objects.filter(
        user=goal.user,
        type=Transaction.TransactionType.INCOME,
        date__gte=period_start,
        date__lte=today
    )
    
    # Filtrar por categorias se definidas
    if goal.target_categories.exists():
        query = query.filter(category__in=goal.target_categories.all())
    
    current_income = query.aggregate(
        total=Coalesce(Sum('amount'), Decimal('0'))
    )['total']
    
    current_income = _decimal(current_income)
    
    # Calcular dias reais no período para normalização
    days_in_period = (today - period_start).days
    if days_in_period == 0:
        current_monthly = Decimal('0')
    else:
        current_monthly = (current_income / Decimal(str(days_in_period))) * Decimal('30')
    
    # Aumento alcançado
    increase = current_monthly - goal.baseline_amount
    goal.current_amount = increase if increase > 0 else Decimal('0')
    
    goal.save(update_fields=['current_amount', 'updated_at'])
```

---

## 🔧 FASE 2: Backend - Serializer

### Arquivo: `Api/finance/serializers/goal.py`

#### Tarefa 2.1: Importar a nova função no topo do arquivo

**Localização**: Seção de imports

**Adicionar**:
```python
from ..services.goals import calculate_initial_amount
```

#### Tarefa 2.2: Modificar método `create`

**Localização**: Método `create` da classe `GoalSerializer`

**Substituir o método `create` existente por**:

```python
def create(self, validated_data):
    # Extrai categorias antes de criar
    target_categories = validated_data.pop('target_categories', [])
    target_category = validated_data.pop('target_category', None)
    
    validated_data["user"] = self.context["request"].user
    goal_type = validated_data.get('goal_type', 'CUSTOM')
    
    # Calcular initial_amount automaticamente (exceto CUSTOM)
    if goal_type != 'CUSTOM':
        category_ids = [c.id for c in target_categories] if target_categories else None
        if not category_ids and target_category:
            category_ids = [target_category.id]
        
        # Só calcula se não foi informado ou é zero
        if validated_data.get('initial_amount', Decimal('0')) == Decimal('0'):
            initial_value = calculate_initial_amount(
                user=validated_data["user"],
                goal_type=goal_type,
                category_ids=category_ids
            )
            validated_data['initial_amount'] = initial_value
            validated_data['current_amount'] = initial_value
            
            # Para EXPENSE_REDUCTION, initial_amount define baseline_amount se não informado
            if goal_type == 'EXPENSE_REDUCTION' and not validated_data.get('baseline_amount'):
                validated_data['baseline_amount'] = initial_value
    
    goal = super().create(validated_data)
    
    # Adiciona categorias ao M2M
    if target_categories:
        goal.target_categories.set(target_categories)
    elif target_category:
        goal.target_categories.add(target_category)
    
    return goal
```

#### Tarefa 2.3: Atualizar método `validate`

**Localização**: Método `validate` da classe `GoalSerializer`

**Substituir o método `validate` existente por**:

```python
def validate(self, attrs):
    goal_type = attrs.get('goal_type', self.instance.goal_type if self.instance else None)
    request = self.context.get('request')
    
    # Combina categorias de ambos os campos
    target_categories = attrs.get('target_categories', [])
    target_category = attrs.get('target_category')
    
    if target_category and not target_categories:
        target_categories = [target_category]
    
    # Validações específicas por tipo
    if goal_type == Goal.GoalType.EXPENSE_REDUCTION:
        # Obrigatório pelo menos uma categoria
        if not target_categories:
            raise serializers.ValidationError({
                'target_categories': 'Selecione pelo menos uma categoria para reduzir gastos.'
            })
        
        # Limite de 5 categorias
        if len(target_categories) > 5:
            raise serializers.ValidationError({
                'target_categories': 'Máximo de 5 categorias por meta.'
            })
        
        # Validar ownership e tipo de cada categoria
        from ..models import Category
        for category in target_categories:
            if not Category.objects.filter(
                models.Q(id=category.id, user=request.user) | 
                models.Q(id=category.id, user__isnull=True)
            ).exists():
                raise serializers.ValidationError({
                    'target_categories': f'Categoria "{category.name}" não pertence a você.'
                })
            
            if category.type != 'EXPENSE':
                raise serializers.ValidationError({
                    'target_categories': f'"{category.name}" não é uma categoria de despesa.'
                })
    
    elif goal_type == Goal.GoalType.INCOME_INCREASE:
        # Categorias opcionais, mas se informadas devem ser INCOME
        if target_categories:
            for category in target_categories:
                if category.type != 'INCOME':
                    raise serializers.ValidationError({
                        'target_categories': f'"{category.name}" não é uma categoria de receita.'
                    })
        
        # baseline_amount obrigatório se não for calculado automaticamente
        # (será calculado no create se não informado)
    
    elif goal_type == Goal.GoalType.SAVINGS:
        # Categorias opcionais (usa SAVINGS/INVESTMENT como padrão)
        pass
    
    elif goal_type == Goal.GoalType.CUSTOM:
        # CUSTOM não usa categorias
        if target_categories:
            logger.warning("Meta CUSTOM recebeu categorias - serão ignoradas")
            # Limpar categorias para CUSTOM
            attrs['target_categories'] = []
            attrs['target_category'] = None
    
    logger.info(f"[GOAL SERIALIZER] Validating attrs: {attrs}")
    return attrs
```

---

## 🔧 FASE 3: Backend - Signals

### Arquivo: `Api/finance/signals.py`

#### Tarefa 3.1: Substituir signal `update_goals_on_transaction_change`

**Localização**: Função decorada com `@receiver(post_save, sender=Transaction)` chamada `update_goals_on_transaction_change`

**Substituir a função existente por**:

```python
@receiver(post_save, sender=Transaction)
def update_goals_on_transaction_change(sender, instance, **kwargs):
    """
    Atualiza metas relevantes quando uma transação é criada ou atualizada.
    
    Para cada tipo de meta:
    - SAVINGS: atualiza se transação em categoria SAVINGS/INVESTMENT ou target_categories
    - EXPENSE_REDUCTION: atualiza se transação EXPENSE está nas target_categories
    - INCOME_INCREASE: atualiza se transação é INCOME (e em target_categories se definido)
    - CUSTOM: não atualiza automaticamente
    """
    from .services import update_goal_progress
    from .models import Goal, Category
    
    if not instance.category:
        return
    
    # Buscar todas metas ativas do usuário (exceto CUSTOM)
    goals = Goal.objects.filter(user=instance.user).exclude(
        goal_type=Goal.GoalType.CUSTOM
    ).prefetch_related('target_categories')
    
    for goal in goals:
        should_update = False
        
        if goal.goal_type == Goal.GoalType.SAVINGS:
            # Verifica se categoria está em target_categories ou é SAVINGS/INVESTMENT
            if goal.target_categories.exists():
                should_update = goal.target_categories.filter(id=instance.category_id).exists()
            else:
                should_update = instance.category.group in [
                    Category.CategoryGroup.SAVINGS,
                    Category.CategoryGroup.INVESTMENT
                ]
        
        elif goal.goal_type == Goal.GoalType.EXPENSE_REDUCTION:
            # Só atualiza se transação é EXPENSE e está nas categorias monitoradas
            if instance.type == Transaction.TransactionType.EXPENSE:
                should_update = goal.target_categories.filter(id=instance.category_id).exists()
        
        elif goal.goal_type == Goal.GoalType.INCOME_INCREASE:
            # Atualiza se transação é INCOME
            if instance.type == Transaction.TransactionType.INCOME:
                if goal.target_categories.exists():
                    should_update = goal.target_categories.filter(id=instance.category_id).exists()
                else:
                    should_update = True  # Todas receitas
        
        # EMERGENCY_FUND tratado como SAVINGS (compatibilidade durante migração)
        elif goal.goal_type == 'EMERGENCY_FUND':
            if goal.target_categories.exists():
                should_update = goal.target_categories.filter(id=instance.category_id).exists()
            else:
                should_update = instance.category.group in [
                    Category.CategoryGroup.SAVINGS,
                    Category.CategoryGroup.INVESTMENT
                ]
        
        if should_update:
            update_goal_progress(goal)
```

#### Tarefa 3.2: Verificar signal `update_goals_on_transaction_delete`

**Localização**: Função decorada com `@receiver(post_delete, sender=Transaction)`

**Verificação**: A função existente já chama `update_all_active_goals(instance.user)`. Confirmar que está correto.

---

## 🔧 FASE 4: Backend - Endpoint de Resumo Mensal

### Arquivo: `Api/finance/views/goals.py`

#### Tarefa 4.1: Adicionar action `monthly_summary`

**Localização**: Dentro da classe `GoalViewSet`, após o método `insights`

**Adicionar imports no topo do arquivo** (se não existirem):
```python
from decimal import Decimal
from django.db.models import Sum
from django.db.models.functions import Coalesce
```

**Adicionar o método**:

```python
@action(detail=False, methods=['get'], url_path='monthly-summary')
def monthly_summary(self, request):
    """
    Retorna o resumo de transações do mês atual por tipo e categorias.
    
    Query params:
    - type: EXPENSE, INCOME, SAVINGS, ALL (default: ALL)
    - categories: lista de IDs separados por vírgula (opcional)
    
    Retorna:
    {
        "month": "2025-12",
        "total": 1500.00,
        "by_category": [
            {"id": "uuid", "name": "Alimentação", "total": 500.00},
            ...
        ]
    }
    """
    from datetime import date
    from ..models import Category, Transaction
    
    today = date.today()
    month_start = today.replace(day=1)
    
    type_filter = request.query_params.get('type', 'ALL').upper()
    category_ids = request.query_params.get('categories', '')
    
    query = Transaction.objects.filter(
        user=request.user,
        date__gte=month_start,
        date__lte=today
    )
    
    # Filtro por tipo de transação
    if type_filter == 'EXPENSE':
        query = query.filter(type=Transaction.TransactionType.EXPENSE)
    elif type_filter == 'INCOME':
        query = query.filter(type=Transaction.TransactionType.INCOME)
    elif type_filter == 'SAVINGS':
        query = query.filter(
            category__group__in=[
                Category.CategoryGroup.SAVINGS,
                Category.CategoryGroup.INVESTMENT
            ]
        )
    
    # Filtro por categorias específicas
    if category_ids:
        ids = [id.strip() for id in category_ids.split(',') if id.strip()]
        if ids:
            query = query.filter(category_id__in=ids)
    
    # Total geral
    total = query.aggregate(
        total=Coalesce(Sum('amount'), Decimal('0'))
    )['total']
    
    # Breakdown por categoria
    by_category = query.values(
        'category__id', 'category__name'
    ).annotate(
        total=Sum('amount')
    ).order_by('-total')
    
    return Response({
        'month': today.strftime('%Y-%m'),
        'total': float(total),
        'by_category': [
            {
                'id': str(item['category__id']) if item['category__id'] else None,
                'name': item['category__name'] or 'Sem categoria',
                'total': float(item['total'] or 0)
            }
            for item in by_category
            if item['category__id']  # Ignorar transações sem categoria
        ]
    })
```

---

## 🔧 FASE 5: Frontend - Repository e Modelo

### Arquivo: `Front/lib/core/models/goal.dart`

#### Tarefa 5.1: Atualizar enum `GoalType`

**Localização**: Enum `GoalType` no início do arquivo

**Substituir o enum por**:

```dart
/// Tipos de metas financeiras
enum GoalType {
  savings('SAVINGS', 'Economizar', '💰'),
  expenseReduction('EXPENSE_REDUCTION', 'Reduzir Gastos', '📉'),
  incomeIncrease('INCOME_INCREASE', 'Aumentar Receita', '📈'),
  custom('CUSTOM', 'Personalizada', '✏️');

  const GoalType(this.value, this.label, this.icon);
  final String value;
  final String label;
  final String icon;
}
```

#### Tarefa 5.2: Atualizar `_parseGoalType` para compatibilidade

**Localização**: Função estática `_parseGoalType` dentro de `GoalModel`

**Substituir por**:

```dart
static GoalType _parseGoalType(String? value) {
  switch (value?.toUpperCase()) {
    case 'SAVINGS':
    case 'EMERGENCY_FUND':  // Compatibilidade: tratar como SAVINGS
      return GoalType.savings;
    case 'EXPENSE_REDUCTION':
      return GoalType.expenseReduction;
    case 'INCOME_INCREASE':
      return GoalType.incomeIncrease;
    default:
      return GoalType.custom;
  }
}
```

### Arquivo: `Front/lib/core/repositories/goal_repository.dart`

#### Tarefa 5.3: Adicionar classes para resumo mensal

**Localização**: No final do arquivo, antes do fechamento

**Adicionar**:

```dart
/// Modelo para resumo mensal de transações
class MonthlySummary {
  /// Mês no formato YYYY-MM
  final String month;
  
  /// Total geral das transações
  final double total;
  
  /// Breakdown por categoria
  final List<CategoryTotal> byCategory;
  
  const MonthlySummary({
    required this.month,
    required this.total,
    required this.byCategory,
  });
  
  factory MonthlySummary.fromMap(Map<String, dynamic> map) {
    return MonthlySummary(
      month: map['month'] as String? ?? '',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      byCategory: (map['by_category'] as List?)
          ?.map((e) => CategoryTotal.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
  
  /// Retorna um MonthlySummary vazio
  static MonthlySummary empty() {
    return const MonthlySummary(month: '', total: 0, byCategory: []);
  }
}

/// Total de transações em uma categoria
class CategoryTotal {
  final String id;
  final String name;
  final double total;
  
  const CategoryTotal({
    required this.id,
    required this.name,
    required this.total,
  });
  
  factory CategoryTotal.fromMap(Map<String, dynamic> map) {
    return CategoryTotal(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
```

#### Tarefa 5.4: Adicionar método `fetchMonthlySummary`

**Localização**: Dentro da classe `GoalRepository`, após os métodos existentes

**Adicionar**:

```dart
/// Busca resumo mensal de transações para pré-preencher wizard de metas.
///
/// [type]: EXPENSE, INCOME, SAVINGS ou ALL (default)
/// [categoryIds]: Lista de IDs de categorias (opcional)
/// 
/// Retorna [MonthlySummary] com total e breakdown por categoria.
Future<MonthlySummary> fetchMonthlySummary({
  String type = 'ALL',
  List<String>? categoryIds,
}) async {
  try {
    final queryParams = <String, String>{
      'type': type,
    };
    
    if (categoryIds != null && categoryIds.isNotEmpty) {
      queryParams['categories'] = categoryIds.join(',');
    }
    
    final response = await client.client.get<Map<String, dynamic>>(
      '${ApiEndpoints.goals}monthly-summary/',
      queryParameters: queryParams,
    );
    
    final data = response.data ?? {};
    return MonthlySummary.fromMap(data);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ GoalRepository: Error fetching monthly summary: $e');
    }
    return MonthlySummary.empty();
  }
}
```

---

## 🔧 FASE 6: Frontend - Wizard

### Arquivo: `Front/lib/features/progress/presentation/widgets/simple_goal_wizard.dart`

#### Tarefa 6.1: Adicionar estados para resumo mensal

**Localização**: Dentro de `_SimpleGoalWizardState`, junto com as outras variáveis de estado

**Adicionar após as variáveis existentes**:

```dart
// Resumo mensal para contexto
double _monthlySummaryTotal = 0;
bool _loadingMonthlySummary = false;
String _monthlySummaryError = '';
```

#### Tarefa 6.2: Adicionar método para buscar resumo mensal

**Localização**: Dentro de `_SimpleGoalWizardState`, após `_loadCategories()`

**Adicionar**:

```dart
/// Busca o resumo mensal das categorias selecionadas
Future<void> _fetchMonthlySummary() async {
  if (_selectedCategories.isEmpty && _selectedType != GoalType.incomeIncrease) {
    return;
  }
  
  setState(() {
    _loadingMonthlySummary = true;
    _monthlySummaryError = '';
  });
  
  try {
    String type;
    switch (_selectedType) {
      case GoalType.expenseReduction:
        type = 'EXPENSE';
        break;
      case GoalType.incomeIncrease:
        type = 'INCOME';
        break;
      case GoalType.savings:
        type = 'SAVINGS';
        break;
      default:
        type = 'ALL';
    }
    
    final categoryIds = _selectedCategories.isNotEmpty
        ? _selectedCategories.map((c) => c.id).toList()
        : null;
    
    final summary = await _repository.fetchMonthlySummary(
      type: type,
      categoryIds: categoryIds,
    );
    
    if (mounted) {
      setState(() {
        _monthlySummaryTotal = summary.total;
        // Auto-preencher baselineAmount com o total do mês
        if (_baselineAmount == 0) {
          _baselineAmount = summary.total;
        }
        _loadingMonthlySummary = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _loadingMonthlySummary = false;
        _monthlySummaryError = 'Erro ao buscar resumo';
      });
    }
  }
}
```

#### Tarefa 6.3: Chamar `_fetchMonthlySummary` ao selecionar categorias

**Localização**: No método `_buildCategoryOption`, dentro do `onTap`

**Modificar o onTap para chamar `_fetchMonthlySummary` após selecionar categoria**:

Procurar pelo trecho:
```dart
onTap: () {
  setState(() {
    _useDefaultCategories = false;
    if (isSelected) {
      _selectedCategories.remove(category);
    } else if (canAddMore) {
      _selectedCategories.add(category);
    }
```

E adicionar após a atualização de estado:
```dart
    // Buscar resumo mensal após selecionar categoria
    _fetchMonthlySummary();
```

#### Tarefa 6.4: Adicionar widget para exibir resumo mensal

**Localização**: No método `_buildStepCategory()`, após a lista de categorias e antes do campo de baseline_amount

**Adicionar antes do bloco de baseline_amount**:

```dart
// Exibir resumo mensal se disponível
if (_monthlySummaryTotal > 0 && !_loadingMonthlySummary) ...[
  const SizedBox(height: 16),
  Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Icon(Icons.insights, color: AppColors.primary, size: 32),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedType == GoalType.expenseReduction
                    ? 'Você gastou este mês:'
                    : _selectedType == GoalType.incomeIncrease
                        ? 'Sua receita este mês:'
                        : 'Total este mês:',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                _currency.format(_monthlySummaryTotal),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
],

if (_loadingMonthlySummary)
  const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  ),
```

#### Tarefa 6.5: Remover opção EMERGENCY_FUND do step de tipo

**Localização**: No método `_buildStep1Type()`

**Remover o bloco**:
```dart
// Opção: Fundo de emergência
GoalTypeCard(
  icon: Icons.shield_outlined,
  iconColor: Colors.purple,
  title: 'Fundo de emergência',
  description: 'Criar uma reserva financeira',
  examples: '🛡️ Reserva 3, 6 ou 12 meses',
  trackedInfo: 'Padrão: Poupança e Investimentos',
  isSelected: _selectedType == GoalType.emergencyFund,
  onTap: () {
    setState(() => _selectedType = GoalType.emergencyFund);
    _loadCategories();
    _nextStep();
  },
),

const SizedBox(height: 12),
```

---

## 🔧 FASE 7: Migração de Dados e Testes

### Arquivo: Nova migração Django

#### Tarefa 7.1: Criar migração para consolidar EMERGENCY_FUND

**Criar arquivo**: `Api/finance/migrations/XXXX_consolidate_emergency_fund.py`

**Conteúdo**:

```python
"""
Migração para consolidar metas EMERGENCY_FUND em SAVINGS.

Esta migração:
1. Atualiza todas as metas com goal_type='EMERGENCY_FUND' para goal_type='SAVINGS'
2. É irreversível (não há como distinguir metas após a conversão)
"""

from django.db import migrations


def consolidate_emergency_fund_to_savings(apps, schema_editor):
    """Converte todas as metas EMERGENCY_FUND para SAVINGS."""
    Goal = apps.get_model('finance', 'Goal')
    count = Goal.objects.filter(goal_type='EMERGENCY_FUND').update(goal_type='SAVINGS')
    if count > 0:
        print(f'\n✅ Migrated {count} EMERGENCY_FUND goal(s) to SAVINGS')


def reverse_migration(apps, schema_editor):
    """
    Reversão não é possível - não há como identificar quais metas
    eram originalmente EMERGENCY_FUND após a conversão.
    """
    print('\n⚠️ AVISO: Esta migração não pode ser revertida.')
    print('   Metas EMERGENCY_FUND já foram convertidas para SAVINGS.')


class Migration(migrations.Migration):

    dependencies = [
        # Atualizar para a última migração existente
        ('finance', '0037_add_snapshot_models_and_mission_enhancements'),
    ]

    operations = [
        migrations.RunPython(
            consolidate_emergency_fund_to_savings,
            reverse_migration,
        ),
    ]
```

**⚠️ IMPORTANTE**: Antes de criar o arquivo, verificar qual é a última migração em `Api/finance/migrations/` e atualizar a dependência.

#### Tarefa 7.2: Executar migração

**Comando**:
```bash
cd Api
python manage.py makemigrations finance --name consolidate_emergency_fund
python manage.py migrate
```

---

## ✅ Verificação Final

### Testes a executar após cada fase:

#### Após FASE 1-2:
```bash
cd Api
python manage.py shell
```
```python
from finance.services.goals import calculate_initial_amount
from django.contrib.auth import get_user_model

User = get_user_model()
user = User.objects.first()

# Testar cálculo
print(calculate_initial_amount(user, 'SAVINGS'))
print(calculate_initial_amount(user, 'EXPENSE_REDUCTION', category_ids=[...]))
print(calculate_initial_amount(user, 'CUSTOM'))
```

#### Após FASE 3:
- Criar uma transação via API
- Verificar se as metas foram atualizadas

#### Após FASE 4:
```bash
curl -X GET "http://localhost:8000/api/goals/monthly-summary/?type=EXPENSE" -H "Authorization: Bearer <token>"
```

#### Após FASE 5-6:
- Abrir o app Flutter
- Criar uma nova meta do tipo EXPENSE_REDUCTION
- Verificar se o resumo mensal aparece
- Verificar se o baseline é preenchido automaticamente

#### Após FASE 7:
```bash
cd Api
python manage.py shell
```
```python
from finance.models import Goal
# Não deve existir mais metas EMERGENCY_FUND
print(Goal.objects.filter(goal_type='EMERGENCY_FUND').count())  # Deve ser 0
```

---

## 📝 Notas para o Agente

1. **Ordem é importante**: Execute as fases na ordem indicada
2. **Backup**: Faça backup do banco antes da FASE 7
3. **Testes**: Execute os testes após cada fase
4. **Imports**: Verifique se todos os imports necessários estão presentes
5. **Compatibilidade**: O código mantém compatibilidade com `target_category` (singular) para clientes antigos
6. **EMERGENCY_FUND**: Durante a transição, o signal trata EMERGENCY_FUND como SAVINGS

---

## 🔄 Rollback

Se algo der errado:

1. **Backend**: Reverter commits das fases 1-4
2. **Frontend**: Reverter commits das fases 5-6
3. **Migração**: A FASE 7 NÃO pode ser revertida automaticamente
   - Se necessário, restaurar backup do banco de dados
