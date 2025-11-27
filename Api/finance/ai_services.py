import google.generativeai as genai
from django.conf import settings
from django.db.models import Avg, Count, Sum, Q
from django.core.cache import cache
from decimal import Decimal
import json
import datetime
import logging
import time

logger = logging.getLogger(__name__)

try:
    genai.configure(api_key=settings.GEMINI_API_KEY)
    model = genai.GenerativeModel('gemini-2.5-flash')
except Exception as e:
    logger.warning(f"Gemini API não configurada: {e}")
    model = None


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
- Educação sobre conceitos (TPS, RDR, ILI)
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
- Redução estratégica de dívidas (RDR)
- Melhoria de reserva de emergência (ILI)
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
- Dívidas controladas ou zeradas (RDR < 20%)
- Reserva de emergência sólida (ILI > 6 meses)
- Pensa em investimentos e patrimônio
- Usa o app há meses

**Foco das Missões:**
- Metas ambiciosas de TPS (30%+)
- Otimização fina de categorias
- Estratégias de alocação avançada
- Desafios de longo prazo
- Preparação para objetivos maiores (casa, carro, aposentadoria)
"""
}


MISSION_SCENARIOS = {
    'BEGINNER_ONBOARDING': {
        'name': 'Primeiros Passos',
        'description': 'Missões para usuários iniciantes com poucas transações',
        'focus': 'ONBOARDING',
        'min_existing': 20,
        'distribution': {
            'ONBOARDING': 12,
            'SAVINGS': 5,
            'EXPENSE_CONTROL': 3
        }
    },
    'TPS_LOW': {
        'name': 'Melhorando TPS - Baixo',
        'description': 'Missões focadas em elevar TPS de 0-15% para 15-25%',
        'focus': 'SAVINGS',
        'tps_range': (0, 15),
        'target_range': (15, 25),
        'distribution': {
            'SAVINGS': 14,
            'EXPENSE_CONTROL': 6
        }
    },
    'TPS_MEDIUM': {
        'name': 'Melhorando TPS - Médio',
        'description': 'Missões focadas em elevar TPS de 15-25% para 25-35%',
        'focus': 'SAVINGS',
        'tps_range': (15, 25),
        'target_range': (25, 35),
        'distribution': {
            'SAVINGS': 12,
            'EXPENSE_CONTROL': 8
        }
    },
    'TPS_HIGH': {
        'name': 'Melhorando TPS - Alto',
        'description': 'Missões focadas em manter/elevar TPS de 25%+',
        'focus': 'SAVINGS',
        'tps_range': (25, 100),
        'target_range': (30, 40),
        'distribution': {
            'SAVINGS': 10,
            'EXPENSE_CONTROL': 10
        }
    },
    'RDR_HIGH': {
        'name': 'Reduzindo Despesas Recorrentes - Alto',
        'description': 'Missões focadas em reduzir RDR de 50%+ para 30-40%',
        'focus': 'EXPENSE_CONTROL',
        'rdr_range': (50, 200),
        'target_range': (30, 40),
        'distribution': {
            'EXPENSE_CONTROL': 17,
            'SAVINGS': 3
        }
    },
    'RDR_MEDIUM': {
        'name': 'Reduzindo Despesas Recorrentes - Médio',
        'description': 'Missões focadas em reduzir RDR de 30-50% para 20-30%',
        'focus': 'EXPENSE_CONTROL',
        'rdr_range': (30, 50),
        'target_range': (20, 30),
        'distribution': {
            'EXPENSE_CONTROL': 15,
            'SAVINGS': 5
        }
    },
    'RDR_LOW': {
        'name': 'Mantendo Controle de Despesas Recorrentes',
        'description': 'Missões focadas em manter RDR abaixo de 30%',
        'focus': 'EXPENSE_CONTROL',
        'rdr_range': (0, 30),
        'target_range': (0, 20),
        'distribution': {
            'EXPENSE_CONTROL': 12,
            'SAVINGS': 8
        }
    },
    'ILI_LOW': {
        'name': 'Construindo Reserva - Iniciante',
        'description': 'Missões focadas em elevar ILI de 0-3 meses para 3-6 meses',
        'focus': 'SAVINGS',
        'ili_range': (0, 3),
        'target_range': (3, 6),
        'distribution': {
            'SAVINGS': 14,
            'EXPENSE_CONTROL': 6
        }
    },
    'ILI_MEDIUM': {
        'name': 'Construindo Reserva - Intermediário',
        'description': 'Missões focadas em elevar ILI de 3-6 meses para 6-12 meses',
        'focus': 'SAVINGS',
        'ili_range': (3, 6),
        'target_range': (6, 12),
        'distribution': {
            'SAVINGS': 12,
            'EXPENSE_CONTROL': 8
        }
    },
    'ILI_HIGH': {
        'name': 'Mantendo Reserva Sólida',
        'description': 'Missões focadas em manter ILI acima de 6 meses',
        'focus': 'SAVINGS',
        'ili_range': (6, 100),
        'target_range': (12, 24),
        'distribution': {
            'SAVINGS': 10,
            'EXPENSE_CONTROL': 10
        }
    },
    'MIXED_BALANCED': {
        'name': 'Equilíbrio Financeiro',
        'description': 'Missões mistas focadas em melhorar TPS, RDR e ILI simultaneamente',
        'focus': 'MIXED',
        'distribution': {
            'SAVINGS': 10,
            'EXPENSE_CONTROL': 10
        }
    },
    'MIXED_RECOVERY': {
        'name': 'Recuperação Financeira',
        'description': 'Missões para situações desafiadoras (baixo TPS + alto RDR)',
        'focus': 'MIXED',
        'requires': {
            'tps': (0, 15),
            'rdr': (40, 200)
        },
        'distribution': {
            'EXPENSE_CONTROL': 14,
            'SAVINGS': 6
        }
    },
    'MIXED_OPTIMIZATION': {
        'name': 'Otimização Avançada',
        'description': 'Missões para quem já tem bom controle e busca excelência',
        'focus': 'MIXED',
        'requires': {
            'tps': (20, 100),
            'rdr': (0, 30),
            'ili': (6, 100)
        },
        'distribution': {
            'SAVINGS': 10,
            'EXPENSE_CONTROL': 10
        }
    }
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
Você é um ESPECIALISTA EM EDUCAÇÃO FINANCEIRA criando missões gamificadas ÚNICAS e MENSURÁVEIS.

## ⚠️ REGRA CRÍTICA: VARIEDADE MÁXIMA

Cada missão DEVE ser SUBSTANCIALMENTE DIFERENTE das outras. Use:
- Títulos COMPLETAMENTE distintos (evite repetir palavras-chave)
- Abordagens variadas (economia, redução, otimização, construção)
- Contextos diferentes (curto prazo, médio prazo, emergencial, planejado)
- Linguagem diversificada (motivacional, desafiadora, educacional, prática)

## MÉTRICAS DO SISTEMA

**TPS (Taxa de Poupança)**: (Receitas - Despesas) / Receitas × 100
- Iniciante: 10-15% | Intermediário: 15-25% | Avançado: 25%+

**RDR (Razão Despesas-Receita)**: Total Despesas / Receita × 100  
- Saudável: <30% | Atenção: 30-50% | Crítico: >50%

**ILI (Reserva em Meses)**: Saldo / Despesas Mensais
- Básico: 3 meses | Ideal: 6 meses | Excelente: 12+ meses

## TIPOS DE MISSÃO (use EXATAMENTE estes valores)

### 1. ONBOARDING - Criar hábito de registro
**Campo OBRIGATÓRIO**: `min_transactions` (int, 5-50)
**Foco**: Familiarização com o app, primeiros registros
**Exemplos de abordagens**:
- "Complete sua primeira semana financeira" (10 transações)
- "Mapeie seus gastos essenciais" (15 transações básicas)
- "Construa sua linha do tempo financeira" (20 registros variados)

### 2. TPS_IMPROVEMENT - Elevar poupança
**Campo OBRIGATÓRIO**: `target_tps` (float, 5-40)
**Foco**: Aumentar % de economia sobre receita
**Exemplos de abordagens**:
- "Economize X% este mês" (meta direta)
- "Reduza gastos supérfluos para atingir X%" (via cortes)
- "Otimize sua renda disponível para X%" (via eficiência)

### 3. RDR_REDUCTION - Controlar despesas
**Campo OBRIGATÓRIO**: `target_rdr` (float, 10-50)
**Foco**: Reduzir comprometimento de renda
**Exemplos de abordagens**:
- "Mantenha despesas abaixo de X%" (limite)
- "Corte X% dos gastos recorrentes" (redução ativa)
- "Libere X% da sua renda" (via renegociação/cancelamentos)

### 4. ILI_BUILDING - Construir reserva
**Campo OBRIGATÓRIO**: `min_ili` (float, 1-12)
**Foco**: Aumentar meses de cobertura
**Exemplos de abordagens**:
- "Construa X meses de reserva" (acumulação)
- "Proteja-se por X meses" (segurança)
- "Alcance X meses de independência" (liberdade)

### 5. ADVANCED - Desafios múltiplos
**Campos**: Combinar 2+ de (target_tps, target_rdr, min_ili)
**Foco**: Otimização completa das finanças
**Exemplos de abordagens**:
- "Equilíbrio total: TPS X%, RDR Y%, ILI Z meses"
- "Transformação financeira completa"
- "Maestria em gestão de recursos"

## EXEMPLOS REAIS (siga ESTE padrão exato):

{reference_missions}

## CENÁRIO ATUAL: {scenario_name}

**Descrição**: {scenario_description}
**Foco**: {scenario_focus}
**Faixa**: {user_tier}

{tier_description}

## ESTATÍSTICAS DO USUÁRIO

- Nível: {avg_level}
- TPS atual: {avg_tps}%{tps_context}
- RDR atual: {avg_rdr}%{rdr_context}
- ILI atual: {avg_ili} meses{ili_context}
- Categorias comuns: {common_categories}
- Experiência: {experience_level}

## CONTEXTO TEMPORAL: {period_name}

{period_context}

## SUA TAREFA: Criar {count} Missões ÚNICAS

**DISTRIBUIÇÃO OBRIGATÓRIA**:
{distribution_requirements}

**DIFICULDADE** (progressiva):
- {easy_count} EASY: Alcançável para 80% dos usuários
- {medium_count} MEDIUM: Alcançável para 50% dos usuários  
- {hard_count} HARD: Desafio para top 20%

**DURAÇÃO** (variada):
- Curtas: 7 dias (ação rápida)
- Médias: 14-21 dias (formação de hábito)
- Longas: 30 dias (transformação completa)

**XP REWARD** (por dificuldade):
- EASY: 50-150 XP
- MEDIUM: 100-250 XP
- HARD: 200-500 XP

## ⚠️ VALIDAÇÃO CRÍTICA (não negociável)

1. **mission_type**: Deve ser EXATAMENTE um de: ONBOARDING, TPS_IMPROVEMENT, RDR_REDUCTION, ILI_BUILDING, ADVANCED

2. **Campos obrigatórios por tipo**:
   - ONBOARDING → `min_transactions` (int entre 5-50)
   - TPS_IMPROVEMENT → `target_tps` (float entre 5-40)
   - RDR_REDUCTION → `target_rdr` (float entre 10-50)
   - ILI_BUILDING → `min_ili` (float entre 1-12)
   - ADVANCED → 2 ou mais dos campos acima

3. **difficulty**: EASY, MEDIUM ou HARD (maiúsculas)

4. **duration_days**: 7, 14, 21 ou 30 (números exatos)

5. **xp_reward**: Dentro do range da difficulty

6. **title**: Máximo 150 caracteres, SEM emojis, ÚNICO

7. **description**: Clara, educacional, motivadora, SEM jargão excessivo

## 🎯 DIRETRIZES DE VARIEDADE (CRÍTICO)

**Títulos**: Use estruturas completamente diferentes
- ✅ "Economize 15% Este Mês"
- ✅ "Construa Sua Reserva de 3 Meses"  
- ✅ "Otimize Gastos Recorrentes"
- ❌ "Economize 15%", "Economize 20%", "Economize 25%" (muito similar)

**Descrições**: Varie abordagens educacionais
- Motivação: "Cada real economizado..."
- Prática: "Revise seus gastos em..."
- Benefício: "Garanta tranquilidade com..."
- Desafio: "Supere a meta de..."

**Contexto**: Adapte ao cenário
- Use {period_name} quando relevante
- Mencione {common_categories} em missões de controle
- Referencie métricas atuais do usuário
- Considere próximos passos naturais

## FORMATO DE RESPOSTA (JSON válido)

Retorne APENAS um array JSON válido, SEM texto antes/depois.
NÃO inclua campos não utilizados.

[
    {{
        "title": "Título único e claro (max 150 chars)",
        "description": "Descrição educacional e motivadora",
        "mission_type": "ONBOARDING|TPS_IMPROVEMENT|RDR_REDUCTION|ILI_BUILDING|ADVANCED",
        "target_tps": null ou float (obrigatório se TPS_IMPROVEMENT),
        "target_rdr": null ou float (obrigatório se RDR_REDUCTION),
        "min_ili": null ou float (obrigatório se ILI_BUILDING),
        "min_transactions": null ou int (obrigatório se ONBOARDING),
        "duration_days": 7|14|21|30,
        "xp_reward": int (50-500),
        "difficulty": "EASY|MEDIUM|HARD"
    }}
]

## ✅ CHECKLIST FINAL

Antes de retornar, verifique:
- [ ] Todos os títulos são ÚNICOS e DISTINTOS
- [ ] Descrições variam em tom e abordagem
- [ ] Campos obrigatórios presentes por tipo
- [ ] Valores dentro dos ranges especificados
- [ ] JSON válido (sem trailing commas, aspas corretas)
- [ ] Distribuição de dificuldade atendida
- [ ] Contexto do usuário considerado
- [ ] Linguagem clara e motivadora (não punitiva)
"""


