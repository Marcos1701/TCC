
from typing import Dict, List, Any
from decimal import Decimal
import random



ONBOARDING_TEMPLATES = [
    {
        'title': 'Seus Primeiros {count} Registros',
        'description': 'Registre {count} transações para mapear seu fluxo financeiro e iniciar o controle orçamentário.',
        'min_transactions': [5, 10, 15],
        'duration_days': 7,
        'xp_reward': 50,
        'difficulty': 'EASY'
    },
    {
        'title': 'Explorando Categorias',
        'description': 'Categorize suas primeiras {count} transações para identificar padrões de consumo.',
        'min_transactions': [10, 15, 20],
        'duration_days': 14,
        'xp_reward': 75,
        'difficulty': 'EASY'
    },
    {
        'title': 'Construindo o Hábito',
        'description': 'Mantenha a consistência registrando pelo menos {count} transações neste período.',
        'min_transactions': [20, 30, 40],
        'duration_days': 21,
        'xp_reward': 100,
        'difficulty': 'MEDIUM'
    },
    {
        'title': 'Mapeando Suas Finanças',
        'description': 'Registre {count} transações para visualizar seus padrões de consumo.',
        'min_transactions': [15, 25, 35],
        'duration_days': 14,
        'xp_reward': 75,
        'difficulty': 'EASY'
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

# GOAL_TEMPLATES removido - Goal system desativado em migration 0058

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



def generate_from_template(template: Dict, tier: str, current_metrics: Dict) -> Dict[str, Any]:
    mission_data = {
        'difficulty': template['difficulty'],
        'duration_days': template['duration_days'],
        'reward_points': template.get('xp_reward', template.get('reward_points', 50)),
        'is_active': True,
    }
    
    if 'min_transactions' in template:
        counts = template['min_transactions']
        if tier == 'BEGINNER':
            count = counts[0]
        elif tier == 'INTERMEDIATE':
            count = counts[min(1, len(counts)-1)]
        else:
            count = counts[-1]
        
        mission_data['title'] = template['title'].format(count=count)
        mission_data['description'] = template['description'].format(count=count)
        mission_data['mission_type'] = 'ONBOARDING'
        mission_data['validation_type'] = 'TRANSACTION_COUNT'
        mission_data['min_transactions'] = count
    
    elif 'target_tps_ranges' in template:
        ranges = template['target_tps_ranges']
        current_tps = current_metrics.get('tps', 10)
        
        suitable_ranges = [r for r in ranges if r[0] > current_tps]
        if not suitable_ranges:
            suitable_ranges = [ranges[-1]]
        
        target_range = suitable_ranges[0]
        target = target_range[1]
        
        mission_data['title'] = template['title'].format(target=target)
        mission_data['description'] = template['description'].format(target=target)
        mission_data['mission_type'] = 'TPS_IMPROVEMENT'
        mission_data['validation_type'] = 'INDICATOR_THRESHOLD'
        mission_data['target_tps'] = target
    
    elif 'target_rdr_ranges' in template:
        ranges = template['target_rdr_ranges']
        current_rdr = current_metrics.get('rdr', 50)
        
        suitable_ranges = [r for r in ranges if r[1] < current_rdr]
        if not suitable_ranges:
            suitable_ranges = [ranges[0]]
        
        target_range = suitable_ranges[0]
        target = target_range[1]
        
        mission_data['title'] = template['title'].format(target=target)
        mission_data['description'] = template['description'].format(target=target)
        mission_data['mission_type'] = 'RDR_REDUCTION'
        mission_data['validation_type'] = 'INDICATOR_THRESHOLD'
        mission_data['target_rdr'] = target
    
    elif 'min_ili_ranges' in template:
        ranges = template['min_ili_ranges']
        current_ili = current_metrics.get('ili', 2)
        
        suitable_ranges = [r for r in ranges if r[0] > current_ili]
        if not suitable_ranges:
            suitable_ranges = [ranges[-1]]
        
        target_range = suitable_ranges[0]
        target = target_range[1]
        
        mission_data['title'] = template['title'].format(target=target)
        mission_data['description'] = template['description'].format(target=target)
        mission_data['mission_type'] = 'ILI_BUILDING'
        mission_data['validation_type'] = 'INDICATOR_THRESHOLD'
        mission_data['min_ili'] = target
    
    elif 'reduction_percent_ranges' in template:
        ranges = template['reduction_percent_ranges']
        if tier == 'BEGINNER':
            target_range = ranges[0]
        elif tier == 'INTERMEDIATE':
            target_range = ranges[min(1, len(ranges)-1)]
        else:
            target_range = ranges[-1]
        
        percent = target_range[1]
        mission_data['title'] = template['title'].format(percent=percent)
        mission_data['description'] = template['description'].format(percent=percent)
        mission_data['mission_type'] = 'CATEGORY_REDUCTION'
        mission_data['validation_type'] = 'CATEGORY_REDUCTION'
        mission_data['target_reduction_percent'] = percent
    
    # progress_percent_ranges removido - Goal system desativado
    
    return mission_data


def generate_mission_batch_from_templates(
    tier: str,
    current_metrics: Dict,
    count: int = 20,
    distribution: Dict[str, int] = None
) -> List[Dict[str, Any]]:
    if distribution is None:
        if tier == 'BEGINNER':
            distribution = {
                'ONBOARDING': 7,
                'TPS_IMPROVEMENT': 5,
                'RDR_REDUCTION': 4,
                'ILI_BUILDING': 2,
                'CATEGORY_REDUCTION': 2,
            }
            distribution = {
                'ONBOARDING': 3,
                'TPS_IMPROVEMENT': 6,
                'RDR_REDUCTION': 4,
                'ILI_BUILDING': 4,
                'CATEGORY_REDUCTION': 3,
            }
        else:
            distribution = {
                'TPS_IMPROVEMENT': 6,
                'ILI_BUILDING': 6,
                'RDR_REDUCTION': 4,
                'CATEGORY_REDUCTION': 4,
            }
    
    missions = []
    
    for mission_type, target_count in distribution.items():
        if mission_type == 'ONBOARDING':
            templates = ONBOARDING_TEMPLATES
        elif mission_type == 'TPS_IMPROVEMENT':
            templates = TPS_TEMPLATES
        elif mission_type == 'RDR_REDUCTION':
            templates = RDR_TEMPLATES
        elif mission_type == 'ILI_BUILDING':
            templates = ILI_TEMPLATES
        elif mission_type == 'CATEGORY_REDUCTION':
            templates = CATEGORY_TEMPLATES
        else:
            continue
        
        for i in range(target_count):
            template = random.choice(templates)
            mission_data = generate_from_template(template, tier, current_metrics)
            missions.append(mission_data)
    
    return missions[:count]


def get_template_variety_score(tier: str, mission_type: str) -> int:
    template_counts = {
        'ONBOARDING': len(ONBOARDING_TEMPLATES),
        'TPS_IMPROVEMENT': len(TPS_TEMPLATES),
        'RDR_REDUCTION': len(RDR_TEMPLATES),
        'ILI_BUILDING': len(ILI_TEMPLATES),
        'CATEGORY_REDUCTION': len(CATEGORY_TEMPLATES),
    }
    
    return template_counts.get(mission_type, 0)

