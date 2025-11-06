# 🤖 Fase 3 - IA e UX Inteligente

Sistema de geração de missões e sugestões inteligentes usando **Google Gemini 2.5 Flash**.

## 📋 Funcionalidades

### 1. Geração de Missões em Lote

Gera **60 missões mensais** (20 por faixa de usuário) usando IA:

- **BEGINNER** (Níveis 1-5): Missões focadas em hábitos básicos
- **INTERMEDIATE** (Níveis 6-15): Otimização de gastos
- **ADVANCED** (Níveis 16+): Metas avançadas de investimento

**Benefícios:**
- Custo: ~$0.004/mês (vs $7/mês com abordagem individual)
- Tier gratuito do Gemini suporta até 900 usuários ativos
- Missões contextualizadas sazonalmente (Janeiro, Férias, Black Friday, etc)
- Distribuição balanceada: 8 EASY, 8 MEDIUM, 4 HARD

### 2. Sugestão Inteligente de Categoria

Analisa descrição da transação e sugere categoria automaticamente:

**Estratégia de 3 níveis:**
1. Histórico do usuário (aprendizado)
2. Cache global (economia de API)
3. IA (Gemini 2.5 Flash)

**Performance:**
- 80% das sugestões via cache (sem custo)
- Apenas 20% chegam na IA
- Cache de 30 dias por sugestão

## 🚀 Instalação

### 1. Instalar dependências

```bash
cd Api
pip install -r requirements.txt
```

Isso instalará:
- `google-generativeai>=0.8.3`

### 2. Configurar API Key

Obtenha sua chave gratuita em: https://aistudio.google.com/apikey

Adicione ao `.env`:

```env
GEMINI_API_KEY=sua-chave-aqui
```

### 3. Verificar configuração

```python
# Django shell
python manage.py shell

from finance.ai_services import model
print("Gemini configurado:", model is not None)
```

## 📚 Uso

### Gerar Missões (Admin apenas)

```bash
# Via API
POST /api/missions/generate_ai_missions/
Authorization: Bearer <admin-token>

# Para todas as faixas (60 missões)
{}

# Para faixa específica (20 missões)
{
    "tier": "BEGINNER"
}
```

**Resposta:**
```json
{
    "success": true,
    "total_created": 60,
    "results": {
        "BEGINNER": {
            "generated": 20,
            "created": 20,
            "missions": [
                {
                    "id": "uuid",
                    "title": "Desafio da Economia Criativa",
                    "type": "SAVINGS",
                    "difficulty": "EASY",
                    "xp": 75
                }
            ]
        }
    }
}
```

### Sugerir Categoria

```bash
# Via API
POST /api/transactions/suggest_category/
Authorization: Bearer <user-token>
Content-Type: application/json

{
    "description": "Uber para o trabalho"
}
```

**Resposta:**
```json
{
    "suggested_category": {
        "id": "uuid",
        "name": "Transporte",
        "type": "EXPENSE",
        "confidence": 0.90
    }
}
```

### Teste Local (Django Shell)

```python
python manage.py shell

# Testar geração de missões
from finance.ai_services import generate_batch_missions_for_tier

batch = generate_batch_missions_for_tier('BEGINNER')
print(f"Geradas {len(batch)} missões")

for m in batch[:3]:
    print(f"\n{m['title']} ({m['difficulty']})")
    print(f"  {m['description']}")
    print(f"  XP: {m['xp_reward']} | Dias: {m['duration_days']}")

# Testar sugestão de categoria
from django.contrib.auth import get_user_model
from finance.ai_services import suggest_category

User = get_user_model()
user = User.objects.first()

category = suggest_category("Uber para o trabalho", user)
print(f"Categoria sugerida: {category.name if category else 'Nenhuma'}")
```

## 💰 Custos

### Gemini 2.5 Flash (Nov 2024)

**Pricing:**
- Input: $0.075 por 1M tokens
- Output: $0.30 por 1M tokens
- **Tier Gratuito:** 15 req/min, 1500 req/dia

**Estimativa (1000 usuários ativos/mês):**

| Funcionalidade | Requests/mês | Custo/mês |
|---------------|--------------|-----------|
| Geração de Missões | 3 batches | ~$0.004 |
| Sugestão de Categoria | 10K (20% de 50K) | ~$0.19 |
| **TOTAL** | | **~$0.20** |

**Comparação:**
- OpenAI Individual: $7.00/mês (3400% mais caro)
- OpenAI Batch: $2.50/mês (1150% mais caro)
- **Gemini Batch: $0.20/mês ✅**

### Tier Gratuito

Suporta até **1500 requests/dia = 45K/mês**

**Capacidade:**
- Geração mensal: 3 requests/mês (OK)
- Sugestões: ~44.9K requests/mês
- **Suporta ~900 usuários ativos com custo ZERO**

## 🧪 Estrutura do Prompt

