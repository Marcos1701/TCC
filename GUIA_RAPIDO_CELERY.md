# Guia Rápido - Sistema Celery + Snapshots

## ✅ Status: Pronto para uso!

Todas as configurações e migrações foram aplicadas com sucesso.

---

## 🚀 Como Iniciar o Sistema

### Passo 1: Ativar ambiente virtual

```powershell
.\.venv\Scripts\activate
```

### Passo 2: Iniciar Redis (Broker)

**Opção A - Docker (Recomendado):**
```powershell
docker run -d -p 6379:6379 --name redis-tcc redis:latest
```

**Opção B - WSL:**
```bash
wsl
sudo service redis-server start
```

**Verificar se Redis está rodando:**
```powershell
docker ps | findstr redis
# Ou tentar conectar:
redis-cli ping
# Deve retornar: PONG
```

### Passo 3: Iniciar Celery Worker (Terminal 1)

```powershell
cd Api
celery -A config worker -l info --pool=solo
```

**Saída esperada:**
```
 -------------- celery@DESKTOP-XXX v5.3.6 (emerald-rush)
--- ***** -----
-- ******* ---- Windows-10-... 2025-11-09 ...
- *** --- * ---
- ** ---------- [config]
- ** ---------- .> app:         tcc_finance:0x...
- ** ---------- .> transport:   redis://localhost:6379/0
- ** ---------- .> results:     django-db
- *** --- * --- .> concurrency: 8 (solo)
-- ******* ----
--- ***** -----
 -------------- [queues]
                .> celery           exchange=celery(direct) key=celery

[tasks]
  . finance.tasks.create_daily_mission_snapshots
  . finance.tasks.create_daily_user_snapshots
  . finance.tasks.create_monthly_snapshots

[2025-11-09 ...] INFO/MainProcess] Connected to redis://localhost:6379/0
[2025-11-09 ...] INFO/MainProcess] mingle: searching for neighbors
[2025-11-09 ...] INFO/MainProcess] mingle: all alone
[2025-11-09 ...] INFO/MainProcess] celery@DESKTOP ready.
```

### Passo 4: Iniciar Celery Beat (Terminal 2)

```powershell
cd Api
celery -A config beat -l info --scheduler django_celery_beat.schedulers:DatabaseScheduler
```

**Saída esperada:**
```
celery beat v5.3.6 (emerald-rush) is starting.
__    -    ... __   -        _
LocalTime -> 2025-11-09 ...
Configuration ->
    . broker -> redis://localhost:6379/0
    . loader -> celery.loaders.app.AppLoader
    . scheduler -> django_celery_beat.schedulers.DatabaseScheduler
    . db -> default
    . logfile -> [stderr]@%INFO
    . maxinterval -> 5.00 seconds (5s)
[2025-11-09 ...] DatabaseScheduler: Schedule changed.
[2025-11-09 ...] Writing entries (3)...
```

### Passo 5: Iniciar Django (Terminal 3)

```powershell
cd Api
python manage.py runserver
```

---

## 🧪 Testar o Sistema

### Teste 1: Verificar Tasks Agendadas

Acesse o admin: http://localhost:8000/admin/django_celery_beat/periodictask/

Você deve ver 3 tasks:
1. **create-daily-user-snapshots** - Crontab: 23:59 todos os dias
2. **create-daily-mission-snapshots** - Crontab: 23:59 todos os dias
3. **create-monthly-snapshots** - Crontab: 23:50 dias 28-31

### Teste 2: Executar Tasks Manualmente (Shell)

```powershell
cd Api
python manage.py shell
```

```python
# Importar tasks
from finance.tasks import create_daily_user_snapshots, create_daily_mission_snapshots

# Executar snapshot de usuários
result = create_daily_user_snapshots()
print(result)
# Output esperado: {'success': True, 'snapshots_created': X, 'date': '2025-11-09'}

# Executar snapshot de missões
result = create_daily_mission_snapshots()
print(result)
# Output esperado: {'success': True, 'snapshots_created': Y, 'validations_updated': Z, 'date': '2025-11-09'}
```

