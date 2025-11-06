# 🚨 Ações Prioritárias - Melhorias Críticas

## 📋 Resumo Executivo

Este documento lista as **melhorias críticas** que devem ser implementadas IMEDIATAMENTE para resolver problemas de segurança, eficiência e experiência do usuário.

---

## 🔴 PRIORIDADE CRÍTICA - IMPLEMENTAR AGORA

### 1. 🔐 **Isolamento de Categorias por Usuário**

**Status Atual:** ❌ VULNERÁVEL  
**Impacto:** LGPD, Privacidade, Segurança  
**Tempo:** 2-3 dias

**Problema:**
```python
# models.py - ATUAL (VULNERÁVEL)
user = models.ForeignKey(..., null=True, blank=True)  # ← Permite categorias globais

# views.py - ATUAL (VULNERÁVEL)
qs = Category.objects.filter(Q(user=user) | Q(user__isnull=True))  # ← Compartilha dados
```

**Risco:** Usuário A pode ver padrões de gastos de usuário B através de categorias compartilhadas.

**Solução Imediata:**

1. **Migration para adicionar campo `is_system_default`:**
```bash
python manage.py makemigrations finance --empty --name isolate_categories
```

```python
# migrations/XXXX_isolate_categories.py
from django.db import migrations, models

def migrate_categories_to_users(apps, schema_editor):
    """Migra categorias globais para cada usuário."""
    Category = apps.get_model('finance', 'Category')
    User = apps.get_model('auth', 'User')
    
    # Buscar categorias sem dono
    global_cats = Category.objects.filter(user__isnull=True)
    
    if not global_cats.exists():
        return
    
    # Para cada usuário, criar cópia
    for user in User.objects.all():
        for cat in global_cats:
            Category.objects.create(
                user=user,
                name=cat.name,
                type=cat.type,
                color=cat.color,
                group=cat.group,
                is_system_default=True,
            )
    
    # Deletar categorias globais
    global_cats.delete()

class Migration(migrations.Migration):
    dependencies = [
        ('finance', '0033_create_m2m_table_with_uuid'),
    ]
    
    operations = [
        # Adicionar campo
        migrations.AddField(
            model_name='category',
            name='is_system_default',
            field=models.BooleanField(default=False),
        ),
        # Migrar dados
        migrations.RunPython(migrate_categories_to_users),
        # Tornar user obrigatório
        migrations.AlterField(
            model_name='category',
            name='user',
            field=models.ForeignKey(..., null=False),
        ),
    ]
```

2. **Atualizar model:**
```python
# models.py
class Category(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        null=False,  # ← OBRIGATÓRIO
        blank=False,
    )
    is_system_default = models.BooleanField(default=False)
```

3. **Atualizar views:**
```python
# views.py
class CategoryViewSet(viewsets.ModelViewSet):
    def get_queryset(self):
        # APENAS categorias do próprio usuário
        return Category.objects.filter(user=self.request.user)
```

---

### 2. ⚡ **Rate Limiting Crítico**

**Status Atual:** ❌ SEM PROTEÇÃO  
**Impacto:** Abuso, Performance  
**Tempo:** 1 dia

**Implementação:**

```python
# throttling.py (criar novo arquivo)
from rest_framework.throttling import UserRateThrottle

class TransactionCreateThrottle(UserRateThrottle):
    rate = '100/hour'

class CategoryCreateThrottle(UserRateThrottle):
    rate = '20/hour'

# views.py
class TransactionViewSet(viewsets.ModelViewSet):
    def get_throttles(self):
        if self.action == 'create':
            return [TransactionCreateThrottle()]
        return super().get_throttles()

class CategoryViewSet(viewsets.ModelViewSet):
    def get_throttles(self):
        if self.action == 'create':
            return [CategoryCreateThrottle()]
        return super().get_throttles()
```

---

### 3. 🔒 **Validação Robusta em TransactionLink**

**Status Atual:** ⚠️ PARCIAL  
**Impacto:** Integridade de dados  
**Tempo:** 1 dia

**Adicionar validações:**

