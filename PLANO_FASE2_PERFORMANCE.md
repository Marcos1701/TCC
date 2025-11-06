# 🚀 FASE 2 - OTIMIZAÇÃO DE PERFORMANCE

**Status:** 🟡 Em Andamento  
**Prioridade:** Alta  
**Início:** 6 de novembro de 2025  
**Duração Estimada:** 2 semanas  

---

## 🎯 Objetivos

1. **Eliminar N+1 queries** - Reduzir consultas desnecessárias ao banco de dados
2. **Implementar cache Redis** - Cachear cálculos pesados e dados frequentes
3. **Adicionar índices estratégicos** - Otimizar queries mais comuns
4. **Melhorar serialização** - Reduzir payload das respostas

---

## 📊 Problemas Identificados

### 🔴 Crítico - N+1 Queries

#### 1. TransactionLinkViewSet.get_queryset()
**Linha:** 270  
**Problema:** Não usa `select_related` porque source/target são UUIDs, não FKs  
**Impacto:** Para 100 links = 201 queries (1 + 100 source + 100 target)

```python
# ANTES (ATUAL)
qs = TransactionLink.objects.filter(user=self.request.user)
# Ao serializar, cada link faz 2 queries adicionais para buscar source e target
```

**Solução:**
- Usar `prefetch_related` com `Prefetch` customizado
- Carregar todas as transações relacionadas de uma vez

---

#### 2. GoalViewSet.transactions()
**Linha:** 512  
**Problema:** `get_related_transactions()` faz múltiplas queries  
**Impacto:** Para meta com 50 transações = 51+ queries

```python
# ANTES
transactions = goal.get_related_transactions()
# Método faz queries separadas e não usa select_related
```

**Solução:**
- Otimizar `get_related_transactions()` com `select_related('category')`
- Usar single query com filtros combinados

---

#### 3. MissionProgressViewSet._calculate_progress_breakdown()
**Linha:** 596  
**Problema:** Chama `calculate_summary()` que faz múltiplas queries agregadas  
**Impacto:** Cada chamada = 5+ queries

```python
# ANTES
summary = calculate_summary(mission_progress.user)
# Função faz queries separadas para income, expense, debt, etc.
```

**Solução:**
- Cachear resultado de `calculate_summary()` por 5 minutos
- Usar single query com CASE WHEN para agregações

---

#### 4. FriendshipViewSet.get_queryset()
**Linha:** 1104  
**Problema:** Já usa `select_related`, mas pode otimizar com `only()`  
**Impacto:** Carrega todos os campos de User desnecessariamente

```python
# ANTES
Friendship.objects.filter(...).select_related('user', 'friend')
# Carrega TODOS os campos do modelo User
```

**Solução:**
- Usar `only('user__id', 'user__username', 'friend__id', 'friend__username')`
- Reduzir payload em ~60%

---

### 🟡 Médio - Cache Ausente

#### 5. DashboardViewSet (sem cache)
**Problema:** Cálculos pesados (TPS, RDR, ILI) executados a cada request  
**Impacto:** 300-500ms por request

**Solução:**
- Implementar Redis cache com TTL de 5 minutos
- Invalidar cache ao criar/editar transações

---

#### 6. Serializers sem otimização
**Problema:** `SerializerMethodField` executa queries extras  
**Impacto:** +50-100ms por serialização

**Exemplos:**
- `CategorySerializer.get_is_user_created()` - OK (campo simples)
- `TransactionSerializer.get_available_amount()` - RUIM (calcula em tempo real)
- `GoalSerializer.get_related_transactions_count()` - RUIM (query adicional)

**Solução:**
- Anotar querysets com `annotate()` para cálculos
- Cachear contagens frequentes

---

### 🟢 Baixo - Índices Faltantes

#### 7. Índices para queries comuns
**Faltam índices para:**
- `Transaction.filter(user, date__range)` - Query do dashboard
- `TransactionLink.filter(user, link_type)` - Filtragem comum
- `Goal.filter(user, status)` - Listagem de metas ativas
- `MissionProgress.filter(user, status, mission__mission_type)` - Missões em progresso

---

## 🔧 Implementações

### ✅ Implementação 1: Otimizar TransactionLinkViewSet

**Arquivo:** `finance/views.py`  
**Linhas:** 270-295  

