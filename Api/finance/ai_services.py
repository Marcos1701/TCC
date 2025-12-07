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

SEASON_DESCRIPTIONS = {
    'JANUARY': """**Janeiro - Ano Novo, Novos Começos**

Momento de renovação e planejamento. Muitos usuários estão motivados após as festas 
e querem começar o ano com o pé direito financeiramente.

**Oportunidades:**
- Metas anuais de economia
- Recuperação de excessos de dezembro
- Planejamento de grandes objetivos
- Limpeza financeira (cancelar assinaturas não usadas)
""",
    'FEBRUARY': """**Fevereiro - Planejamento e Disciplina**

Mês de manter o foco nas metas estabelecidas em janeiro. Período de consolidação de hábitos.

**Oportunidades:**
- Reforçar hábitos iniciados em janeiro
- Ajustar metas se necessário
- Preparação para gastos de meio de ano
""",
    'JULY': """**Julho - Metade do Ano, Revisão de Metas**

Momento de avaliar o progresso do ano e fazer ajustes. Férias escolares podem impactar 
orçamentos familiares.

**Oportunidades:**
- Revisão de metas do ano
- Ajustes de categoria para férias
- Preparação para 2º semestre
- Análise de progresso TPS/RDR
""",
    'NOVEMBER': """**Novembro - Black Friday e Preparação para Festas**

Mês de tentações de consumo com promoções. Importante manter controle antes das 
despesas de dezembro.

**Oportunidades:**
- Resistir a compras impulsivas
- Planejamento de presentes
- Economia para festas
- Análise crítica de "promoções"
""",
    'DECEMBER': """**Dezembro - Festas e Planejamento do Próximo Ano**

Mês de gastos maiores mas também de planejamento para o ano seguinte.

**Oportunidades:**
- Controle de gastos com festas
- Análise do ano completo
- Definição de metas para próximo ano
- Balanço financeiro anual
""",
    'DEFAULT': """**Período Regular**

Mês comum, foco em manutenção de hábitos e progresso incremental.

**Oportunidades:**
- Manter consistência
- Progresso gradual em TPS/RDR
- Otimização de categorias específicas
"""
}

