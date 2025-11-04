# Implementação de Seleção de Categorias em Metas

## Resumo das Alterações

Este documento descreve as alterações implementadas para permitir a seleção de múltiplas categorias em metas com atualização automática, especialmente para tipos como "Juntar Dinheiro" e "Reduzir Dívidas".

## Backend (API Django)

### 1. Modelo Goal (`finance/models.py`)

**Alterações:**
- Adicionado campo `tracked_categories` (ManyToManyField) para permitir seleção de múltiplas categorias
- Mantido campo `target_category` para retrocompatibilidade com metas CATEGORY_EXPENSE/INCOME
- Atualizado método `get_related_transactions()` para suportar:
  - Para `SAVINGS`: usa categorias monitoradas se definidas, senão usa SAVINGS + INVESTMENT (padrão)
  - Para `DEBT_REDUCTION`: usa categorias monitoradas se definidas, senão usa todas as DEBT (padrão)
  - Para `CATEGORY_EXPENSE/INCOME`: continua usando `target_category` (retrocompatibilidade)

**Lógica:**
```python
if self.goal_type == self.GoalType.SAVINGS:
    if self.tracked_categories.exists():
        qs = qs.filter(category__in=self.tracked_categories.all())
    else:
        # Comportamento padrão: SAVINGS e INVESTMENT
        qs = qs.filter(
            category__group__in=[Category.CategoryGroup.SAVINGS, Category.CategoryGroup.INVESTMENT]
        )
```

### 2. Migration (`finance/migrations/0019_goal_tracked_categories.py`)

**Criada:**
- Adiciona campo `tracked_categories` (ManyToMany)
- Atualiza descrição de `target_category` para indicar uso em retrocompatibilidade

### 3. Serializer (`finance/serializers.py`)

**Alterações:**
- Adicionado campo `tracked_category_ids` (write_only) para receber IDs das categorias
- Adicionado campo `tracked_categories_data` (read_only) para retornar dados completos das categorias
- Método `get_tracked_categories_data()` retorna lista com id, name e icon de cada categoria
- Atualizado `create()` e `update()` para gerenciar o relacionamento ManyToMany
- Validações adicionadas para garantir que usuário não use categorias de outros usuários

**Exemplo de resposta:**
```json
{
  "id": 1,
  "title": "Juntar para Viagem",
  "goal_type": "SAVINGS",
  "tracked_categories_data": [
    {"id": 5, "name": "Poupança", "icon": "💰"},
    {"id": 8, "name": "Investimentos", "icon": "📈"}
  ],
  "auto_update": true
}
```

## Frontend (Flutter)

### 1. Modelo GoalModel (`lib/core/models/goal.dart`)

**Alterações:**
- Adicionada classe `TrackedCategory` para representar categorias monitoradas
- Campo `trackedCategories` (List<TrackedCategory>) adicionado ao GoalModel
- Parser atualizado para extrair `tracked_categories_data` do JSON

**Nova classe:**
```dart
class TrackedCategory {
  final int id;
  final String name;
  final String icon;
}
```

### 2. Repository (`lib/core/repositories/finance_repository.dart`)

**Alterações:**
- Adicionado parâmetro `trackedCategoryIds` em `createGoal()`
- Adicionado parâmetro `trackedCategoryIds` em `updateGoal()`
- Payload enviado inclui `tracked_category_ids` quando não vazio

### 3. UI - Dialog de Metas (`lib/features/progress/presentation/pages/progress_page.dart`)

**Alterações:**
- Variável `selectedTrackedCategoryIds` (Set<int>) para armazenar seleções
- Variáveis de controle:
  - `needsSingleCategory`: true para CATEGORY_EXPENSE/INCOME
  - `allowsMultipleCategories`: true para SAVINGS/DEBT_REDUCTION

**Nova UI:**
1. **Seletor de Categoria Única** (CATEGORY_EXPENSE/INCOME):
   - Dropdown tradicional
   - Obrigatório