# ==================== FUNÇÕES AUXILIARES ====================

def count_existing_missions_by_type(mission_type=None, tier=None):
    """
    Conta missões existentes no banco por tipo e/ou faixa.
    
    Args:
        mission_type: Tipo da missão (SAVINGS, EXPENSE_CONTROL, etc)
        tier: Faixa de usuários (BEGINNER, INTERMEDIATE, ADVANCED)
        
    Returns:
        int: Número de missões existentes
    """
    from .models import Mission
    
    qs = Mission.objects.filter(is_active=True)
    
    if mission_type:
        qs = qs.filter(mission_type=mission_type)
    
    return qs.count()


def determine_best_scenario(tier_stats):
    """
    Determina o melhor cenário de geração baseado nas estatísticas da faixa.
    
    Args:
        tier_stats: Dicionário com estatísticas da faixa
        
    Returns:
        str: Chave do cenário mais apropriado
    """
    tps = tier_stats.get('avg_tps', 10)
    rdr = tier_stats.get('avg_rdr', 50)
    ili = tier_stats.get('avg_ili', 2)
    tier = tier_stats.get('tier', 'BEGINNER')
    
    # Iniciantes com poucas missões
    if tier == 'BEGINNER':
        onboarding_count = count_existing_missions_by_type('ONBOARDING', tier)
        if onboarding_count < 20:
            return 'BEGINNER_ONBOARDING'
    
    # Situação de recuperação (TPS baixo + RDR alto)
    if tps < 15 and rdr > 40:
        return 'MIXED_RECOVERY'
    
    # Otimização avançada (tudo bom)
    if tps >= 20 and rdr < 30 and ili >= 6:
        return 'MIXED_OPTIMIZATION'
    
    # Foco em TPS
    if tps < 15:
        return 'TPS_LOW'
    elif tps < 25:
        return 'TPS_MEDIUM'
    elif tps >= 25:
        return 'TPS_HIGH'
    
    # Foco em RDR
    if rdr > 50:
        return 'RDR_HIGH'
    elif rdr > 30:
        return 'RDR_MEDIUM'
    elif rdr <= 30:
        return 'RDR_LOW'
    
    # Foco em ILI
    if ili < 3:
        return 'ILI_LOW'
    elif ili < 6:
        return 'ILI_MEDIUM'
    else:
        return 'ILI_HIGH'


# ==================== NOVAS FUNÇÕES DE VALIDAÇÃO E QUALIDADE ====================

def get_reference_missions(mission_type=None, limit=3):
    """
    Busca missões padrão (priority>=90) como referência para a IA.
    
    Args:
        mission_type: Tipo específico de missão (ONBOARDING, TPS_IMPROVEMENT, etc)
        limit: Número máximo de exemplos a retornar
        
    Returns:
        list: Lista de dicionários com exemplos de missões padrão
    """
    from .models import Mission
    
    qs = Mission.objects.filter(
        is_active=True,
        priority__gte=90  # Missões padrão/default têm priority alta
    )
    
    if mission_type:
        qs = qs.filter(mission_type=mission_type)
    
    missions = list(qs.order_by('?')[:limit].values(
        'title', 'description', 'mission_type', 
        'target_tps', 'target_rdr', 'min_ili',
        'min_transactions', 'duration_days', 
        'reward_points', 'difficulty'
    ))
    
    # Padronizar nome do campo para compatibilidade com IA
    for mission in missions:
        mission['xp_reward'] = mission.pop('reward_points')
    
    return missions


def validate_generated_mission(mission_data):
    """
    Valida missão gerada pela IA ANTES de salvar no banco.
    
    Verifica:
    - mission_type válido (6 tipos)
    - Campos obrigatórios por tipo
    - Ranges de valores
    - Difficulty vs XP coerente
    - duration_days válido
    
    Args:
        mission_data: Dicionário com dados da missão gerada
        
    Returns:
        tuple: (is_valid: bool, errors: list)
    """
    errors = []
    mission_type = mission_data.get('mission_type')
    
    # 1. Validar mission_type (6 tipos)
    valid_types = [
        'ONBOARDING',           # Primeiros passos - requer min_transactions
        'TPS_IMPROVEMENT',      # Aumentar poupança - requer target_tps
        'RDR_REDUCTION',        # Reduzir gastos recorrentes - requer target_rdr
        'ILI_BUILDING',         # Construir reserva - requer min_ili
        'CATEGORY_REDUCTION',   # Reduzir gastos em categoria - requer target_reduction_percent
        'GOAL_ACHIEVEMENT',     # Progredir em meta - requer goal_progress_target
    ]
    if mission_type not in valid_types:
        errors.append(f"mission_type inválido: '{mission_type}'. Tipos válidos: {', '.join(valid_types)}")
        return (False, errors)
    
    # 2. Validar campos obrigatórios por tipo
    if mission_type == 'TPS_IMPROVEMENT':
        if not mission_data.get('target_tps'):
            errors.append("TPS_IMPROVEMENT requer campo 'target_tps' (float, 5-50)")
        elif not (5 <= float(mission_data['target_tps']) <= 50):
            errors.append(f"target_tps deve estar entre 5 e 50, recebeu: {mission_data['target_tps']}")
    
    elif mission_type == 'RDR_REDUCTION':
        if not mission_data.get('target_rdr'):
            errors.append("RDR_REDUCTION requer campo 'target_rdr' (float, 10-80)")
        elif not (10 <= float(mission_data['target_rdr']) <= 80):
            errors.append(f"target_rdr deve estar entre 10 e 80, recebeu: {mission_data['target_rdr']}")
    
    elif mission_type == 'ILI_BUILDING':
        if not mission_data.get('min_ili'):
            errors.append("ILI_BUILDING requer campo 'min_ili' (float, 1-12)")
        elif not (1 <= float(mission_data['min_ili']) <= 12):
            errors.append(f"min_ili deve estar entre 1 e 12 meses, recebeu: {mission_data['min_ili']}")
    
    elif mission_type == 'ONBOARDING':
        if not mission_data.get('min_transactions'):
            errors.append("ONBOARDING requer campo 'min_transactions' (int, 5-50)")
        elif not (5 <= int(mission_data['min_transactions']) <= 50):
            errors.append(f"min_transactions deve estar entre 5 e 50, recebeu: {mission_data['min_transactions']}")
    
    elif mission_type == 'CATEGORY_REDUCTION':
        if not mission_data.get('target_reduction_percent'):
            errors.append("CATEGORY_REDUCTION requer campo 'target_reduction_percent' (float, 5-50)")
        elif not (5 <= float(mission_data['target_reduction_percent']) <= 50):
            errors.append(f"target_reduction_percent deve estar entre 5 e 50, recebeu: {mission_data['target_reduction_percent']}")
    
    elif mission_type == 'GOAL_ACHIEVEMENT':
        if not mission_data.get('goal_progress_target'):
            errors.append("GOAL_ACHIEVEMENT requer campo 'goal_progress_target' (float, 10-100)")
        elif not (10 <= float(mission_data['goal_progress_target']) <= 100):
            errors.append(f"goal_progress_target deve estar entre 10 e 100, recebeu: {mission_data['goal_progress_target']}")
    
    # 3. Validar difficulty
    if mission_data.get('difficulty') not in ['EASY', 'MEDIUM', 'HARD']:
        errors.append(f"difficulty inválida: '{mission_data.get('difficulty')}'. Deve ser EASY, MEDIUM ou HARD")
    
    # 4. Validar duration_days (mais flexível)
    duration = mission_data.get('duration_days')
    if not duration or duration < 7 or duration > 60:
        errors.append(f"duration_days deve estar entre 7 e 60, recebeu: {duration}")
    
    # 5. Validar XP por dificuldade (ranges ajustados)
    xp = mission_data.get('xp_reward', mission_data.get('reward_points', 0))
    difficulty = mission_data.get('difficulty')
    
    if difficulty == 'EASY' and not (25 <= xp <= 100):
        errors.append(f"XP para dificuldade EASY deve ser 25-100, recebeu: {xp}")
    elif difficulty == 'MEDIUM' and not (75 <= xp <= 200):
        errors.append(f"XP para dificuldade MEDIUM deve ser 75-200, recebeu: {xp}")
    elif difficulty == 'HARD' and not (150 <= xp <= 400):
        errors.append(f"XP para dificuldade HARD deve ser 150-400, recebeu: {xp}")
    
    # 6. Validar campos obrigatórios básicos
    title = mission_data.get('title', '')
    if not title or len(title) > 150:
        errors.append("title é obrigatório e deve ter no máximo 150 caracteres")
    
    if not mission_data.get('description'):
        errors.append("description é obrigatório")
    
    return (len(errors) == 0, errors)


