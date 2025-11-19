from typing import Dict, List, Any
from decimal import Decimal
import random

ONBOARDING_TEMPLATES = [
    {
        'title': 'Seus Primeiros {count} Registros',
        'description': 'Registre {count} transações para mapear seu fluxo financeiro e iniciar o controle orçamentário.',
        'min_transactions': [5, 10, 15],
        'duration_days': 7,
        'xp_reward': 100,
        'difficulty': 'EASY'
    },
    {
        'title': 'Explorando Categorias',
        'description': 'Categorize suas primeiras {count} transações para identificar padrões de consumo.',
        'min_transactions': [10, 15, 20],
        'duration_days': 14,
        'xp_reward': 120,
        'difficulty': 'EASY'
    },
    {
        'title': 'Construindo o Hábito',
        'description': 'Mantenha a consistência registrando pelo menos {count} transações neste período.',
        'min_transactions': [20, 30, 40],
        'duration_days': 21,
        'xp_reward': 150,
        'difficulty': 'MEDIUM'
    },
    {
        'title': 'Mapeando Suas Finanças',
        'description': 'Registre {count} transações para visualizar seus padrões de consumo.',
        'min_transactions': [15, 25, 35],
        'duration_days': 14,
        'xp_reward': 130,
        'difficulty': 'EASY'
    },
    {
        'title': 'Dominando o Básico',
        'description': 'Alcance {count} transações registradas para consolidar sua base de dados financeiros.',
        'min_transactions': [30, 40, 50],
        'duration_days': 30,
        'xp_reward': 200,
        'difficulty': 'MEDIUM'
    },
]

TPS_TEMPLATES = [
    {
        'title': 'Alcançando {target}% de Economia',
        'description': 'Eleve sua Taxa de Poupança Pessoal para {target}%. Ajustes nos gastos geram resultados.',
        'target_tps_ranges': [(10, 15), (15, 20), (20, 25), (25, 30)],
        'duration_days': 30,
        'xp_reward': 200,
        'difficulty': 'MEDIUM'
    },
    {
        'title': 'Desafio: {target}% de TPS',
        'description': 'Atinja {target}% de Taxa de Poupança. Revise despesas não essenciais.',
        'target_tps_ranges': [(15, 20), (20, 25), (25, 30), (30, 35)],
        'duration_days': 30,
        'xp_reward': 250,
        'difficulty': 'HARD'
    },
    {
        'title': 'Construindo Reservas: Meta {target}%',
        'description': 'Aumente sua poupança para {target}% da renda mensal.',
        'target_tps_ranges': [(10, 15), (15, 20), (20, 25)],
        'duration_days': 30,
        'xp_reward': 180,
        'difficulty': 'MEDIUM'
    },
    {
        'title': 'Poupador Consistente: {target}%',
        'description': 'Mantenha {target}% de TPS durante todo o período.',
        'target_tps_ranges': [(15, 20), (20, 25), (25, 30), (30, 40)],
        'duration_days': 30,
        'xp_reward': 300,
        'difficulty': 'HARD'
    },
    {
        'title': 'Primeiro Passo: {target}% de Economia',
        'description': 'Inicie sua jornada de poupança atingindo {target}% de TPS.',
        'target_tps_ranges': [(5, 10), (10, 15), (15, 20)],
        'duration_days': 21,
        'xp_reward': 150,
        'difficulty': 'EASY'
    },
]

RDR_TEMPLATES = [
    {
        'title': 'Controlando Gastos Fixos: Meta {target}%',
        'description': 'Reduza despesas recorrentes para {target}% da renda. Revise assinaturas e custos fixos.',
        'target_rdr_ranges': [(30, 40), (40, 50), (20, 30)],
        'duration_days': 30,
        'xp_reward': 220,
        'difficulty': 'MEDIUM'
    },
    {
        'title': 'Liberdade Financeira: RDR {target}%',
        'description': 'Reduza seu RDR para {target}% para aumentar sua margem de manobra financeira.',
        'target_rdr_ranges': [(25, 35), (35, 45), (15, 25)],
        'duration_days': 30,
        'xp_reward': 250,
        'difficulty': 'HARD'
    },
    {
        'title': 'Otimizando Despesas Fixas',
        'description': 'Alcance {target}% de RDR através da análise crítica de despesas recorrentes.',
        'target_rdr_ranges': [(30, 40), (40, 50), (50, 60)],
        'duration_days': 30,
        'xp_reward': 200,
        'difficulty': 'MEDIUM'
    },
    {
        'title': 'Redução Inteligente: {target}%',
        'description': 'Mantenha despesas recorrentes em {target}% ou menos. Negocie contratos e elimine supérfluos.',
        'target_rdr_ranges': [(20, 30), (30, 40), (40, 50)],
        'duration_days': 30,
        'xp_reward': 230,
        'difficulty': 'MEDIUM'
    },
]

