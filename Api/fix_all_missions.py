"""Script completo para corrigir configuração das missões."""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from finance.models import Mission

print("="*80)
print("CORRIGINDO MISSÕES DO SISTEMA")
print("="*80)

print("\n1️⃣  Corrigindo validation_type das missões ILI_BUILDING...")
ili_missions = Mission.objects.filter(mission_type='ILI_BUILDING')
for mission in ili_missions:
    if mission.validation_type == 'TRANSACTION_COUNT':
        old_type = mission.validation_type
        mission.validation_type = 'INDICATOR_THRESHOLD'
        mission.save()
        print(f"   ✅ Missão {mission.id} '{mission.title}': {old_type} -> INDICATOR_THRESHOLD")

print("\n2️⃣  Corrigindo validation_type das missões TPS_IMPROVEMENT...")
tps_missions = Mission.objects.filter(mission_type='TPS_IMPROVEMENT')
for mission in tps_missions:
    if mission.validation_type not in ['INDICATOR_THRESHOLD', 'INDICATOR_IMPROVEMENT']:
        old_type = mission.validation_type
        mission.validation_type = 'INDICATOR_IMPROVEMENT'
        mission.save()
        print(f"   ✅ Missão {mission.id} '{mission.title}': {old_type} -> INDICATOR_IMPROVEMENT")

print("\n3️⃣  Corrigindo validation_type das missões RDR_REDUCTION...")
rdr_missions = Mission.objects.filter(mission_type='RDR_REDUCTION')
for mission in rdr_missions:
    if mission.validation_type not in ['INDICATOR_THRESHOLD', 'INDICATOR_IMPROVEMENT']:
        old_type = mission.validation_type
        mission.validation_type = 'INDICATOR_IMPROVEMENT'
        mission.save()
        print(f"   ✅ Missão {mission.id} '{mission.title}': {old_type} -> INDICATOR_IMPROVEMENT")

print("\n4️⃣  Corrigindo validation_type das missões CATEGORY_REDUCTION...")
cat_missions = Mission.objects.filter(mission_type='CATEGORY_REDUCTION')
for mission in cat_missions:
    if mission.validation_type != 'CATEGORY_REDUCTION':
        old_type = mission.validation_type
        mission.validation_type = 'CATEGORY_REDUCTION'
        mission.save()
        print(f"   ✅ Missão {mission.id} '{mission.title}': {old_type} -> CATEGORY_REDUCTION")

print("\n5️⃣  Corrigindo validation_type das missões CATEGORY_SPENDING_LIMIT...")
limit_missions = Mission.objects.filter(mission_type='CATEGORY_SPENDING_LIMIT')
for mission in limit_missions:
    if mission.validation_type != 'CATEGORY_LIMIT':
        old_type = mission.validation_type
        mission.validation_type = 'CATEGORY_LIMIT'
        mission.save()
        print(f"   ✅ Missão {mission.id} '{mission.title}': {old_type} -> CATEGORY_LIMIT")

print("\n6️⃣  Corrigindo validation_type das missões GOAL_ACHIEVEMENT...")
goal_missions = Mission.objects.filter(mission_type='GOAL_ACHIEVEMENT')
for mission in goal_missions:
    if mission.validation_type not in ['GOAL_PROGRESS', 'GOAL_COMPLETION']:
        old_type = mission.validation_type
        mission.validation_type = 'GOAL_PROGRESS'
        mission.save()
        print(f"   ✅ Missão {mission.id} '{mission.title}': {old_type} -> GOAL_PROGRESS")

print("\n7️⃣  Configurando min_ili para missões ILI_BUILDING...")
from decimal import Decimal
ili_configs = [
    ("Primeira segurança", Decimal('1.0'), Decimal('3.0')),
    ("Almofada de segurança", Decimal('3.0'), Decimal('6.0')),
    ("Reserva sólida", Decimal('6.0'), None),
    ("Reserva de 3 Meses", Decimal('3.0'), None),
    ("Fortalecendo Sua Rede de Segurança", Decimal('6.0'), None),
]

for title_part, min_val, max_val in ili_configs:
    missions = Mission.objects.filter(
        mission_type='ILI_BUILDING',
        title__icontains=title_part
    )
    for mission in missions:
        updated = False
        if mission.min_ili is None and min_val:
            mission.min_ili = min_val
            updated = True
        if mission.max_ili is None and max_val:
            mission.max_ili = max_val
            updated = True
        if updated:
            mission.save()
            print(f"   ✅ Configurado '{mission.title}': min_ili={mission.min_ili}, max_ili={mission.max_ili}")

print("\n" + "="*80)
print("✨ CORREÇÃO CONCLUÍDA COM SUCESSO!")
print("="*80)

# Relatório final
print("\n📊 RELATÓRIO FINAL:")
print(f"   • Missões ILI_BUILDING: {Mission.objects.filter(mission_type='ILI_BUILDING').count()}")
print(f"   • Missões TPS_IMPROVEMENT: {Mission.objects.filter(mission_type='TPS_IMPROVEMENT').count()}")
print(f"   • Missões RDR_REDUCTION: {Mission.objects.filter(mission_type='RDR_REDUCTION').count()}")
print(f"   • Missões CATEGORY_REDUCTION: {Mission.objects.filter(mission_type='CATEGORY_REDUCTION').count()}")
print(f"   • Missões GOAL_ACHIEVEMENT: {Mission.objects.filter(mission_type='GOAL_ACHIEVEMENT').count()}")
print(f"   • Total de missões: {Mission.objects.count()}")