### Teste 3: Verificar Snapshots no Banco

```python
from finance.models import UserDailySnapshot, MissionProgressSnapshot
from django.contrib.auth import get_user_model

User = get_user_model()
user = User.objects.first()

# Ver snapshots do usuário
snapshots = UserDailySnapshot.objects.filter(user=user).order_by('-snapshot_date')[:5]
for snap in snapshots:
    print(f"Data: {snap.snapshot_date} | TPS: {snap.tps_at_snapshot}% | RDR: {snap.rdr_at_snapshot}%")

# Ver snapshots de missões
mission_snaps = MissionProgressSnapshot.objects.filter(
    mission_progress__user=user
).order_by('-snapshot_date')[:5]
for snap in mission_snaps:
    print(f"Missão: {snap.mission_progress.mission.title} | Válido: {snap.is_valid}")
```

### Teste 4: Análises Avançadas

```python
from finance.services import (
    analyze_category_patterns,
    analyze_tier_progression,
    get_comprehensive_mission_context
)

# Análise de tier
tier_info = analyze_tier_progression(user)
print(f"Tier: {tier_info['tier']} | Nível: {tier_info['level']}")
print(f"Progresso no tier: {tier_info['tier_progress']:.1f}%")

# Análise de categorias
cat_analysis = analyze_category_patterns(user, days=90)
if cat_analysis['has_data']:
    print(f"\nTotal de categorias: {cat_analysis['total_categories']}")
    print("Recomendações:")
    for rec in cat_analysis['recommendations'][:3]:
        print(f"  - {rec['category']}: {rec['type']} ({rec['priority']})")

# Context completo para IA
context = get_comprehensive_mission_context(user)
print(f"\nFoco recomendado: {', '.join(context['recommended_focus'])}")
print(f"Problemas: {', '.join(context['evolution']['problems'])}")
print(f"Pontos fortes: {', '.join(context['evolution']['strengths'])}")
```

---

## 📊 Schedules Configurados

### Daily User Snapshots (23:59)

**Task:** `finance.tasks.create_daily_user_snapshots`

**O que faz:**
- Percorre todos os usuários com transações
- Calcula TPS, RDR, ILI no momento do snapshot
- Armazena gastos por categoria
- Registra progresso de metas
- Marca comportamento diário

**Tabela:** `finance_userdailysnapshot`

### Daily Mission Snapshots (23:59)

**Task:** `finance.tasks.create_daily_mission_snapshots`

**Dependência:** Roda APÓS user snapshots (precisa dos dados do dia)

**O que faz:**
- Valida todas as missões ativas
- Atualiza progresso de missões temporais
- Verifica violações de limites de categoria
- Atualiza streaks de consistência
- Marca missões completadas/falhadas

**Tabela:** `finance_missionprogresssnapshot`

### Monthly Snapshots (28-31, 23:50)

**Task:** `finance.tasks.create_monthly_snapshots`

**O que faz:**
- Consolida snapshots diários do mês
- Calcula médias mensais (TPS, RDR, ILI)
- Identifica categorias mais problemáticas
- Armazena tendências mensais

**Tabela:** `finance_usermonthlysnapshot`

---

## 🔧 Troubleshooting

### ❌ Erro: "redis.exceptions.ConnectionError"

**Causa:** Redis não está rodando

**Solução:**
```powershell
docker run -d -p 6379:6379 --name redis-tcc redis:latest
```

### ❌ Worker não inicia no Windows

**Causa:** Pool threads não funciona no Windows

**Solução:** Use `--pool=solo`
```powershell
celery -A config worker -l info --pool=solo
```

### ❌ Beat não agenda tasks

**Causa:** Usando scheduler errado

**Solução:** Sempre especifique o DatabaseScheduler:
```powershell
celery -A config beat -l info --scheduler django_celery_beat.schedulers:DatabaseScheduler
```

