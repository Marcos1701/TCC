# 🎯 Plano de Melhoria - Sistema de Metas

## 📋 Análise da Situação Atual

### Modelo Atual (Goal)
```python
class Goal(models.Model):
    user = ForeignKey
    title = CharField(150)
    description = TextField
    target_amount = Decimal
    current_amount = Decimal
    deadline = DateField (nullable)
    created_at = DateTimeField
    updated_at = DateTimeField
```

### Limitações Identificadas
1. **Atualização Manual**: `current_amount` precisa ser atualizado manualmente pelo usuário
2. **Sem Vinculação com Categorias**: Não há relação entre metas e categorias de transação
3. **Tipo Genérico**: Todas as metas são tratadas igualmente (apenas valores monetários)
4. **Falta de Contexto**: Não há tracking de período ou histórico de progresso

## 🎯 Objetivos da Melhoria

### Simples e Direto
- Permitir criar metas por categoria específica (ex: "Aumentar investimentos em ações")
- Atualizar automaticamente o progresso baseado nas transações
- Manter facilidade de criação e gerenciamento
- Mostrar detalhes relevantes sem complexidade excessiva

## 🏗️ Arquitetura da Solução

### 1. Tipos de Metas Suportadas

#### A. Meta de Economia Geral (SAVINGS)
- **Objetivo**: Juntar X reais até uma data
- **Exemplo**: "Juntar R$ 10.000 para reserva de emergência"
- **Atualização**: Soma de transações de categorias SAVINGS + INVESTMENT

#### B. Meta por Categoria (CATEGORY_EXPENSE / CATEGORY_INCOME)
- **Objetivo**: Reduzir/aumentar gastos em categoria específica
- **Exemplo**: "Reduzir gastos com alimentação para R$ 500/mês"
- **Atualização**: Soma de transações da categoria específica no período

#### C. Meta de Redução de Dívidas (DEBT_REDUCTION)
- **Objetivo**: Reduzir dívidas totais
- **Exemplo**: "Quitar R$ 5.000 em dívidas"
- **Atualização**: Soma de transações de categorias DEBT

#### D. Meta Personalizada (CUSTOM)
- **Objetivo**: Controle manual do usuário
- **Exemplo**: "Meta de fitness - não vinculada automaticamente"
- **Atualização**: Manual apenas

### 2. Campos Adicionados ao Modelo Goal

```python
class Goal(models.Model):
    # ... campos existentes ...
    
    # NOVOS CAMPOS
    goal_type = models.CharField(
        max_length=20,
        choices=GoalType.choices,
        default='CUSTOM'
    )
    target_category = models.ForeignKey(
        Category, 
        null=True, 
        blank=True,
        on_delete=models.SET_NULL,
        help_text="Categoria vinculada (para metas CATEGORY_*)"
    )
    auto_update = models.BooleanField(
        default=False,
        help_text="Atualizar automaticamente com transações"
    )
    tracking_period = models.CharField(
        max_length=10,
        choices=TrackingPeriod.choices,
        default='TOTAL',
        help_text="MONTHLY, QUARTERLY, TOTAL"
    )
    is_reduction_goal = models.BooleanField(
        default=False,
        help_text="True se o objetivo é reduzir (gastos/dívidas)"
    )
```

### 3. Lógica de Atualização Automática

```python
def update_goal_progress(goal: Goal) -> None:
    """
    Atualiza o progresso da meta baseado nas transações.
    Chamado após criar/atualizar/deletar transação.
    """
    if not goal.auto_update:
        return
    
    user = goal.user
    
    # Definir período de análise
    if goal.tracking_period == 'MONTHLY':
        start_date = timezone.now().replace(day=1)
    elif goal.tracking_period == 'QUARTERLY':
        # Lógica de trimestre
        pass
    else:  # TOTAL
        start_date = goal.created_at.date()
    
    end_date = goal.deadline or timezone.now().date()
    
    # Buscar transações relevantes
    if goal.goal_type == 'SAVINGS':
        # Soma de SAVINGS + INVESTMENT
        transactions = Transaction.objects.filter(
            user=user,
            date__range=[start_date, end_date],
            category__group__in=['SAVINGS', 'INVESTMENT']
        )
        
    elif goal.goal_type == 'CATEGORY_EXPENSE':
        # Gastos em categoria específica
        transactions = Transaction.objects.filter(
            user=user,
            date__range=[start_date, end_date],
            category=goal.target_category,
            type='EXPENSE'
        )
        
    elif goal.goal_type == 'CATEGORY_INCOME':
        # Receitas em categoria específica
        transactions = Transaction.objects.filter(
            user=user,
            date__range=[start_date, end_date],
            category=goal.target_category,
            type='INCOME'
        )
        
    elif goal.goal_type == 'DEBT_REDUCTION':
        # Soma de pagamentos de dívidas
        transactions = Transaction.objects.filter(
            user=user,
            date__range=[start_date, end_date],
            category__group='DEBT'
        )
    
    else:  # CUSTOM
        return
    
    # Calcular progresso
    total = transactions.aggregate(
        total=models.Sum('amount')
    )['total'] or Decimal('0.00')
    
    # Para metas de redução, inverter lógica
    if goal.is_reduction_goal:
        # Se o objetivo é reduzir gastos de 1000 para 500
        # current = quanto reduziu (quanto deixou de gastar)
        goal.current_amount = max(Decimal('0.00'), goal.target_amount - total)
    else:
        goal.current_amount = total
    
    goal.save(update_fields=['current_amount', 'updated_at'])
```