```python
# models.py - TransactionLink.clean()
def clean(self):
    from django.core.exceptions import ValidationError
    
    # NOVO: Validar não vincula consigo mesmo
    if self.source_transaction_uuid == self.target_transaction_uuid:
        raise ValidationError("Não pode vincular transação consigo mesma.")
    
    # NOVO: Validar tipo correto para DEBT_PAYMENT
    if self.link_type == self.LinkType.DEBT_PAYMENT:
        if self.source_transaction.type != Transaction.TransactionType.INCOME:
            raise ValidationError("Source deve ser INCOME para pagamento de dívida.")
        
        if not self.target_transaction.category or \
           self.target_transaction.category.type != Category.CategoryType.DEBT:
            raise ValidationError("Target deve ser DEBT para pagamento de dívida.")
    
    # NOVO: Lock para prevenir race conditions
    from django.db import transaction
    with transaction.atomic():
        source = Transaction.objects.select_for_update().get(
            id=self.source_transaction_uuid
        )
        
        if self.linked_amount > source.available_amount:
            raise ValidationError(f"Valor excede disponível: {source.available_amount}")
```

---

## 🟡 PRIORIDADE ALTA - Implementar em 1 Semana

### 4. ⚡ **Otimização de Queries N+1**

**Impacto:** Performance (70% mais rápido)  
**Tempo:** 2 dias

```python
# views.py - TransactionViewSet
def get_queryset(self):
    return Transaction.objects.filter(
        user=self.request.user
    ).select_related(
        'category'  # JOIN com Category
    ).prefetch_related(
        'outgoing_links',
        'incoming_links'
    ).order_by("-date", "-created_at")

# GoalViewSet
def get_queryset(self):
    return Goal.objects.filter(
        user=self.request.user
    ).select_related(
        'target_category'
    ).prefetch_related(
        'tracked_categories'
    )
```

---

### 5. 🚀 **Cache Redis para Indicadores**

**Impacto:** Performance (50% menos carga no banco)  
**Tempo:** 1 dia

**Instalação:**
```bash
pip install redis django-redis
```

**Configuração:**
```python
# settings.py
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': 'redis://127.0.0.1:6379/1',
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        },
        'KEY_PREFIX': 'finance',
        'TIMEOUT': 300,  # 5 minutos
    }
}

# services.py - calculate_summary()
from django.core.cache import cache

def calculate_summary(user):
    cache_key = f"summary_{user.id}"
    
    cached = cache.get(cache_key)
    if cached:
        return cached
    
    # ... cálculo normal ...
    
    cache.set(cache_key, summary, timeout=300)
    return summary

def invalidate_indicators_cache(user):
    cache.delete(f"summary_{user.id}")
```

---

### 6. 📊 **Paginação Padrão**

**Impacto:** Performance, UX  
**Tempo:** 30 minutos

```python
# settings.py
REST_FRAMEWORK = {
    # ... existente ...
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.LimitOffsetPagination',
    'PAGE_SIZE': 50,
}
```

---

### 7. 🔍 **Índices de Banco Adicionais**

**Impacto:** Performance (queries 3x mais rápidas)  
**Tempo:** 1 hora

```bash
python manage.py makemigrations finance --empty --name add_performance_indexes
```

```python
# migrations/XXXX_add_performance_indexes.py
class Migration(migrations.Migration):
    dependencies = [
        ('finance', '0033_create_m2m_table_with_uuid'),
    ]
    
    operations = [
        migrations.AddIndex(
            model_name='transaction',
            index=models.Index(
                fields=['user', 'type', '-date'],
                name='tx_user_type_date_idx'
            ),
        ),
        migrations.AddIndex(
            model_name='transaction',
            index=models.Index(
                fields=['user', 'category', '-date'],
                name='tx_user_cat_date_idx'
            ),
        ),
        migrations.AddIndex(
            model_name='goal',
            index=models.Index(
                fields=['user', 'goal_type'],
                name='goal_user_type_idx'
            ),
        ),
    ]
```

---

## 🟢 PRIORIDADE MÉDIA - Implementar em 2-3 Semanas

### 8. 🤖 **Sistema de Missões com IA**

