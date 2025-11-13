"""
Sistema de templates para geração de missões contextualizadas.

Este módulo define templates estruturados para cada tipo de missão,
garantindo variedade, clareza e alinhamento com objetivos educacionais.

Benefícios:
- Reduz drasticamente duplicatas
- Garante consistência e qualidade
- Facilita localização e personalização
- Acelera geração (menos dependência de IA)
"""

from typing import Dict, List, Any
from decimal import Decimal
import random


# =============================================================================
# TEMPLATES DE ONBOARDING (Integração Inicial)
# =============================================================================

ONBOARDING_TEMPLATES = [
    {
        'title': 'Seus Primeiros {count} Registros',
        'description': 'Registre {count} transações para começar a entender para onde vai seu dinheiro. Cada registro é um passo rumo ao controle financeiro!',
        'min_transactions': [5, 10, 15],
        'duration_days': 7,
        'xp_reward': 100,
        'difficulty': 'EASY'
    },
    {
        'title': 'Explorando Categorias',
        'description': 'Organize suas primeiras {count} transações em categorias diferentes. Isso ajuda a identificar padrões de consumo.',
        'min_transactions': [10, 15, 20],
        'duration_days': 14,
        'xp_reward': 120,
        'difficulty': 'EASY'
    },
    {
        'title': 'Construindo o Hábito',
        'description': 'Registre pelo menos {count} transações neste período. Consistência é a chave para o controle financeiro!',
        'min_transactions': [20, 30, 40],
        'duration_days': 21,
        'xp_reward': 150,
        'difficulty': 'MEDIUM'
    },
    {
        'title': 'Mapeando Suas Finanças',
        'description': 'Registre {count} transações e comece a visualizar seus padrões de consumo. Conhecimento é poder!',
        'min_transactions': [15, 25, 35],
        'duration_days': 14,
        'xp_reward': 130,
        'difficulty': 'EASY'
    },
    {
        'title': 'Dominando o Básico',
        'description': 'Alcance {count} transações registradas. Você está criando uma base sólida para decisões financeiras inteligentes.',
        'min_transactions': [30, 40, 50],
        'duration_days': 30,
        'xp_reward': 200,
        'difficulty': 'MEDIUM'
    },
]


# =============================================================================
# TEMPLATES DE TPS (Melhoria de Poupança)
# =============================================================================

TPS_TEMPLATES = [
    {
        'title': 'Alcançando {target}% de Economia',
        'description': 'Eleve sua Taxa de Poupança Pessoal para {target}%. Pequenos ajustes nos gastos fazem grande diferença!',
        'target_tps_ranges': [(10, 15), (15, 20), (20, 25), (25, 30)],
        'duration_days': 30,
        'xp_reward': 200,
        'difficulty': 'MEDIUM'
    },
    {
        'title': 'Desafio: {target}% de TPS',
        'description': 'Atinja {target}% de Taxa de Poupança. Revise suas despesas não essenciais e encontre oportunidades de economia.',
        'target_tps_ranges': [(15, 20), (20, 25), (25, 30), (30, 35)],
        'duration_days': 30,
        'xp_reward': 250,
        'difficulty': 'HARD'
    },
    {
        'title': 'Construindo Reservas: Meta {target}%',
        'description': 'Aumente sua poupança para {target}% da renda. Cada real economizado é um tijolo na sua segurança financeira.',
        'target_tps_ranges': [(10, 15), (15, 20), (20, 25)],
        'duration_days': 30,
        'xp_reward': 180,
        'difficulty': 'MEDIUM'
    },
    {
        'title': 'Poupador Consistente: {target}%',
        'description': 'Mantenha {target}% de TPS por todo o período. Consistência transforma hábitos em resultados duradouros.',
        'target_tps_ranges': [(15, 20), (20, 25), (25, 30), (30, 40)],
        'duration_days': 30,
        'xp_reward': 300,
        'difficulty': 'HARD'
    },
    {
        'title': 'Primeiro Passo: {target}% de Economia',
        'description': 'Comece sua jornada de poupança atingindo {target}% de TPS. Identifique gastos que podem ser reduzidos ou eliminados.',
        'target_tps_ranges': [(5, 10), (10, 15), (15, 20)],
        'duration_days': 21,
        'xp_reward': 150,
        'difficulty': 'EASY'
    },
]