def check_mission_similarity(title, description, threshold_title=0.90, threshold_desc=0.85):
    """
    Verifica se já existe missão similar no banco (evita duplicação semântica).
    
    Usa SequenceMatcher para comparar similaridade de strings.
    - Títulos: threshold padrão 90% (reduzido de 85% para diminuir falsos positivos)
    - Descrições: threshold padrão 85% (reduzido de 75% para diminuir falsos positivos)
    
    Args:
        title: Título da missão a verificar
        description: Descrição da missão a verificar
        threshold_title: Threshold de similaridade para títulos (0-1)
        threshold_desc: Threshold de similaridade para descrições (0-1)
        
    Returns:
        tuple: (is_duplicate: bool, message: str or None)
    """
    from .models import Mission
    from difflib import SequenceMatcher
    
    existing = Mission.objects.filter(is_active=True)
    
    for mission in existing:
        # Similaridade de título (normalizado: lowercase, sem acentos)
        title_normalized = title.lower().strip()
        existing_title_normalized = mission.title.lower().strip()
        
        title_similarity = SequenceMatcher(
            None, 
            title_normalized, 
            existing_title_normalized
        ).ratio()
        
        if title_similarity > threshold_title:
            return True, f"Título muito similar a missão existente: '{mission.title}' (similaridade: {title_similarity:.0%})"
        
        # Similaridade de descrição
        desc_normalized = description.lower().strip()
        existing_desc_normalized = mission.description.lower().strip()
        
        desc_similarity = SequenceMatcher(
            None, 
            desc_normalized, 
            existing_desc_normalized
        ).ratio()
        
        if desc_similarity > threshold_desc:
            return True, f"Descrição muito similar a missão existente: '{mission.title}' (similaridade: {desc_similarity:.0%})"
    
    return False, None


# ==================== FIM DAS NOVAS FUNÇÕES ====================


def get_scenario_guidelines(scenario_key, tier_stats):
    """
    Retorna diretrizes específicas para cada cenário.
    
    Args:
        scenario_key: Chave do cenário
        tier_stats: Estatísticas da faixa
        
    Returns:
        str: Texto com diretrizes
    """
    scenario = MISSION_SCENARIOS.get(scenario_key, {})
    
    guidelines = []
    
    # Diretrizes baseadas no foco
    if scenario.get('focus') == 'ONBOARDING':
        guidelines.append("- Priorize missões simples de registro de transações")
        guidelines.append("- Ensine conceitos básicos (o que é TPS, RDR, ILI)")
        guidelines.append("- Use marcos progressivos (5, 10, 20 transações)")
        guidelines.append("- Recompensas generosas para encorajar hábito")
    
    elif scenario.get('focus') == 'SAVINGS':
        tps_range = scenario.get('tps_range')
        target_range = scenario.get('target_range')
        ili_range = scenario.get('ili_range')
        
        if tps_range:
            guidelines.append(f"- Usuários têm TPS entre {tps_range[0]}% e {tps_range[1]}%")
            guidelines.append(f"- Meta: elevar TPS para {target_range[0]}-{target_range[1]}%")
            guidelines.append("- Sugira cortes específicos em categorias identificadas")
            guidelines.append("- Crie metas incrementais (1-2% de melhoria por vez)")
        
        if ili_range:
            guidelines.append(f"- Usuários têm reserva de {ili_range[0]}-{ili_range[1]} meses")
            guidelines.append(f"- Meta: elevar para {target_range[0]}-{target_range[1]} meses")
            guidelines.append("- Enfatize importância da reserva de emergência")
            guidelines.append("- Sugira automatização de poupança")
    
    elif scenario.get('focus') == 'EXPENSE_CONTROL':
        rdr_range = scenario.get('rdr_range')
        target_range = scenario.get('target_range')
        
        if rdr_range:
            guidelines.append(f"- Usuários têm RDR entre {rdr_range[0]}% e {rdr_range[1]}%")
            guidelines.append(f"- Meta: reduzir RDR para {target_range[0]}-{target_range[1]}%")
            guidelines.append("- RDR mede despesas recorrentes/renda (quanto menor, melhor)")
            guidelines.append("- Sugira revisar assinaturas, contratos e gastos fixos")
            guidelines.append("- Enfatize negociação e cancelamento de serviços desnecessários")
    
    elif scenario.get('focus') == 'MIXED':
        guidelines.append("- Equilibre melhorias em TPS, RDR e ILI simultaneamente")
        guidelines.append("- Crie missões que impactam múltiplos indicadores")
        guidelines.append("- Missões mais complexas e desafiadoras")
        guidelines.append("- Recompensas maiores por complexidade")
    
    # Diretrizes de distribuição
    distribution = scenario.get('distribution', {})
    dist_lines = []
    for mission_type, count in distribution.items():
        dist_lines.append(f"  * {count} missões de {mission_type}")
    
    if dist_lines:
        guidelines.append("\n**Distribuição obrigatória:**")
        guidelines.extend(dist_lines)
    
    return '\n'.join(guidelines) if guidelines else "- Crie missões variadas e progressivas"


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
            'avg_ili': 2.0 if tier == 'BEGINNER' else 4.0 if tier == 'INTERMEDIATE' else 8.0,
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
    
    # Calcular TPS, RDR e ILI médios (amostra de 50 usuários para performance)
    sample_users = list(users[:50])
    tps_values = []
    rdr_values = []
    ili_values = []
    
    for user in sample_users:
        try:
            summary = calculate_summary(user)
            tps_values.append(float(summary.get('tps', 0)))
            rdr_values.append(float(summary.get('rdr', 0)))
            ili_values.append(float(summary.get('ili', 0)))
        except Exception as e:
            logger.debug(f"Erro ao calcular summary para {user.id}: {e}")
            continue
    
    avg_tps = sum(tps_values) / len(tps_values) if tps_values else 10.0
    avg_rdr = sum(rdr_values) / len(rdr_values) if rdr_values else 50.0
    avg_ili = sum(ili_values) / len(ili_values) if ili_values else 2.0
    
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
        'avg_ili': round(avg_ili, 1),
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


def _extract_stats_from_user_context(user_context):
    """
    Extrai estatísticas do contexto completo do usuário para geração de missões.
    
    Args:
        user_context: Dict retornado por get_comprehensive_mission_context()
    
    Returns:
        dict: Estatísticas formatadas para uso na geração
    """
    tier_info = user_context.get('tier', {})
    current = user_context.get('current_indicators', {})
    evolution = user_context.get('evolution', {})
    
    # Extrair categorias de forma segura
    categories_dict = evolution.get('categories', {}) if evolution.get('has_data') else {}
    all_spending = categories_dict.get('all_spending', {})
    common_categories = ', '.join(list(all_spending.keys())[:3]) if all_spending else 'Alimentação, Transporte, Moradia'
    
    # Extrair dados de evolução de forma segura (campos podem ser None)
    evolution_data = evolution if evolution.get('has_data') else {}
    tps_evo = evolution_data.get('tps', {}) or {}
    rdr_evo = evolution_data.get('rdr', {}) or {}
    ili_evo = evolution_data.get('ili', {}) or {}
    consistency_data = evolution_data.get('consistency', {}) or {}
    
    return {
        'tier': tier_info.get('tier', 'BEGINNER'),
        'avg_level': tier_info.get('level', 1),
        'avg_tps': current.get('tps', 0),
        'avg_rdr': current.get('rdr', 0),
        'avg_ili': current.get('ili', 0),
        'common_categories': common_categories,
        'experience_level': _get_experience_level(tier_info.get('level', 1)),
        'user_count': 1,  # Contexto individual
        # Dados extras do contexto (com fallbacks seguros)
        'problems': evolution_data.get('problems', []),
        'strengths': evolution_data.get('strengths', []),
        'consistency_rate': consistency_data.get('rate', 0),
        'category_recommendations': user_context.get('category_patterns', {}).get('recommendations', []),
        'recommended_focus': user_context.get('recommended_focus', []),
        # Dados de evolução (para uso em prompts personalizados)
        'tps_trend': tps_evo.get('trend', 'estável'),
        'rdr_trend': rdr_evo.get('trend', 'estável'),
        'ili_trend': ili_evo.get('trend', 'estável'),
        'tps_average': tps_evo.get('average', 0),
        'rdr_average': rdr_evo.get('average', 0),
        'ili_average': ili_evo.get('average', 0),
    }


def _get_experience_level(level):
    """Retorna descrição de experiência baseada no nível."""
    if level <= 5:
        return "Primeiras semanas no app"
    elif level <= 15:
        return "1-3 meses de uso regular"
    else:
        return "Mais de 3 meses de uso consistente"