### 4. Interface do Usuário (Flutter)

#### Fluxo de Criação de Meta

```
1. Selecionar Tipo de Meta
   ├── 💰 Juntar Dinheiro (SAVINGS)
   ├── 📉 Reduzir Gastos por Categoria
   ├── 📈 Aumentar Receita por Categoria  
   ├── 💳 Reduzir Dívidas
   └── ✏️ Personalizada

2. Configurar Detalhes
   - Título da Meta
   - Descrição (opcional)
   - Valor Alvo
   - Data Limite (opcional)
   - [Se categoria] Selecionar Categoria
   - [Se categoria] Período de Tracking (Mensal/Trimestral/Total)
   - Toggle: Atualização Automática

3. Confirmar e Criar
```

#### Visualização de Meta (Card)

```
┌─────────────────────────────────────┐
│ 🎯 Reduzir Alimentação              │
│ Meta: R$ 500,00 / mês               │
│                                     │
│ ████████░░░░ 65% (R$ 325,00)       │
│                                     │
│ 📊 15 transações este mês           │
│ 📅 Faltam 12 dias                   │
│ ✅ Atualização automática           │
└─────────────────────────────────────┘
```

#### Tela de Detalhes da Meta

```
┌─────────────────────────────────────┐
│ ← Reduzir Alimentação           ... │
├─────────────────────────────────────┤
│                                     │
│     ████████░░░░ 65%                │
│     R$ 325,00 de R$ 500,00          │
│                                     │
│ 📈 Progresso Mensal                 │
│ [Gráfico de barras por mês]        │
│                                     │
│ 📝 Transações Relacionadas (15)     │
│ ┌─────────────────────────────────┐ │
│ │ 01/11 - Supermercado - R$ 85,00 │ │
│ │ 02/11 - Restaurante - R$ 45,00  │ │
│ │ 03/11 - Lanchonete - R$ 12,00   │ │
│ └─────────────────────────────────┘ │
│                                     │
│ 💡 Insights                         │
│ • Você está no caminho certo!       │
│ • Evite gastar mais de R$ 175 nos  │
│   próximos 12 dias                  │
└─────────────────────────────────────┘
```

## 📋 Implementação Passo a Passo

### Backend (Django)

#### Passo 1: Atualizar Models
```python
# finance/models.py

class Goal(models.Model):
    class GoalType(models.TextChoices):
        SAVINGS = "SAVINGS", "Juntar Dinheiro"
        CATEGORY_EXPENSE = "CATEGORY_EXPENSE", "Reduzir Gastos"
        CATEGORY_INCOME = "CATEGORY_INCOME", "Aumentar Receita"
        DEBT_REDUCTION = "DEBT_REDUCTION", "Reduzir Dívidas"
        CUSTOM = "CUSTOM", "Personalizada"
    
    class TrackingPeriod(models.TextChoices):
        MONTHLY = "MONTHLY", "Mensal"
        QUARTERLY = "QUARTERLY", "Trimestral"
        TOTAL = "TOTAL", "Total"
    
    # Campos existentes...
    user = models.ForeignKey(...)
    title = models.CharField(max_length=150)
    description = models.TextField(blank=True)
    target_amount = models.DecimalField(max_digits=12, decimal_places=2)
    current_amount = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    deadline = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # Novos campos
    goal_type = models.CharField(
        max_length=20,
        choices=GoalType.choices,
        default=GoalType.CUSTOM
    )
    target_category = models.ForeignKey(
        Category,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="goals"
    )
    auto_update = models.BooleanField(default=False)
    tracking_period = models.CharField(
        max_length=10,
        choices=TrackingPeriod.choices,
        default=TrackingPeriod.TOTAL
    )
    is_reduction_goal = models.BooleanField(default=False)
    
    @property
    def progress_percentage(self) -> float:
        if self.target_amount == 0:
            return 0
        return min(100, (float(self.current_amount) / float(self.target_amount)) * 100)
    
    def get_related_transactions(self, start_date=None, end_date=None):
        """Retorna transações relacionadas a esta meta."""
        # Implementar lógica similar ao update_goal_progress
        pass
```