GEMINI_MISSION_PROMPT = """
Você é um ESPECIALISTA EM EDUCAÇÃO FINANCEIRA criando missões gamificadas ÚNICAS e MENSURÁVEIS.

Cada missão DEVE ser SUBSTANCIALMENTE DIFERENTE das outras. Use:
- Títulos COMPLETAMENTE distintos (evite repetir palavras-chave)
- Abordagens variadas (economia, redução, otimização, construção)
- Contextos diferentes (curto prazo, médio prazo, emergencial, planejado)
- Linguagem diversificada (motivacional, desafiadora, educacional, prática)

**INDICADORES FINANCEIROS:**

**TPS (Taxa de Poupança)**: (Receitas - Despesas) / Receitas × 100
- Iniciante: 10-15% | Intermediário: 15-25% | Avançado: 25%+

**RDR (Razão Despesas-Receita)**: Total Despesas / Receita × 100  
- Saudável: <30% | Atenção: 30-50% | Crítico: >50%

**ILI (Reserva em Meses)**: Saldo / Despesas Mensais
- Básico: 3 meses | Ideal: 6 meses | Excelente: 12+ meses

**TIPOS DE MISSÃO:**

ONBOARDING:
- Campo OBRIGATÓRIO: min_transactions (int, 5-50)
- Foco: Familiarização com o app, primeiros registros

TPS_IMPROVEMENT:
- Campo OBRIGATÓRIO: target_tps (float, 5-40)
- Foco: Aumentar % de economia sobre receita

RDR_REDUCTION:
- Campo OBRIGATÓRIO: target_rdr (float, 10-50)
- Foco: Reduzir comprometimento de renda

ILI_BUILDING:
- Campo OBRIGATÓRIO: min_ili (float, 1-12)
- Foco: Aumentar meses de cobertura

CATEGORY_REDUCTION:
- Campo OBRIGATÓRIO: target_reduction_percent (float, 10-30)
- Foco: Reduzir gastos em categoria específica

**REGRAS TÉCNICAS:**

1. mission_type: ONBOARDING, TPS_IMPROVEMENT, RDR_REDUCTION, ILI_BUILDING ou CATEGORY_REDUCTION

2. Campos obrigatórios por tipo:
   - ONBOARDING → min_transactions (int entre 5-50)
   - TPS_IMPROVEMENT → target_tps (float entre 5-40)
   - RDR_REDUCTION → target_rdr (float entre 10-50)
   - ILI_BUILDING → min_ili (float entre 1-12)
   - CATEGORY_REDUCTION → target_reduction_percent (float entre 10-30)

3. difficulty: EASY, MEDIUM ou HARD (maiúsculas)

4. duration_days: 7, 14, 21 ou 30 (números exatos)

5. xp_reward: 
   - EASY: 50-150 XP
   - MEDIUM: 100-250 XP
   - HARD: 200-500 XP

6. title: Máximo 150 caracteres, SEM emojis, ÚNICO

7. description: Clara, educacional, motivadora, SEM jargão excessivo

**FORMATO DE RESPOSTA:**

Retorne APENAS um array JSON válido, SEM texto antes/depois.
NÃO inclua campos não utilizados.

[
    {{
        "title": "Título único e claro (max 150 chars)",
        "description": "Descrição educacional e motivadora",
        "mission_type": "ONBOARDING|TPS_IMPROVEMENT|RDR_REDUCTION|ILI_BUILDING|CATEGORY_REDUCTION",
        "target_tps": null,
        "target_rdr": null,
        "min_ili": null,
        "min_transactions": null,
        "target_reduction_percent": null,
        "duration_days": 7,
        "xp_reward": 100,
        "difficulty": "EASY|MEDIUM|HARD"
    }}
]

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


def _get_experience_level(level):
    """Retorna descrição do nível de experiência baseado no level."""
    if level <= 5:
        return "Primeiras semanas no app"
    elif level <= 15:
        return "1-3 meses de uso regular"
    else:
        return "Mais de 3 meses de uso consistente"


def _determine_scenario_from_context(user_context):
    recommended_focus = user_context.get('recommended_focus', [])
    current = user_context.get('current_indicators', {})
    tier_info = user_context.get('tier', {})
    evolution = user_context.get('evolution', {})
    flags = user_context.get('flags', {})
    
    tps = current.get('tps', 0)
    rdr = current.get('rdr', 0)
    ili = current.get('ili', 0)
    level = tier_info.get('level', 1)
    
    if flags.get('is_new_user') or level <= 2:
        return 'BEGINNER_ONBOARDING'
    
    if 'CONSISTENCY' in recommended_focus:
        return 'BEGINNER_ONBOARDING'
    
    if 'DEBT' in recommended_focus and rdr > 50:
        return 'RDR_HIGH'
    elif 'DEBT' in recommended_focus:
        return 'RDR_MEDIUM'
    
    if 'SAVINGS' in recommended_focus and tps < 10:
        return 'TPS_LOW'
    elif 'SAVINGS' in recommended_focus:
        return 'TPS_MEDIUM'
    
    if 'CATEGORY_CONTROL' in recommended_focus:
        if level <= 5:
            return 'TPS_LOW'
        else:
            return 'MIXED_BALANCED'
    
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
    
    if tps < 15 and rdr > 40:
        return 'MIXED_RECOVERY'
    
    return 'MIXED_BALANCED'


def _build_personalized_prompt(tier, scenario, stats, user_context, period_type, period_name, period_context):
    evolution = user_context.get('evolution', {})
    category_patterns = user_context.get('category_patterns', {})
    mission_distribution = user_context.get('mission_distribution', {})
    
    problems_text = ""
    if stats.get('problems'):
        problems_text = "\n**PROBLEMAS IDENTIFICADOS:**\n" + "\n".join([f"- {p}" for p in stats['problems']])
    
    strengths_text = ""
    if stats.get('strengths'):
        strengths_text = "\n**PONTOS FORTES:**\n" + "\n".join([f"- {s}" for s in stats['strengths']])
    
    categories_text = ""
    if category_patterns.get('recommendations'):
        categories_text = "\n**CATEGORIAS QUE PRECISAM ATENÇÃO:**\n"
        for rec in category_patterns['recommendations'][:3]:
            categories_text += f"- {rec['category']}: {rec['reason']} (prioridade {rec['priority']})\n"
    
    distribution_text = ""
    underutilized = mission_distribution.get('underutilized_mission_types', [])
    if underutilized:
        distribution_text = f"\n**TIPOS DE MISSÕES POUCO EXPLORADOS:** {', '.join(underutilized[:3])}\n"
    
    evolution_text = ""
    if evolution.get('has_data'):
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
    
    distribution = scenario.get('distribution', {})
    dist_requirements = []
    for mission_type, count in distribution.items():
        dist_requirements.append(f"   - {count} missões de {mission_type}")
    distribution_requirements = '\n'.join(dist_requirements) if dist_requirements else "   - Distribuir equilibradamente"
    
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
  "validation_type": "INDICATOR_THRESHOLD|CATEGORY_REDUCTION|CATEGORY_LIMIT|TRANSACTION_COUNT|SAVINGS_INCREASE|CONSISTENCY",
  "priority": "LOW|MEDIUM|HIGH",
  "xp_reward": número (50-500),
  "duration_days": número (7-90),
  "target_tps": número ou null,
  "target_rdr": número ou null,
  "target_category": "nome da categoria" ou null,
  "category_limit_amount": número ou null,
  "category_reduction_percent": número ou null,
  "target_savings_amount": número ou null
}}

**IMPORTANTE:** 
- NÃO use markdown, retorne APENAS o JSON
- As missões devem ser ESPECÍFICAS para este usuário
- Use os dados de evolução para criar desafios progressivos
- Seja criativo mas realista
    Constrói prompt padrão (sem contexto de usuário específico).
    Mantém a lógica original.
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
    Gera 20 missões em lote para uma faixa de usuários usando Gemini.
    
    Args:
        tier: 'BEGINNER', 'INTERMEDIATE' ou 'ADVANCED'
        scenario_key: Chave do cenário específico ou None para auto-detectar
        user_context: Contexto completo de um usuário real (opcional, para personalização)
        
    Returns:
        List[dict]: Lista de 20 missões geradas ou lista vazia em caso de erro
    Cria missões no banco a partir do batch gerado.
    
    Args:
        tier: Faixa de usuários
        missions_data: Lista de dicts com dados das missões
        scenario_key: Chave do cenário (opcional, para logging)
        
    Returns:
        List[Mission]: Missões criadas
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
    Gera missões para um cenário específico.
    
    Args:
        scenario_key: Chave do cenário (ex: 'TPS_LOW', 'RDR_HIGH')
        tiers: Lista de tiers ou None para todos
        
    Returns:
        dict: Resultado da geração
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
Categorize esta transação financeira:

Descrição: "{description}"

Categorias do usuário:
{categories_list}

Responda APENAS com o nome exato de UMA categoria da lista acima.
Se nenhuma se encaixar perfeitamente, escolha a mais próxima.
Não adicione explicações.
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
        
        if response_text.startswith('```'):
            response_text = response_text.split('```')[1]
            if response_text.startswith('json'):
                response_text = response_text[4:]
        
        achievements_data = json.loads(response_text)
        
        logger.info(f"IA gerou {len(achievements_data)} conquistas com sucesso")
        
        cache.set(cache_key, achievements_data, timeout=2592000)
        
        return achievements_data
        
    except json.JSONDecodeError as e:
        logger.error(f"Erro ao parsear JSON da IA: {e}")
        logger.error(f"Resposta recebida: {response_text[:500]}")
        return []
    except Exception as e:
        logger.error(f"Erro ao gerar conquistas via IA: {e}")
        return []



def generate_general_missions(quantidade=10):
    """Gera missões gerais para o sistema usando IA."""
    from .models import Mission, Category
    
    base = quantidade // 5
    resto = quantidade % 5
    
    distribuicao = {
        'ONBOARDING': base + (1 if resto > 0 else 0),
        'TPS_IMPROVEMENT': base + (1 if resto > 1 else 0),
        'RDR_REDUCTION': base + (1 if resto > 2 else 0),
        'ILI_BUILDING': base + (1 if resto > 3 else 0),
        'CATEGORY_REDUCTION': base + (1 if resto > 4 else 0),
    }
    
    categorias_sistema = list(
        Category.objects.filter(is_system_default=True, type='EXPENSE')
        .values_list('name', flat=True)[:10]
    )
    categorias_sugestao = ', '.join(categorias_sistema) if categorias_sistema else 'Alimentação, Transporte, Lazer, Compras'
    
    created = []
    failed = []
    
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
    "target_category_name": null
  }}
]

IMPORTANTE: Preencha APENAS o campo específico do tipo de missão. Os demais devem ser null.
"""
    
    if not model:
        logger.warning("Gemini API não disponível para geração de missões")
        return {'created': [], 'failed': [], 'summary': {'error': 'API não disponível'}}
    
    try:
        response = model.generate_content(prompt)
        response_text = response.text.strip()
        
        if response_text.startswith('```'):
            response_text = response_text.split('```')[1]
            if response_text.startswith('json'):
                response_text = response_text[4:]
        
        missions_data = json.loads(response_text)
        
        for mission_data in missions_data:
            try:
                mission = Mission.objects.create(
                    title=mission_data.get('title', 'Missão'),
                    description=mission_data.get('description', ''),
                    mission_type=mission_data.get('mission_type', 'ONBOARDING'),
                    difficulty=mission_data.get('difficulty', 'MEDIUM'),
                    duration_days=mission_data.get('duration_days', 14),
                    reward_points=mission_data.get('reward_points', 100),
                    min_transactions=mission_data.get('min_transactions'),
                    target_tps=mission_data.get('target_tps'),
                    target_rdr=mission_data.get('target_rdr'),
                    min_ili=mission_data.get('min_ili'),
                    target_reduction_percent=mission_data.get('target_reduction_percent'),
                    is_active=True,
                    is_system_generated=True,
                    priority=50
                )
                created.append({'id': mission.id, 'title': mission.title})
            except Exception as e:
                failed.append({'title': mission_data.get('title'), 'error': str(e)})
        
        return {
            'created': created,
            'failed': failed,
            'summary': {
                'total_created': len(created),
                'total_failed': len(failed)
            }
        }
        
    except json.JSONDecodeError as e:
        logger.error(f"Erro ao parsear JSON: {e}")
        return {'created': [], 'failed': [], 'summary': {'error': f'JSON inválido: {e}'}}
    except Exception as e:
        logger.error(f"Erro ao gerar missões: {e}")
        return {'created': [], 'failed': [], 'summary': {'error': str(e)}}