ILI_TEMPLATES = [
    {
        'title': 'Reserva de {target} Meses',
        'description': 'Construa uma reserva equivalente a {target} meses de despesas.',
        'min_ili_ranges': [(3, 4), (4, 6), (6, 9), (9, 12)],
        'duration_days': 30,
        'xp_reward': 250,
        'difficulty': 'MEDIUM'
    },
    {
        'title': 'Fortalecendo Sua Rede de Segurança',
        'description': 'Aumente sua reserva de emergência para cobrir {target} meses.',
        'min_ili_ranges': [(3, 5), (6, 8), (9, 12)],
        'duration_days': 30,
        'xp_reward': 280,
        'difficulty': 'HARD'
    },
    {
        'title': 'Primeiros Passos: {target} Meses de Reserva',
        'description': 'Inicie sua reserva de emergência com meta de {target} meses.',
        'min_ili_ranges': [(1, 2), (2, 3), (3, 4)],
        'duration_days': 21,
        'xp_reward': 180,
        'difficulty': 'EASY'
    },
    {
        'title': 'Tranquilidade Financeira: {target} Meses',
        'description': 'Alcance {target} meses de ILI para maior segurança financeira.',
        'min_ili_ranges': [(6, 8), (9, 12), (12, 15)],
        'duration_days': 30,
        'xp_reward': 300,
        'difficulty': 'HARD'
    },
]

CATEGORY_TEMPLATES = [
    {
        'title': 'Reduzindo {percent}% em Gastos',
        'description': 'Reduza gastos em uma categoria específica em {percent}%.',
        'reduction_percent_ranges': [(10, 15), (15, 20), (20, 30)],
        'duration_days': 30,
        'xp_reward': 180,
        'difficulty': 'MEDIUM'
    },
    {
        'title': 'Desafio de Economia: {percent}%',
        'description': 'Corte {percent}% dos gastos em uma categoria selecionada.',
        'reduction_percent_ranges': [(15, 20), (20, 30), (30, 40)],
        'duration_days': 30,
        'xp_reward': 220,
        'difficulty': 'HARD'
    },
    {
        'title': 'Controle Inteligente',
        'description': 'Reduza {percent}% em gastos supérfluos através de revisão detalhada.',
        'reduction_percent_ranges': [(10, 15), (15, 25), (25, 35)],
        'duration_days': 30,
        'xp_reward': 200,
        'difficulty': 'MEDIUM'
    },
]

GOAL_TEMPLATES = [
    {
        'title': 'Progresso de {percent}% na Meta',
        'description': 'Alcance {percent}% de progresso na meta selecionada.',
        'progress_percent_ranges': [(30, 50), (50, 75), (75, 100)],
        'duration_days': 30,
        'xp_reward': 200,
        'difficulty': 'MEDIUM'
    },
    {
        'title': 'Rumo à Conquista: {percent}%',
        'description': 'Atinja {percent}% da meta estabelecida.',
        'progress_percent_ranges': [(40, 60), (60, 80), (80, 100)],
        'duration_days': 30,
        'xp_reward': 250,
        'difficulty': 'HARD'
    },
    {
        'title': 'Primeiros Passos: {percent}%',
        'description': 'Complete {percent}% da meta inicial.',
        'progress_percent_ranges': [(10, 25), (25, 40), (40, 60)],
        'duration_days': 21,
        'xp_reward': 150,
        'difficulty': 'EASY'
    },
]

BEHAVIOR_TEMPLATES = [
    {
        'title': 'Consistência de {days} Dias',
        'description': 'Registre transações por {days} dias consecutivos.',
        'consecutive_days_ranges': [(7, 10), (14, 21), (21, 30)],
        'duration_days': 30,
        'xp_reward': 180,
        'difficulty': 'MEDIUM'
    },
    {
        'title': 'Disciplina Financeira',
        'description': 'Mantenha registros diários por {days} dias.',
        'consecutive_days_ranges': [(10, 14), (14, 21), (21, 30)],
        'duration_days': 30,
        'xp_reward': 220,
        'difficulty': 'HARD'
    },
    {
        'title': 'Construindo o Hábito',
        'description': 'Registre finanças por {days} dias seguidos.',
        'consecutive_days_ranges': [(3, 7), (7, 14), (14, 21)],
        'duration_days': 21,
        'xp_reward': 150,
        'difficulty': 'EASY'
    },
]

ADVANCED_TEMPLATES = [
    {
        'title': 'Equilíbrio Financeiro Total',
        'description': 'Atinja {tps}% de TPS, mantenha RDR abaixo de {rdr}% e construa {ili} meses de reserva.',
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
