"""
Serviços de IA para geração de missões e sugestões inteligentes.

Este módulo usa Google Gemini 2.5 Flash para:
1. Gerar missões em lote por faixa de usuário (BEGINNER, INTERMEDIATE, ADVANCED)
2. Sugerir categorias para transações baseado em descrição
3. Personalizar experiência do usuário

Estratégia de geração em lote:
- 3 batches mensais (1 por faixa de usuário)
- 20 missões por batch = 60 missões totais/mês
- Custo estimado: ~$0.004/mês (tier gratuito até 1500 req/dia)
"""

import google.generativeai as genai
from django.conf import settings
from django.db.models import Avg, Count, Sum, Q
from django.core.cache import cache
from decimal import Decimal
import json
import datetime
import logging

logger = logging.getLogger(__name__)

# Configurar Gemini
try:
    genai.configure(api_key=settings.GEMINI_API_KEY)
    model = genai.GenerativeModel('gemini-2.0-flash-exp')
except Exception as e:
    logger.warning(f"Gemini API não configurada: {e}")
    model = None


# ==================== DESCRIÇÕES DAS FAIXAS DE USUÁRIOS ====================

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


# ==================== CONTEXTOS SAZONAIS ====================

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
    'february': """
**Fevereiro - Planejamento e Disciplina**

Mês de manter o foco nas metas estabelecidas em janeiro. Período de consolidação de hábitos.

**Oportunidades:**
- Reforçar hábitos iniciados em janeiro
- Ajustar metas se necessário
- Preparação para gastos de meio de ano
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
    'december': """
**Dezembro - Festas e Planejamento do Próximo Ano**

Mês de gastos maiores mas também de planejamento para o ano seguinte.

**Oportunidades:**
- Controle de gastos com festas
- Análise do ano completo
- Definição de metas para próximo ano
- Balanço financeiro anual
""",
    'default': """
**Período Regular**

Mês comum, foco em manutenção de hábitos e progresso incremental.

**Oportunidades:**
- Manter consistência
- Progresso gradual em TPS/RDR
- Otimização de categorias específicas
"""
}


# ==================== PROMPT TEMPLATE ====================

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
Retorne APENAS um array JSON válido, sem texto adicional antes ou depois.

[
    {{
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
        "tags": ["tag1", "tag2"]
    }}
]

**IMPORTANTE:**
- Seja específico e mensurável
- Use linguagem motivadora, não punitiva
- Varie os títulos e descrições
- Adapte as metas ao nível da faixa
- Mantenha consistência JSON válido
"""


# ==================== FUNÇÕES AUXILIARES ====================