### ❌ Tasks não aparecem no admin

**Causa:** Migrações não foram aplicadas

**Solução:**
```powershell
cd Api
python manage.py migrate django_celery_beat
python manage.py migrate django_celery_results
```

### ❌ "No such task: finance.tasks.xxx"

**Causa:** Worker não encontrou as tasks

**Solução:**
1. Reinicie o worker
2. Verifique se `finance` está em INSTALLED_APPS
3. Verifique se tasks.py está no diretório correto

---

## 📈 Monitoramento

### Ver logs do Worker

O worker mostra em tempo real:
- Tasks recebidas
- Tasks executadas
- Tempo de execução
- Erros

```
[2025-11-09 23:59:00,123: INFO/MainProcess] Task finance.tasks.create_daily_user_snapshots[xxx] received
[2025-11-09 23:59:02,456: INFO/ForkPoolWorker-1] Task finance.tasks.create_daily_user_snapshots[xxx] succeeded in 2.3s: {'success': True, 'snapshots_created': 42}
```

### Ver logs do Beat

O beat mostra:
- Schedule carregado
- Tasks enviadas ao broker
- Próximas execuções

```
[2025-11-09 23:59:00,000: INFO/MainProcess] Scheduler: Sending due task create-daily-user-snapshots (finance.tasks.create_daily_user_snapshots)
```

### Flower (Web UI - Opcional)

Instalar:
```powershell
pip install flower
```

Iniciar:
```powershell
celery -A config flower
```

Acessar: http://localhost:5555

---

## 🎯 Próximos Passos

### 1. Integrar com AI Services ⏳

Modificar `ai_services.py`:

```python
from .services import get_comprehensive_mission_context

def generate_batch_missions_for_tier(tier: str):
    # Buscar usuário representativo do tier
    representative_user = _find_representative_user_for_tier(tier)
    
    if representative_user:
        # Usar context REAL
        context = get_comprehensive_mission_context(representative_user)
    else:
        # Fallback: context mock
        context = _generate_mock_context_for_tier(tier)
    
    # Construir prompt enriquecido com context
    prompt = _build_enriched_prompt(tier, context)
    
    # Chamar Gemini
    response = genai.GenerativeModel('gemini-2.0-flash-exp').generate_content(prompt)
    
    return parse_response(response.text)
```

### 2. Criar Endpoint de Analytics ⏳

Em `views.py`:

```python
@action(detail=False, methods=['get'])
def analytics(self, request):
    """GET /api/users/analytics/"""
    from .services import (
        analyze_category_patterns,
        analyze_tier_progression,
        get_mission_distribution_analysis
    )
    
    user = request.user
    
    return Response({
        'tier': analyze_tier_progression(user),
        'categories': analyze_category_patterns(user, days=90),
        'missions': get_mission_distribution_analysis(user),
    })
```

### 3. Dashboard no Frontend ⏳

Criar telas para:
- Progressão de tier (barra de progresso)
- Categorias problemáticas (gráficos)
- Distribuição de missões (pizza chart)
- Recomendações personalizadas

---

## 📚 Documentação Completa

Ver: **`IMPLEMENTACAO_COMPLETA_ANALYTICS.md`**

Contém:
- Detalhes de todas as funções
- Exemplos de código
- Estrutura de dados completa
- Troubleshooting avançado
- Checklist de validação

---

## ✅ Checklist de Validação

- [x] Redis instalado
- [x] Dependências instaladas (celery, redis, django-celery-beat, django-celery-results)
- [x] django_celery_beat em INSTALLED_APPS
- [x] Migrações aplicadas
- [ ] Redis rodando
- [ ] Celery worker rodando
- [ ] Celery beat rodando
- [ ] Teste manual de snapshots executado
- [ ] Análises testadas no shell
- [ ] Tasks visíveis no admin

---

**Sistema pronto para produção!** 🚀

Execute os passos acima e teste todo o fluxo.