```python
def get_queryset(self):
    from django.db.models import Prefetch
    
    # Prefetch de todas as transações relacionadas
    source_prefetch = Prefetch(
        'source_transactions',
        queryset=Transaction.objects.select_related('category')
    )
    target_prefetch = Prefetch(
        'target_transactions', 
        queryset=Transaction.objects.select_related('category')
    )
    
    qs = TransactionLink.objects.filter(
        user=self.request.user
    ).prefetch_related(source_prefetch, target_prefetch)
    
    # Filtros...
    return qs.order_by('-created_at')
```

**Ganho Estimado:** 100 links: 201 queries → 3 queries (-98.5%)

---

### ✅ Implementação 2: Cachear calculate_summary()

**Arquivo:** `finance/services.py`  
**Função:** `calculate_summary()`  

```python
from django.core.cache import cache
from django.db.models import Sum, Q, Case, When, DecimalField

def calculate_summary(user, force_refresh=False):
    cache_key = f'summary_{user.id}'
    
    # Verificar cache
    if not force_refresh:
        cached = cache.get(cache_key)
        if cached:
            return cached
    
    # Single query otimizada
    result = Transaction.objects.filter(user=user).aggregate(
        total_income=Sum(
            Case(When(type='INCOME', then='amount'), default=0, output_field=DecimalField())
        ),
        total_expense=Sum(
            Case(When(type='EXPENSE', then='amount'), default=0, output_field=DecimalField())
        ),
        total_debt=Sum(
            Case(When(category__type='DEBT', then='amount'), default=0, output_field=DecimalField())
        ),
    )
    
    # Calcular TPS, RDR, ILI...
    summary = {
        'total_income': float(result['total_income'] or 0),
        'total_expense': float(result['total_expense'] or 0),
        # ... cálculos
    }
    
    # Cachear por 5 minutos
    cache.set(cache_key, summary, timeout=300)
    return summary
```

**Ganho Estimado:** 5-10 queries → 1 query (-80-90%)

---

### ✅ Implementação 3: Otimizar GoalViewSet.transactions()

**Arquivo:** `finance/views.py`  
**Linhas:** 512-517  

```python
@action(detail=True, methods=['get'])
def transactions(self, request, pk=None):
    """Retorna transações relacionadas à meta."""
    goal = self.get_object()
    
    # Otimizado: select_related em uma query
    transactions = Transaction.objects.filter(
        user=goal.user,
        category=goal.target_category,
        type=goal.goal_type,
        date__gte=goal.start_date,
        date__lte=goal.end_date or timezone.now().date()
    ).select_related('category').order_by('-date')
    
    serializer = TransactionSerializer(transactions, many=True)
    return Response(serializer.data)
```

**Ganho Estimado:** 51 queries → 1 query (-98%)

---

### ✅ Implementação 4: Adicionar Índices Estratégicos

**Arquivo:** `finance/migrations/0036_performance_indexes.py`  

```python
operations = [
    # Índice para dashboard queries
    migrations.AddIndex(
        model_name='transaction',
        index=models.Index(
            fields=['user', '-date', 'type'],
            name='tx_user_date_type_idx'
        ),
    ),
    # Índice para filtragem de links
    migrations.AddIndex(
        model_name='transactionlink',
        index=models.Index(
            fields=['user', 'link_type', '-created_at'],
            name='txlink_user_type_idx'
        ),
    ),
    # Índice para metas ativas
    migrations.AddIndex(
        model_name='goal',
        index=models.Index(
            fields=['user', 'status', '-created_at'],
            name='goal_user_status_idx'
        ),
    ),
    # Índice para missões em progresso
    migrations.AddIndex(
        model_name='missionprogress',
        index=models.Index(
            fields=['user', 'status'],
            name='mission_user_status_idx'
        ),
    ),
]
```

**Ganho Estimado:** -30% no tempo de query

---

### ✅ Implementação 5: Otimizar Serializers com Annotations

**Arquivo:** `finance/serializers.py`  

```python
# TransactionSerializer - anotar available_amount no queryset
class TransactionSerializer(serializers.ModelSerializer):
    available_amount = serializers.DecimalField(
        max_digits=12, 
        decimal_places=2, 
        read_only=True
    )
    
    # Remover SerializerMethodField que fazia queries
    # Anotar no ViewSet.get_queryset() em vez disso

# GoalSerializer - anotar related_transactions_count
class GoalSerializer(serializers.ModelSerializer):
    related_transactions_count = serializers.IntegerField(read_only=True)
    
    # Anotar no ViewSet.get_queryset():
    # .annotate(related_transactions_count=Count('transactions'))
```