# =============================================================================
# TEMPLATES DE RDR (Redução de Despesas Recorrentes)
# =============================================================================

RDR_TEMPLATES = [
    {
        'title': 'Controlando Gastos Fixos: Meta {target}%',
        'description': 'Reduza suas despesas recorrentes para {target}% da renda. Revise assinaturas e compromissos fixos desnecessários.',
        'target_rdr_ranges': [(30, 40), (40, 50), (20, 30)],
        'duration_days': 30,
        'xp_reward': 220,
        'difficulty': 'MEDIUM'
    },
    {
        'title': 'Liberdade Financeira: RDR {target}%',
        'description': 'Baixe seu RDR para {target}%. Quanto menos comprometida sua renda, mais liberdade você tem para escolhas.',
        'target_rdr_ranges': [(25, 35), (35, 45), (15, 25)],
        'duration_days': 30,
        'xp_reward': 250,
        'difficulty': 'HARD'
    },
    {
        'title': 'Otimizando Despesas Fixas',
        'description': 'Alcance {target}% de RDR. Analise cada despesa recorrente e questione: "Isso ainda faz sentido para mim?"',
        'target_rdr_ranges': [(30, 40), (40, 50), (50, 60)],
        'duration_days': 30,
        'xp_reward': 200,
        'difficulty': 'MEDIUM'
    },
    {
        'title': 'Redução Inteligente: {target}%',
        'description': 'Mantenha suas despesas recorrentes em {target}% ou menos. Negocie contratos e elimine gastos supérfluos.',
        'target_rdr_ranges': [(20, 30), (30, 40), (40, 50)],
        'duration_days': 30,
        'xp_reward': 230,
        'difficulty': 'MEDIUM'
    },
]


# =============================================================================
# TEMPLATES DE ILI (Construção de Reserva)
# =============================================================================

ILI_TEMPLATES = [
    {
        'title': 'Reserva de {target} Meses',
        'description': 'Construa uma reserva capaz de cobrir {target} meses de despesas. Segurança financeira começa com planejamento.',
        'min_ili_ranges': [(3, 4), (4, 6), (6, 9), (9, 12)],
        'duration_days': 30,
        'xp_reward': 250,
        'difficulty': 'MEDIUM'
    },
    {
        'title': 'Fortalecendo Sua Rede de Segurança',
        'description': 'Aumente sua reserva de emergência para {target} meses. Imprevistos acontecem, estar preparado faz toda diferença.',
        'min_ili_ranges': [(3, 5), (6, 8), (9, 12)],
        'duration_days': 30,
        'xp_reward': 280,
        'difficulty': 'HARD'
    },
    {
        'title': 'Primeiros Passos: {target} Meses de Reserva',
        'description': 'Comece sua reserva de emergência com meta de {target} meses. Pequenas contribuições regulares geram grandes resultados.',
        'min_ili_ranges': [(1, 2), (2, 3), (3, 4)],
        'duration_days': 21,
        'xp_reward': 180,
        'difficulty': 'EASY'
    },
    {
        'title': 'Tranquilidade Financeira: {target} Meses',
        'description': 'Alcance {target} meses de ILI. Durma tranquilo sabendo que está preparado para emergências.',
        'min_ili_ranges': [(6, 8), (9, 12), (12, 15)],
        'duration_days': 30,
        'xp_reward': 300,
        'difficulty': 'HARD'
    },
]


# =============================================================================
# TEMPLATES AVANÇADOS (Múltiplos Critérios)
# =============================================================================

