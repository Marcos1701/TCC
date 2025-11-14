# 🎯 Plano de Refatoração do Sistema de Missões

**Data de Criação:** 13 de novembro de 2025  
**Status Geral:** 🟢 Em Progresso  
**Progresso Global:** 60% (6/10 sprints)

---

## 📋 Índice
1. [Objetivo](#objetivo)
2. [Análise do Estado Atual](#análise-do-estado-atual)
3. [Alterações Necessárias](#alterações-necessárias)
4. [Sprints de Implementação](#sprints-de-implementação)
5. [Checklist de Validação](#checklist-de-validação)
6. [Notas e Decisões](#notas-e-decisões)

---

## 🎯 Objetivo

Refatorar o sistema de missões para focar **exclusivamente** em aspectos financeiros:

### ✅ Incluir
- Transações (receitas/despesas)
- Pagamentos vinculados
- Categorias específicas
- Metas financeiras
- Indicadores (TPS, RDR, ILI)
- Comportamentos financeiros (poupança, redução de gastos)

### ❌ Remover
- Missões sociais (adicionar amigos, leaderboard)
- Missões fora do escopo financeiro

---

## 📊 Análise do Estado Atual

### ✅ Pontos Positivos
- [x] Arquitetura sólida com validators especializados por tipo
- [x] Factory Pattern para criação de validators
- [x] Tracking de métricas (TPS, RDR, ILI) bem implementado
- [x] Validation types flexíveis e extensíveis

### ⚠️ Problemas Identificados
- [ ] Tipos de missão muito genéricos (ONBOARDING, ADVANCED)
- [ ] Falta de missões específicas por categoria
- [ ] Ausência de missões relacionadas a metas
- [ ] Lógica de atribuição pode gerar missões irrelevantes
- [ ] Frontend com lógica duplicada de tipos
- [ ] Missões sociais ainda presentes no código

---

## 🔧 Alterações Necessárias

### FASE 1: Reestruturação do Modelo (Backend)
**Arquivos Afetados:**
- `Api/finance/models.py`
- `Api/finance/migrations/XXXX_refactor_mission_system.py`

#### 1.1 Novos Tipos de Missão

```python
class MissionType(models.TextChoices):
    # Básicas - Introdução
    ONBOARDING_TRANSACTIONS = "ONBOARDING_TRANSACTIONS", "Primeiros passos: Transações"
    ONBOARDING_CATEGORIES = "ONBOARDING_CATEGORIES", "Primeiros passos: Categorias"
    ONBOARDING_GOALS = "ONBOARDING_GOALS", "Primeiros passos: Metas"
    
    # Indicadores - Melhoria de índices
    TPS_IMPROVEMENT = "TPS_IMPROVEMENT", "Aumentar poupança (TPS)"
    RDR_REDUCTION = "RDR_REDUCTION", "Reduzir dívidas (RDR)"
    ILI_BUILDING = "ILI_BUILDING", "Construir reserva (ILI)"
    
    # Categorias - Controle de gastos
    CATEGORY_REDUCTION = "CATEGORY_REDUCTION", "Reduzir gastos em categoria"
    CATEGORY_SPENDING_LIMIT = "CATEGORY_SPENDING_LIMIT", "Manter limite de categoria"
    CATEGORY_ELIMINATION = "CATEGORY_ELIMINATION", "Eliminar gastos supérfluos"
    
    # Metas - Progresso
    GOAL_ACHIEVEMENT = "GOAL_ACHIEVEMENT", "Completar meta"
    GOAL_CONSISTENCY = "GOAL_CONSISTENCY", "Contribuir regularmente"
    GOAL_ACCELERATION = "GOAL_ACCELERATION", "Acelerar progresso de meta"
    
    # Comportamento - Hábitos financeiros
    SAVINGS_STREAK = "SAVINGS_STREAK", "Sequência de poupança"
    EXPENSE_CONTROL = "EXPENSE_CONTROL", "Controlar gastos mensais"
    INCOME_TRACKING = "INCOME_TRACKING", "Registrar receitas"
    PAYMENT_DISCIPLINE = "PAYMENT_DISCIPLINE", "Pagar contas em dia"
    
    # Avançadas - Múltiplos critérios
    FINANCIAL_HEALTH = "FINANCIAL_HEALTH", "Saúde financeira completa"
    WEALTH_BUILDING = "WEALTH_BUILDING", "Construção de patrimônio"
```

#### 1.2 Novos Validation Types

```python
class ValidationType(models.TextChoices):
    # Já existentes
    SNAPSHOT = "SNAPSHOT", "Comparação inicial vs atual"
    TEMPORAL = "TEMPORAL", "Manter critério por período"
    
    # Específicos para categorias
    CATEGORY_REDUCTION = "CATEGORY_REDUCTION", "Reduzir X% em categoria"
    CATEGORY_LIMIT = "CATEGORY_LIMIT", "Não exceder R$ em categoria"
    CATEGORY_ZERO = "CATEGORY_ZERO", "Zero gastos em categoria"
    
    # Específicos para metas
    GOAL_PROGRESS = "GOAL_PROGRESS", "Atingir X% de progresso"
    GOAL_CONTRIBUTION = "GOAL_CONTRIBUTION", "Contribuir R$ para meta"
    GOAL_COMPLETION = "GOAL_COMPLETION", "Completar meta 100%"
    
    # Específicos para transações
    TRANSACTION_COUNT = "TRANSACTION_COUNT", "Registrar X transações"
    TRANSACTION_CONSISTENCY = "TRANSACTION_CONSISTENCY", "X transações/semana"
    PAYMENT_COUNT = "PAYMENT_COUNT", "Registrar X pagamentos"
    
    # Específicos para indicadores
    INDICATOR_THRESHOLD = "INDICATOR_THRESHOLD", "Atingir valor de indicador"
    INDICATOR_IMPROVEMENT = "INDICATOR_IMPROVEMENT", "Melhorar indicador em X%"
    INDICATOR_MAINTENANCE = "INDICATOR_MAINTENANCE", "Manter indicador por X dias"
    
    # Combinados
    MULTI_CRITERIA = "MULTI_CRITERIA", "Múltiplos critérios simultâneos"
```

#### 1.3 Campos Adicionais no Modelo Mission

```python
# Campos para tracking de transações
min_transaction_frequency = models.PositiveIntegerField(
    null=True, blank=True,
    help_text="Frequência mínima de transações (por semana)"
)
transaction_type_filter = models.CharField(
    max_length=20,
    choices=[('INCOME', 'Receitas'), ('EXPENSE', 'Despesas'), ('BOTH', 'Ambos')],
    default='BOTH'
)

# Campos para múltiplas categorias alvo
target_categories = models.ManyToManyField(
    'Category',
    blank=True,
    related_name='targeted_by_missions'
)

# Campos para múltiplas metas
target_goals = models.ManyToManyField(
    'Goal',
    blank=True,
    related_name='targeted_by_missions'
)

# Campos para pagamentos
requires_payment_tracking = models.BooleanField(default=False)
min_payments_count = models.PositiveIntegerField(null=True, blank=True)

# Metadata para contexto
is_system_generated = models.BooleanField(
    default=True,
    help_text="Se foi gerada pelo sistema (vs criada manualmente/admin)"
)
generation_context = models.JSONField(
    default=dict,
    blank=True,
    help_text="Contexto que gerou esta missão (índices, categorias, etc)"
)
```

---

### FASE 2: Novos Validators (Backend)
**Arquivos Afetados:**
- `Api/finance/mission_types.py`

#### 2.1 Validators a Implementar

- [ ] **CategoryReductionValidator**
  - Calcula redução percentual de gastos em categoria específica
  - Compara período atual vs período anterior
  - Tracking de transações por categoria

- [ ] **CategoryLimitValidator**
  - Verifica se gastos em categoria ficaram abaixo do limite
  - Tracking diário/semanal
  - Alertas quando próximo do limite

- [ ] **GoalProgressValidator**
  - Calcula progresso atual da meta
  - Verifica contribuições regulares
  - Tracking de velocidade de progresso

- [ ] **GoalContributionValidator**
  - Rastreia contribuições financeiras para a meta
  - Valida montantes e frequência
  - Calcula impacto no prazo da meta

- [ ] **TransactionConsistencyValidator**
  - Verifica frequência de registro
  - Detecta padrões (diário, semanal)
  - Streak de dias consecutivos

- [ ] **PaymentDisciplineValidator**
  - Rastreia pagamentos vinculados
  - Verifica pontualidade
  - Tracking de contas pagas vs pendentes

- [ ] **IndicatorMaintenanceValidator**
  - Mantém indicador em faixa específica por período
  - Tracking diário de conformidade
  - Detecção de quebras de streak

- [ ] **MultiCriteriaValidator**
  - Combina múltiplos indicadores
  - Pesos por critério
  - Sistema de pontuação progressivo

#### 2.2 Estrutura Base dos Novos Validators

```python
class CategoryReductionValidator(BaseMissionValidator):
    """
    Validador para missões de redução de gastos em categoria específica.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        # 1. Buscar transações da categoria no período
        # 2. Comparar com período anterior (mesmo número de dias)
        # 3. Calcular % de redução
        # 4. Retornar progresso e métricas detalhadas
        pass
        
    def validate_completion(self) -> Tuple[bool, str]:
        # Verificar se redução atingiu o target_reduction_percent
        pass
```

---

### FASE 3: Lógica de Atribuição Contextual (Baseada em Regras)
**Arquivos Afetados:**
- `Api/finance/services.py`

#### 3.1 Funções a Implementar

- [ ] `analyze_user_context(user) -> Dict[str, Any]` *(regras determinísticas)*
  - Transações recentes (últimos 30 dias)
  - Categorias com maior gasto
  - Metas próximas de vencer
  - Indicadores em risco (TPS, RDR, ILI)
  - Padrões temporais e frequência

- [ ] `calculate_mission_priorities(context) -> List[Tuple[Mission, float]]` *(score baseado em regras)*
  - Score de relevância por missão
  - Baseado em impacto potencial nos indicadores
  - Considerando dificuldade e prazo
  - Alinhamento com perfil do usuário

- [ ] `assign_missions_smartly(user) -> List[MissionProgress]` *(atribuição contextual)*
  - Usa análise de contexto baseada em regras
  - Limita a 3 missões ativas simultaneamente
  - Evita missões muito similares
  - Prioriza oportunidades identificadas

- [ ] `identify_improvement_opportunities(user) -> List[Dict]` *(detecção de padrões)*
  - Categorias com gasto crescente
  - Metas estagnadas
  - Indicadores em declínio

**Nota:** A IA é utilizada separadamente para **geração em lote** de missões via `ai_services.py`, considerando diferentes contextos/perfis.

---

### FASE 4: Templates de Missões
**Arquivos Afetados:**
- `Api/finance/mission_templates.py` (novo arquivo)
- `Api/finance/management/commands/seed_mission_templates.py` (novo)

#### 4.1 Templates por Categoria

```python
MISSION_TEMPLATES = {
    # Redução de gastos por categoria
    'reduce_food_expenses': {
        'type': 'CATEGORY_REDUCTION',
        'validation_type': 'CATEGORY_REDUCTION',
        'title': 'Reduzir Gastos com Alimentação',
        'description': 'Reduza seus gastos com alimentação em {target}% este mês',
        'target_reduction_percent': 15,
        'category_slug': 'food',
        'duration_days': 30,
        'reward_points': 100,
        'difficulty': 'MEDIUM',
    },
    'reduce_transport_expenses': {...},
    'reduce_entertainment_expenses': {...},
    
    # Construção de reserva
    'build_emergency_fund': {
        'type': 'ILI_BUILDING',
        'validation_type': 'INDICATOR_THRESHOLD',
        'title': 'Construir Reserva de Emergência',
        'description': 'Alcance {target} meses de reserva de emergência',
        'min_ili': 3.0,
        'duration_days': 90,
        'reward_points': 300,
        'difficulty': 'HARD',
    },
    
    # Metas de poupança
    'increase_savings_rate': {...},
    'maintain_positive_balance': {...},
    
    # Pagamentos
    'pay_bills_on_time': {...},
    'track_recurring_payments': {...},
    
    # Transações
    'daily_tracking_habit': {...},
    'categorize_all_expenses': {...},
}
```

#### 4.2 Geração Dinâmica

- [ ] `generate_mission_from_template(template_key, user, custom_params)` *(usa IA para personalização)*
- [ ] `personalize_template(template, user)` *(adapta template ao contexto do usuário)*
- [ ] `validate_template_params(template)` *(validação estrutural)*

**Nota:** Templates servem de base para geração em lote via IA, garantindo variedade e coerência nas missões criadas para diferentes perfis/contextos.

---

### FASE 5: API e Serializers
**Arquivos Afetados:**
- `Api/finance/views.py`
- `Api/finance/serializers.py`
- `Api/finance/urls.py`

#### 5.1 Novos Endpoints

- [ ] `GET /api/missions/recommend/`
  - Retorna missões recomendadas baseadas em análise de contexto
  - Filtros: tipo, dificuldade, categoria

- [ ] `GET /api/missions/by-category/<category_id>/`
  - Missões disponíveis para categoria específica
  - Inclui templates personalizáveis

- [ ] `GET /api/missions/by-goal/<goal_id>/`
  - Missões relacionadas a meta específica
  - Sugere missões para acelerar progresso

- [ ] `GET /api/missions/context-analysis/`
  - Análise de contexto do usuário
  - Oportunidades de melhoria identificadas

- [ ] `GET /api/missions/templates/` (admin only)
  - Lista templates disponíveis
  - Permite preview antes de gerar

- [ ] `POST /api/missions/generate-from-template/` (admin only)
  - Gera missão personalizada de template
  - Permite override de parâmetros

#### 5.2 Serializers Aprimorados

```python
class MissionSerializer(serializers.ModelSerializer):
    # Campos computados
    is_suitable_for_user = serializers.SerializerMethodField()
    estimated_completion_date = serializers.SerializerMethodField()
    difficulty_score = serializers.SerializerMethodField()
    related_categories = CategorySerializer(many=True, source='target_categories')
    related_goals = GoalSerializer(many=True, source='target_goals')
    potential_impact = serializers.SerializerMethodField()
    
    class Meta:
        model = Mission
        fields = '__all__'
    
    def get_is_suitable_for_user(self, obj):
        # Verifica se missão é adequada para o usuário atual
        pass
        
    def get_estimated_completion_date(self, obj):
        # Estimativa baseada em padrões do usuário
        pass
        
    def get_potential_impact(self, obj):
        # Impacto estimado nos indicadores
        pass
```

---

### FASE 6: Frontend (Flutter)
**Arquivos Afetados:**
- `Front/lib/core/models/mission.dart`
- `Front/lib/features/missions/data/missions_viewmodel.dart`
- `Front/lib/features/missions/presentation/pages/missions_page.dart`
- `Front/lib/features/missions/presentation/widgets/*` (vários)

#### 6.1 Modelos Atualizados

```dart
class MissionModel {
  // Campos existentes...
  
  // Novos campos
  final List<int>? targetCategoryIds;
  final List<int>? targetGoalIds;
  final String? transactionTypeFilter;
  final int? minTransactionFrequency;
  final bool requiresPaymentTracking;
  final Map<String, dynamic>? generationContext;
  
  // Campos computados da API
  final bool isSuitableForUser;
  final DateTime? estimatedCompletionDate;
  final double difficultyScore;
  final List<CategoryModel>? relatedCategories;
  final List<GoalModel>? relatedGoals;
  final Map<String, dynamic>? potentialImpact;
}
```

#### 6.2 Novos Widgets

- [ ] **MissionRecommendationWidget**
  - Exibe missões recomendadas contextualmente
  - Baseado na tela atual
  - Swipeable cards

- [ ] **CategoryMissionBadge**
  - Badge em cada categoria mostrando missões disponíveis
  - Quick action para iniciar missão
  - Contador visual

- [ ] **GoalMissionPanel**
  - Painel em cada meta sugerindo missões relacionadas
  - Progresso visual integrado
  - Call-to-action destacado

- [ ] **MissionImpactVisualization**
  - Visualização do impacto de completar missão
  - Projeções de indicadores (TPS, RDR, ILI)
  - Gráficos antes/depois

- [ ] **MissionProgressDetailWidget**
  - Detalhamento do progresso com métricas específicas
  - Timeline de atividades
  - Sugestões contextuais

#### 6.3 ViewModels Refatorados

```dart
class MissionsViewModel extends ChangeNotifier {
  // Métodos existentes...
  
  // Novos métodos
  Future<List<MissionModel>> fetchRecommended();
  Future<List<MissionModel>> fetchForCategory(int categoryId);
  Future<List<MissionModel>> fetchForGoal(int goalId);
  Future<MissionImpact> calculateImpact(int missionId);
  Future<ContextAnalysis> fetchContextAnalysis();
  
  // Filtros e ordenação
  List<MissionModel> filterByType(List<String> types);
  List<MissionModel> filterByCategory(int categoryId);
  List<MissionModel> sortByPriority();
  List<MissionModel> sortByDifficulty();
  List<MissionModel> sortByImpact();
}
```

---

### FASE 7: Admin e Gerenciamento
**Arquivos Afetados:**
- `Api/finance/admin.py`
- `Api/finance/views.py` (admin views)

#### 7.1 Interface Admin Aprimorada

```python
class MissionAdmin(admin.ModelAdmin):
    list_display = [
        'title', 'mission_type', 'validation_type',
        'is_active', 'priority', 'reward_points',
        'active_users_count', 'completion_rate'
    ]
    
    list_filter = [
        'mission_type', 'validation_type', 'difficulty',
        'is_active', 'is_system_generated',
        'target_categories', 'target_goals'
    ]
    
    search_fields = ['title', 'description']
    
    readonly_fields = [
        'created_at', 'updated_at',
        'active_users_count', 'completion_rate',
        'average_completion_time'
    ]
    
    fieldsets = (
        ('Básico', {
            'fields': ('title', 'description', 'reward_points', 'difficulty')
        }),
        ('Tipo e Validação', {
            'fields': ('mission_type', 'validation_type', 'priority')
        }),
        ('Alvos', {
            'fields': (
                'target_categories', 'target_goals',
                'target_category', 'target_goal'
            )
        }),
        ('Critérios de Indicadores', {
            'fields': ('target_tps', 'target_rdr', 'min_ili', 'max_ili')
        }),
        ('Critérios de Categoria', {
            'fields': (
                'target_reduction_percent',
                'category_spending_limit'
            )
        }),
        ('Critérios de Meta', {
            'fields': ('goal_progress_target',)
        }),
        ('Critérios de Transação', {
            'fields': (
                'min_transactions',
                'min_transaction_frequency',
                'transaction_type_filter'
            )
        }),
        ('Critérios de Pagamento', {
            'fields': (
                'requires_payment_tracking',
                'min_payments_count'
            )
        }),
        ('Critérios Temporais', {
            'fields': (
                'duration_days',
                'requires_consecutive_days',
                'min_consecutive_days',
                'requires_daily_action',
                'min_daily_actions'
            )
        }),
        ('Gamificação', {
            'fields': ('impacts', 'tips')
        }),
        ('Metadados', {
            'fields': (
                'is_active',
                'is_system_generated',
                'generation_context',
                'created_at',
                'updated_at'
            )
        }),
        ('Estatísticas', {
            'fields': (
                'active_users_count',
                'completion_rate',
                'average_completion_time'
            )
        }),
    )
    
    actions = [
        'duplicate_mission',
        'generate_variations',
        'test_validation',
        'assign_to_selected_users',
        'deactivate_missions',
        'export_analytics'
    ]
```

#### 7.2 Ferramentas de Análise

- [ ] **MissionAnalyticsView** (`/api/admin/missions/analytics/`)
  - Taxa de conclusão por tipo
  - Tempo médio de conclusão
  - Impacto em indicadores (TPS, RDR, ILI)
  - Engagement e abandono
  - Top missões por popularidade

- [ ] **MissionTestingView** (`/api/admin/missions/test/`)
  - Simular validação de missão
  - Testar com dados mockados
  - Verificar lógica de atribuição

---

### FASE 8: Migração e Limpeza
**Arquivos Afetados:**
- `Api/finance/migrations/XXXX_refactor_mission_system.py`
- Vários arquivos para limpeza de código

#### 8.1 Migration Plan

```python
# 0001_refactor_mission_system.py
def forwards(apps, schema_editor):
    Mission = apps.get_model('finance', 'Mission')
    MissionProgress = apps.get_model('finance', 'MissionProgress')
    
    # 1. Adicionar novos campos ao modelo Mission
    # 2. Mapear missões antigas para novos tipos
    # 3. Desativar missões irrelevantes (sociais)
    # 4. Criar missões novas baseadas em templates
    # 5. Atualizar MissionProgress existentes
    # 6. Limpar dados inconsistentes
```

#### 8.2 Limpeza de Código

- [ ] Remover validators não utilizados
- [ ] Remover lógica social de missões
- [ ] Consolidar duplicações
- [ ] Remover imports não utilizados
- [ ] Atualizar docstrings
- [ ] Adicionar type hints completos

---

## 📅 Sprints de Implementação

### Sprint 1: Fundação (2-3 dias)
**Status:** ✅ Concluído  
**Progresso:** 4/4 tarefas

- [x] Atualizar modelo Mission com novos campos
- [x] Criar migration inicial
- [x] Implementar novos MissionTypes
- [x] Implementar novos ValidationTypes

**Arquivos:**
- `Api/finance/models.py`
- `Api/finance/migrations/XXXX_add_mission_fields.py`

---

### Sprint 2: Validators (3-4 dias)
**Status:** ✅ Concluído  
**Progresso:** 8/8 tarefas

- [x] CategoryReductionValidator
- [x] CategoryLimitValidator
- [x] GoalProgressValidator
- [x] GoalContributionValidator
- [x] TransactionConsistencyValidator
- [x] PaymentDisciplineValidator
- [x] IndicatorMaintenanceValidator
- [x] Atualizar MissionValidatorFactory

**Arquivos:**
- `Api/finance/mission_types.py`

---

### Sprint 3: Lógica de Atribuição Contextual (2-3 dias)
**Status:** ✅ Concluído  
**Progresso:** 5/5 tarefas  
**Concluído em:** 14/11/2025

- [x] Implementar análise contextual baseada em regras (`analyze_user_context()`)
- [x] Calcular prioridades de missão por contexto (`calculate_mission_priorities()`)
- [x] Identificar oportunidades de melhoria (`identify_improvement_opportunities()`)
- [x] Sistema de atribuição inteligente por perfil/contexto (`assign_missions_smartly()`)
- [x] Testes unitários completos

**Arquivos:**
- ✅ `Api/finance/services.py` - 4 funções implementadas
- ✅ `Api/finance/tests/test_mission_assignment.py` - 7 test cases

**Implementado:**
- `analyze_user_context()`: Análise completa (transações, categorias, metas, indicadores, padrões)
- `identify_improvement_opportunities()`: Detecta crescimento de gastos, metas estagnadas, indicadores em risco
- `calculate_mission_priorities()`: Score baseado em risco, oportunidades, dificuldade, prioridade
- `assign_missions_smartly()`: Atribuição inteligente com limite de 3 missões ativas, evita duplicatas

---

### Sprint 4: Templates (2 dias)
**Status:** ✅ Concluído  
**Progresso:** 4/4 tarefas  
**Concluído em:** 14/11/2025

- [x] Criar arquivo `mission_templates.py`
- [x] Implementar biblioteca de templates (8 categorias)
- [x] Implementar geração dinâmica via `generate_mission_batch_from_templates`
- [x] Criar comando `seed_missions` (com e sem IA)

**Arquivos:**
- ✅ `Api/finance/mission_templates.py` - 8 tipos de templates
- ✅ `Api/finance/management/commands/seed_missions.py`

**Implementado:**
- Templates: ONBOARDING, TPS, RDR, ILI, CATEGORY, GOAL, BEHAVIOR, ADVANCED
- Comando `python manage.py seed_missions --count 30 --use-ai false`
- Expansão automática de placeholders ({count}, {target}, {percent})

---

### Sprint 5: API Contextual (2-3 dias)
**Status:** ✅ Concluído  
**Progresso:** 7/7 tarefas  
**Concluído em:** 14/11/2025

- [x] Endpoint: `/api/missions/recommend/` (baseado em regras contextuais)
- [x] Endpoint: `/api/missions/by-category/` (query param: category_id)
- [x] Endpoint: `/api/missions/by-goal/` (query param: goal_id)
- [x] Endpoint: `/api/missions/context-analysis/` (análise determinística)
- [x] Endpoint: `/api/missions/generate_template_missions/` (admin)
- [x] Endpoint: `/api/missions/generate_ai_missions/` (admin + IA)
- [x] Atualizar serializers

**Arquivos:**
- ✅ `Api/finance/views.py` - MissionViewSet com 4 novos @action endpoints
- ✅ `Api/finance/serializers.py`
- ⚠️ `Api/finance/urls.py` - Router automático já expõe endpoints

**Implementado:**
- `GET /missions/recommend/`: Recomendações baseadas em score de prioridade contextual
- `GET /missions/by-category/`: Missões filtradas por categoria específica
- `GET /missions/by-goal/`: Missões filtradas por meta específica
- `GET /missions/context-analysis/`: Análise completa + oportunidades + ações sugeridas
- Helper functions: `_get_recommendation_reason()`, `_opportunity_to_action()`

---

### Sprint 6: Testes Automatizados (2 dias)

**Status:** ✅ Concluído  
**Progresso:** 5/5 tarefas

- [x] Cobrir serializers com 12 testes (missões e progressos)
- [x] Validar legacy choices e migrations
- [x] Garantir `keepdb` com fixtures consistentes
- [x] Criar bateria de testes para API `/missions`
- [x] Documentar estratégia de testes end-to-end

**Arquivos:**

- `Api/finance/tests/test_serializers.py`
- `Api/finance/tests/test_missions_api.py`
- `Api/finance/serializers.py`
- `Api/finance/migrations/0047_add_legacy_validation_choices.py`
- `MISSION_SYSTEM_REFACTOR.md`

**Notas rápidas:**

- A suíte `test_missions_api.py` cobre autenticação, filtros (`tier`, `has_category`, `has_goal`), agregações (`/by_validation_type`) e estatísticas dos endpoints `/missions`, garantindo regressões mínimas antes de liberar novas missões.
- O serializer agora lê `target_goal.title`, corrigindo o crash observado quando metas são serializadas nas respostas.
- Execução recomendada: `python manage.py test finance.tests.test_missions_api --keepdb` (evita recriar o banco e mantém os fixtures consistentes exigidos pelo Sprint 6).

**Estratégia E2E documentada:**

- Backend: smoke diário com `test_missions_api.py` + `test_admin_user_management.py`, sempre com `--keepdb` para reaproveitar cate/goal defaults e acelerar pipelines.
- Frontend (quando Sprint 7 concluir widgets): rodar `flutter test --tags missions` após o backend para validar recomendações, garantindo que o contrato dos campos adicionais (categorias, metas e indicadores) permaneça estável.
- Antes de cada release, executar sequência completa (API missions → admin management → serializer regressions) + uma rodada manual do app apontando para o ambiente de staging para verificar o fluxo Recomendar → Disponibilizar automaticamente nas missões ativas.

---

### Sprint 7: Frontend (3-4 dias)

**Status:** 🟡 Em andamento  
**Progresso:** 6/8 tarefas

#### Fase 1 – Modelos e Dados

- [x] Atualizar `MissionModel` com campos de categorias, metas, filtros de transação e metadata
- [x] Ajustar viewmodels/repos (`missions_viewmodel.dart`, serviços) para novos campos + ordenação

#### Fase 2 – UI e Widgets

- [x] MissionRecommendationWidget com cards scrolláveis (sem swipe)
- [x] CategoryMissionBadgeList exibindo categorias com missões
- [x] GoalMissionPanel mostrando metas relacionadas
- [x] MissionImpactVisualization exibindo indicadores e oportunidades
- [x] MissionProgressDetailWidget com 3 seções (objetivo/ação/tracking)

#### Fase 3 – Integração e QA

- [x] Integração parcial com endpoints `/missions` (lista principal)
- [x] Testes widget para recommendation/impact/progress
- [ ] Integração completa com endpoints contextuais (recomendação, categoria, metas)
- [ ] Smoke E2E navegando por missões ativas e recomendadas

**Arquivos:**

- `Front/lib/core/models/mission.dart`
- `Front/lib/features/missions/data/missions_viewmodel.dart`
- `Front/lib/features/missions/presentation/widgets/*`
- `Front/lib/features/missions/presentation/pages/missions_page.dart`

#### Kickoff 14/11 — Plano imediato

- Prioridade #1: entregar **MissionRecommendationWidget** consumindo `/api/missions/recommend/`, evidenciando que as missões são ativadas automaticamente (sem botão de aceite) e exibindo `target_info`, `source` e filtros tier/categoria/meta.
- Prioridade #2: garantir **CategoryMissionBadge** + **GoalMissionPanel** reutilizem o repositório já ajustado (Sprint 6), exponham estados de loading/erro e sirvam como apontadores rápidos para as missões que já estão na fila automática.
- Prioridade #3: preparar scaffolding para **MissionImpactVisualization** e **MissionProgressDetailWidget**, mesmo que inicial (layout + dados mockados), para alinhar com design e permitir avaliações de impacto antes da integração final.

#### Plano de execução (atualizado)

##### Fase A – Fundamentos e mocks

- [ ] Revisar contratos atuais do `missions_repository`, garantindo estados de loading/erro padronizados e mocks (`fake_missions.json`) com `target_info`, categorias e metas múltiplas.
- [ ] Ajustar o `missions_viewmodel.dart` para publicar indicadores derivados (ex.: resumos por categoria/meta) e estados específicos para recomendações automáticas.

##### Fase B – Widgets e experiência do usuário

- [ ] **MissionRecommendationWidget**
  - [ ] Cards swipeables com badges de dificuldade/tier e selo “Ativação automática”.
  - [ ] Link único de “Ver detalhes” (sem ação de aceite) e tooltip explicando que o sistema adiciona a missão sozinho quando necessário.
  - [ ] Swipe gestures (`Dismissible`/`TinderCard`) ajustadas para manter 60 fps.
- [ ] **CategoryMissionBadge**
  - [ ] Mostrar contadores por categoria (ativas vs. fila automática) usando as cores já cadastradas em `Category.color` com fallback seguro.
  - [ ] Tocar abre um modal ou bottom sheet com detalhes da categoria e missões relacionadas.
- [ ] **GoalMissionPanel**
  - [ ] Listar metas priorizadas com `goal_progress_target`, destacando o impacto estimado e oferecendo navegação direta para a tela da meta.
- [ ] **MissionImpactVisualization**
  - [ ] Gráfico radial/linha que projeta TPS/RDR/ILI com base em `target_info`; inicia com dados mockados e já deixa hooks para os indicadores reais.
- [ ] **MissionProgressDetailWidget**
  - [ ] Timeline das atividades mais recentes + dicas (`tips`) e métricas por critério (transações, pagamentos, etc.).

##### Fase C – Integração, QA e telemetria

- [ ] Conectar widgets aos endpoints `/missions` (recomendação, categoria, metas, contexto) e validar cache/local loading.
- [ ] Criar widget tests para Recommendation/Badges, smoke `flutter test --tags missions` e um roteiro manual verificando auto-disponibilização das missões.
- [ ] Instrumentar eventos (ex.: “mission_recommendation_viewed”) para medir engajamento pós-remoção do botão de aceite.
- [ ] Atualizar documentação interna explicando que missões são sempre ativadas automaticamente.


### Sprint 8: Admin & Migração (4 dias)

**Status:** ⚪ Não iniciado  
**Progresso:** 0/11 tarefas

- [ ] Atualizar MissionAdmin com novos fieldsets
- [ ] Implementar actions customizadas
- [ ] MissionAnalyticsView
- [ ] MissionTestingView
- [ ] Documentação admin
- [ ] Criar migration completa
- [ ] Executar migrations em ambiente de dev
- [ ] Testes de integração
- [ ] Testes end-to-end
- [ ] Limpeza de código
- [ ] Documentação final

**Arquivos:**

- `Api/finance/admin.py`
- `Api/finance/views.py`
- `Api/finance/migrations/XXXX_refactor_mission_system.py`
- Vários (limpeza)

---

### Sprint 9: Limpeza de Legados & Legibilidade (2 dias)

**Status:** ⚪ Não iniciado  
**Progresso:** 0/6 tarefas

- [ ] Mapear e remover missões/códigos legados (social, duplicados, enums obsoletos)
- [ ] Simplificar serializers/validators com lógica compartilhada (reduzir ramos mortos)
- [ ] Padronizar nomenclatura e ordenação de campos (backend + Flutter)
- [ ] Remover comentários redundantes, mantendo apenas notas essenciais (≤1 comentário por arquivo crítico)
- [ ] Extrair helpers/constantes repetidas para módulos dedicados
- [ ] Atualizar documentação técnica após limpeza

**Arquivos:**

- `Api/finance/mission_types.py`
- `Api/finance/serializers.py`
- `Api/finance/services.py`
- `Front/lib/**` (modelos, viewmodels, widgets)
- `README.md` / documentação

---

### Sprint 10: QA, Performance & Release (2 dias)

**Status:** ⚪ Não iniciado  
**Progresso:** 0/7 tarefas

- [ ] Rodar bateria completa de testes (unitários, integração, widget/E2E)
- [ ] Criar checklist de regressão para endpoints `/missions`
- [ ] Profilar queries e aplicar otimizações (N+1, índices, cache)
- [ ] Validar tempos de resposta (<200ms) e métricas Flutter (jank < 16ms)
- [ ] Revisar acessibilidade e feedback visual nas telas de missões
- [ ] Preparar release notes + plano de rollback
- [ ] Aprovar merge final com revisão cruzada

**Arquivos:**

- `Api/finance/tests/**`
- `Front/test/**` e `integration_test/**`
- `MISSION_SYSTEM_REFACTOR.md`
- Playbook de deploy / release notes

---

## ✅ Checklist de Validação

### Backend

- [ ] Todos os novos MissionTypes implementados
- [ ] Todos os novos ValidationTypes implementados
- [ ] Validators cobrem todos os tipos de missão
- [ ] Lógica de atribuição testada com diferentes perfis de usuário
- [ ] Todas as missões sociais removidas/desativadas
- [ ] Templates criados e testados
- [ ] Endpoints funcionando corretamente
- [x] Serializers retornando dados corretos
- [ ] Admin interface funcional e intuitiva

### Frontend

- [x] Modelos Dart atualizados
- [ ] Todos os novos widgets implementados
- [x] ViewModels refatorados
- [ ] Integração com API completa
- [ ] UI/UX consistente
- [ ] Tratamento de erros adequado
- [ ] Loading states implementados

### Performance

- [ ] Endpoints respondem em < 200ms
- [ ] Queries otimizadas (sem N+1)
- [ ] Cache implementado onde necessário
- [ ] Frontend sem lag perceptível

### Qualidade

- [ ] Cobertura de testes > 80%
- [ ] Documentação completa
- [ ] Code review realizado
- [ ] Sem warnings/erros no console
- [ ] Acessibilidade básica implementada

### Funcional

- [ ] Missões são atribuídas corretamente
- [ ] Progresso é calculado com precisão
- [ ] Recompensas são aplicadas
- [ ] Usuários entendem o que fazer
- [ ] Feedback visual adequado

---

## 📝 Notas e Decisões

### Decisão 1: ManyToMany vs ForeignKey para Categorias/Metas

**Data:** 13/11/2025  
**Decisão:** Manter ambos (`target_category` e `target_categories`)
**Razão:**

- `target_category`: Para missões focadas em UMA categoria específica
- `target_categories`: Para missões que envolvem múltiplas categorias
- Mais flexibilidade sem complexidade excessiva

### Decisão 2: Validação Síncrona vs Assíncrona

**Data:** 13/11/2025  
**Decisão:** Manter validação síncrona com opção de celery task
**Razão:**

- Maioria das validações é rápida (< 100ms)
- Celery task apenas para validações pesadas (análise de grandes períodos)
- Melhor UX com feedback imediato

### Decisão 3: Frequência de Atualização de Progresso

**Data:** 13/11/2025  
**Decisão:** Atualização em tempo real + batch noturno
**Razão:**

- Tempo real: Ao criar/editar transação
- Batch: 3h da manhã para recalcular todas as missões ativas
- Garante precisão sem sobrecarregar sistema

### Decisão 4: Política de Comentários no Código

**Data:** 14/11/2025  
**Decisão:** Manter no máximo um comentário essencial por arquivo crítico, removendo anotações redundantes/obsoletas.
**Razão:**

- Incentivar legibilidade através de código claro em vez de comentários extensos
- Facilitar auditoria de legados e evitar divergência entre comentário e implementação
- Reduzir ruído visual para o time de frontend/backend

---

## 🔄 Registro de Alterações

### 2025-11-13 - Criação do Plano

- ✅ Plano completo criado
- ✅ Sprints definidos
- ✅ Checklist de validação estabelecido
- ⏳ Aguardando início da implementação

### 2025-11-14 - Sprint 6 (Testes)

- ✅ Serializers ajustados e cobertos por 12 testes
- ✅ Migration `0047_add_legacy_validation_choices` aplicada
- 🟡 Planejamento de testes da API `/missions` em andamento

### 2025-11-14 - Sprint 7 (Frontend)

- 🚀 Kickoff focado em modelos e widgets de missões no Flutter
- 📌 Planejamento dividido em 3 fases (dados, UI e integração)
- ⏱️ Dependências: finalizar bateria de testes da API `/missions`

### 2025-11-14 - Sprint 7 (Phase 1 concluída)

- ✅ `MissionModel` atualizado com filtros, múltiplos alvos e metadata
- ✅ `missions_viewmodel.dart` e `FinanceRepository` consumindo novos endpoints
- ⚠️ Próxima etapa: widgets/context cards consumindo dados enriquecidos

---

## 📞 Contatos e Referências

**Documentação Relacionada:**

- `Api/finance/models.py` - Modelos principais
- `Api/finance/mission_types.py` - Validators atuais
- `Api/finance/services.py` - Lógica de negócio
- `Front/lib/features/missions/` - Frontend Flutter

**Referências Externas:**

- [Django Best Practices](https://docs.djangoproject.com/en/stable/topics/db/models/)
- [Flutter Architecture](https://docs.flutter.dev/app-architecture)
- [MVVM Pattern](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93viewmodel)

---

**Última Atualização:** 13 de novembro de 2025  
**Próxima Revisão:** Após conclusão de cada sprint
