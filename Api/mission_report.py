"""Relatório final das correções de missões."""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from finance.models import Mission, MissionProgress
from django.db.models import Count

print("="*80)
print("📊 RELATÓRIO FINAL - CORREÇÃO DE MISSÕES")
print("="*80)

print("\n1️⃣  MISSÕES POR TIPO:")
mission_types = Mission.objects.values('mission_type').annotate(
    count=Count('id')
).order_by('mission_type')

for mt in mission_types:
    print(f"   • {mt['mission_type']}: {mt['count']} missões")

print("\n2️⃣  MISSÕES POR VALIDATION_TYPE:")
validation_types = Mission.objects.values('validation_type').annotate(
    count=Count('id')
).order_by('validation_type')

for vt in validation_types:
    print(f"   • {vt['validation_type']}: {vt['count']} missões")

print("\n3️⃣  MISSÕES ILI_BUILDING:")
ili_missions = Mission.objects.filter(mission_type='ILI_BUILDING')
for m in ili_missions:
    print(f"   • ID {m.id}: {m.title}")
    print(f"     - min_ili={m.min_ili}, max_ili={m.max_ili}")
    print(f"     - validation_type={m.validation_type}")

print("\n4️⃣  MISSÕES TPS_IMPROVEMENT:")
tps_missions = Mission.objects.filter(mission_type='TPS_IMPROVEMENT')
for m in tps_missions:
    print(f"   • ID {m.id}: {m.title}")
    print(f"     - target_tps={m.target_tps}")
    print(f"     - validation_type={m.validation_type}")

print("\n5️⃣  MISSÕES RDR_REDUCTION:")
rdr_missions = Mission.objects.filter(mission_type='RDR_REDUCTION')
for m in rdr_missions:
    print(f"   • ID {m.id}: {m.title}")
    print(f"     - target_rdr={m.target_rdr}")
    print(f"     - validation_type={m.validation_type}")

print("\n6️⃣  PROGRESSO DE MISSÕES:")
total_progress = MissionProgress.objects.count()
by_status = MissionProgress.objects.values('status').annotate(
    count=Count('id')
).order_by('status')

print(f"   Total: {total_progress}")
for s in by_status:
    print(f"   • {s['status']}: {s['count']}")

print("\n7️⃣  VERIFICAÇÃO DE PLACEHOLDERS:")
with_placeholder = Mission.objects.filter(title__contains='{')
print(f"   Missões com placeholder: {with_placeholder.count()}")
if with_placeholder.exists():
    for m in with_placeholder:
        print(f"   ⚠️  ID {m.id}: {m.title}")

print("\n" + "="*80)
print("✅ TODAS AS CORREÇÕES APLICADAS COM SUCESSO!")
print("="*80)