def get_user_tier_stats(tier):
    """
    Calcula estatísticas agregadas para uma faixa de usuários.
    
    Args:
        tier: 'BEGINNER', 'INTERMEDIATE' ou 'ADVANCED'
        
    Returns:
        dict: Estatísticas da faixa ou None se não houver usuários
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
        # Retornar valores padrão se não houver usuários
        logger.warning(f"Nenhum usuário encontrado para {tier}, usando valores padrão")
        return {
            'tier': tier,
            'avg_level': level_range[0],
            'avg_tps': 10.0 if tier == 'BEGINNER' else 20.0 if tier == 'INTERMEDIATE' else 30.0,
            'avg_rdr': 60.0 if tier == 'BEGINNER' else 40.0 if tier == 'INTERMEDIATE' else 20.0,
            'common_categories': 'Alimentação, Transporte, Moradia',
            'experience_level': 'Primeiras semanas' if tier == 'BEGINNER' else '1-3 meses' if tier == 'INTERMEDIATE' else 'Mais de 3 meses',
            'user_count': 0
        }
    
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
    sample_users = list(users[:50])
    tps_values = []
    rdr_values = []
    
    for user in sample_users:
        try:
            summary = calculate_summary(user)
            tps_values.append(float(summary.get('tps', 0)))
            rdr_values.append(float(summary.get('rdr', 0)))
        except Exception as e:
            logger.debug(f"Erro ao calcular summary para {user.id}: {e}")
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
        'common_categories': ', '.join(common_categories[:3]) if common_categories else 'Alimentação, Transporte, Moradia',
        'experience_level': experience,
        'user_count': users.count()
    }


def get_period_context():
    """
    Retorna contexto do período atual (mês/sazonalidade).
    
    Returns:
        tuple: (tipo, nome, contexto)
    """
    now = datetime.datetime.now()
    month = now.strftime('%B').lower()
    
    # Buscar contexto sazonal
    if month in SEASONAL_CONTEXTS:
        month_name = now.strftime('%B')
        return ('MENSAL', month_name, SEASONAL_CONTEXTS[month])
    
    # Mês comum
    month_name = now.strftime('%B')
    return ('MENSAL', month_name, SEASONAL_CONTEXTS['default'])


# ==================== GERAÇÃO DE MISSÕES ====================

def generate_batch_missions_for_tier(tier):
    """
    Gera 20 missões em lote para uma faixa de usuários usando Gemini.
    
    Args:
        tier: 'BEGINNER', 'INTERMEDIATE' ou 'ADVANCED'
        
    Returns:
        List[dict]: Lista de 20 missões geradas ou lista vazia em caso de erro
    """
    if not model:
        logger.error("Gemini API não configurada")
        return []
    
    # Verificar cache (missões do mesmo mês)
    cache_key = f'ai_missions_{tier}_{datetime.datetime.now().strftime("%Y_%m")}'
    cached_missions = cache.get(cache_key)
    if cached_missions:
        logger.info(f"Usando missões em cache para {tier}")
        return cached_missions
    
    # Coletar estatísticas da faixa
    stats = get_user_tier_stats(tier)
    
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
        logger.info(f"Gerando missões para {tier} via Gemini API...")
        
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
        elif response_text.startswith('```'):
            response_text = response_text[3:]
        
        if response_text.endswith('```'):
            response_text = response_text[:-3]
        
        missions = json.loads(response_text.strip())
        
        # Validar estrutura
        if not isinstance(missions, list):
            raise ValueError("Resposta não é uma lista")
        
        if len(missions) < 10:
            logger.warning(f"Apenas {len(missions)} missões geradas para {tier}")
        
        # Cachear por 30 dias
        cache.set(cache_key, missions, timeout=2592000)
        
        logger.info(f"✓ {len(missions)} missões geradas para {tier}")
        return missions
        
    except json.JSONDecodeError as e:
        logger.error(f"Erro ao parsear JSON da resposta Gemini para {tier}: {e}")
        logger.debug(f"Resposta recebida: {response_text[:500]}")
        return []
    except Exception as e:
        logger.error(f"Erro ao gerar missões para {tier}: {e}")
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
                # Categoria global (sem user) ou primeira do tipo
                target_category = Category.objects.filter(
                    Q(name__icontains=data['target_category']) | 
                    Q(type__iexact=data['target_category']),
                    user__isnull=True  # Apenas categorias globais
                ).first()
            
            mission = Mission.objects.create(
                title=data['title'][:100],  # Limite do campo
                description=data['description'][:255],
                mission_type=data['mission_type'],
                target_tps=Decimal(str(data['target_tps'])) if data.get('target_tps') else None,
                target_rdr=Decimal(str(data['target_rdr'])) if data.get('target_rdr') else None,
                duration_days=data['duration_days'],
                xp_reward=data['xp_reward'],
                is_active=True,
                priority=data['difficulty'],
                # Futuramente adicionar: tier=tier, tags=data.get('tags', [])
            )
            created_missions.append(mission)
            
        except Exception as e:
            logger.error(f"Erro ao criar missão '{data.get('title', 'unknown')}': {e}")
            continue
    
    logger.info(f"✓ {len(created_missions)}/{len(missions_data)} missões criadas no DB para {tier}")
    return created_missions


def generate_all_monthly_missions():
    """
    Gera missões mensais para todas as faixas de usuários (60 missões total).
    
    Uso: Celery task agendada para 1º dia do mês.
    
    Returns:
        dict: Resultado da geração com estatísticas
    """
    all_missions = []
    results = {}
    
    for tier in ['BEGINNER', 'INTERMEDIATE', 'ADVANCED']:
        logger.info(f"=== Gerando missões para {tier} ===")
        
        batch = generate_batch_missions_for_tier(tier)
        if batch:
            created = create_missions_from_batch(tier, batch)
            all_missions.extend(created)
            results[tier] = {
                'generated': len(batch),
                'created': len(created),
                'success': True
            }
        else:
            logger.error(f"✗ Falha ao gerar batch para {tier}")
            results[tier] = {
                'generated': 0,
                'created': 0,
                'success': False
            }
    
    total_created = sum(r['created'] for r in results.values())
    logger.info(f"\n=== RESUMO ===")
    logger.info(f"Total de missões criadas: {total_created}")
    
    return {
        'missions': all_missions,
        'results': results,
        'total_created': total_created,
        'timestamp': datetime.datetime.now().isoformat()
    }


# ==================== SUGESTÃO DE CATEGORIA ====================

def suggest_category(description, user):
    """
    Sugere categoria baseado na descrição da transação.
    
    Estratégia:
    1. Verificar histórico do usuário (aprendizado)
    2. Buscar em cache global
    3. Usar IA (Gemini)
    
    Args:
        description: Descrição da transação
        user: Usuário (para aprender preferências)
        
    Returns:
        Category: Categoria sugerida ou None
    """
    from .models import Category, Transaction
    
    if not description or len(description) < 3:
        return None
    
    # 1. Verificar histórico do usuário
    similar = Transaction.objects.filter(
        user=user,
        description__icontains=description[:20]
    ).values('category').annotate(
        count=Count('id')
    ).order_by('-count').first()
    
    if similar and similar['count'] >= 3:
        # Usuário já usou esta categoria 3+ vezes para descrições similares
        try:
            return Category.objects.get(id=similar['category'])
        except Category.DoesNotExist:
            pass
    
    # 2. Buscar em cache global
    cache_key = f'category_suggestion_{description.lower()[:50]}'
    cached = cache.get(cache_key)
    if cached:
        try:
            return Category.objects.get(id=cached)
        except Category.DoesNotExist:
            cache.delete(cache_key)
    
    # 3. Usar IA (Gemini)
    if not model:
        return None
    
    try:
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
        
    except Exception as e:
        logger.error(f"Erro ao sugerir categoria via IA: {e}")
    
    return None
