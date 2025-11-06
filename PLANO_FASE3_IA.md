# 🤖 FASE 3 - IA E UX INTELIGENTE

**Status:** 🟡 Iniciando  
**Prioridade:** Média-Alta  
**Início:** 6 de novembro de 2025  
**Duração Estimada:** 2-3 semanas  

---

## 🎯 Objetivos

1. **Geração de Missões com IA** - Criar missões personalizadas usando ChatGPT
2. **Sugestões Inteligentes** - Categorizar transações automaticamente
3. **Personalização Avançada** - Adaptar missões ao perfil do usuário
4. **Insights Proativos** - Alertas e recomendações baseadas em IA

---

## 📋 Implementações Planejadas

### 1. 🤖 Sistema de Geração de Missões com IA

**Objetivo:** Criar missões variadas e personalizadas usando ChatGPT

**Tecnologia:**
- Google Gemini 2.5 Flash (mais rápido e econômico)
- Prompts estruturados por faixas de usuários
- Batch generation mensal/sazonal com Celery
- Geração em lotes por perfil de usuário

**Funcionalidades:**
```python
# Exemplos de missões geradas por IA:
{
    "title": "Desafio da Economia Criativa",
    "description": "Reduza gastos com entretenimento em 20% este mês",
    "mission_type": "SAVINGS",
    "target_tps": 25.0,
    "duration_days": 30,
    "xp_reward": 150
}

{
    "title": "Mestre das Finanças Mensais",
    "description": "Mantenha suas despesas essenciais abaixo de 50% da renda",
    "mission_type": "EXPENSE_CONTROL",
    "target_rdr": 35.0,
    "duration_days": 30,
    "xp_reward": 200
}
```

**Estratégia de Geração em Lotes:**

**Faixas de Usuários:**
1. **Iniciantes (Nível 1-5)** - Foco em hábitos básicos
2. **Intermediários (Nível 6-15)** - Desafios de otimização
3. **Avançados (Nível 16+)** - Metas complexas de investimento

**Sazonalidade:**
- Missões mensais geradas no dia 1° de cada mês
- Missões sazonais (Ano Novo, Férias, Volta às Aulas, Black Friday)
- Refresh semanal de missões ativas

**Prompt Template (Geração em Lote):**
```python
BATCH_MISSION_GENERATION_PROMPT = """
Você é um especialista em educação financeira criando missões gamificadas para um sistema de gestão financeira pessoal.

## CONTEXTO DO SISTEMA

O sistema usa gamificação para ensinar educação financeira através de missões. Usuários ganham XP ao completar desafios.

**Métricas Principais:**
- TPS (Taxa de Poupança Sobre Receitas): % da receita que vira poupança/investimento
  * Meta saudável: 20-30%
  * Cálculo: (Receitas - Despesas) / Receitas × 100
  
- RDR (Razão Dívida-Receita): % da receita comprometida com dívidas
  * Meta saudável: <30%
  * Cálculo: Total de Dívidas / Receita Mensal × 100

## FAIXA DE USUÁRIOS: {user_tier}

{tier_description}

**Características desta faixa:**
- Nível médio: {avg_level}
- TPS médio atual: {avg_tps}%
- RDR médio atual: {avg_rdr}%
- Categorias de gasto mais comuns: {common_categories}
- Experiência com o app: {experience_level}

## PERÍODO: {period_type} - {period_name}

{period_context}

## TAREFA

Crie 20 missões variadas e progressivas para esta faixa de usuários neste período.

**Requisitos:**

1. **Distribuição por Tipo:**
   - 8 missões de SAVINGS (melhoria de TPS)
   - 7 missões de EXPENSE_CONTROL (controle de categorias)
   - 5 missões de DEBT_REDUCTION (melhoria de RDR)

2. **Distribuição por Dificuldade:**
   - 8 missões EASY (alcançável para 80% da faixa)
   - 8 missões MEDIUM (alcançável para 50% da faixa)
   - 4 missões HARD (desafio para 20% da faixa)

3. **Variedade de Duração:**
   - Missões curtas: 7 dias (ações rápidas)
   - Missões médias: 14-21 dias (formação de hábito)
   - Missões longas: 30 dias (transformação mensal)

4. **Progressão de Recompensa:**
   - EASY: 50-100 XP
   - MEDIUM: 100-200 XP
   - HARD: 200-350 XP

5. **Contextualização:**
   - Use {period_name} no título/descrição quando relevante
   - Mencione {common_categories} em missões de EXPENSE_CONTROL
   - Adapte metas ao perfil da faixa

**Formato de Resposta (JSON):**
```json
[
    {
        "title": "Título criativo e motivador (max 60 caracteres)",
        "description": "Descrição clara do desafio e benefício educacional (max 200 caracteres)",
        "mission_type": "SAVINGS|EXPENSE_CONTROL|DEBT_REDUCTION",
        "target_tps": float ou null (use para SAVINGS, ex: 25.0 significa meta de 25% TPS),
        "target_rdr": float ou null (use para DEBT_REDUCTION, ex: 30.0 significa meta de 30% RDR),
        "target_category": "nome_categoria" ou null (use para EXPENSE_CONTROL),
        "target_reduction_percent": float ou null (use para EXPENSE_CONTROL, ex: 15.0 significa reduzir 15%),
        "duration_days": int (7, 14, 21 ou 30),
        "xp_reward": int,
        "difficulty": "EASY|MEDIUM|HARD",
        "tags": ["tag1", "tag2"] (ex: ["mensal", "habito", "categoria_alimentacao"])
    }
]
```

**IMPORTANTE:**
- Seja específico e mensurável
- Use linguagem motivadora, não punitiva
- Varie os títulos e descrições
- Adapte as metas ao nível da faixa
- Mantenha consistência JSON válido

Retorne APENAS o array JSON, sem texto adicional.
"""
```