2. **Seletor de Múltiplas Categorias** (SAVINGS/DEBT_REDUCTION):
   - Apenas visível quando `auto_update = true`
   - CheckboxListTile para cada categoria
   - Opcional (se vazio, usa comportamento padrão)
   - Visual com cor da categoria e nome
   - Container com scroll (max height: 200px)

**Fluxo de Uso:**

1. **Criar Meta "Juntar Dinheiro":**
   - Usuário seleciona tipo "Juntar Dinheiro"
   - Ativa "Atualização Automática"
   - Aparece lista de categorias com checkboxes
   - Pode selecionar categorias específicas (ex: Poupança, Investimentos)
   - Ou deixar vazio para monitorar todas SAVINGS + INVESTMENT

2. **Criar Meta "Reduzir Dívidas":**
   - Usuário seleciona tipo "Reduzir Dívidas"
   - Ativa "Atualização Automática"
   - Aparece lista de categorias com checkboxes
   - Pode selecionar categorias específicas de dívidas
   - Ou deixar vazio para monitorar todas DEBT

## Comportamento

### Com Categorias Selecionadas
- Meta monitora **apenas** as categorias selecionadas
- Transações de outras categorias (mesmo do mesmo grupo) são ignoradas

### Sem Categorias Selecionadas (Padrão)
- **SAVINGS**: monitora todas as categorias dos grupos SAVINGS + INVESTMENT
- **DEBT_REDUCTION**: monitora todas as categorias do grupo DEBT

### Retrocompatibilidade
- Metas antigas continuam funcionando
- Metas CATEGORY_EXPENSE/INCOME mantêm comportamento original com `target_category`

## Validações

### Backend
1. Categorias devem pertencer ao usuário ou serem globais
2. CATEGORY_EXPENSE/INCOME requerem `target_category`
3. Validação de ownership de categorias em `tracked_categories`

### Frontend
1. CATEGORY_EXPENSE/INCOME requerem seleção de categoria única
2. Seleção múltipla apenas disponível com `auto_update = true`
3. Validação visual: checkboxes destacados com cor primária

## Próximos Passos

1. **Executar Migration:**
   ```bash
   cd Api
   python manage.py migrate
   ```

2. **Testar Funcionalidades:**
   - Criar meta "Juntar Dinheiro" com categorias específicas
   - Criar meta "Juntar Dinheiro" sem categorias (padrão)
   - Verificar cálculo correto de progresso
   - Testar edição de metas existentes

3. **Melhorias Futuras (Opcional):**
   - Adicionar filtro de categorias por tipo (mostrar apenas INCOME, EXPENSE, etc)
   - Adicionar "Selecionar Todas" / "Limpar Seleção"
   - Indicador visual de quantas categorias selecionadas
   - Preview do valor atual das categorias selecionadas

## Arquivos Modificados

### Backend
- `Api/finance/models.py`
- `Api/finance/serializers.py`
- `Api/finance/migrations/0019_goal_tracked_categories.py` (novo)

### Frontend
- `Front/lib/core/models/goal.dart`
- `Front/lib/core/repositories/finance_repository.dart`
- `Front/lib/features/progress/presentation/pages/progress_page.dart`

## Exemplo de Uso Completo

```dart
// Criando meta "Juntar Dinheiro" com categorias específicas
await _repository.createGoal(
  title: 'Viagem de Férias',
  targetAmount: 5000.0,
  goalType: 'SAVINGS',
  autoUpdate: true,
  trackedCategoryIds: [5, 8], // Poupança e Investimentos
  trackingPeriod: 'TOTAL',
);
```

```python
# Backend processa e salva
goal = Goal.objects.create(
    user=user,
    title='Viagem de Férias',
    target_amount=5000.0,
    goal_type='SAVINGS',
    auto_update=True,
    tracking_period='TOTAL'
)
goal.tracked_categories.set([5, 8])

# Cálculo automático considera apenas categorias 5 e 8
transactions = Transaction.objects.filter(
    user=user,
    category__in=[5, 8],
    date__range=[start_date, end_date]
)
```