def _determine_scenario_from_context(user_context):
    """
    Determina o melhor cenário baseado no contexto completo do usuário.
    
    Args:
        user_context: Dict retornado por get_comprehensive_mission_context()
    
    Returns:
        str: Chave do cenário mais adequado
    """
    recommended_focus = user_context.get('recommended_focus', [])
    current = user_context.get('current_indicators', {})
    tier_info = user_context.get('tier', {})
    evolution = user_context.get('evolution', {})
    flags = user_context.get('flags', {})
    
    tps = current.get('tps', 0)
    rdr = current.get('rdr', 0)
    ili = current.get('ili', 0)
    level = tier_info.get('level', 1)
    
    # Usuários novos sempre começam com onboarding
    if flags.get('is_new_user') or level <= 2:
        return 'BEGINNER_ONBOARDING'
    
    # Baseado no foco recomendado (prioridade)
    if 'CONSISTENCY' in recommended_focus:
        return 'BEGINNER_ONBOARDING'  # Melhorar consistência
    
    if 'DEBT' in recommended_focus and rdr > 50:
        return 'RDR_HIGH'
    elif 'DEBT' in recommended_focus:
        return 'RDR_MEDIUM'
    
    if 'SAVINGS' in recommended_focus and tps < 10:
        return 'TPS_LOW'
    elif 'SAVINGS' in recommended_focus:
        return 'TPS_MEDIUM'
    
    if 'CATEGORY_CONTROL' in recommended_focus:
        # Usuário precisa controlar categorias específicas
        if level <= 5:
            return 'TPS_LOW'  # Começar simples
        else:
            return 'MIXED_BALANCED'  # Otimização geral
    
    # Baseado nos indicadores (fallback)
    if tps < 10:
        return 'TPS_LOW'
    elif tps < 20:
        return 'TPS_MEDIUM'
    elif tps >= 30:
        return 'TPS_HIGH'
    
    if rdr > 50:
        return 'RDR_HIGH'
    elif rdr > 30:
        return 'RDR_MEDIUM'
    
    if ili < 3:
        return 'ILI_LOW'
    elif ili >= 6:
        return 'ILI_HIGH'
    
    # Situação mista
    if tps < 15 and rdr > 40:
        return 'MIXED_RECOVERY'
    
    return 'MIXED_BALANCED'


def _build_personalized_prompt(tier, scenario, stats, user_context, period_type, period_name, period_context):
    """
    Constrói prompt enriquecido com contexto completo do usuário.
    
    Args:
        tier: BEGINNER/INTERMEDIATE/ADVANCED
        scenario: Dict do cenário
        stats: Estatísticas extraídas
        user_context: Contexto completo do usuário
        period_type, period_name, period_context: Contexto temporal
    
    Returns:
        str: Prompt formatado para Gemini
    """
    evolution = user_context.get('evolution', {})
    category_patterns = user_context.get('category_patterns', {})
    mission_distribution = user_context.get('mission_distribution', {})
    
    # Construir contexto de problemas
    problems_text = ""
    if stats.get('problems'):
        problems_text = "\n**PROBLEMAS IDENTIFICADOS:**\n" + "\n".join([f"- {p}" for p in stats['problems']])
    
    # Construir contexto de forças
    strengths_text = ""
    if stats.get('strengths'):
        strengths_text = "\n**PONTOS FORTES:**\n" + "\n".join([f"- {s}" for s in stats['strengths']])
    
    # Construir contexto de categorias problemáticas
    categories_text = ""
    if category_patterns.get('recommendations'):
        categories_text = "\n**CATEGORIAS QUE PRECISAM ATENÇÃO:**\n"
        for rec in category_patterns['recommendations'][:3]:
            categories_text += f"- {rec['category']}: {rec['reason']} (prioridade {rec['priority']})\n"
    
    # Construir contexto de distribuição de missões
    distribution_text = ""
    underutilized = mission_distribution.get('underutilized_mission_types', [])
    if underutilized:
        distribution_text = f"\n**TIPOS DE MISSÕES POUCO EXPLORADOS:** {', '.join(underutilized[:3])}\n"
    
    # Construir contexto de evolução
    evolution_text = ""
    if evolution.get('has_data'):
        # Acessar de forma segura os dados que podem ser None
        tps_data = evolution.get('tps') or {}
        rdr_data = evolution.get('rdr') or {}
        ili_data = evolution.get('ili') or {}
        consistency_data = evolution.get('consistency') or {}
        
        tps_trend = tps_data.get('trend', 'estável')
        rdr_trend = rdr_data.get('trend', 'estável')
        ili_trend = ili_data.get('trend', 'estável')
        consistency = consistency_data.get('rate', 0)
        
        evolution_lines = []
        
        if tps_data:
            evolution_lines.append(f"- TPS: {tps_data.get('average', 0):.1f}% (tendência: {tps_trend})")
        if rdr_data:
            evolution_lines.append(f"- RDR: {rdr_data.get('average', 0):.1f}% (tendência: {rdr_trend})")
        if ili_data:
            evolution_lines.append(f"- ILI: {ili_data.get('average', 0):.1f} meses (tendência: {ili_trend})")
        if consistency_data:
            evolution_lines.append(f"- Consistência: {consistency:.1f}% dos dias com registro")
        
        if evolution_lines:
            evolution_text = "\n**EVOLUÇÃO (últimos 90 dias):**\n" + "\n".join(evolution_lines)
    
    # Preparar requirements de distribuição do cenário
    distribution = scenario.get('distribution', {})
    dist_requirements = []
    for mission_type, count in distribution.items():
        dist_requirements.append(f"   - {count} missões de {mission_type}")
    distribution_requirements = '\n'.join(dist_requirements) if dist_requirements else "   - Distribuir equilibradamente"
    
    # Montar prompt personalizado
    prompt = f"""Você é um especialista em educação financeira gamificada. Gere 20 missões PERSONALIZADAS para este usuário específico.

**CONTEXTO DO USUÁRIO:**
Nome/ID: {user_context.get('username', 'usuário')}
Tier: {tier} (Nível {stats['avg_level']})
Foco recomendado: {', '.join(user_context.get('recommended_focus', []))}

**INDICADORES ATUAIS:**
- TPS (Taxa de Poupança): {stats['avg_tps']:.1f}%
- RDR (Relação Dívida/Renda): {stats['avg_rdr']:.1f}%
- ILI (Índice de Liquidez Imediata): {stats['avg_ili']:.1f} meses
{evolution_text}
{problems_text}
{strengths_text}
{categories_text}
{distribution_text}

**CENÁRIO ALVO:**
Nome: {scenario['name']}
Descrição: {scenario['description']}
Foco: {scenario['focus']}

**PERÍODO:**
{period_name} - {period_context}

**DISTRIBUIÇÃO REQUERIDA:**
{distribution_requirements}

**INSTRUÇÕES ESPECÍFICAS:**
1. Use os problemas identificados para criar missões corretivas
2. Reforce os pontos fortes com missões de consolidação
3. Foque nas categorias problemáticas quando relevante
4. Evite tipos de missões já muito utilizados: {', '.join(underutilized[:2]) if underutilized else 'nenhum'}
5. Considere a tendência dos indicadores (crescente/decrescente)
6. Adapte a dificuldade ao nível atual ({stats['avg_level']})

{USER_TIER_DESCRIPTIONS[tier]}

**FORMATO DE RESPOSTA:**
Retorne APENAS um array JSON com 20 missões. Cada missão deve ter:
{{
  "title": "Título motivador e específico",
  "description": "Descrição clara do objetivo",
  "mission_type": "ONBOARDING|TPS_IMPROVEMENT|RDR_REDUCTION|ILI_BUILDING|ADVANCED",
  "validation_type": "SNAPSHOT|TEMPORAL|CATEGORY_REDUCTION|CATEGORY_LIMIT|GOAL_PROGRESS|SAVINGS_INCREASE|CONSISTENCY",
  "priority": "LOW|MEDIUM|HIGH",
  "xp_reward": número (50-500),
  "duration_days": número (7-90),
  "target_tps": número ou null,
  "target_rdr": número ou null,
  "target_category": "nome da categoria" ou null,
  "category_limit_amount": número ou null,
  "category_reduction_percent": número ou null,
  "target_goal_id": null,
  "target_goal_progress_percent": número ou null,
  "target_savings_amount": número ou null,
  "consistency_required_days": número ou null
}}

**IMPORTANTE:** 
- NÃO use markdown, retorne APENAS o JSON
- As missões devem ser ESPECÍFICAS para este usuário
- Use os dados de evolução para criar desafios progressivos
- Seja criativo mas realista
"""
    
    return prompt


def _build_standard_prompt(tier, scenario, stats, period_type, period_name, period_context):
    """
    Constrói prompt padrão (sem contexto de usuário específico).
    Mantém a lógica original.
    """
    # Preparar contextos adicionais baseados no cenário
    tps_context = ""
    rdr_context = ""
    ili_context = ""
    
    if 'tps_range' in scenario:
        tps_range = scenario['tps_range']
        target_range = scenario['target_range']
        tps_context = f" (faixa: {tps_range[0]}-{tps_range[1]}%, meta: {target_range[0]}-{target_range[1]}%)"
    
    if 'rdr_range' in scenario:
        rdr_range = scenario['rdr_range']
        target_range = scenario['target_range']
        rdr_context = f" (faixa: {rdr_range[0]}-{rdr_range[1]}%, meta: {target_range[0]}-{target_range[1]}%)"
    
    if 'ili_range' in scenario:
        ili_range = scenario['ili_range']
        target_range = scenario['target_range']
        ili_context = f" (faixa: {ili_range[0]}-{ili_range[1]} meses, meta: {target_range[0]}-{target_range[1]} meses)"
    
    # Preparar requirements de distribuição
    distribution = scenario.get('distribution', {})
    dist_requirements = []
    for mission_type, count in distribution.items():
        dist_requirements.append(f"   - {count} missões de {mission_type}")
    distribution_text = '\n'.join(dist_requirements)
    
    # Calcular distribuição de dificuldade (padrão: 40% EASY, 40% MEDIUM, 20% HARD)
    total_count = 20
    easy_count = 8
    medium_count = 8
    hard_count = 4
    
    # Obter diretrizes específicas do cenário
    guidelines = get_scenario_guidelines(scenario.get('key', ''), stats)
    
    # Montar prompt padrão (original)
    prompt = BATCH_MISSION_GENERATION_PROMPT.format(
        scenario_name=scenario['name'],
        scenario_description=scenario['description'],
        scenario_focus=scenario['focus'],
        user_tier=tier,
        tier_description=USER_TIER_DESCRIPTIONS[tier],
        avg_level=stats['avg_level'],
        avg_tps=stats['avg_tps'],
        tps_context=tps_context,
        avg_rdr=stats['avg_rdr'],
        rdr_context=rdr_context,
        avg_ili=stats.get('avg_ili', 2.0),
        ili_context=ili_context,
        common_categories=stats['common_categories'],
        experience_level=stats['experience_level'],
        period_type=period_type,
        period_name=period_name,
        period_context=period_context,
        distribution_requirements=distribution_text,
        scenario_guidelines=guidelines,
        count=total_count,
        easy_count=easy_count,
        medium_count=medium_count,
        hard_count=hard_count
    )
    
    return prompt