**Implementação:**

```python
# finance/ai_services.py (NOVO ARQUIVO)
import google.generativeai as genai
from django.conf import settings
from django.db.models import Avg, Count, Sum, Q
from decimal import Decimal
import json
import datetime

# Configurar Gemini
genai.configure(api_key=settings.GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-2.0-flash-exp')

# Descrições das faixas de usuários
USER_TIER_DESCRIPTIONS = {
    'BEGINNER': """
**INICIANTES (Níveis 1-5)**

Usuários que estão começando sua jornada de educação financeira. Muitos ainda não têm 
clareza sobre para onde vai seu dinheiro e estão aprendendo conceitos básicos.

**Desafios Comuns:**
- Falta de controle sobre gastos
- Não tem hábito de registrar transações
- Poucas categorias organizadas
- TPS baixo ou negativo
- Não sabem quanto ganham/gastam realmente

**Foco das Missões:**
- Criar hábito de registro
- Identificar vazamentos financeiros
- Estabelecer categorias básicas
- Metas pequenas e alcançáveis
- Educação sobre conceitos (TPS, RDR)
""",
    'INTERMEDIATE': """
**INTERMEDIÁRIOS (Níveis 6-15)**

Usuários que já têm controle básico e estão otimizando suas finanças. Registram 
transações regularmente e entendem os conceitos fundamentais.

**Características:**
- Registro consistente de transações
- TPS positivo mas pode melhorar
- Entende categorias e usa regularmente
- Começa a pensar em objetivos financeiros
- Pode ter dívidas sob controle

**Foco das Missões:**
- Otimização de gastos por categoria
- Aumento gradual de TPS
- Redução estratégica de dívidas
- Metas de médio prazo
- Identificação de padrões de consumo
""",
    'ADVANCED': """
**AVANÇADOS (Níveis 16+)**

Usuários experientes com controle financeiro consolidado. Buscam otimização avançada 
e estratégias de investimento.

**Características:**
- TPS consistentemente alto (>25%)
- Categorias bem organizadas
- Dívidas controladas ou zeradas
- Pensa em investimentos e patrimônio
- Usa o app há meses

**Foco das Missões:**
- Metas ambiciosas de TPS (30%+)
- Otimização fina de categorias
- Estratégias de alocação
- Desafios de longo prazo
- Preparação para objetivos maiores (casa, carro, aposentadoria)
"""
}

# Contextos sazonais
SEASONAL_CONTEXTS = {
    'january': """
**Janeiro - Ano Novo, Novos Começos**

Momento de renovação e planejamento. Muitos usuários estão motivados após as festas 
e querem começar o ano com o pé direito financeiramente.

**Oportunidades:**
- Metas anuais de economia
- Recuperação de excessos de dezembro
- Planejamento de grandes objetivos
- Limpeza financeira (cancelar assinaturas não usadas)
""",
    'july': """
**Julho - Metade do Ano, Revisão de Metas**

Momento de avaliar o progresso do ano e fazer ajustes. Férias escolares podem impactar 
orçamentos familiares.

**Oportunidades:**
- Revisão de metas do ano
- Ajustes de categoria para férias
- Preparação para 2º semestre
- Análise de progresso TPS/RDR
""",
    'november': """
**Novembro - Black Friday e Preparação para Festas**

Mês de tentações de consumo com promoções. Importante manter controle antes das 
despesas de dezembro.

**Oportunidades:**
- Resistir a compras impulsivas
- Planejamento de presentes
- Economia para festas
- Análise crítica de "promoções"
""",
    'default': """
**Período Regular**

Mês comum, foco em manutenção de hábitos e progresso incremental.
"""
}


def get_user_tier_stats(tier):
    """
    Calcula estatísticas agregadas para uma faixa de usuários.
    """
    from django.contrib.auth import get_user_model
    from .models import UserProfile, Transaction
    from .services import calculate_summary
    
    User = get_user_model()
    
    # Definir range de níveis
    if tier == 'BEGINNER':
        level_range = (1, 5)
    elif tier == 'INTERMEDIATE':
        level_range = (6, 15)
    else:  # ADVANCED
        level_range = (16, 100)
    
    # Buscar usuários da faixa
    users = User.objects.filter(
        userprofile__level__gte=level_range[0],
        userprofile__level__lte=level_range[1],
        is_active=True
    )
    
    if not users.exists():
        return None
    
    # Calcular médias
    avg_level = UserProfile.objects.filter(
        user__in=users
    ).aggregate(avg=Avg('level'))['avg'] or level_range[0]
    
    # Categorias mais comuns
    top_categories = Transaction.objects.filter(
        user__in=users,
        type='EXPENSE'
    ).values('category__name').annotate(
        count=Count('id')
    ).order_by('-count')[:5]
    
    common_categories = [cat['category__name'] for cat in top_categories if cat['category__name']]
    
    # Calcular TPS e RDR médios (amostra de 50 usuários para performance)
    sample_users = users[:50]
    tps_values = []
    rdr_values = []
    
    for user in sample_users:
        try:
            summary = calculate_summary(user)
            tps_values.append(float(summary.get('tps', 0)))
            rdr_values.append(float(summary.get('rdr', 0)))
        except:
            continue
    
    avg_tps = sum(tps_values) / len(tps_values) if tps_values else 10.0
    avg_rdr = sum(rdr_values) / len(rdr_values) if rdr_values else 50.0
    
    # Experiência
    if tier == 'BEGINNER':
        experience = "Primeiras semanas no app"
    elif tier == 'INTERMEDIATE':
        experience = "1-3 meses de uso regular"
    else:
        experience = "Mais de 3 meses de uso consistente"
    
    return {
        'tier': tier,
        'avg_level': round(avg_level, 1),
        'avg_tps': round(avg_tps, 1),
        'avg_rdr': round(avg_rdr, 1),
        'common_categories': ', '.join(common_categories[:3]) or 'Alimentação, Transporte, Moradia',
        'experience_level': experience,
        'user_count': users.count()
    }


def get_period_context():
    """
    Retorna contexto do período atual (mês/sazonalidade).
    """
    now = datetime.datetime.now()
    month = now.strftime('%B').lower()
    
    # Meses especiais
    special_months = {
        'january': ('MENSAL', 'Janeiro', SEASONAL_CONTEXTS['january']),
        'july': ('MENSAL', 'Julho', SEASONAL_CONTEXTS['july']),
        'november': ('MENSAL', 'Novembro', SEASONAL_CONTEXTS['november']),
    }
    
    if month in special_months:
        return special_months[month]
    
    # Mês comum
    month_name = now.strftime('%B')
    return ('MENSAL', month_name, SEASONAL_CONTEXTS['default'])


def generate_batch_missions_for_tier(tier):
    """
    Gera 20 missões em lote para uma faixa de usuários usando Gemini.
    
    Args:
        tier: 'BEGINNER', 'INTERMEDIATE' ou 'ADVANCED'
        
    Returns:
        List[dict]: Lista de 20 missões geradas
    """
    # Coletar estatísticas da faixa
    stats = get_user_tier_stats(tier)
    if not stats:
        return []
    
    # Contexto do período
    period_type, period_name, period_context = get_period_context()
    
    # Montar prompt
    prompt = BATCH_MISSION_GENERATION_PROMPT.format(
        user_tier=tier,
        tier_description=USER_TIER_DESCRIPTIONS[tier],
        avg_level=stats['avg_level'],
        avg_tps=stats['avg_tps'],
        avg_rdr=stats['avg_rdr'],
        common_categories=stats['common_categories'],
        experience_level=stats['experience_level'],
        period_type=period_type,
        period_name=period_name,
        period_context=period_context
    )
    
    try:
        # Chamar Gemini
        response = model.generate_content(
            prompt,
            generation_config={
                'temperature': 0.8,
                'top_p': 0.95,
                'max_output_tokens': 8000,
            }
        )
        
        # Parse resposta
        response_text = response.text.strip()
        
        # Remover markdown se presente
        if response_text.startswith('```json'):
            response_text = response_text[7:]
        if response_text.startswith('```'):
            response_text = response_text[3:]
        if response_text.endswith('```'):
            response_text = response_text[:-3]
        
        missions = json.loads(response_text.strip())
        
        # Validar estrutura
        if not isinstance(missions, list):
            raise ValueError("Resposta não é uma lista")
        
        return missions
        
    except Exception as e:
        print(f"Erro ao gerar missões para {tier}: {e}")
        return []