**Impacto:** Diferencial competitivo, Engajamento  
**Tempo:** 5 dias

**Requisitos:**
```bash
pip install openai
```

**Configuração:**
```python
# .env
OPENAI_API_KEY=sk-xxx

# settings.py
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
```

**Implementação Base:**
```python
# services.py
from openai import OpenAI

class MissionGenerator:
    def __init__(self):
        self.client = OpenAI(api_key=settings.OPENAI_API_KEY)
    
    def generate_personalized_missions(self, user, count=3):
        """Gera missões usando IA."""
        
        # Construir contexto
        summary = calculate_summary(user)
        profile = user.userprofile
        
        context = {
            "nivel": profile.level,
            "tps": float(summary['tps']),
            "rdr": float(summary['rdr']),
            "ili": float(summary['ili']),
        }
        
        prompt = f"""
Crie {count} missões financeiras personalizadas para:
Nível: {context['nivel']}
TPS: {context['tps']}%
RDR: {context['rdr']}%
ILI: {context['ili']} meses

Formato JSON:
{{
  "missions": [
    {{
      "title": "...",
      "description": "...",
      "difficulty": "EASY|MEDIUM|HARD",
      "reward_points": 50-200
    }}
  ]
}}
"""
        
        response = self.client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"}
        )
        
        return json.loads(response.choices[0].message.content)

# Management command
# management/commands/generate_ai_missions.py
from django.core.management.base import BaseCommand

class Command(BaseCommand):
    def handle(self, *args, **options):
        generator = MissionGenerator()
        
        for profile in UserProfile.objects.filter(user__is_active=True):
            missions = generator.generate_personalized_missions(profile.user)
            
            for m in missions['missions']:
                Mission.objects.create(
                    user=profile.user,  # Missão pessoal
                    title=m['title'],
                    description=m['description'],
                    difficulty=m['difficulty'],
                    reward_points=m['reward_points'],
                    created_via_ai=True,
                )
```

**Cron Job (Linux):**
```bash
# /etc/cron.d/finance-missions
0 3 * * 1 cd /path/to/project && python manage.py generate_ai_missions
```

---

### 9. 💡 **Sugestões Inteligentes de Categoria**

**Impacto:** UX, Produtividade  
**Tempo:** 3 dias

```python
# services.py
class CategorySuggester:
    def suggest_category(self, user, description, amount):
        """Sugere categoria baseado em histórico + IA."""
        
        # 1. Buscar transações similares
        from difflib import SequenceMatcher
        
        recent = Transaction.objects.filter(
            user=user,
            category__isnull=False
        ).order_by('-date')[:50]
        
        best_match = None
        best_score = 0
        
        for tx in recent:
            score = SequenceMatcher(
                None, 
                description.lower(), 
                tx.description.lower()
            ).ratio()
            
            if score > best_score and score > 0.7:
                best_score = score
                best_match = tx.category
        
        if best_match:
            return best_match
        
        # 2. Fallback: Usar IA
        return self._ai_suggest(user, description)

# serializers.py - TransactionSerializer
class TransactionSerializer(serializers.ModelSerializer):
    suggested_category = serializers.SerializerMethodField()
    
    def get_suggested_category(self, obj):
        if obj.category:
            return None
        
        suggester = CategorySuggester()
        suggested = suggester.suggest_category(
            obj.user, 
            obj.description, 
            obj.amount
        )
        
        if suggested:
            return {
                'id': suggested.id,
                'name': suggested.name,
                'confidence': 'high'
            }
        
        return None
```

---

### 10. 📊 **Dashboard com Insights**

**Impacto:** UX, Engajamento  
**Tempo:** 4 dias