### Prompt de Geração (BATCH_MISSION_GENERATION_PROMPT)

```python
"""
Você é um especialista em educação financeira criando missões gamificadas.

## CONTEXTO DO SISTEMA
- TPS (Taxa de Poupança): (Receitas - Despesas) / Receitas × 100
- RDR (Razão Dívida-Receita): Total Dívidas / Receita × 100

## FAIXA DE USUÁRIOS: {tier}
- Nível médio: {avg_level}
- TPS médio: {avg_tps}%
- RDR médio: {avg_rdr}%
- Categorias comuns: {common_categories}

## PERÍODO: {period_name}
{period_context}

## TAREFA
Crie 20 missões:
- 8 SAVINGS (TPS)
- 7 EXPENSE_CONTROL (Categorias)
- 5 DEBT_REDUCTION (RDR)

Distribuição:
- 8 EASY (80% alcançável)
- 8 MEDIUM (50% alcançável)
- 4 HARD (20% alcançável)

Formato JSON...
"""
```

### Descrições de Faixas

**BEGINNER (1-5):**
- Falta de controle sobre gastos
- Não registra transações consistentemente
- TPS baixo ou negativo
- **Foco:** Hábitos básicos, categorização, metas alcançáveis

**INTERMEDIATE (6-15):**
- Registro consistente
- TPS positivo mas pode melhorar
- Entende conceitos
- **Foco:** Otimização de categorias, aumento gradual de TPS

**ADVANCED (16+):**
- TPS alto (>25%)
- Dívidas controladas
- Usa app há meses
- **Foco:** Metas ambiciosas (30%+ TPS), estratégias avançadas

### Contextos Sazonais

**Janeiro:** Ano Novo, metas anuais, recuperação de dezembro
**Julho:** Revisão de meio de ano, férias
**Novembro:** Black Friday, preparação para festas
**Dezembro:** Gastos de festas, planejamento do próximo ano

## 🔧 Arquitetura

```
finance/
├── ai_services.py          # Lógica de IA (Gemini)
│   ├── generate_batch_missions_for_tier()
│   ├── create_missions_from_batch()
│   ├── suggest_category()
│   └── get_user_tier_stats()
│
├── views.py               # Endpoints
│   ├── MissionViewSet.generate_ai_missions()  (admin)
│   └── TransactionViewSet.suggest_category()  (user)
│
└── tasks.py (futuro)      # Celery tasks
    └── generate_monthly_missions()
```

## 📊 Monitoramento

### Logs

```python
import logging
logger = logging.getLogger('finance.ai_services')

# Verificar logs
tail -f logs/django.log | grep "ai_services"
```

### Métricas

```python
# Django shell
from django.core.cache import cache
from finance.models import Mission

# Cache hits
cache_hits = cache.get('ai_cache_hits', 0)
cache_misses = cache.get('ai_cache_misses', 0)
print(f"Cache hit rate: {cache_hits/(cache_hits+cache_misses)*100:.1f}%")

# Missões geradas este mês
import datetime
this_month = datetime.datetime.now().replace(day=1)
missions = Mission.objects.filter(created_at__gte=this_month).count()
print(f"Missões geradas este mês: {missions}")
```

## 🐛 Troubleshooting

### Erro: "Gemini API não configurada"

**Solução:**
```bash
# Verificar .env
cat .env | grep GEMINI

# Adicionar se faltando
echo "GEMINI_API_KEY=sua-chave" >> .env

# Reiniciar servidor
python manage.py runserver
```

### Erro: JSON inválido da API

**Causa:** Gemini às vezes retorna markdown
**Solução:** Código já trata isso automaticamente:

```python
# Remove ```json e ``` da resposta
if response_text.startswith('```json'):
    response_text = response_text[7:]
```

### Taxa de cache baixa (<50%)

**Solução:**
```python
# Aumentar TTL do cache
cache.set(cache_key, category.id, timeout=7776000)  # 90 dias
```

## 📈 Próximos Passos

### Semana 2
- [ ] Criar Celery task para geração automática (1º dia do mês)
- [ ] Adicionar campo `tier` no modelo Mission
- [ ] Endpoint de listagem por tier

### Semana 3
- [ ] Melhorar confiança da sugestão (score real)
- [ ] A/B testing de prompts
- [ ] Insights proativos

### Futuro
- [ ] Modelo local (Llama/Mistral) como fallback
- [ ] Personalização por histórico de aceite
- [ ] Multi-idioma

## 📚 Referências

- [Gemini API Docs](https://ai.google.dev/gemini-api/docs)
- [Pricing](https://ai.google.dev/pricing)
- [Best Practices](https://ai.google.dev/gemini-api/docs/prompting-strategies)
- [Rate Limits](https://ai.google.dev/gemini-api/docs/rate-limits)

---

**Criado em:** 6 de novembro de 2025  
**Status:** ✅ Implementação inicial completa  
**Custo:** $0.00 (tier gratuito)
