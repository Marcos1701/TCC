from decimal import Decimal
from django.db import migrations


def create_new_missions(apps, schema_editor):
    Mission = apps.get_model("finance", "Mission")
    
    # Limpar missões antigas
    Mission.objects.all().delete()
    
    # Missões de ONBOARDING - Foco em cadastro inicial
    missions = [
        # ===== ONBOARDING =====
        {
            "title": "Primeiros passos",
            "description": "Registre suas primeiras 5 transações para começar a entender seu fluxo financeiro.",
            "reward_points": 50,
            "difficulty": "EASY",
            "mission_type": "ONBOARDING",
            "priority": 1,
            "min_transactions": 5,
            "duration_days": 7,
        },
        {
            "title": "Mapeamento inicial",
            "description": "Cadastre 10 transações incluindo receitas e despesas para ter uma visão básica do seu orçamento.",
            "reward_points": 80,
            "difficulty": "EASY",
            "mission_type": "ONBOARDING",
            "priority": 2,
            "min_transactions": 10,
            "duration_days": 14,
        },
        {
            "title": "Registro completo",
            "description": "Alcance 20 transações registradas para construir um histórico consistente.",
            "reward_points": 120,
            "difficulty": "MEDIUM",
            "mission_type": "ONBOARDING",
            "priority": 3,
            "min_transactions": 20,
            "duration_days": 21,
        },
        
        # ===== TPS_IMPROVEMENT - Melhoria de poupança =====
        {
            "title": "Começar a poupar",
            "description": "Melhore sua taxa de poupança para pelo menos 10% da renda líquida mensal.",
            "reward_points": 100,
            "difficulty": "MEDIUM",
            "mission_type": "TPS_IMPROVEMENT",
            "priority": 10,
            "target_tps": 10,
            "max_ili": Decimal("3.0"),
            "duration_days": 30,
        },
        {
            "title": "Disciplina financeira",
            "description": "Alcance 15% de taxa de poupança para garantir segurança financeira básica.",
            "reward_points": 150,
            "difficulty": "MEDIUM",
            "mission_type": "TPS_IMPROVEMENT",
            "priority": 11,
            "target_tps": 15,
            "min_ili": Decimal("3.0"),
            "max_ili": Decimal("6.0"),
            "duration_days": 45,
        },
        {
            "title": "Poupador consistente",
            "description": "Mantenha 20% de taxa de poupança para acelerar seus objetivos financeiros.",
            "reward_points": 200,
            "difficulty": "HARD",
            "mission_type": "TPS_IMPROVEMENT",
            "priority": 12,
            "target_tps": 20,
            "min_ili": Decimal("6.0"),
            "duration_days": 60,
        },
        
        # ===== RDR_REDUCTION - Redução de dívidas =====
        {
            "title": "Controle das dívidas",
            "description": "Reduza o comprometimento da renda com dívidas para menos de 49%.",
            "reward_points": 150,
            "difficulty": "MEDIUM",
            "mission_type": "RDR_REDUCTION",
            "priority": 20,
            "target_rdr": 49,
            "duration_days": 45,
        },
        {
            "title": "Respirar melhor",
            "description": "Baixe a razão dívida/renda para menos de 42% e ganhe mais folga no orçamento.",
            "reward_points": 180,
            "difficulty": "MEDIUM",
            "mission_type": "RDR_REDUCTION",
            "priority": 21,
            "target_rdr": 42,
            "duration_days": 60,
        },
        {
            "title": "Dívidas sob controle",
            "description": "Alcance comprometimento de renda abaixo de 35% para ter saúde financeira.",
            "reward_points": 220,
            "difficulty": "HARD",
            "mission_type": "RDR_REDUCTION",
            "priority": 22,
            "target_rdr": 35,
            "duration_days": 90,
        },
        
        # ===== ILI_BUILDING - Construção de reserva =====
        {
            "title": "Primeira segurança",
            "description": "Construa uma reserva de emergência que cubra pelo menos 1 mês de despesas essenciais.",
            "reward_points": 120,
            "difficulty": "MEDIUM",
            "mission_type": "ILI_BUILDING",
            "priority": 30,
            "min_ili": Decimal("1.0"),
            "max_ili": Decimal("3.0"),
            "duration_days": 60,
        },
        {
            "title": "Almofada de segurança",
            "description": "Amplie sua reserva para cobrir 3 meses de despesas essenciais.",
            "reward_points": 180,
            "difficulty": "MEDIUM",
            "mission_type": "ILI_BUILDING",
            "priority": 31,
            "min_ili": Decimal("3.0"),
            "max_ili": Decimal("6.0"),
            "duration_days": 90,
        },
        {
            "title": "Reserva sólida",
            "description": "Construa uma reserva completa que cubra 6 meses de despesas essenciais.",
            "reward_points": 250,
            "difficulty": "HARD",
            "mission_type": "ILI_BUILDING",
            "priority": 32,
            "min_ili": Decimal("6.0"),
            "duration_days": 120,
        },
        
        # ===== ADVANCED - Missões avançadas =====
        {
            "title": "Diversificar investimentos",
            "description": "Com reserva consolidada, explore diferentes tipos de investimento para otimizar retornos.",
            "reward_points": 200,
            "difficulty": "HARD",
            "mission_type": "ADVANCED",
            "priority": 40,
            "target_tps": 15,
            "target_rdr": 35,
            "min_ili": Decimal("6.0"),
            "min_transactions": 50,
            "duration_days": 90,
        },
        {
            "title": "Otimização patrimonial",
            "description": "Mantenha índices saudáveis enquanto maximiza seus investimentos de longo prazo.",
            "reward_points": 250,
            "difficulty": "HARD",
            "mission_type": "ADVANCED",
            "priority": 41,
            "target_tps": 20,
            "target_rdr": 30,
            "min_ili": Decimal("9.0"),
            "min_transactions": 100,
            "duration_days": 120,
        },
    ]
    
    for data in missions:
        Mission.objects.create(**data)


def drop_new_missions(apps, schema_editor):
    Mission = apps.get_model("finance", "Mission")
    Mission.objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ("finance", "0006_mission_improvements"),
    ]

    operations = [
        migrations.RunPython(create_new_missions, drop_new_missions),
    ]