ADVANCED_TEMPLATES = [
    {
        'title': 'Equilíbrio Financeiro Total',
        'description': 'Atinja {tps}% de TPS, mantenha RDR abaixo de {rdr}% e construa {ili} meses de reserva. Desafio completo!',
        'criteria': [
            {'target_tps': 20, 'target_rdr': 35, 'min_ili': 6},
            {'target_tps': 25, 'target_rdr': 30, 'min_ili': 9},
            {'target_tps': 30, 'target_rdr': 25, 'min_ili': 12},
        ],
        'duration_days': 30,
        'xp_reward': 400,
        'difficulty': 'HARD'
    },
    {
        'title': 'Mestre das Finanças',
        'description': 'Demonstre excelência financeira: TPS de {tps}%+, RDR abaixo de {rdr}% e ILI de {ili}+ meses.',
        'criteria': [
            {'target_tps': 25, 'target_rdr': 30, 'min_ili': 6},
            {'target_tps': 30, 'target_rdr': 25, 'min_ili': 9},
            {'target_tps': 35, 'target_rdr': 20, 'min_ili': 12},
        ],
        'duration_days': 30,
        'xp_reward': 500,
        'difficulty': 'HARD'
    },
]


# =============================================================================
# FUNÇÕES DE GERAÇÃO
# =============================================================================

def generate_from_template(template: Dict, tier: str, current_metrics: Dict) -> Dict[str, Any]:
    """
    Gera uma missão específica a partir de um template.
    
    Args:
        template: Template base
        tier: Faixa do usuário (BEGINNER, INTERMEDIATE, ADVANCED)
        current_metrics: Métricas atuais do usuário (TPS, RDR, ILI)
        
    Returns:
        Dict com dados da missão pronta para salvar
    """
    mission_data = {
        'difficulty': template['difficulty'],
        'duration_days': template['duration_days'],
        'xp_reward': template['xp_reward'],
    }
    
    # ONBOARDING
    if 'min_transactions' in template:
        counts = template['min_transactions']
        # Escolher baseado na tier
        if tier == 'BEGINNER':
            count = counts[0]
        elif tier == 'INTERMEDIATE':
            count = counts[min(1, len(counts)-1)]
        else:
            count = counts[-1]
        
        mission_data['title'] = template['title'].format(count=count)
        mission_data['description'] = template['description'].format(count=count)
        mission_data['mission_type'] = 'ONBOARDING'
        mission_data['min_transactions'] = count
    
    # TPS
    elif 'target_tps_ranges' in template:
        ranges = template['target_tps_ranges']
        current_tps = current_metrics.get('tps', 10)
        
        # Escolher range apropriado baseado no TPS atual
        suitable_ranges = [r for r in ranges if r[0] > current_tps]
        if not suitable_ranges:
            suitable_ranges = [ranges[-1]]
        
        target_range = suitable_ranges[0]
        target = target_range[1]  # Usar limite superior como meta
        
        mission_data['title'] = template['title'].format(target=target)
        mission_data['description'] = template['description'].format(target=target)
        mission_data['mission_type'] = 'TPS_IMPROVEMENT'
        mission_data['target_tps'] = target
    
    # RDR
    elif 'target_rdr_ranges' in template:
        ranges = template['target_rdr_ranges']
        current_rdr = current_metrics.get('rdr', 50)
        
        # Escolher range apropriado (menor que o atual)
        suitable_ranges = [r for r in ranges if r[1] < current_rdr]
        if not suitable_ranges:
            suitable_ranges = [ranges[0]]
        
        target_range = suitable_ranges[0]
        target = target_range[1]
        
        mission_data['title'] = template['title'].format(target=target)
        mission_data['description'] = template['description'].format(target=target)
        mission_data['mission_type'] = 'RDR_REDUCTION'
        mission_data['target_rdr'] = target
    
    # ILI
    elif 'min_ili_ranges' in template:
        ranges = template['min_ili_ranges']
        current_ili = current_metrics.get('ili', 2)
        
        # Escolher range apropriado (maior que o atual)
        suitable_ranges = [r for r in ranges if r[0] > current_ili]
        if not suitable_ranges:
            suitable_ranges = [ranges[-1]]
        
        target_range = suitable_ranges[0]
        target = target_range[1]
        
        mission_data['title'] = template['title'].format(target=target)
        mission_data['description'] = template['description'].format(target=target)
        mission_data['mission_type'] = 'ILI_BUILDING'
        mission_data['min_ili'] = target
    
    # ADVANCED
    elif 'criteria' in template:
        # Escolher critério baseado na tier
        criteria_options = template['criteria']
        if tier == 'BEGINNER':
            criteria = criteria_options[0]
        elif tier == 'INTERMEDIATE':
            criteria = criteria_options[min(1, len(criteria_options)-1)]
        else:
            criteria = criteria_options[-1]
        
        mission_data['title'] = template['title'].format(**criteria)
        mission_data['description'] = template['description'].format(**criteria)
        mission_data['mission_type'] = 'ADVANCED'
        mission_data.update(criteria)
    
    return mission_data