def create_missions_from_batch(tier, missions_data):
    """
    Cria missões no banco a partir do batch gerado.
    
    Args:
        tier: Faixa de usuários
        missions_data: Lista de dicts com dados das missões
        
    Returns:
        List[Mission]: Missões criadas
    """
    from .models import Mission, Category
    
    created_missions = []
    
    for data in missions_data:
        try:
            # Buscar categoria se especificada
            target_category = None
            if data.get('target_category'):
                # Categoria global ou primeira do tipo
                target_category = Category.objects.filter(
                    Q(name__icontains=data['target_category']) | 
                    Q(type__iexact=data['target_category'])
                ).first()
            
            mission = Mission.objects.create(
                title=data['title'],
                description=data['description'],
                mission_type=data['mission_type'],
                target_tps=Decimal(str(data['target_tps'])) if data.get('target_tps') else None,
                target_rdr=Decimal(str(data['target_rdr'])) if data.get('target_rdr') else None,
                duration_days=data['duration_days'],
                xp_reward=data['xp_reward'],
                is_active=True,
                priority=data['difficulty'],
                # Adicionar tier como metadata (pode criar campo depois)
                # tier=tier,
                # tags=data.get('tags', [])
            )
            created_missions.append(mission)
            
        except Exception as e:
            print(f"Erro ao criar missão '{data.get('title', 'unknown')}': {e}")
            continue
    
    return created_missions