def generate_and_save_incrementally(tier, scenario_key=None, user_context=None, count=10, max_retries=2, use_templates_first=True):
    """
    Gera e salva missões incrementalmente (uma por vez) com validação robusta.
    
    NOVA ESTRATÉGIA HÍBRIDA:
    1. Tenta usar templates primeiro (rápido, consistente, sem duplicatas)
    2. Complementa com IA apenas se necessário (variações específicas)
    3. Validação rigorosa antes de salvar
    
    Esta função oferece:
    - Geração 80% mais rápida via templates
    - Validação antes de salvar cada missão
    - Detecção de duplicatas semânticas
    - Salvamento parcial (não perde tudo se houver erro)
    - Relatório detalhado de sucessos e falhas
    
    Args:
        tier: 'BEGINNER', 'INTERMEDIATE' ou 'ADVANCED'
        scenario_key: Chave do cenário específico ou None para auto-detectar
        user_context: Contexto completo de um usuário real (opcional)
        count: Número de missões a tentar gerar (padrão: 10)
        max_retries: Tentativas por missão se falhar validação (padrão: 2)
        use_templates_first: Se True, tenta usar templates antes da IA (padrão: True)
        
    Returns:
        dict: {
            'created': [lista de missões criadas],
            'failed': [lista de erros com detalhes],
            'summary': {
                'total_created': int,
                'total_failed': int,
                'from_templates': int,
                'from_ai': int,
                'failed_validation': int,
                'failed_duplicate': int,
                'failed_api': int
            }
        }
    """
    from .models import Mission
    from .mission_templates import generate_mission_batch_from_templates, get_template_variety_score
    
    # Contadores para summary detalhado
    created_from_templates = 0
    created_from_ai = 0
    failed_validation_count = 0
    failed_duplicate_count = 0
    failed_api_count = 0
    
    created_missions = []
    failed_missions = []
    
    # Preparar contexto (igual à função antiga)
    if user_context:
        stats = _extract_stats_from_user_context(user_context)
        if not scenario_key:
            scenario_key = _determine_scenario_from_context(user_context)
    else:
        stats = get_user_tier_stats(tier)
        if not scenario_key:
            scenario_key = determine_best_scenario(stats)
    
    scenario = MISSION_SCENARIOS.get(scenario_key)
    if not scenario:
        logger.error(f"Cenário inválido: {scenario_key}")
        return {
            'created': [],
            'failed': [{'error': f'Cenário inválido: {scenario_key}', 'type': 'config_error'}],
            'summary': {
                'total_created': 0,
                'total_failed': 1,
                'from_templates': 0,
                'from_ai': 0,
                'failed_validation': 0,
                'failed_duplicate': 0,
                'failed_api': 1
            }
        }
    
    logger.info(f"Iniciando geração HÍBRIDA de {count} missões para {tier}/{scenario_key}")
    
    # =========================================================================
    # FASE 1: PRIORIZAR TEMPLATES (mais rápido, gratuito e consistente)
    # =========================================================================
    
    template_missions_data = []
    if use_templates_first:
        try:
            logger.info("🎯 FASE 1: Gerando missões de templates...")
            
            # Gerar a partir de templates
            current_metrics = {
                'tps': stats.get('avg_tps', 10),
                'rdr': stats.get('avg_rdr', 50),
                'ili': stats.get('avg_ili', 2),
            }
            
            # Obter distribuição do cenário
            distribution = scenario.get('distribution', {})
            
            # Gerar TODAS as missões possíveis de templates
            template_missions_data = generate_mission_batch_from_templates(
                tier=tier,
                current_metrics=current_metrics,
                count=count * 2,  # Gerar mais candidatos de templates
                distribution=distribution
            )
            
            logger.info(f"📋 Templates geraram {len(template_missions_data)} missões candidatas")
            
            # Salvar missões de template com validação (PRIORIDADE ALTA)
            templates_saved = 0
            for i, mission_data in enumerate(template_missions_data):
                # Se já temos missões suficientes de templates, parar
                if templates_saved >= count:
                    logger.info(f"✅ {templates_saved} missões de templates salvas - limite atingido")
                    break
                    
                try:
                    # 1. Validar estrutura
                    is_valid, validation_errors = validate_generated_mission(mission_data)
                    if not is_valid:
                        logger.warning(f"Template {i+1} falhou validação: {validation_errors}")
                        failed_validation_count += 1
                        continue
                    
                    # 2. Verificar duplicação semântica
                    is_duplicate, dup_message = check_mission_similarity(
                        mission_data['title'],
                        mission_data['description']
                    )
                    if is_duplicate:
                        logger.debug(f"Template {i+1} é duplicata: {dup_message}")
                        failed_duplicate_count += 1
                        continue
                    
                    # 3. Salvar no banco
                    mission = Mission.objects.create(
                        title=mission_data['title'],
                        description=mission_data['description'],
                        mission_type=mission_data['mission_type'],
                        target_tps=mission_data.get('target_tps'),
                        target_rdr=mission_data.get('target_rdr'),
                        min_ili=mission_data.get('min_ili'),
                        min_transactions=mission_data.get('min_transactions'),
                        duration_days=mission_data['duration_days'],
                        reward_points=mission_data['xp_reward'],
                        difficulty=mission_data['difficulty'],
                        is_active=True,
                        priority=5  # Templates têm prioridade média
                    )
                    
                    created_missions.append({
                        'id': mission.id,
                        'title': mission.title,
                        'mission_type': mission.mission_type,
                        'difficulty': mission.difficulty,
                        'xp_reward': mission.reward_points,
                        'source': 'template'
                    })
                    
                    created_from_templates += 1
                    templates_saved += 1
                    logger.info(f"✓ Template {templates_saved}/{count} salvo: '{mission.title}' (ID: {mission.id})")
                        
                except Exception as e:
                    logger.error(f"Erro ao salvar template {i+1}: {e}")
                    failed_missions.append({
                        'title': mission_data.get('title', 'Unknown'),
                        'error': str(e),
                        'type': 'save_error'
                    })
            
            logger.info(f"✅ FASE 1 completa: {created_from_templates} missões de templates salvas")
            
            # Se conseguimos todas as missões via templates, retornar imediatamente
            if len(created_missions) >= count:
                logger.info(f"🎉 Todas as {count} missões geradas via TEMPLATES (rápido e gratuito)!")
                return {
                    'created': created_missions,
                    'failed': failed_missions,
                    'summary': {
                        'total_created': len(created_missions),
                        'total_failed': len(failed_missions),
                        'from_templates': created_from_templates,
                        'from_ai': 0,
                        'failed_validation': failed_validation_count,
                        'failed_duplicate': failed_duplicate_count,
                        'failed_api': 0,
                        'failed_parsing': 0
                    }
                }
            
        except Exception as e:
            logger.warning(f"Erro na geração de templates: {e}, prosseguindo para IA...")
    
    # =========================================================================
    # FASE 2: COMPLEMENTAR COM IA (apenas se necessário)
    # =========================================================================
    
    remaining_count = count - len(created_missions)
    
    if remaining_count > 0:
        logger.info(f"🤖 FASE 2: Complementando com IA ({remaining_count} missões restantes)...")
        
        if not model:
            logger.error("Gemini API não configurada, não é possível complementar")
            failed_api_count += remaining_count
            return {
                'created': created_missions,
                'failed': failed_missions,
                'summary': {
                    'total_created': len(created_missions),
                    'total_failed': len(failed_missions),
                    'from_templates': created_from_templates,
                    'from_ai': created_from_ai,
                    'failed_validation': failed_validation_count,
                    'failed_duplicate': failed_duplicate_count,
                    'failed_api': failed_api_count
                }
            }
    
        # Preparar prompt para IA (versão simplificada para 1 missão por vez)
        prompt_single = f"""Gere UMA missão de educação financeira gamificada ÚNICA e DIFERENTE.

IMPORTANTE: Esta missão deve ser SUBSTANCIALMENTE DIFERENTE de missões comuns.
Evite títulos e descrições genéricas. Seja criativo e específico.

CONTEXTO:
- Tier: {tier}
- Cenário: {scenario.get('name')}
- Nível médio: {stats['avg_level']}

INDICADORES ATUAIS:
- TPS: {stats['avg_tps']:.1f}%
- RDR: {stats['avg_rdr']:.1f}%
- ILI: {stats.get('avg_ili', 2.0):.1f} meses

DISTRIBUIÇÃO NECESSÁRIA: {scenario.get('distribution', {})}

RETORNE APENAS UM OBJETO JSON (SEM ARRAY):
{{
  "title": "Título específico e único (max 150 chars)",
  "description": "Descrição educacional clara",
  "mission_type": "ONBOARDING|TPS_IMPROVEMENT|RDR_REDUCTION|ILI_BUILDING|ADVANCED",
  "duration_days": 7|14|21|30,
  "xp_reward": 50-500,
  "difficulty": "EASY|MEDIUM|HARD",
  "target_tps": null,
  "target_rdr": null,
  "min_ili": null,
  "min_transactions": null
}}

REGRAS CRÍTICAS:
1. Campos obrigatórios por tipo:
   - ONBOARDING: min_transactions (5-50)
   - TPS_IMPROVEMENT: target_tps (5-40)
   - RDR_REDUCTION: target_rdr (10-50)
   - ILI_BUILDING: min_ili (1-12)
   - ADVANCED: 2+ campos acima
2. Título DEVE ser único e específico
3. JSON válido (sem markdown, sem comentários)
"""
    if user_context:
        stats = _extract_stats_from_user_context(user_context)
        if not scenario_key:
            scenario_key = _determine_scenario_from_context(user_context)
    else:
        stats = get_user_tier_stats(tier)
        if not scenario_key:
            scenario_key = determine_best_scenario(stats)
    
    scenario = MISSION_SCENARIOS.get(scenario_key)
    if not scenario:
        logger.error(f"Cenário inválido: {scenario_key}")
        return {
            'created': [],
            'failed': [{'error': f'Cenário inválido: {scenario_key}', 'type': 'config_error'}],
            'summary': {'total_created': 0, 'total_failed': 1, 'failed_validation': 0, 'failed_duplicate': 0, 'failed_api': 1}
        }
    
    # Buscar missões de referência (exemplos para IA)
    reference_missions = get_reference_missions(limit=3)
    if reference_missions:
        reference_text = "\n".join([
            f"**{i+1}. [{ref['mission_type']}] {ref['title']}**\n"
            f"Descrição: {ref['description']}\n"
            f"Duração: {ref['duration_days']} dias | XP: {ref['xp_reward']} | Dificuldade: {ref['difficulty']}\n"
            for i, ref in enumerate(reference_missions)
        ])
    else:
        reference_text = "(Nenhuma missão de referência disponível - crie baseado nas diretrizes)"
    
    # Preparar prompt base (similar à função antiga, mas com reference_missions)
    period_type, period_name, period_context = get_period_context()
    
    if user_context:
        prompt_base = _build_personalized_prompt(tier, scenario, stats, user_context, period_type, period_name, period_context)
    else:
        prompt_base = _build_standard_prompt(tier, scenario, stats, period_type, period_name, period_context)
    
    # Injetar missões de referência no prompt
    prompt_base = prompt_base.replace('{reference_missions}', reference_text)
    
    # Modificar prompt para gerar apenas 1 missão por vez (versão simplificada)
    prompt_single = f"""Gere UMA missão de educação financeira gamificada.

TIER: {tier}
CENÁRIO: {scenario.get('name')}
NÍVEL MÉDIO: {stats['avg_level']}

INDICADORES ATUAIS:
- TPS: {stats['avg_tps']:.1f}%
- RDR: {stats['avg_rdr']:.1f}%
- ILI: {stats.get('avg_ili', 2.0):.1f} meses

RETORNE APENAS UM OBJETO JSON (SEM ARRAY, SEM MARKDOWN):
{{
  "title": "Título curto e motivador",
  "description": "Descrição clara e objetiva",
  "mission_type": "ONBOARDING",
  "duration_days": 7,
  "xp_reward": 100,
  "difficulty": "EASY",
  "target_tps": null,
  "target_rdr": null,
  "min_ili": null,
  "min_transactions": 5
}}

REGRAS:
1. JSON válido, sem quebras de linha em strings
2. Apenas campos necessários (null para opcionais)
3. duration_days: 7-90
4. xp_reward: 50-500
5. difficulty: EASY, MEDIUM ou HARD
"""
    
    created_missions = []
    failed_missions = []
    
    # Contadores para summary
    failed_validation_count = 0
    failed_duplicate_count = 0
    failed_api_count = 0
    
    logger.info(f"Iniciando geração incremental de {count} missões para {tier}/{scenario_key}")
    
    for i in range(count):
        retry_count = 0
        mission_created = False
        
        while retry_count < max_retries and not mission_created:
            try:
                # Gerar 1 missão
                logger.info(f"Gerando missão {i+1}/{count} (tentativa {retry_count+1}/{max_retries})...")
                
                # Configuração otimizada para velocidade e criatividade
                response = model.generate_content(
                    prompt_single,
                    generation_config={
                        'temperature': 0.85,  # Aumentado para mais criatividade (reduz duplicatas)
                        'top_p': 0.92,
                        'max_output_tokens': 800,  # Reduzido para 800 (mais rápido, missões são curtas)
                    },
                    request_options={'timeout': 45}  # Timeout de 45 segundos
                )
                
                # Parse resposta com sanitização robusta
                response_text = response.text.strip()
                
                # Remover markdown code blocks
                if response_text.startswith('```json'):
                    response_text = response_text[7:]
                elif response_text.startswith('```'):
                    response_text = response_text[3:]
                if response_text.endswith('```'):
                    response_text = response_text[:-3]
                
                response_text = response_text.strip()
                
                # Sanitizar strings com escape incorreto
                # Remove quebras de linha dentro de strings JSON
                response_text = response_text.replace('\n"', '"').replace('"\n', '"')
                
                # Tentar parsear JSON
                try:
                    mission_data = json.loads(response_text)
                except json.JSONDecodeError as e:
                    # Se falhar, tentar limpar mais agressivamente
                    logger.warning(f"Primeira tentativa de parse falhou: {e}, tentando limpeza agressiva...")
                    
                    # Remove quebras de linha problemáticas
                    import re
                    response_text = re.sub(r'(?<!\\)\\n', ' ', response_text)
                    response_text = re.sub(r'\s+', ' ', response_text)
                    
                    mission_data = json.loads(response_text)
                
                # Se retornou array, pegar primeiro
                if isinstance(mission_data, list):
                    if len(mission_data) == 0:
                        raise ValueError("IA retornou array vazio")
                    mission_data = mission_data[0]
                
                # 1. Validar estrutura
                is_valid, validation_errors = validate_generated_mission(mission_data)
                if not is_valid:
                    logger.warning(f"Missão {i+1} falhou validação: {validation_errors}")
                    failed_validation_count += 1
                    retry_count += 1
                    continue
                
                # 2. Verificar duplicação semântica
                is_duplicate, dup_message = check_mission_similarity(
                    mission_data['title'],
                    mission_data['description']
                )
                if is_duplicate:
                    logger.warning(f"Missão {i+1} é duplicata: {dup_message}")
                    failed_duplicate_count += 1
                    retry_count += 1
                    continue
                
                # 3. Salvar no banco
                mission = Mission.objects.create(
                    title=mission_data['title'],
                    description=mission_data['description'],
                    mission_type=mission_data['mission_type'],
                    target_tps=mission_data.get('target_tps'),
                    target_rdr=mission_data.get('target_rdr'),
                    min_ili=mission_data.get('min_ili'),
                    min_transactions=mission_data.get('min_transactions'),
                    duration_days=mission_data['duration_days'],
                    reward_points=mission_data['xp_reward'],
                    difficulty=mission_data['difficulty'],
                    is_active=True,
                    priority=1  # IA missions têm prioridade baixa
                )
                
                created_missions.append({
                    'id': mission.id,
                    'title': mission.title,
                    'mission_type': mission.mission_type,
                    'difficulty': mission.difficulty,
                    'xp_reward': mission.reward_points
                })
                
                mission_created = True
                logger.info(f"✓ Missão {i+1}/{count} criada: '{mission.title}' (ID: {mission.id})")
                
                # Delay de 1 segundo entre requisições para evitar sobrecarga
                time.sleep(1)
                
            except json.JSONDecodeError as e:
                logger.error(f"Erro de JSON na missão {i+1}: {e}")
                failed_api_count += 1
                retry_count += 1
                
            except Exception as e:
                logger.error(f"Erro ao gerar missão {i+1}: {e}")
                failed_api_count += 1
                retry_count += 1
        
        # Se esgotou tentativas
        if not mission_created:
            failed_missions.append({
                'index': i + 1,
                'error': 'Máximo de tentativas excedido',
                'retries': max_retries
            })
            logger.error(f"✗ Missão {i+1}/{count} falhou após {max_retries} tentativas")
    
    # Retornar resultado
    summary = {
        'total_created': len(created_missions),
        'total_failed': len(failed_missions),
        'failed_validation': failed_validation_count,
        'failed_duplicate': failed_duplicate_count,
        'failed_api': failed_api_count
    }
    
    logger.info(f"Geração incremental finalizada: {summary['total_created']} criadas, {summary['total_failed']} falharam")
    
    return {
        'created': created_missions,
        'failed': failed_missions,
        'summary': summary
    }


