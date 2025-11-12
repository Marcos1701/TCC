#!/usr/bin/env python
"""
Script para atualizar as dicas das missões adicionando o campo 'color'.
"""
import os
import django

# Configurar Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from finance.models import Mission


def get_tips_by_mission_type(mission_type):
    """Retorna tips com cores baseado no tipo de missão."""
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


def update_missions():
    """Atualiza todas as missões com dicas que incluem cores."""
    missions = Mission.objects.all()
    updated_count = 0
    
    for mission in missions:
        tips = get_tips_by_mission_type(mission.mission_type)
        if tips:
            mission.tips = tips
            mission.save(update_fields=['tips'])
            updated_count += 1
            print(f"✓ Atualizada missão: {mission.title}")
    
    print(f"\n{updated_count} missões atualizadas com sucesso!")


if __name__ == '__main__':
    print("Atualizando dicas das missões com campo 'color'...\n")
    update_missions()