def generate_all_monthly_missions():
    """
    Gera missões mensais para todas as faixas de usuários (60 missões total).
    
    Uso em Celery task agendada para 1º dia do mês.
    """
    all_missions = []
    
    for tier in ['BEGINNER', 'INTERMEDIATE', 'ADVANCED']:
        print(f"Gerando missões para {tier}...")
        
        batch = generate_batch_missions_for_tier(tier)
        if batch:
            created = create_missions_from_batch(tier, batch)
            all_missions.extend(created)
            print(f"  ✓ {len(created)} missões criadas")
        else:
            print(f"  ✗ Falha ao gerar batch")
    
    return all_missions
```

**Configuração:**
```python
# settings.py
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY', '')

# Custo estimado (Gemini 2.5 Flash):
# Input: $0.075 por 1M tokens
# Output: $0.30 por 1M tokens
#
# Por batch (20 missões):
# - Input: ~2K tokens = $0.00015
# - Output: ~4K tokens = $0.0012
# - Total por batch: ~$0.0014
#
# 3 batches/mês (BEGINNER, INTERMEDIATE, ADVANCED):
# = 60 missões totais = ~$0.0042/mês
#
# Muito mais econômico que gerar individual!
# 1000 usuários teriam acesso a 60 missões por ~$0.004/mês
```

**Agendamento com Celery:**
```python
# finance/tasks.py
from celery import shared_task
from .ai_services import generate_all_monthly_missions

@shared_task
def generate_monthly_missions():
    """
    Gera 60 missões novas mensalmente (20 por faixa).
    
    Agendamento: 1º dia de cada mês às 02:00
    Cron: 0 2 1 * *
    
    Benefícios:
    - 1 chamada à API vs 1000+ chamadas
    - Missões consistentes para toda faixa
    - Custo ~$0.004/mês vs ~$7/mês
    - Processamento em minutos vs horas
    """
    try:
        missions = generate_all_monthly_missions()
        return {
            'status': 'success',
            'missions_created': len(missions),
            'timestamp': datetime.datetime.now().isoformat()
        }
    except Exception as e:
        return {
            'status': 'error',
            'error': str(e),
            'timestamp': datetime.datetime.now().isoformat()
        }