def generate_batch_missions_for_tier(tier, scenario_key=None, user_context=None):
    """
    Gera 20 missões em lote para uma faixa de usuários usando Gemini.
    
    Args:
        tier: 'BEGINNER', 'INTERMEDIATE' ou 'ADVANCED'
        scenario_key: Chave do cenário específico ou None para auto-detectar
        user_context: Contexto completo de um usuário real (opcional, para personalização)
        
    Returns:
        List[dict]: Lista de 20 missões geradas ou lista vazia em caso de erro
    """
    if not model:
        logger.error("Gemini API não configurada")
        return []
    
    # Se forneceu contexto de usuário real, usar para personalização
    if user_context:
        logger.info(f"Usando contexto de usuário real para geração personalizada (tier: {tier})")
        stats = _extract_stats_from_user_context(user_context)
        
        # Determinar cenário baseado no contexto do usuário
        if not scenario_key:
            scenario_key = _determine_scenario_from_context(user_context)
            logger.info(f"Cenário determinado pelo contexto do usuário: {scenario_key}")
    else:
        # Coletar estatísticas da faixa (método antigo)
        stats = get_user_tier_stats(tier)
        
        # Determinar cenário se não fornecido
        if not scenario_key:
            scenario_key = determine_best_scenario(stats)
            logger.info(f"Cenário auto-detectado para {tier}: {scenario_key}")
    
    scenario = MISSION_SCENARIOS.get(scenario_key)
    if not scenario:
        logger.error(f"Cenário inválido: {scenario_key}")
        return []
    
    # Verificar se já temos missões suficientes deste tipo
    min_existing = scenario.get('min_existing', 0)
    if min_existing > 0:
        existing_count = count_existing_missions_by_type(scenario.get('focus'), tier)
        if existing_count >= min_existing:
            logger.info(f"Já existem {existing_count} missões de {scenario.get('focus')} para {tier}, pulando geração")
            return []
    
    # Verificar cache (desabilitar se for personalizado)
    cache_key = None
    if not user_context:
        cache_key = f'ai_missions_{tier}_{scenario_key}_{datetime.datetime.now().strftime("%Y_%m")}'
        cached_missions = cache.get(cache_key)
        if cached_missions:
            logger.info(f"Usando missões em cache para {tier}/{scenario_key}")
            return cached_missions
    
    # Contexto do período
    period_type, period_name, period_context = get_period_context()
    
    # Preparar prompt enriquecido com contexto do usuário
    if user_context:
        prompt = _build_personalized_prompt(tier, scenario, stats, user_context, period_type, period_name, period_context)
    else:
        prompt = _build_standard_prompt(tier, scenario, stats, period_type, period_name, period_context)
    
    try:
        logger.info(f"Gerando missões para {tier}/{scenario_key} via Gemini API...")
        
        # Chamar Gemini
        response = model.generate_content(
            prompt,
            generation_config={
                'temperature': 0.9,  # Aumentado para mais criatividade
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
            logger.warning(f"Apenas {len(missions)} missões geradas para {tier}/{scenario_key}")
        
        # Cachear por 30 dias
        cache.set(cache_key, missions, timeout=2592000)
        
        logger.info(f"✓ {len(missions)} missões geradas para {tier}/{scenario_key}")
        return missions
        
    except json.JSONDecodeError as e:
        logger.error(f"Erro ao parsear JSON da resposta Gemini para {tier}/{scenario_key}: {e}")
        logger.debug(f"Resposta recebida: {response_text[:500]}")
        return []
    except Exception as e:
        logger.error(f"Erro ao gerar missões para {tier}/{scenario_key}: {e}")
        return []


def create_missions_from_batch(tier, missions_data, scenario_key=None):
    """
    Cria missões no banco a partir do batch gerado.
    
    Args:
        tier: Faixa de usuários
        missions_data: Lista de dicts com dados das missões
        scenario_key: Chave do cenário (opcional, para logging)
        
    Returns:
        List[Mission]: Missões criadas
    """
    from .models import Mission, Category
    
    created_missions = []
    skipped = 0
    
    for data in missions_data:
        try:
            # Verificar se missão similar já existe (por título)
            existing = Mission.objects.filter(
                title__iexact=data['title'][:100],
                is_active=True
            ).exists()
            
            if existing:
                logger.debug(f"Missão '{data['title']}' já existe, pulando")
                skipped += 1
                continue
            
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
                title=data['title'][:150],  # Limite do campo title
                description=data['description'],  # TextField não tem limite
                mission_type=data.get('mission_type', 'ONBOARDING'),
                difficulty=data.get('difficulty', 'MEDIUM'),
                priority=1,  # Pode ser ajustado baseado em lógica futura
                target_tps=Decimal(str(data['target_tps'])) if data.get('target_tps') else None,
                target_rdr=Decimal(str(data['target_rdr'])) if data.get('target_rdr') else None,
                min_ili=Decimal(str(data['min_ili'])) if data.get('min_ili') else None,
                min_transactions=data.get('min_transactions'),
                duration_days=data.get('duration_days', 14),
                reward_points=data.get('xp_reward', 100),
                is_active=True,
                target_category=target_category,
                target_reduction_percent=Decimal(str(data['target_reduction_percent'])) if data.get('target_reduction_percent') else None,
            )
            created_missions.append(mission)
            
        except Exception as e:
            logger.error(f"Erro ao criar missão '{data.get('title', 'unknown')}': {e}")
            continue
    
    scenario_info = f" para cenário {scenario_key}" if scenario_key else ""
    logger.info(f"✓ {len(created_missions)}/{len(missions_data)} missões criadas no DB para {tier}{scenario_info} ({skipped} puladas por duplicação)")
    return created_missions


def generate_all_monthly_missions(specific_scenario=None):
    """
    Gera missões mensais para todas as faixas de usuários.
    
    Estratégia:
    - Se scenario especificado: gera apenas esse cenário para todas as faixas
    - Se não: detecta automaticamente o melhor cenário para cada faixa
    
    Uso: 
    - Celery task agendada para 1º dia do mês (auto-detecta cenários)
    - Admin manual (pode escolher cenário específico)
    
    Args:
        specific_scenario: Chave do cenário específico ou None para auto-detectar
    
    Returns:
        dict: Resultado da geração com estatísticas
    """
    all_missions = []
    results = {}
    
    for tier in ['BEGINNER', 'INTERMEDIATE', 'ADVANCED']:
        logger.info(f"\n=== Gerando missões para {tier} ===")
        
        # Usar cenário específico ou auto-detectar
        scenario_key = specific_scenario
        if not scenario_key:
            stats = get_user_tier_stats(tier)
            scenario_key = determine_best_scenario(stats)
        
        logger.info(f"Cenário selecionado: {scenario_key}")
        
        batch = generate_batch_missions_for_tier(tier, scenario_key)
        if batch:
            created = create_missions_from_batch(tier, batch, scenario_key)
            all_missions.extend(created)
            results[tier] = {
                'scenario': scenario_key,
                'scenario_name': MISSION_SCENARIOS.get(scenario_key, {}).get('name', 'Desconhecido'),
                'generated': len(batch),
                'created': len(created),
                'success': True
            }
        else:
            logger.error(f"✗ Falha ao gerar batch para {tier}/{scenario_key}")
            results[tier] = {
                'scenario': scenario_key,
                'generated': 0,
                'created': 0,
                'success': False
            }
    
    total_created = sum(r['created'] for r in results.values())
    logger.info(f"\n=== RESUMO FINAL ===")
    logger.info(f"Total de missões criadas: {total_created}")
    for tier, data in results.items():
        logger.info(f"  {tier}: {data['created']} missões ({data['scenario_name']})")
    
    return {
        'missions': all_missions,
        'results': results,
        'total_created': total_created,
        'timestamp': datetime.datetime.now().isoformat()
    }


def generate_missions_by_scenario(scenario_key, tiers=None):
    """
    Gera missões para um cenário específico.
    
    Args:
        scenario_key: Chave do cenário (ex: 'TPS_LOW', 'RDR_HIGH')
        tiers: Lista de tiers ou None para todos
        
    Returns:
        dict: Resultado da geração
    """
    if scenario_key not in MISSION_SCENARIOS:
        return {
            'error': f'Cenário inválido: {scenario_key}',
            'available_scenarios': list(MISSION_SCENARIOS.keys())
        }
    
    tiers = tiers or ['BEGINNER', 'INTERMEDIATE', 'ADVANCED']
    results = {}
    all_missions = []
    
    for tier in tiers:
        logger.info(f"Gerando missões {scenario_key} para {tier}")
        
        batch = generate_batch_missions_for_tier(tier, scenario_key)
        if batch:
            created = create_missions_from_batch(tier, batch, scenario_key)
            all_missions.extend(created)
            results[tier] = {
                'generated': len(batch),
                'created': len(created),
                'success': True
            }
        else:
            results[tier] = {
                'generated': 0,
                'created': 0,
                'success': False
            }
    
    return {
        'scenario': scenario_key,
        'scenario_name': MISSION_SCENARIOS[scenario_key]['name'],
        'missions': all_missions,
        'results': results,
        'total_created': sum(r['created'] for r in results.values())
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


# ==================== GERAÇÃO DE CONQUISTAS COM IA ====================

def generate_achievements_with_ai(category='ALL', tier='ALL'):
    """
    Gera conquistas personalizadas usando Google Gemini 2.5 Flash.
    
    Args:
        category: Categoria ('FINANCIAL', 'SOCIAL', 'MISSION', 'STREAK', 'GENERAL', 'ALL')
        tier: Nível de dificuldade ('BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'ALL')
    
    Returns:
        list: Lista de dicts com conquistas geradas
    
    Exemplos de conquistas:
    
    FINANCIAL:
    - "Primeira Economia" - Registre sua primeira transação de receita
    - "Mestre da Poupança" - Atinja TPS de 30% por 3 meses consecutivos
    - "Caçador de Descontos" - Economize R$ 500 em um mês
    
    SOCIAL:
    - "Amigo Financeiro" - Adicione seu primeiro amigo
    - "Influenciador" - Tenha 10 amigos ativos
    - "Top 10" - Entre no top 10 do ranking global
    
    MISSION:
    - "Aventureiro" - Complete sua primeira missão
    - "Mestre das Missões" - Complete 50 missões
    - "Sequência de Ouro" - Complete missões 7 dias seguidos
    
    STREAK:
    - "Consistência" - Faça login 7 dias consecutivos
    - "Dedicação Total" - Mantenha streak de 30 dias
    - "Inabalável" - Atinja streak de 100 dias
    """
    from .models import Achievement
    
    if not model:
        logger.error("Modelo Gemini não configurado")
        return []
    
    # Verificar cache (30 dias)
    cache_key = f'ai_achievements_{category}_{tier}'
    cached_achievements = cache.get(cache_key)
    if cached_achievements:
        logger.info(f"Conquistas carregadas do cache: {cache_key}")
        return cached_achievements
    
    # Determinar quantas conquistas gerar
    categories_to_generate = []
    if category == 'ALL':
        categories_to_generate = ['FINANCIAL', 'SOCIAL', 'MISSION', 'STREAK', 'GENERAL']
    else:
        categories_to_generate = [category]
    
    tiers_to_generate = []
    if tier == 'ALL':
        tiers_to_generate = ['BEGINNER', 'INTERMEDIATE', 'ADVANCED']
    else:
        tiers_to_generate = [tier]
    
    total_achievements = len(categories_to_generate) * len(tiers_to_generate) * 2  # 2 por combinação
    
    # Construir prompt para Gemini
    prompt = f"""Você é um especialista em gamificação e educação financeira. 
Gere {total_achievements} conquistas (achievements) para um aplicativo de gestão financeira gamificada.

**CATEGORIAS DE CONQUISTAS:**

1. FINANCIAL (Financeiro):
   - Relacionadas a transações, economias, metas financeiras
   - Ex: "Primeira Economia", "Mestre da Poupança", "Caçador de Descontos"

2. SOCIAL (Social):
   - Relacionadas a amigos, ranking, comparações
   - Ex: "Amigo Financeiro", "Top 10", "Influenciador"

3. MISSION (Missões):
   - Relacionadas a completar missões do app
   - Ex: "Aventureiro", "Mestre das Missões", "Sequência de Ouro"

4. STREAK (Sequência):
   - Relacionadas a dias consecutivos de ações
   - Ex: "Consistência", "Dedicação Total", "Inabalável"

5. GENERAL (Geral):
   - Conquistas variadas, onboarding, uso do app
   - Ex: "Primeiro Passo", "Explorador", "Veterano"

**NÍVEIS DE DIFICULDADE:**

- BEGINNER (Iniciante): Fácil de alcançar, incentiva primeiros passos
  - XP: 25-50
  - Critérios simples (1-5 ações)

- INTERMEDIATE (Intermediário): Requer consistência e esforço moderado
  - XP: 75-150
  - Critérios moderados (10-30 ações)

- ADVANCED (Avançado): Conquistas épicas, long-term
  - XP: 200-500
  - Critérios desafiadores (50+ ações ou metas ambiciosas)

**REQUISITOS:**

1. Cada conquista deve ter:
   - title: Nome criativo e motivador (máx 50 caracteres)
   - description: Descrição clara do objetivo (máx 200 caracteres)
   - category: Uma das 5 categorias acima
   - tier: Um dos 3 níveis
   - xp_reward: Pontos de XP apropriados ao tier
   - icon: Um emoji relevante (🏆, 💰, 👥, 🔥, ⭐, 💎, 🎯, etc)
   - criteria: JSON com tipo e valor
     - Para contadores: {{"type": "count", "target": X, "metric": "transactions|missions|friends|days"}}
     - Para valores: {{"type": "value", "target": X, "metric": "tps|rdr|ili|savings"}}
     - Para streaks: {{"type": "streak", "target": X, "activity": "login|transaction|mission"}}

2. Distribua igualmente entre:
   - Categorias: {', '.join(categories_to_generate)}
   - Tiers: {', '.join(tiers_to_generate)}

3. Seja criativo com nomes e emojis
4. Critérios devem ser mensuráveis e alcançáveis
5. Evite duplicação de conceitos

**FORMATO DE RESPOSTA (JSON Array):**

```json
[
  {{
    "title": "Primeira Economia",
    "description": "Registre sua primeira transação de receita",
    "category": "FINANCIAL",
    "tier": "BEGINNER",
    "xp_reward": 25,
    "icon": "💰",
    "criteria": {{"type": "count", "target": 1, "metric": "income_transactions"}}
  }},
  {{
    "title": "Mestre da Poupança",
    "description": "Mantenha TPS acima de 30% por 3 meses consecutivos",
    "category": "FINANCIAL",
    "tier": "ADVANCED",
    "xp_reward": 300,
    "icon": "💎",
    "criteria": {{"type": "value", "target": 30, "metric": "tps_3months", "duration": 90}}
  }}
]
```

**IMPORTANTE:** Retorne APENAS o JSON array, sem texto adicional antes ou depois."""

    try:
        logger.info(f"Gerando {total_achievements} conquistas via IA ({category}, {tier})")
        
        response = model.generate_content(prompt)
        response_text = response.text.strip()
        
        # Limpar markdown code blocks se houver
        if response_text.startswith('```'):
            response_text = response_text.split('```')[1]
            if response_text.startswith('json'):
                response_text = response_text[4:]
        
        achievements_data = json.loads(response_text)
        
        logger.info(f"IA gerou {len(achievements_data)} conquistas com sucesso")
        
        # Cachear por 30 dias
        cache.set(cache_key, achievements_data, timeout=2592000)
        
        return achievements_data
        
    except json.JSONDecodeError as e:
        logger.error(f"Erro ao parsear JSON da IA: {e}")
        logger.error(f"Resposta recebida: {response_text[:500]}")
        return []
    except Exception as e:
        logger.error(f"Erro ao gerar conquistas via IA: {e}")
        return []


# ============================================================================
# GERAÇÃO GENERALIZADA DE MISSÕES (PAINEL ADMIN)
# ============================================================================

def generate_general_missions(quantidade=10):
    """
    Gera missões de forma generalizada para todos os contextos de usuários.
    
    Esta função é usada pelo painel administrativo para gerar lotes de missões
    que podem ser aplicadas a qualquer usuário, sem personalização individual.
    
    Args:
        quantidade: Número de missões a gerar (10 ou 20)
        
    Returns:
        dict: Resultado da geração com missões criadas e erros
    """
    from .models import Mission, Category
    
    # Distribuição equilibrada entre todos os 6 tipos
    base = quantidade // 6
    resto = quantidade % 6
    
    distribuicao = {
        'ONBOARDING': base + (1 if resto > 0 else 0),
        'TPS_IMPROVEMENT': base + (1 if resto > 1 else 0),
        'RDR_REDUCTION': base + (1 if resto > 2 else 0),
        'ILI_BUILDING': base + (1 if resto > 3 else 0),
        'CATEGORY_REDUCTION': base + (1 if resto > 4 else 0),
        'GOAL_ACHIEVEMENT': base,
    }
    
    # Obter categorias do sistema para sugestão
    categorias_sistema = list(
        Category.objects.filter(is_system_default=True, type='EXPENSE')
        .values_list('name', flat=True)[:10]
    )
    categorias_sugestao = ', '.join(categorias_sistema) if categorias_sistema else 'Alimentação, Transporte, Lazer, Compras'
    
    created = []
    failed = []
    
    # Prompt melhorado para geração generalizada
    prompt = f"""Você é um especialista em educação financeira gamificada. 
Gere {quantidade} missões VARIADAS e ÚNICAS para um aplicativo de finanças pessoais.

**TIPOS DE MISSÃO (distribua exatamente conforme indicado):**
1. ONBOARDING ({distribuicao['ONBOARDING']} missões) - Primeiros passos
   → Campo obrigatório: min_transactions (int, 5-30)
   → Objetivo: Criar hábito de registrar transações
   
2. TPS_IMPROVEMENT ({distribuicao['TPS_IMPROVEMENT']} missões) - Melhorar Taxa de Poupança
   → Campo obrigatório: target_tps (float, 10-40)
   → Objetivo: Aumentar % poupado da renda
   
3. RDR_REDUCTION ({distribuicao['RDR_REDUCTION']} missões) - Reduzir Despesas Recorrentes
   → Campo obrigatório: target_rdr (float, 20-60)
   → Objetivo: Diminuir % de gastos fixos sobre renda
   
4. ILI_BUILDING ({distribuicao['ILI_BUILDING']} missões) - Construir Reserva de Emergência
   → Campo obrigatório: min_ili (float, 1-6)
   → Objetivo: Acumular X meses de despesas em reserva
   
5. CATEGORY_REDUCTION ({distribuicao['CATEGORY_REDUCTION']} missões) - Reduzir Gastos em Categoria
   → Campo obrigatório: target_reduction_percent (float, 10-30)
   → Campo opcional: target_category_name (string) - nome da categoria sugerida
   → Categorias disponíveis: {categorias_sugestao}
   → Objetivo: Reduzir X% em uma categoria específica
   → NOTA: target_category_name é apenas uma SUGESTÃO. O sistema vinculará 
           automaticamente à categoria com maior gasto se não especificada.
   
6. GOAL_ACHIEVEMENT ({distribuicao['GOAL_ACHIEVEMENT']} missões) - Progredir em Meta
   → Campo obrigatório: goal_progress_target (float, 25-100)
   → Objetivo: Atingir X% de progresso em uma meta financeira
   → NOTA: Metas são vinculadas AUTOMATICAMENTE às metas ativas do usuário.
           NÃO inclua target_goal_id ou nomes de metas específicas.
   → Valores sugeridos: 25%, 50%, 75%, 100%

**REGRAS IMPORTANTES:**
- Títulos curtos e motivadores (máx 100 caracteres)
- Descrições educativas e encorajadoras (2-3 frases)
- Dificuldade: EASY (30%), MEDIUM (50%), HARD (20%)
- Duração: 7-30 dias (EASY: 7-14, MEDIUM: 14-21, HARD: 21-30)
- XP: EASY 25-75, MEDIUM 75-150, HARD 150-300
- Cada missão deve ter APENAS os campos do seu tipo preenchidos
- NÃO inclua campos de outros tipos (ex: target_tps em missão ONBOARDING)

**FORMATO JSON (retorne APENAS o array, sem markdown):**
[
  {{
    "title": "Título Motivador da Missão",
    "description": "Descrição educativa explicando o benefício e como completar.",
    "mission_type": "TIPO_AQUI",
    "difficulty": "EASY|MEDIUM|HARD",
    "duration_days": 14,
    "reward_points": 100,
    "min_transactions": null,
    "target_tps": null,
    "target_rdr": null,
    "min_ili": null,
    "target_reduction_percent": null,
    "target_category_name": null,
    "goal_progress_target": null
  }}
]

IMPORTANTE: Preencha APENAS o campo específico do tipo de missão. Os demais devem ser null.
"""
    
    if not model:
        logger.warning("Gemini não configurado, geração via IA indisponível")
        return {'created': [], 'failed': [{'erro': 'IA não configurada'}]}
    
    try:
        response = model.generate_content(prompt)
        response_text = response.text.strip()
        
        # Limpar markdown code blocks
        if '```' in response_text:
            parts = response_text.split('```')
            for part in parts:
                if part.strip().startswith('[') or part.strip().startswith('json'):
                    response_text = part.replace('json', '').strip()
                    break
        
        missions_data = json.loads(response_text)
        
        for data in missions_data:
            try:
                # Validar e criar missão
                is_valid, errors = validate_generated_mission(data)
                
                if not is_valid:
                    failed.append({
                        'titulo': data.get('title', 'Sem título'),
                        'erros': errors,
                    })
                    continue
                
                # Verificar duplicação
                is_duplicate, msg = check_mission_similarity(
                    data.get('title', ''),
                    data.get('description', '')
                )
                
                if is_duplicate:
                    failed.append({
                        'titulo': data.get('title', 'Sem título'),
                        'erros': [msg],
                    })
                    continue
                
                # Resolver categoria por nome se especificada
                target_category_id = None
                target_category_name = data.get('target_category_name')
                if target_category_name and data['mission_type'] == 'CATEGORY_REDUCTION':
                    # Tentar encontrar categoria pelo nome
                    categoria = Category.objects.filter(
                        is_system_default=True,
                        name__icontains=target_category_name
                    ).first()
                    if categoria:
                        target_category_id = categoria.id
                        logger.info(f"Categoria '{target_category_name}' resolvida para ID {categoria.id}")
                
                # Criar missão com todos os campos
                mission = Mission.objects.create(
                    title=data['title'],
                    description=data['description'],
                    mission_type=data['mission_type'],
                    difficulty=data['difficulty'],
                    duration_days=data.get('duration_days', 14),
                    reward_points=data.get('reward_points', data.get('xp_reward', 100)),
                    min_transactions=data.get('min_transactions'),
                    target_tps=data.get('target_tps'),
                    target_rdr=data.get('target_rdr'),
                    min_ili=data.get('min_ili'),
                    target_reduction_percent=data.get('target_reduction_percent'),
                    target_category_id=target_category_id,
                    goal_progress_target=data.get('goal_progress_target'),
                    is_active=True,
                    is_system_generated=True,
                    generation_context={
                        'source': 'admin_panel', 
                        'method': 'ai_general',
                        'suggested_category': target_category_name,
                    },
                )
                
                created.append({
                    'id': mission.id,
                    'titulo': mission.title,
                    'tipo': mission.mission_type,
                    'dificuldade': mission.difficulty,
                })
                
            except Exception as e:
                failed.append({
                    'titulo': data.get('title', 'Sem título'),
                    'erros': [str(e)],
                })
        
        logger.info(f"Geração generalizada: {len(created)} criadas, {len(failed)} falharam")
        
        return {
            'created': created,
            'failed': failed,
            'summary': {
                'total_created': len(created),
                'total_failed': len(failed),
            }
        }
        
    except json.JSONDecodeError as e:
        logger.error(f"Erro ao parsear JSON da IA: {e}")
        return {'created': [], 'failed': [{'erro': f'Erro ao processar resposta da IA: {e}'}]}
    except Exception as e:
        logger.error(f"Erro na geração generalizada: {e}", exc_info=True)
        return {'created': [], 'failed': [{'erro': str(e)}]}


# ============================================================================
# ALIASES PARA COMPATIBILIDADE
# ============================================================================

# Alias para views.py e outras partes do código que usam o nome antigo
generate_hybrid_missions = generate_and_save_incrementally