def generate_mission_batch_from_templates(
    tier: str,
    current_metrics: Dict,
    count: int = 20,
    distribution: Dict[str, int] = None
) -> List[Dict[str, Any]]:
    """
    Gera um lote de missões usando templates.
    
    Args:
        tier: Faixa do usuário
        current_metrics: Métricas atuais (TPS, RDR, ILI)
        count: Número de missões a gerar
        distribution: Distribuição por tipo (ex: {'ONBOARDING': 8, 'TPS_IMPROVEMENT': 12})
        
    Returns:
        Lista de dicionários com dados de missões
    """
    if distribution is None:
        # Distribuição padrão baseada na tier
        if tier == 'BEGINNER':
            distribution = {
                'ONBOARDING': 10,
                'TPS_IMPROVEMENT': 6,
                'RDR_REDUCTION': 4,
            }
        elif tier == 'INTERMEDIATE':
            distribution = {
                'TPS_IMPROVEMENT': 8,
                'RDR_REDUCTION': 6,
                'ILI_BUILDING': 6,
            }
        else:  # ADVANCED
            distribution = {
                'TPS_IMPROVEMENT': 6,
                'ILI_BUILDING': 6,
                'ADVANCED': 8,
            }
    
    missions = []
    
    for mission_type, target_count in distribution.items():
        # Selecionar templates apropriados
        if mission_type == 'ONBOARDING':
            templates = ONBOARDING_TEMPLATES
        elif mission_type == 'TPS_IMPROVEMENT':
            templates = TPS_TEMPLATES
        elif mission_type == 'RDR_REDUCTION':
            templates = RDR_TEMPLATES
        elif mission_type == 'ILI_BUILDING':
            templates = ILI_TEMPLATES
        elif mission_type == 'ADVANCED':
            templates = ADVANCED_TEMPLATES
        else:
            continue
        
        # Gerar missões a partir dos templates
        for i in range(target_count):
            template = random.choice(templates)
            mission_data = generate_from_template(template, tier, current_metrics)
            missions.append(mission_data)
    
    return missions[:count]


def get_template_variety_score(tier: str, mission_type: str) -> int:
    """
    Retorna o número de variações disponíveis para um tipo de missão.
    Útil para decidir se precisa gerar mais com IA ou se templates são suficientes.
    """
    template_counts = {
        'ONBOARDING': len(ONBOARDING_TEMPLATES),
        'TPS_IMPROVEMENT': len(TPS_TEMPLATES),
        'RDR_REDUCTION': len(RDR_TEMPLATES),
        'ILI_BUILDING': len(ILI_TEMPLATES),
        'ADVANCED': len(ADVANCED_TEMPLATES),
    }
    
    return template_counts.get(mission_type, 0)
