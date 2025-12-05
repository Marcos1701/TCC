# 📋 Plano de Refatoração do Sistema de Metas

> **Data de Criação:** 05/12/2025  
> **Status:** Em planejamento  
> **Versão:** 1.0

---

## 📑 Índice

1. [Análise da Situação Atual](#1-análise-da-situação-atual)
2. [Problemas Identificados](#2-problemas-identificados)
3. [Proposta de Simplificação](#3-proposta-de-simplificação)
4. [Plano de Implementação](#4-plano-de-implementação)
5. [Detalhamento das Fases](#5-detalhamento-das-fases)
6. [Arquivos Afetados](#6-arquivos-afetados)
7. [Critérios de Aceite](#7-critérios-de-aceite)
8. [Checklist de Implementação](#8-checklist-de-implementação)

---

## 1. Análise da Situação Atual

### 1.1 Backend (Django)

#### Modelo `Goal` (`Api/finance/models/goal.py`)

**Tipos de metas existentes:**
```python
class GoalType(models.TextChoices):
    SAVINGS = "SAVINGS", "Juntar Dinheiro"
    EXPENSE_REDUCTION = "EXPENSE_REDUCTION", "Reduzir Gastos"
    INCOME_INCREASE = "INCOME_INCREASE", "Aumentar Receita"
    EMERGENCY_FUND = "EMERGENCY_FUND", "Fundo de Emergência"
    CUSTOM = "CUSTOM", "Personalizada"
```

**Campos principais:**
| Campo | Tipo | Descrição |
|-------|------|-----------|
| `target_amount` | Decimal | Valor alvo da meta |
| `current_amount` | Decimal | Valor atual (progresso) |
| `initial_amount` | Decimal | Valor inicial (transações antes da criação) |
| `baseline_amount` | Decimal | Valor de referência (gasto/receita mensal) |
| `target_categories` | ManyToMany | Categorias monitoradas (max 5) |
| `tracking_period_months` | Integer | Período de cálculo em meses (padrão: 3) |
| `goal_type` | CharField | Tipo da meta |
| `deadline` | DateField | Data limite (opcional) |

#### Serviços (`Api/finance/services/goals.py`)

**Funções existentes:**
- `update_goal_progress(goal)` - Atualiza progresso baseado no tipo
- `_update_savings_goal(goal)` - Soma transações SAVINGS/INVESTMENT
- `_update_expense_reduction_goal(goal)` - Compara gastos vs baseline
- `_update_income_increase_goal(goal)` - Compara receitas vs baseline
- `update_all_active_goals(user)` - Atualiza todas metas (exceto CUSTOM)
- `get_goal_insights(goal)` - Gera insights sobre progresso

#### Signals (`Api/finance/signals.py`)

**Comportamento atual:**
```python
@receiver(post_save, sender=Transaction)
def update_goals_on_transaction_change(sender, instance, **kwargs):
    # APENAS atualiza SAVINGS e EMERGENCY_FUND automaticamente
    auto_update_goals = Goal.objects.filter(
        user=instance.user, 
        goal_type__in=[Goal.GoalType.SAVINGS, Goal.GoalType.EMERGENCY_FUND]
    )
```

### 1.2 Frontend (Flutter)

#### Modelo `GoalModel` (`Front/lib/core/models/goal.dart`)

```dart
enum GoalType {
  savings('SAVINGS', 'Juntar Dinheiro', '💰'),
  expenseReduction('EXPENSE_REDUCTION', 'Reduzir Gastos', '📉'),
  incomeIncrease('INCOME_INCREASE', 'Aumentar Receita', '📈'),
  emergencyFund('EMERGENCY_FUND', 'Fundo de Emergência', '🛡️'),
  custom('CUSTOM', 'Personalizada', '✏️');
}
```

#### Wizard (`Front/lib/features/progress/presentation/widgets/simple_goal_wizard.dart`)

**Fluxo atual (5 passos):**
1. **Tipo** - Escolher tipo de meta
2. **Categoria** - Selecionar categorias (se não for CUSTOM)
3. **Nome** - Título da meta
4. **Valor** - Valor alvo
5. **Prazo** - Data limite (opcional)

**Validações implementadas:**
- EXPENSE_REDUCTION: obrigatório 1-5 categorias EXPENSE + baseline_amount
- INCOME_INCREASE: baseline_amount obrigatório
- Limite de 5 categorias por meta

---

## 2. Problemas Identificados

### 2.1 Backend

| # | Problema | Impacto | Prioridade |
|---|----------|---------|------------|
| B1 | `initial_amount` não é calculado automaticamente | Valor inicial sempre 0 | 🔴 Alta |
| B2 | Signal só atualiza SAVINGS/EMERGENCY_FUND | EXPENSE_REDUCTION e INCOME_INCREASE não atualizam automaticamente | 🔴 Alta |
| B3 | Tipo EMERGENCY_FUND é redundante com SAVINGS | Complexidade desnecessária | 🟡 Média |
| B4 | Lógica de atualização não considera todas as categorias | Progresso pode ser incorreto | 🔴 Alta |

### 2.2 Frontend

| # | Problema | Impacto | Prioridade |
|---|----------|---------|------------|
| F1 | Wizard não calcula valor inicial automaticamente | Usuário não sabe quanto já tem | 🔴 Alta |
| F2 | `baseline_amount` preenchido manualmente | UX ruim, usuário pode não saber o valor | 🟡 Média |
| F3 | Não mostra resumo mensal antes de definir meta | Falta contexto para decisão | 🟡 Média |
| F4 | 5 tipos de meta pode confundir usuário | UX complexa | 🟢 Baixa |

### 2.3 Inconsistências entre Backend e Frontend

| # | Inconsistência | Local |
|---|---------------|-------|
| I1 | EMERGENCY_FUND tratado igual a SAVINGS no backend mas diferente no frontend | Modelo e signals |
| I2 | Campos de categoria não sincronizados completamente | Repository e Serializer |

---

## 3. Proposta de Simplificação

### 3.1 Tipos de Metas (4 tipos)

| Tipo | Descrição | Categorias | Valor Inicial | Atualização |
|------|-----------|------------|---------------|-------------|
| **SAVINGS** | Juntar dinheiro / Economizar | Poupança/Investimento (padrão) ou personalizáveis | Soma do mês atual nas categorias selecionadas | ✅ Automática |
| **EXPENSE_REDUCTION** | Reduzir gastos em categorias | **Obrigatório**: 1-5 categorias EXPENSE | Soma do mês atual nas categorias selecionadas | ✅ Automática |
| **INCOME_INCREASE** | Aumentar receita | Opcional: todas receitas ou categorias específicas | Soma do mês atual das receitas | ✅ Automática |
| **CUSTOM** | Meta personalizada | Nenhuma (não monitora) | Informado pelo usuário | ❌ Manual |

### 3.2 Lógica de Cálculo por Tipo

#### SAVINGS (Economizar)
```
initial_amount = Σ(transações do mês atual em categorias SAVINGS/INVESTMENT)
current_amount = Σ(todas transações desde criação nas categorias monitoradas)
progress = (current_amount / target_amount) * 100
```

#### EXPENSE_REDUCTION (Reduzir Gastos)
```
initial_amount = Σ(despesas do mês atual nas categorias selecionadas) → define baseline_amount
baseline_amount = média mensal de gastos (últimos X meses ou mês atual)
current_reduction = baseline_amount - Σ(despesas do período atual nas categorias)
progress = (current_reduction / target_amount) * 100
```

#### INCOME_INCREASE (Aumentar Receita)
```
initial_amount = Σ(receitas do mês atual)
baseline_amount = média mensal de receitas
current_increase = Σ(receitas do período atual) - baseline_amount
progress = (current_increase / target_amount) * 100
```

#### CUSTOM (Personalizada)
```
initial_amount = valor informado pelo usuário
current_amount = atualizado manualmente pelo usuário
progress = (current_amount / target_amount) * 100
```

### 3.3 Fluxo de Atualização

```
[Transação Criada/Editada/Deletada]
         ↓
[Signal: post_save/post_delete]
         ↓
[Buscar metas do usuário (exceto CUSTOM)]
         ↓
[Para cada meta:]
   ├─ Verificar se categoria da transação está em target_categories
   ├─ Se sim → update_goal_progress(goal)
   └─ Salvar alterações
```

---

## 4. Plano de Implementação

### Visão Geral das Fases

```
┌─────────────────────────────────────────────────────────────────┐
│  FASE 1: Backend - Services                                     │
│  - Criar calculate_initial_amount()                             │
│  - Atualizar lógica de update_goal_progress()                   │
│  Duração estimada: 2-3 horas                                    │
├─────────────────────────────────────────────────────────────────┤
│  FASE 2: Backend - Serializer                                   │
│  - Calcular initial_amount automaticamente no create()          │
│  - Ajustar validações por tipo                                  │
│  Duração estimada: 1-2 horas                                    │
├─────────────────────────────────────────────────────────────────┤
│  FASE 3: Backend - Signals                                      │
│  - Extender para EXPENSE_REDUCTION e INCOME_INCREASE            │
│  - Verificar target_categories da meta                          │
│  Duração estimada: 1-2 horas                                    │
├─────────────────────────────────────────────────────────────────┤
│  FASE 4: Backend - Endpoint de Resumo Mensal                    │
│  - Criar action para buscar totais por categoria no mês         │
│  Duração estimada: 1 hora                                       │
├─────────────────────────────────────────────────────────────────┤
│  FASE 5: Frontend - Repository e Modelo                         │
│  - Remover EMERGENCY_FUND do enum                               │
│  - Adicionar método fetchMonthlySummary()                       │
│  Duração estimada: 1 hora                                       │
├─────────────────────────────────────────────────────────────────┤
│  FASE 6: Frontend - Wizard                                      │
│  - Buscar e exibir soma do mês atual                            │
│  - Auto-preencher baseline_amount                               │
│  - Melhorar UX com contexto                                     │
│  Duração estimada: 2-3 horas                                    │
├─────────────────────────────────────────────────────────────────┤
│  FASE 7: Migração de Dados e Testes                             │
│  - Migrar EMERGENCY_FUND → SAVINGS                              │
│  - Testes unitários e integração                                │
│  Duração estimada: 2-3 horas                                    │
└─────────────────────────────────────────────────────────────────┘

TOTAL ESTIMADO: 10-15 horas
```

---

## 5. Detalhamento das Fases

### FASE 1: Backend - Services

#### 1.1 Criar função `calculate_initial_amount()`

**Arquivo:** `Api/finance/services/goals.py`

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
        Decimal: Valor total das transações do mês atual
    """
    from datetime import date
    from django.db.models import Sum
    from django.db.models.functions import Coalesce
    from ..models import Category, Transaction
    
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
        # Se categorias específicas, usa elas; senão, SAVINGS/INVESTMENT
        if category_ids:
            query = base_query.filter(category_id__in=category_ids)
        else:
            query = base_query.filter(
                category__group__in=[
                    Category.CategoryGroup.SAVINGS,
                    Category.CategoryGroup.INVESTMENT
                ]
            )
    
    elif goal_type == 'EXPENSE_REDUCTION':
        # Obrigatório ter categorias para EXPENSE_REDUCTION
        if not category_ids:
            return Decimal('0')
        query = base_query.filter(
            type=Transaction.TransactionType.EXPENSE,
            category_id__in=category_ids
        )
    
    elif goal_type == 'INCOME_INCREASE':
        # Se categorias específicas, usa elas; senão, todas receitas
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

#### 1.2 Atualizar `update_goal_progress()`

**Arquivo:** `Api/finance/services/goals.py`

Garantir que a função considera TODAS as categorias em `target_categories`:

```python
def update_goal_progress(goal) -> None:
    """
    Atualiza o progresso de uma meta baseado no tipo.
    
    Tipos suportados:
    - SAVINGS: Soma transações em categorias SAVINGS/INVESTMENT ou target_categories
    - EXPENSE_REDUCTION: Compara gastos atuais vs baseline nas target_categories
    - INCOME_INCREASE: Compara receitas atuais vs baseline
    - CUSTOM: Não atualizado automaticamente
    """
    if goal.goal_type == Goal.GoalType.CUSTOM:
        return  # Metas CUSTOM são atualizadas manualmente
    
    if goal.goal_type == Goal.GoalType.SAVINGS:
        _update_savings_goal(goal)
    elif goal.goal_type == Goal.GoalType.EXPENSE_REDUCTION:
        _update_expense_reduction_goal(goal)
    elif goal.goal_type == Goal.GoalType.INCOME_INCREASE:
        _update_income_increase_goal(goal)
    # EMERGENCY_FUND será migrado para SAVINGS
```

---

### FASE 2: Backend - Serializer

#### 2.1 Atualizar `create()` para calcular `initial_amount`

**Arquivo:** `Api/finance/serializers/goal.py`

```python
def create(self, validated_data):
    from ..services.goals import calculate_initial_amount
    
    # Extrai categorias antes de criar
    target_categories = validated_data.pop('target_categories', [])
    target_category = validated_data.pop('target_category', None)
    
    validated_data["user"] = self.context["request"].user
    goal_type = validated_data.get('goal_type', 'CUSTOM')
    
    # Calcular initial_amount automaticamente (exceto CUSTOM)
    if goal_type != 'CUSTOM' and validated_data.get('initial_amount', 0) == 0:
        category_ids = [c.id for c in target_categories] if target_categories else None
        if not category_ids and target_category:
            category_ids = [target_category.id]
        
        initial_value = calculate_initial_amount(
            user=validated_data["user"],
            goal_type=goal_type,
            category_ids=category_ids
        )
        validated_data['initial_amount'] = initial_value
        validated_data['current_amount'] = initial_value  # Começa com o valor inicial
        
        # Para EXPENSE_REDUCTION, initial_amount também define baseline_amount
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

#### 2.2 Ajustar validações

```python
def validate(self, attrs):
    goal_type = attrs.get('goal_type', self.instance.goal_type if self.instance else None)
    target_categories = attrs.get('target_categories', [])
    target_category = attrs.get('target_category')
    
    # Combina categorias de ambos os campos
    if target_category and not target_categories:
        target_categories = [target_category]
    
    # SAVINGS: categorias opcionais (usa padrão se não informado)
    # EXPENSE_REDUCTION: obrigatório pelo menos uma categoria
    if goal_type == 'EXPENSE_REDUCTION':
        if not target_categories:
            raise serializers.ValidationError({
                'target_categories': 'Selecione pelo menos uma categoria para reduzir gastos.'
            })
        if len(target_categories) > 5:
            raise serializers.ValidationError({
                'target_categories': 'Máximo de 5 categorias por meta.'
            })
        # Validar que são categorias EXPENSE
        for category in target_categories:
            if category.type != 'EXPENSE':
                raise serializers.ValidationError({
                    'target_categories': f'"{category.name}" não é uma categoria de despesa.'
                })
    
    # INCOME_INCREASE: categorias opcionais
    if goal_type == 'INCOME_INCREASE' and target_categories:
        for category in target_categories:
            if category.type != 'INCOME':
                raise serializers.ValidationError({
                    'target_categories': f'"{category.name}" não é uma categoria de receita.'
                })
    
    # CUSTOM: não usa categorias
    if goal_type == 'CUSTOM' and target_categories:
        raise serializers.ValidationError({
            'target_categories': 'Metas personalizadas não usam categorias.'
        })
    
    return attrs
```

---

### FASE 3: Backend - Signals

#### 3.1 Extender signal para todos os tipos

**Arquivo:** `Api/finance/signals.py`

```python
@receiver(post_save, sender=Transaction)
def update_goals_on_transaction_change(sender, instance, **kwargs):
    """
    Atualiza metas relevantes quando uma transação é criada ou atualizada.
    
    Para cada tipo de meta:
    - SAVINGS: atualiza se transação em categoria SAVINGS/INVESTMENT ou target_categories
    - EXPENSE_REDUCTION: atualiza se transação em uma das target_categories
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
        
        if should_update:
            update_goal_progress(goal)


@receiver(post_delete, sender=Transaction)
def update_goals_on_transaction_delete(sender, instance, **kwargs):
    """
    Atualiza metas quando uma transação é deletada.
    """
    from .services import update_all_active_goals
    
    try:
        if instance.user_id and instance.user:
            update_all_active_goals(instance.user)
    except Exception:
        pass  # Usuário pode ter sido deletado
```

---

### FASE 4: Backend - Endpoint de Resumo Mensal

#### 4.1 Criar action em `GoalViewSet`

**Arquivo:** `Api/finance/views/goals.py`

```python
@action(detail=False, methods=['get'], url_path='monthly-summary')
def monthly_summary(self, request):
    """
    Retorna o resumo de transações do mês atual por tipo e categorias.
    
    Query params:
    - type: EXPENSE, INCOME, ALL (default: ALL)
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
    from django.db.models import Sum
    from django.db.models.functions import Coalesce
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
    
    if type_filter == 'EXPENSE':
        query = query.filter(type=Transaction.TransactionType.EXPENSE)
    elif type_filter == 'INCOME':
        query = query.filter(type=Transaction.TransactionType.INCOME)
    
    if category_ids:
        ids = [id.strip() for id in category_ids.split(',') if id.strip()]
        query = query.filter(category_id__in=ids)
    
    # Total geral
    total = query.aggregate(
        total=Coalesce(Sum('amount'), Decimal('0'))
    )['total']
    
    # Por categoria
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
                'id': str(item['category__id']),
                'name': item['category__name'],
                'total': float(item['total'])
            }
            for item in by_category
        ]
    })
```

---

### FASE 5: Frontend - Repository e Modelo

#### 5.1 Atualizar `GoalType` enum

**Arquivo:** `Front/lib/core/models/goal.dart`

```dart
/// Tipos de metas financeiras
enum GoalType {
  savings('SAVINGS', 'Economizar', '💰'),
  expenseReduction('EXPENSE_REDUCTION', 'Reduzir Gastos', '📉'),
  incomeIncrease('INCOME_INCREASE', 'Aumentar Receita', '📈'),
  // EMERGENCY_FUND removido - consolidado com SAVINGS
  custom('CUSTOM', 'Personalizada', '✏️');

  const GoalType(this.value, this.label, this.icon);
  final String value;
  final String label;
  final String icon;
}
```

#### 5.2 Adicionar método `fetchMonthlySummary()`

**Arquivo:** `Front/lib/core/repositories/goal_repository.dart`

```dart
/// Busca resumo mensal de transações para pré-preencher wizard de metas.
///
/// [type]: EXPENSE, INCOME ou ALL
/// [categoryIds]: Lista de IDs de categorias (opcional)
Future<MonthlySummary> fetchMonthlySummary({
  String type = 'ALL',
  List<String>? categoryIds,
}) async {
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
}

/// Modelo para resumo mensal
class MonthlySummary {
  final String month;
  final double total;
  final List<CategoryTotal> byCategory;
  
  MonthlySummary({
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
}

class CategoryTotal {
  final String id;
  final String name;
  final double total;
  
  CategoryTotal({required this.id, required this.name, required this.total});
  
  factory CategoryTotal.fromMap(Map<String, dynamic> map) {
    return CategoryTotal(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
```

---

### FASE 6: Frontend - Wizard

#### 6.1 Atualizar wizard para buscar resumo mensal

**Arquivo:** `Front/lib/features/progress/presentation/widgets/simple_goal_wizard.dart`

**Principais alterações:**

1. **Remover opção EMERGENCY_FUND** do step de tipo
2. **Buscar resumo mensal** ao selecionar categorias
3. **Exibir contexto** para o usuário: "Você gastou R$ X este mês nessas categorias"
4. **Auto-preencher baseline_amount** com o total do mês
5. **Sugerir valor da meta** baseado no contexto

```dart
// Adicionar estado para resumo mensal
double _monthlySummaryTotal = 0;
bool _loadingMonthlySummary = false;

// Método para buscar resumo
Future<void> _fetchMonthlySummary() async {
  if (_selectedCategories.isEmpty) return;
  
  setState(() => _loadingMonthlySummary = true);
  
  try {
    final categoryIds = _selectedCategories.map((c) => c.id).toList();
    final summary = await _repository.fetchMonthlySummary(
      type: _selectedType == GoalType.expenseReduction ? 'EXPENSE' : 'INCOME',
      categoryIds: categoryIds,
    );
    
    if (mounted) {
      setState(() {
        _monthlySummaryTotal = summary.total;
        _baselineAmount = summary.total;
        _loadingMonthlySummary = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() => _loadingMonthlySummary = false);
    }
  }
}

// No step de categoria, exibir o total:
if (_monthlySummaryTotal > 0)
  Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Icon(Icons.insights, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Este mês você gastou:',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
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
```

---

### FASE 7: Migração de Dados e Testes

#### 7.1 Migração de EMERGENCY_FUND → SAVINGS

**Arquivo:** `Api/finance/migrations/XXXX_consolidate_emergency_fund.py`

```python
from django.db import migrations


def consolidate_emergency_fund(apps, schema_editor):
    """Migra metas EMERGENCY_FUND para SAVINGS."""
    Goal = apps.get_model('finance', 'Goal')
    count = Goal.objects.filter(goal_type='EMERGENCY_FUND').update(goal_type='SAVINGS')
    print(f'Migrated {count} EMERGENCY_FUND goals to SAVINGS')


def reverse_consolidation(apps, schema_editor):
    """Reverte a migração (não é possível saber quais eram EMERGENCY_FUND)."""
    pass  # Operação irreversível


class Migration(migrations.Migration):
    dependencies = [
        ('finance', '0037_...'),  # Última migração existente
    ]

    operations = [
        migrations.RunPython(consolidate_emergency_fund, reverse_consolidation),
    ]
```

#### 7.2 Testes Unitários

**Arquivo:** `Api/finance/tests/test_goals.py`

```python
from decimal import Decimal
from django.test import TestCase
from django.contrib.auth import get_user_model
from ..models import Category, Goal, Transaction
from ..services.goals import calculate_initial_amount, update_goal_progress

User = get_user_model()


class GoalInitialAmountTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user('testuser', 'test@test.com', 'password')
        self.expense_category = Category.objects.create(
            user=self.user,
            name='Alimentação',
            type='EXPENSE',
            group='ESSENTIAL_EXPENSE'
        )
        self.savings_category = Category.objects.create(
            user=self.user,
            name='Poupança',
            type='EXPENSE',
            group='SAVINGS'
        )
    
    def test_calculate_initial_amount_expense_reduction(self):
        # Criar transações do mês atual
        Transaction.objects.create(
            user=self.user,
            category=self.expense_category,
            amount=Decimal('100.00'),
            type='EXPENSE',
            date=timezone.now().date()
        )
        
        initial = calculate_initial_amount(
            user=self.user,
            goal_type='EXPENSE_REDUCTION',
            category_ids=[self.expense_category.id]
        )
        
        self.assertEqual(initial, Decimal('100.00'))
    
    def test_calculate_initial_amount_savings_default_categories(self):
        Transaction.objects.create(
            user=self.user,
            category=self.savings_category,
            amount=Decimal('500.00'),
            type='EXPENSE',
            date=timezone.now().date()
        )
        
        initial = calculate_initial_amount(
            user=self.user,
            goal_type='SAVINGS',
            category_ids=None  # Usa padrão
        )
        
        self.assertEqual(initial, Decimal('500.00'))
    
    def test_calculate_initial_amount_custom_returns_zero(self):
        initial = calculate_initial_amount(
            user=self.user,
            goal_type='CUSTOM',
            category_ids=None
        )
        
        self.assertEqual(initial, Decimal('0'))


class GoalSignalTests(TestCase):
    def test_expense_reduction_goal_updates_on_transaction(self):
        # Setup
        user = User.objects.create_user('testuser2', 'test2@test.com', 'password')
        category = Category.objects.create(
            user=user, name='Delivery', type='EXPENSE', group='LIFESTYLE_EXPENSE'
        )
        goal = Goal.objects.create(
            user=user,
            title='Reduzir Delivery',
            goal_type='EXPENSE_REDUCTION',
            target_amount=Decimal('100.00'),
            baseline_amount=Decimal('500.00'),
            current_amount=Decimal('0.00')
        )
        goal.target_categories.add(category)
        
        # Criar transação
        Transaction.objects.create(
            user=user,
            category=category,
            amount=Decimal('50.00'),
            type='EXPENSE',
            date=timezone.now().date()
        )
        
        # Verificar que meta foi atualizada
        goal.refresh_from_db()
        self.assertGreater(goal.current_amount, Decimal('0'))
```

---

## 6. Arquivos Afetados

### Backend (Django)

| Arquivo | Tipo de Alteração |
|---------|-------------------|
| `Api/finance/models/goal.py` | Modificação (remover EMERGENCY_FUND da validação) |
| `Api/finance/services/goals.py` | Modificação (adicionar calculate_initial_amount, atualizar lógica) |
| `Api/finance/serializers/goal.py` | Modificação (calcular initial_amount no create) |
| `Api/finance/signals.py` | Modificação (extender para todos os tipos) |
| `Api/finance/views/goals.py` | Modificação (adicionar action monthly-summary) |
| `Api/finance/migrations/XXXX_*.py` | Criação (migrar EMERGENCY_FUND) |
| `Api/finance/tests/test_goals.py` | Criação/Modificação (novos testes) |

### Frontend (Flutter)

| Arquivo | Tipo de Alteração |
|---------|-------------------|
| `Front/lib/core/models/goal.dart` | Modificação (remover EMERGENCY_FUND) |
| `Front/lib/core/repositories/goal_repository.dart` | Modificação (adicionar fetchMonthlySummary) |
| `Front/lib/features/progress/presentation/widgets/simple_goal_wizard.dart` | Modificação (integrar resumo mensal) |
| `Front/lib/features/progress/presentation/widgets/goal_wizard_components.dart` | Modificação (remover card EMERGENCY_FUND) |

---

## 7. Critérios de Aceite

### Funcionalidade

- [ ] **CA-01**: Sistema suporta 4 tipos de metas: SAVINGS, EXPENSE_REDUCTION, INCOME_INCREASE, CUSTOM
- [ ] **CA-02**: Metas EXPENSE_REDUCTION exigem pelo menos 1 categoria EXPENSE
- [ ] **CA-03**: `initial_amount` é calculado automaticamente baseado no mês atual
- [ ] **CA-04**: Ao criar transação, metas relevantes são atualizadas automaticamente
- [ ] **CA-05**: Metas CUSTOM não são atualizadas automaticamente
- [ ] **CA-06**: Wizard exibe resumo mensal antes de definir meta

### Performance

- [ ] **CA-07**: Signal não causa N+1 queries (usar prefetch_related)
- [ ] **CA-08**: Endpoint monthly-summary responde em < 500ms

### Compatibilidade

- [ ] **CA-09**: Metas EMERGENCY_FUND existentes migradas para SAVINGS
- [ ] **CA-10**: API mantém compatibilidade com campo `target_category` (singular)

### Testes

- [ ] **CA-11**: Testes unitários para calculate_initial_amount
- [ ] **CA-12**: Testes de integração para signals
- [ ] **CA-13**: Testes do wizard no Flutter

---

## 8. Checklist de Implementação

### Fase 1: Backend Services
- [ ] Implementar `calculate_initial_amount()`
- [ ] Atualizar `_update_savings_goal()` para considerar `target_categories`
- [ ] Atualizar `_update_expense_reduction_goal()` para múltiplas categorias
- [ ] Atualizar `_update_income_increase_goal()` para usar `target_categories`
- [ ] Testar funções isoladamente

### Fase 2: Backend Serializer
- [ ] Modificar `create()` para calcular `initial_amount`
- [ ] Modificar `create()` para definir `current_amount = initial_amount`
- [ ] Atualizar validações por tipo de meta
- [ ] Remover validações de EMERGENCY_FUND
- [ ] Testar criação de metas

### Fase 3: Backend Signals
- [ ] Refatorar `update_goals_on_transaction_change`
- [ ] Implementar verificação por tipo de meta
- [ ] Implementar verificação de `target_categories`
- [ ] Usar `prefetch_related` para evitar N+1
- [ ] Testar com diferentes tipos de transações

### Fase 4: Backend Endpoint
- [ ] Criar action `monthly_summary` em GoalViewSet
- [ ] Implementar filtro por tipo
- [ ] Implementar filtro por categorias
- [ ] Retornar total e breakdown por categoria
- [ ] Testar endpoint

### Fase 5: Frontend Repository/Modelo
- [ ] Remover `emergencyFund` de `GoalType` enum
- [ ] Atualizar `_parseGoalType` para tratar EMERGENCY_FUND como SAVINGS
- [ ] Criar classe `MonthlySummary`
- [ ] Implementar `fetchMonthlySummary()`
- [ ] Testar integração com API

### Fase 6: Frontend Wizard
- [ ] Remover card EMERGENCY_FUND do step de tipo
- [ ] Adicionar estado `_monthlySummaryTotal`
- [ ] Implementar `_fetchMonthlySummary()`
- [ ] Chamar ao selecionar categorias
- [ ] Exibir resumo mensal na UI
- [ ] Auto-preencher `baselineAmount`
- [ ] Testar fluxo completo

### Fase 7: Migração e Testes
- [ ] Criar migração para consolidar EMERGENCY_FUND
- [ ] Executar migração em ambiente de teste
- [ ] Criar testes unitários
- [ ] Criar testes de integração
- [ ] Documentar breaking changes (se houver)

---

## Notas Adicionais

### Breaking Changes

1. **Remoção de EMERGENCY_FUND**: Clientes antigos que enviem `goal_type: 'EMERGENCY_FUND'` receberão erro. Considerar aceitar temporariamente e converter para SAVINGS no backend.

### Rollback

Em caso de problemas:
1. Reverter migração de EMERGENCY_FUND (não possível após execução)
2. Manter validação de EMERGENCY_FUND no backend
3. Restaurar enum no frontend

### Monitoramento

Após deploy, monitorar:
- Erros em criação de metas
- Performance dos signals (tempo de execução)
- Queries geradas por update de metas