#### Passo 2: Migration
```bash
python manage.py makemigrations finance -n "extend_goal_model"
python manage.py migrate
```

#### Passo 3: Services
```python
# finance/services.py

def update_goal_progress(goal: Goal) -> None:
    """Implementar conforme descrito acima"""
    pass

def update_all_active_goals(user) -> None:
    """Atualiza todas as metas com auto_update=True do usuário."""
    goals = Goal.objects.filter(user=user, auto_update=True)
    for goal in goals:
        update_goal_progress(goal)
```

#### Passo 4: Signals
```python
# finance/signals.py

@receiver(post_save, sender=Transaction)
def update_goals_on_transaction_change(sender, instance, created, **kwargs):
    """Atualiza metas quando uma transação é criada/atualizada."""
    update_all_active_goals(instance.user)

@receiver(post_delete, sender=Transaction)
def update_goals_on_transaction_delete(sender, instance, **kwargs):
    """Atualiza metas quando uma transação é deletada."""
    update_all_active_goals(instance.user)
```

#### Passo 5: Serializers
```python
# finance/serializers.py

class GoalSerializer(serializers.ModelSerializer):
    progress_percentage = serializers.FloatField(read_only=True)
    category_name = serializers.CharField(source='target_category.name', read_only=True)
    
    class Meta:
        model = Goal
        fields = (
            "id",
            "title",
            "description",
            "target_amount",
            "current_amount",
            "deadline",
            "goal_type",
            "target_category",
            "category_name",
            "auto_update",
            "tracking_period",
            "is_reduction_goal",
            "progress_percentage",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("current_amount",)  # Apenas auto_update modifica
    
    def validate(self, attrs):
        # Validar que CATEGORY_* tem target_category
        goal_type = attrs.get('goal_type')
        target_category = attrs.get('target_category')
        
        if goal_type in ['CATEGORY_EXPENSE', 'CATEGORY_INCOME']:
            if not target_category:
                raise serializers.ValidationError(
                    "Metas por categoria precisam de uma categoria vinculada"
                )
        
        return attrs
```

#### Passo 6: Views
```python
# finance/views.py

class GoalViewSet(viewsets.ModelViewSet):
    serializer_class = GoalSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Goal.objects.filter(user=self.request.user).select_related(
            'target_category'
        ).order_by("-created_at")
    
    @action(detail=True, methods=['get'])
    def transactions(self, request, pk=None):
        """Retorna transações relacionadas à meta."""
        goal = self.get_object()
        
        # Implementar lógica para buscar transações
        transactions = goal.get_related_transactions()
        
        serializer = TransactionSerializer(transactions, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def refresh(self, request, pk=None):
        """Força atualização do progresso da meta."""
        goal = self.get_object()
        
        if goal.auto_update:
            update_goal_progress(goal)
            goal.refresh_from_db()
        
        serializer = self.get_serializer(goal)
        return Response(serializer.data)
```

### Frontend (Flutter)

