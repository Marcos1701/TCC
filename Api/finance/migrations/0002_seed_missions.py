from django.db import migrations


def create_default_missions(apps, schema_editor):
    Mission = apps.get_model("finance", "Mission")
    missions = [
        {
            "title": "Respira e corta 3 gastos extras",
            "description": "Revise os gastos flexíveis da semana e corte pelo menos três despesas pequenas.",
            "reward_points": 80,
            "difficulty": "EASY",
            "target_tps": 12,
            "target_rdr": None,
            "duration_days": 7,
        },
        {
            "title": "Sprint da reserva",
            "description": "Guarde 15% da renda líquida deste mês e deixa separado da conta corrente.",
            "reward_points": 120,
            "difficulty": "MEDIUM",
            "target_tps": 15,
            "target_rdr": None,
            "duration_days": 30,
        },
        {
            "title": "Desacelera as dívidas",
            "description": "Negocie ou antecipe parcelas pra reduzir a razão dívida/renda pra baixo de 40%.",
            "reward_points": 150,
            "difficulty": "MEDIUM",
            "target_tps": None,
            "target_rdr": 40,
            "duration_days": 45,
        },
        {
            "title": "Modo avalanche",
            "description": "Liste todas as dívidas e foque primeiro na com maior juros até quitar a próxima parcela.",
            "reward_points": 200,
            "difficulty": "HARD",
            "target_tps": None,
            "target_rdr": 35,
            "duration_days": 60,
        },
        {
            "title": "30 dias de registro",
            "description": "Anote todas as entradas e saídas diariamente por um mês inteiro.",
            "reward_points": 160,
            "difficulty": "MEDIUM",
            "target_tps": 18,
            "target_rdr": None,
            "duration_days": 30,
        },
    ]

    for data in missions:
        Mission.objects.get_or_create(title=data["title"], defaults=data)


def drop_default_missions(apps, schema_editor):
    Mission = apps.get_model("finance", "Mission")
    Mission.objects.filter(
        title__in=[
            "Respira e corta 3 gastos extras",
            "Sprint da reserva",
            "Desacelera as dívidas",
            "Modo avalanche",
            "30 dias de registro",
        ]
    ).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("finance", "0001_initial"),
    ]

    operations = [
        migrations.RunPython(create_default_missions, drop_default_missions),
    ]