```python
# services.py
class InsightEngine:
    def generate_insights(self, user):
        """Gera insights acionáveis."""
        insights = []
        
        # Comparar mês atual vs anterior
        this_month = self._get_month_expenses(user, 0)
        last_month = self._get_month_expenses(user, 1)
        
        if last_month > 0:
            change = ((this_month - last_month) / last_month) * 100
            
            if abs(change) > 20:
                insights.append({
                    'type': 'TREND',
                    'priority': 8,
                    'title': f"Gastos {'↑' if change > 0 else '↓'} {abs(change):.0f}%",
                    'message': f"Seus gastos {'aumentaram' if change > 0 else 'diminuíram'} em relação ao mês passado.",
                    'severity': 'warning' if change > 0 else 'good',
                })
        
        # Detectar gastos atípicos
        for category in Category.objects.filter(user=user):
            avg = self._get_category_average(user, category)
            recent = self._get_category_recent(user, category)
            
            if recent > avg * 2:  # 2x a média
                insights.append({
                    'type': 'ANOMALY',
                    'priority': 7,
                    'title': f"Gasto alto em {category.name}",
                    'message': f"Você gastou R$ {recent:.2f}, bem acima da média.",
                })
        
        return sorted(insights, key=lambda x: x['priority'], reverse=True)

# views.py
@action(detail=False, methods=['get'])
def insights(self, request):
    engine = InsightEngine()
    insights = engine.generate_insights(request.user)
    return Response({'insights': insights})
```

---

## ✅ Checklist de Implementação

### Semana 1 (Crítico)
- [ ] Isolamento de categorias
- [ ] Rate limiting
- [ ] Validações TransactionLink

### Semana 2 (Alto)
- [ ] Otimização queries N+1
- [ ] Cache Redis
- [ ] Paginação
- [ ] Índices banco

### Semana 3-4 (Médio)
- [ ] Sistema missões IA
- [ ] Sugestões categoria
- [ ] Dashboard insights

---

## 🧪 Como Testar

### Teste de Isolamento de Categorias
```bash
# Após migration
python manage.py shell

from django.contrib.auth.models import User
from finance.models import Category

user1 = User.objects.get(username='user1')
user2 = User.objects.get(username='user2')

# user1 cria categoria
cat = Category.objects.create(user=user1, name='Teste', type='EXPENSE')

# user2 NÃO deve ver
assert not Category.objects.filter(user=user2, name='Teste').exists()
print("✓ Isolamento funcionando!")
```

### Teste de Performance
```bash
python manage.py shell

from django.test.utils import override_settings
from django.db import connection
from django.db.models import Count

# Contar queries
from django.test.utils import CaptureQueriesContext

with CaptureQueriesContext(connection) as context:
    transactions = Transaction.objects.filter(user=user).select_related('category')[:50]
    list(transactions)  # Força execução
    
print(f"Queries executadas: {len(context.captured_queries)}")
# Deve ser <= 3 queries
```

---

## 📈 Métricas de Sucesso

### Segurança
- ✅ 0 categorias compartilhadas entre usuários
- ✅ 0% tentativas de acesso não autorizado bem-sucedidas
- ✅ 100% requisições com rate limit aplicado

### Performance
- ✅ Tempo resposta API < 200ms (média)
- ✅ Queries por requisição < 5
- ✅ Cache hit rate > 80%

### UX
- ✅ 90% precisão em sugestões de categoria
- ✅ Missões IA com rating > 4/5
- ✅ Engajamento +30%

---

## 🆘 Suporte

### Problemas Comuns

**Migration de categorias falha:**
```bash
# Fazer backup primeiro
python manage.py dumpdata finance.Category > backup_categories.json

# Rodar migration em lote menor
python manage.py migrate finance XXXX_isolate_categories --fake
```

**Redis não conecta:**
```bash
# Verificar Redis
redis-cli ping
# Deve retornar: PONG

# Testar conexão
python manage.py shell
>>> from django.core.cache import cache
>>> cache.set('test', 'ok')
>>> cache.get('test')  # Deve retornar: 'ok'
```

**OpenAI timeout:**
```python
# Aumentar timeout
client = OpenAI(api_key=..., timeout=60.0)
```

---

## 📚 Referências

- [Effective Dart](https://dart.dev/effective-dart) - Padrões seguidos no Front
- [Django Best Practices](https://docs.djangoproject.com/en/stable/topics/security/)
- [REST API Security](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html)

---

**Última Atualização:** 6 de novembro de 2025  
**Versão:** 1.0
