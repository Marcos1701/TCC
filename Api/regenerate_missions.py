"""Script final para regenerar todas as missões com as correções aplicadas."""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from finance.models import Mission
from django.core.management import call_command

print("="*80)
print("🔄 REGENERANDO TODAS AS MISSÕES COM CORREÇÕES")
print("="*80)

# 1. Backup das missões atuais
print("\n📦 Backup das missões atuais...")
current_count = Mission.objects.count()
print(f"   Total atual: {current_count} missões")

# 2. Limpar missões
print("\n🗑️  Removendo missões antigas...")
Mission.objects.all().delete()
print("   ✅ Todas as missões removidas")

# 3. Gerar novas missões
print("\n🏗️  Gerando 50 novas missões...")
try:
    call_command('seed_missions', count=50, use_ai=False)
    print("   ✅ Missões geradas com sucesso")
except Exception as e:
    print(f"   ❌ Erro: {e}")
    import traceback
    traceback.print_exc()

# 4. Verificação final
print("\n\n📊 VERIFICAÇÃO FINAL:")
print("="*80)

total = Mission.objects.count()
print(f"\nTotal de missões: {total}")

# Verificar placeholders
with_placeholders_title = Mission.objects.filter(title__contains='{').count()
with_placeholders_desc = Mission.objects.filter(description__contains='{').count()

print(f"\n✅ Placeholders no título: {with_placeholders_title}")
print(f"✅ Placeholders na descrição: {with_placeholders_desc}")

if with_placeholders_title == 0 and with_placeholders_desc == 0:
    print("\n🎉 PERFEITO! Nenhum placeholder encontrado!")
else:
    print("\n⚠️  ATENÇÃO: Ainda existem placeholders!")

# Estatísticas por tipo
print("\n📈 Missões por tipo:")
from django.db.models import Count
types = Mission.objects.values('mission_type').annotate(
    count=Count('id')
).order_by('-count')

for t in types:
    print(f"   • {t['mission_type']}: {t['count']}")

# Estatísticas por validation_type
print("\n🔍 Missões por validation_type:")
validations = Mission.objects.values('validation_type').annotate(
    count=Count('id')
).order_by('-count')

for v in validations:
    print(f"   • {v['validation_type']}: {v['count']}")

# Verificar configurações críticas
print("\n⚙️  Verificações de configuração:")

# ILI com min_ili configurado
ili_without_min = Mission.objects.filter(
    mission_type='ILI_BUILDING',
    min_ili__isnull=True
).count()
print(f"   • Missões ILI sem min_ili: {ili_without_min}")

# TPS com target_tps configurado
tps_without_target = Mission.objects.filter(
    mission_type='TPS_IMPROVEMENT',
    target_tps__isnull=True
).count()
print(f"   • Missões TPS sem target_tps: {tps_without_target}")

# RDR com target_rdr configurado
rdr_without_target = Mission.objects.filter(
    mission_type='RDR_REDUCTION',
    target_rdr__isnull=True
).count()
print(f"   • Missões RDR sem target_rdr: {rdr_without_target}")

print("\n" + "="*80)
print("✨ REGENERAÇÃO CONCLUÍDA!")
print("="*80)
print(f"\n📌 Antes: {current_count} missões")
print(f"📌 Agora: {total} missões")
print(f"📌 Diferença: {total - current_count:+d}")