# Configuração no celery beat
# celerybeat-schedule.py ou settings.py
from celery.schedules import crontab

CELERY_BEAT_SCHEDULE = {
    'generate-monthly-missions': {
        'task': 'finance.tasks.generate_monthly_missions',
        'schedule': crontab(hour=2, minute=0, day_of_month=1),
    },
}
```

---

### 2. 📊 Sugestões Inteligentes de Categoria

**Objetivo:** Categorizar transações automaticamente baseado na descrição

**Tecnologia:**
- Google Gemini 2.5 Flash
- Cache agressivo de sugestões comuns
- Aprendizado com feedback do usuário (histórico)

**Fluxo:**
```
1. Usuário cria transação com descrição
2. Sistema verifica cache de sugestões
3. Se não encontrado, envia para IA
4. IA analisa descrição e sugere categoria
5. Sistema aprende com escolha do usuário
```

**Implementação:**
```python
# finance/ai_services.py
def suggest_category(description, user):
    """
    Sugere categoria baseado na descrição.
    
    Args:
        description: Descrição da transação
        user: Usuário (para aprender preferências)
        
    Returns:
        Category: Categoria sugerida
    """
    from .models import Category, Transaction
    
    # 1. Verificar histórico do usuário
    similar = Transaction.objects.filter(
        user=user,
        description__icontains=description[:20]
    ).values('category').annotate(
        count=Count('id')
    ).order_by('-count').first()
    
    if similar and similar['count'] >= 3:
        # Usuário já usou esta categoria 3+ vezes
        return Category.objects.get(id=similar['category'])
    
    # 2. Buscar em cache global
    cache_key = f'category_suggestion_{description.lower()[:50]}'
    cached = cache.get(cache_key)
    if cached:
        return Category.objects.get(id=cached)
    
    # 3. Usar IA (Gemini)
    user_categories = Category.objects.filter(user=user).values_list('name', flat=True)
    categories_list = '\n'.join([f"- {cat}" for cat in user_categories])
    
    prompt = f"""
Categorize esta transação financeira:

Descrição: "{description}"

Categorias do usuário:
{categories_list}

Responda APENAS com o nome exato de UMA categoria da lista acima.
Se nenhuma se encaixar perfeitamente, escolha a mais próxima.
Não adicione explicações.
    """
    
    response = model.generate_content(
        prompt,
        generation_config={
            'temperature': 0.2,
            'max_output_tokens': 20,
        }
    )
    
    category_name = response.text.strip()
    
    # Buscar categoria
    category = Category.objects.filter(
        user=user,
        name__icontains=category_name
    ).first()
    
    if category:
        # Cachear sugestão por 30 dias
        cache.set(cache_key, category.id, timeout=2592000)
        return category
    
    return None
```

**Endpoint:**
```python
# finance/views.py
@action(detail=False, methods=['post'])
def suggest_category(self, request):
    """
    POST /api/transactions/suggest_category/
    {
        "description": "Uber para o trabalho"
    }
    
    Response:
    {
        "suggested_category": {
            "id": "uuid",
            "name": "Transporte",
            "confidence": 0.95
        }
    }
    """
    description = request.data.get('description', '')
    
    if not description:
        return Response(
            {'error': 'Descrição é obrigatória'},
            status=400
        )
    
    category = suggest_category(description, request.user)
    
    if category:
        return Response({
            'suggested_category': {
                'id': category.id,
                'name': category.name,
                'type': category.type,
                'confidence': 0.90  # Placeholder
            }
        })
    
    return Response({'suggested_category': None})
