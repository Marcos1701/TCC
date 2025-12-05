# Generated manually on 2025-11-12
# Popula missions existentes com impacts e tips contextuais

from django.db import migrations


def get_impacts_by_mission_type(mission_type):
    """Retorna impacts baseado no tipo de missão."""
    impacts_map = {
        'TPS_IMPROVEMENT': [
            {
                'icon': 'trending_up',
                'title': 'Aumenta sua Taxa de Poupança',
                'description': 'Você estará guardando mais dinheiro mensalmente',
                'color': '#4CAF50',
            },
            {
                'icon': 'security',
                'title': 'Melhora sua Segurança Financeira',
                'description': 'Construindo uma reserva para emergências',
                'color': '#7C4DFF',
            },
        ],
        'RDR_REDUCTION': [
            {
                'icon': 'trending_down',
                'title': 'Reduz Comprometimento da Renda',
                'description': 'Menos dinheiro comprometido com dívidas',
                'color': '#00BFA5',
            },
            {
                'icon': 'psychology',
                'title': 'Menos Estresse Financeiro',
                'description': 'Dívidas menores significam mais tranquilidade',
                'color': '#9C27B0',
            },
        ],
        'ILI_BUILDING': [
            {
                'icon': 'shield',
                'title': 'Aumenta sua Liquidez Imediata',
                'description': 'Mais meses de despesas cobertas em emergências',
                'color': '#2196F3',
            },
            {
                'icon': 'self_improvement',
                'title': 'Independência Financeira',
                'description': 'Maior capacidade de enfrentar imprevistos',
                'color': '#7C4DFF',
            },
        ],
        'ADVANCED': [
            {
                'icon': 'rocket_launch',
                'title': 'Nível Avançado de Controle',
                'description': 'Domínio completo das suas finanças',
                'color': '#FF9800',
            },
            {
                'icon': 'stars',
                'title': 'Maximiza Recompensas',
                'description': 'Maior ganho de pontos e progressão rápida',
                'color': '#7C4DFF',
            },
        ],
        'ONBOARDING': [
            {
                'icon': 'lightbulb_outline',
                'title': 'Aprenda Conceitos Fundamentais',
                'description': 'Entenda os pilares da saúde financeira',
                'color': '#9C27B0',
            },
            {
                'icon': 'rocket',
                'title': 'Comece sua Jornada',
                'description': 'Primeiros passos para transformar suas finanças',
                'color': '#7C4DFF',
            },
        ],
    }
    return impacts_map.get(mission_type, [])


def get_tips_by_mission_type(mission_type):
    """Retorna tips baseado no tipo de missão."""
    tips_map = {
        'TPS_IMPROVEMENT': [
            {
                'icon': 'savings_outlined',
                'title': 'Automatize sua Poupança',
                'description': 'Configure transferências automáticas no início do mês para garantir que você poupe antes de gastar.',
                'priority': 'high',
                'color': '#4CAF50',
            },
            {
                'icon': 'cut',
                'title': 'Reduza Gastos Supérfluos',
                'description': 'Identifique e corte despesas não essenciais como assinaturas não utilizadas.',
                'priority': 'medium',
                'color': '#FF9800',
            },
        ],
        'RDR_REDUCTION': [
            {
                'icon': 'priority_high',
                'title': 'Priorize Dívidas Caras',
                'description': 'Foque em pagar primeiro as dívidas com juros mais altos (cartão de crédito, cheque especial).',
                'priority': 'high',
                'color': '#F44336',
            },
            {
                'icon': 'handshake',
                'title': 'Negocie suas Dívidas',
                'description': 'Entre em contato com credores para renegociar taxas e prazos mais favoráveis.',
                'priority': 'medium',
                'color': '#9C27B0',
            },
        ],
        'ILI_BUILDING': [
            {
                'icon': 'account_balance',
                'title': 'Escolha a Conta Certa',
                'description': 'Mantenha sua reserva de emergência em conta com liquidez imediata e rendimento.',
                'priority': 'high',
                'color': '#2196F3',
            },
            {
                'icon': 'shield_moon',
                'title': 'Proteja sua Reserva',
                'description': 'Use a reserva APENAS para emergências reais. Evite retiradas para gastos planejados.',
                'priority': 'medium',
                'color': '#7C4DFF',
            },
        ],
        'ADVANCED': [
            {
                'icon': 'analytics',
                'title': 'Analise Padrões',
                'description': 'Use a aba de análise para identificar tendências e otimizar seus gastos.',
                'priority': 'medium',
                'color': '#FF9800',
            },
            {
                'icon': 'calendar_month',
                'title': 'Planejamento Mensal',
                'description': 'Revise e ajuste seu orçamento no início de cada mês baseado no mês anterior.',
                'priority': 'medium',
                'color': '#7C4DFF',
            },
        ],
        'ONBOARDING': [
            {
                'icon': 'rocket_launch',
                'title': 'Comece Agora!',
                'description': 'Quanto antes você começar, mais fácil será completar o desafio no prazo.',
                'priority': 'high',
                'color': '#7C4DFF',
            },
            {
                'icon': 'today',
                'title': 'Registre Diariamente',
                'description': 'Crie o hábito de registrar suas transações todos os dias para ter um controle preciso.',
                'priority': 'medium',
                'color': '#00BFA5',
            },
        ],
    }
    return tips_map.get(mission_type, [])


def populate_missions_impacts_and_tips(apps, schema_editor):
    """Popula missions existentes com impacts e tips."""
    Mission = apps.get_model('finance', 'Mission')
    
    updated_count = 0
    for mission in Mission.objects.all():
        # Só atualiza se ainda não tem impacts/tips
        if not mission.impacts:
            mission.impacts = get_impacts_by_mission_type(mission.mission_type)
        
        if not mission.tips:
            mission.tips = get_tips_by_mission_type(mission.mission_type)
        
        # Adiciona impact de recompensa de pontos para todas
        points_impact = {
            'icon': 'star_rounded',
            'title': f'+{mission.reward_points} Pontos de Recompensa',
            'description': 'Avance de nível e desbloqueie novos desafios',
            'color': '#7C4DFF',
        }
        
        if points_impact not in mission.impacts:
            mission.impacts.append(points_impact)
        
        mission.save()
        updated_count += 1
    
    print(f"{updated_count} missions atualizadas com impacts e tips")


def reverse_populate(apps, schema_editor):
    """Limpa impacts e tips das missions."""
    Mission = apps.get_model('finance', 'Mission')
    Mission.objects.all().update(impacts=[], tips=[])


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0039_add_mission_impacts_and_tips'),
    ]

    operations = [
        migrations.RunPython(populate_missions_impacts_and_tips, reverse_populate),
    ]