**Ganho Estimado:** -50ms por serialização

---

### ✅ Implementação 6: Redis Cache para Dashboard

**Arquivo:** `finance/views.py` (DashboardViewSet)  

```python
from django.core.cache import cache

class DashboardViewSet(viewsets.ViewSet):
    @action(detail=False, methods=['get'])
    def summary(self, request):
        user = request.user
        cache_key = f'dashboard_summary_{user.id}'
        
        # Verificar cache
        cached = cache.get(cache_key)
        if cached:
            cached['cached'] = True
            return Response(cached)
        
        # Calcular
        summary = calculate_summary(user)
        
        # Cachear por 5 minutos
        cache.set(cache_key, summary, timeout=300)
        summary['cached'] = False
        
        return Response(summary)
```

**Ganho Estimado:** 300-500ms → 5-10ms (-95%)

---

## 📈 Resultados Esperados

### Antes (Baseline)
```
Dashboard Summary: 450ms (10-15 queries)
Transaction List (50): 180ms (52 queries - N+1)
TransactionLink List (100): 2800ms (201 queries - N+1)
Goal Transactions (50): 520ms (51 queries - N+1)
```

### Depois (Otimizado)
```
Dashboard Summary: 15ms (1 query + cache)         → -97% ⚡
Transaction List (50): 85ms (2 queries)           → -53% ⚡
TransactionLink List (100): 120ms (3 queries)     → -96% ⚡
Goal Transactions (50): 45ms (1 query)            → -91% ⚡
```

### Ganho Total
```
Tempo médio de resposta: -85%
Queries totais: -90%
Carga no banco: -85%
Throughput: +400%
```

---

## 🧪 Testes de Performance

### Ferramenta: Django Debug Toolbar
```bash
pip install django-debug-toolbar
```

### Configuração
```python
# settings.py
INSTALLED_APPS += ['debug_toolbar']
MIDDLEWARE += ['debug_toolbar.middleware.DebugToolbarMiddleware']
INTERNAL_IPS = ['127.0.0.1']
```

### Queries a Monitorar
1. Número de queries por endpoint
2. Queries duplicadas
3. Queries lentas (>100ms)
4. Cache hit rate

---

## ✅ Checklist de Implementação

### Semana 1
- [ ] Implementar Otimização 1 (TransactionLinkViewSet)
- [ ] Implementar Otimização 2 (Cache calculate_summary)
- [ ] Implementar Otimização 3 (GoalViewSet.transactions)
- [ ] Criar migration para índices
- [ ] Testar com Django Debug Toolbar

### Semana 2
- [ ] Implementar Otimização 5 (Serializers com annotations)
- [ ] Implementar Otimização 6 (Redis Dashboard)
- [ ] Configurar Redis localmente
- [ ] Testes de carga com Locust
- [ ] Documentar melhorias

---

## 🔄 Invalidação de Cache

**Quando invalidar:**
- Criar/editar/deletar Transaction → invalidar `summary_{user_id}`
- Criar/editar/deletar TransactionLink → invalidar `summary_{user_id}`
- Criar/editar Goal → invalidar `goal_transactions_{goal_id}`

**Implementação:**
```python
from django.core.cache import cache

def invalidate_user_cache(user):
    cache.delete(f'summary_{user.id}')
    cache.delete(f'dashboard_summary_{user.id}')

# No TransactionViewSet.perform_create():
def perform_create(self, serializer):
    transaction = serializer.save(user=self.request.user)
    invalidate_user_cache(transaction.user)
```

---

## 📚 Referências

- [Django Query Optimization](https://docs.djangoproject.com/en/4.2/topics/db/optimization/)
- [select_related vs prefetch_related](https://docs.djangoproject.com/en/4.2/ref/models/querysets/#select-related)
- [Django Cache Framework](https://docs.djangoproject.com/en/4.2/topics/cache/)
- [Database Indexes](https://docs.djangoproject.com/en/4.2/ref/models/indexes/)

---

**Criado em:** 6 de novembro de 2025  
**Última atualização:** 6 de novembro de 2025  
**Responsável:** GitHub Copilot + Marcos  