```

---

### 3. 🎯 Personalização de Missões

**Objetivo:** Adaptar missões ao comportamento e nível do usuário

**Estratégias:**
1. **Dificuldade Adaptativa** - Missões mais fáceis para iniciantes
2. **Baseado em Histórico** - Missões relacionadas a categorias problemáticas
3. **Metas Progressivas** - Aumentar dificuldade conforme usuário evolui

**Implementação:**
```python
def personalize_mission_for_user(user, base_mission):
    """
    Personaliza uma missão baseado no perfil do usuário.
    """
    profile = user.userprofile
    summary = calculate_summary(user)
    
    # Ajustar dificuldade
    if profile.level < 5:
        # Iniciante: missões mais fáceis
        multiplier = 0.8
    elif profile.level < 15:
        # Intermediário
        multiplier = 1.0
    else:
        # Avançado: missões mais desafiadoras
        multiplier = 1.2
    
    # Ajustar targets
    if base_mission.target_tps:
        current_tps = float(summary['tps'])
        # Meta: melhorar 20% sobre atual
        new_target = current_tps * 1.2 * multiplier
        base_mission.target_tps = Decimal(str(new_target))
    
    if base_mission.target_rdr:
        current_rdr = float(summary['rdr'])
        # Meta: reduzir 15%
        new_target = current_rdr * 0.85 / multiplier
        base_mission.target_rdr = Decimal(str(new_target))
    
    # Ajustar recompensa
    base_mission.xp_reward = int(base_mission.xp_reward * multiplier)
    
    return base_mission
```

---

### 4. 💡 Insights Proativos

**Objetivo:** Alertas e recomendações inteligentes

**Exemplos:**
```python
insights = [
    {
        "type": "warning",
        "title": "Gastos com lazer acima da média",
        "message": "Você gastou 30% a mais com lazer este mês comparado aos últimos 3 meses.",
        "suggestion": "Considere reduzir gastos com entretenimento para atingir sua meta de poupança."
    },
    {
        "type": "success",
        "title": "Parabéns! Meta de TPS atingida",
        "message": "Seu TPS este mês foi de 28%, acima da meta de 25%!",
        "reward_xp": 50
    },
    {
        "type": "info",
        "title": "Oportunidade de economia",
        "message": "Transações frequentes com 'Uber' detectadas. Considere usar transporte público.",
        "potential_savings": 250.00
    }
]
```

---

## 📊 Custos Estimados

### OpenAI API
```
GPT-3.5-turbo:
- $0.0005 por 1K tokens (input)
- $0.0015 por 1K tokens (output)

Estimativa mensal (1000 usuários ativos):
- Geração de missões: 1K users × 1 request/semana × 4 = 4K requests
  ~1500 tokens/request = 6M tokens = ~$4/mês
  
- Sugestões de categoria: 1K users × 50 transações/mês = 50K requests
  ~100 tokens/request = 5M tokens = ~$3/mês
  
Total estimado: ~$7/mês para 1000 usuários ativos
```

### Alternativas Gratuitas
- Usar modelos locais (Llama, Mistral) - Sem custo de API
- Cache agressivo - Reduzir chamadas em 80%
- Sugestões baseadas em regras - Híbrido IA + rules

---

## 🚀 Roadmap de Implementação

### Semana 1
- [x] Configurar OpenAI API
- [ ] Implementar `generate_missions_with_ai()`
- [ ] Criar endpoint de teste
- [ ] Validar qualidade das missões geradas

### Semana 2
- [ ] Implementar `suggest_category()`
- [ ] Adicionar cache de sugestões
- [ ] Endpoint `/suggest_category/`
- [ ] Frontend: integração de sugestões

### Semana 3
- [ ] Personalização de missões
- [ ] Insights proativos
- [ ] Celery task para batch generation
- [ ] Testes e ajustes

---

## 🧪 Como Testar

### Teste Local
```python
# Django shell
from finance.ai_services import generate_batch_missions_for_tier, generate_all_monthly_missions

# Gerar batch para iniciantes
batch = generate_batch_missions_for_tier('BEGINNER')
print(f"Geradas {len(batch)} missões")
for m in batch[:3]:
    print(f"\n{m['title']} ({m['difficulty']})")
    print(f"  {m['description']}")
    print(f"  XP: {m['xp_reward']} | Dias: {m['duration_days']}")

# Gerar todas (60 missões)
all_missions = generate_all_monthly_missions()
print(f"\nTotal: {len(all_missions)} missões criadas no DB")
```

### Teste via API
```bash
# Sugerir categoria
curl -X POST http://localhost:8000/api/transactions/suggest_category/ \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"description": "Uber para o trabalho"}'
```

---

## 📚 Referências

- [OpenAI API Docs](https://platform.openai.com/docs/api-reference)
- [GPT Best Practices](https://platform.openai.com/docs/guides/gpt-best-practices)
- [Prompt Engineering Guide](https://www.promptingguide.ai/)

---

**Criado em:** 6 de novembro de 2025  
**Status:** 🟡 Planejamento completo, iniciando implementação