#### Passo 1: Atualizar Model
```dart
// lib/core/models/goal.dart

enum GoalType {
  savings,
  categoryExpense,
  categoryIncome,
  debtReduction,
  custom,
}

enum TrackingPeriod {
  monthly,
  quarterly,
  total,
}

class GoalModel {
  const GoalModel({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.currentAmount,
    this.deadline,
    required this.goalType,
    this.targetCategory,
    this.categoryName,
    required this.autoUpdate,
    required this.trackingPeriod,
    required this.isReductionGoal,
    required this.progressPercentage,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String description;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  final GoalType goalType;
  final int? targetCategory;
  final String? categoryName;
  final bool autoUpdate;
  final TrackingPeriod trackingPeriod;
  final bool isReductionGoal;
  final double progressPercentage;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'] as int,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      targetAmount: double.parse(map['target_amount'].toString()),
      currentAmount: double.parse(map['current_amount'].toString()),
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'] as String)
          : null,
      goalType: _parseGoalType(map['goal_type'] as String?),
      targetCategory: map['target_category'] as int?,
      categoryName: map['category_name'] as String?,
      autoUpdate: (map['auto_update'] as bool?) ?? false,
      trackingPeriod: _parseTrackingPeriod(map['tracking_period'] as String?),
      isReductionGoal: (map['is_reduction_goal'] as bool?) ?? false,
      progressPercentage: double.parse(map['progress_percentage']?.toString() ?? '0'),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
  
  static GoalType _parseGoalType(String? value) {
    switch (value?.toUpperCase()) {
      case 'SAVINGS': return GoalType.savings;
      case 'CATEGORY_EXPENSE': return GoalType.categoryExpense;
      case 'CATEGORY_INCOME': return GoalType.categoryIncome;
      case 'DEBT_REDUCTION': return GoalType.debtReduction;
      default: return GoalType.custom;
    }
  }
  
  static TrackingPeriod _parseTrackingPeriod(String? value) {
    switch (value?.toUpperCase()) {
      case 'MONTHLY': return TrackingPeriod.monthly;
      case 'QUARTERLY': return TrackingPeriod.quarterly;
      default: return TrackingPeriod.total;
    }
  }
}
```

#### Passo 2: Atualizar Repository
```dart
// lib/core/repositories/finance_repository.dart

Future<GoalModel> createGoal({
  required String title,
  String description = '',
  required double targetAmount,
  DateTime? deadline,
  required String goalType,
  int? targetCategoryId,
  bool autoUpdate = false,
  String trackingPeriod = 'TOTAL',
  bool isReductionGoal = false,
}) async {
  final payload = {
    'title': title,
    'description': description,
    'target_amount': targetAmount,
    if (deadline != null)
      'deadline': deadline.toIso8601String().split('T').first,
    'goal_type': goalType,
    if (targetCategoryId != null)
      'target_category': targetCategoryId,
    'auto_update': autoUpdate,
    'tracking_period': trackingPeriod,
    'is_reduction_goal': isReductionGoal,
  };
  
  final response = await _client.client.post<Map<String, dynamic>>(
    ApiEndpoints.goals,
    data: payload,
  );
  
  return GoalModel.fromMap(response.data!);
}
```

## 🎨 Exemplos de Uso

### Exemplo 1: Meta de Investimento
```
Tipo: SAVINGS
Título: "Aumentar investimentos"
Valor: R$ 10.000
Período: 6 meses
Auto-update: SIM

→ Sistema soma automaticamente transações de SAVINGS + INVESTMENT
```

### Exemplo 2: Meta de Redução de Gastos
```
Tipo: CATEGORY_EXPENSE
Título: "Economizar em alimentação"
Categoria: Alimentação
Valor alvo: R$ 500 (mensal)
Tracking: MONTHLY
Is Reduction: SIM
Auto-update: SIM

→ Sistema monitora gastos mensais em alimentação
→ Mostra se está dentro da meta
```

### Exemplo 3: Meta de Quitação de Dívidas
```
Tipo: DEBT_REDUCTION
Título: "Quitar dívidas do cartão"
Valor: R$ 5.000
Prazo: 12 meses
Auto-update: SIM

→ Sistema soma pagamentos em categorias DEBT
→ Mostra quanto já foi quitado
```

## ✅ Benefícios da Solução

1. **Simplicidade**: Tipos claros e intuitivos de metas
2. **Automação**: Atualização automática via transações
3. **Flexibilidade**: Suporta metas personalizadas também
4. **Contexto**: Mostra transações relacionadas
5. **Motivação**: Progresso visual e insights
6. **Manutenibilidade**: Código organizado e testável

## 🚀 Próximos Passos

1. ✅ Criar este documento de planejamento
2. ⏳ Implementar backend (models + services)
3. ⏳ Criar migrations
4. ⏳ Atualizar serializers e views
5. ⏳ Implementar frontend (models + UI)
6. ⏳ Testar fluxo completo
7. ⏳ Documentar uso para usuários

---

**Nota**: Este plano prioriza simplicidade e utilidade. Funcionalidades avançadas (previsões, ML, orçamentos complexos) foram intencionalmente deixadas de fora para manter o sistema acessível e fácil de usar.
