"""Script de teste para validar geração de missões sem placeholders."""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from finance.management.commands.seed_missions import Command
from finance.models import Mission

print("="*80)
print("TESTE DE GERAÇÃO DE MISSÕES")
print("="*80)

# Limpar missões existentes
print("\n🗑️  Limpando missões antigas...")
Mission.objects.all().delete()

# Testar geração
print("\n🔧 Gerando 10 missões de teste (2 de cada tipo)...")
cmd = Command()
cmd.stdout = cmd.stdout

# Simular argumentos
class FakeOptions:
    def __init__(self):
        self.clear = False
        self.count = 10
        self.type = None
        self.use_ai = False
    
    def get(self, key, default=None):
        return getattr(self, key, default)

options = FakeOptions()

try:
    cmd.handle(**vars(options))
except Exception as e:
    print(f"❌ Erro na geração: {e}")
    import traceback
    traceback.print_exc()

print("\n\n📊 VERIFICANDO RESULTADOS:")
print("="*80)

# Verificar placeholders não substituídos
missions_with_placeholders = Mission.objects.filter(title__contains='{')
print(f"\n⚠️  Missões com placeholders no título: {missions_with_placeholders.count()}")
if missions_with_placeholders.exists():
    for m in missions_with_placeholders:
        print(f"   ❌ ID {m.id}: {m.title}")
else:
    print("   ✅ Nenhum placeholder encontrado nos títulos")

# Verificar descrições
desc_with_placeholders = Mission.objects.filter(description__contains='{')
print(f"\n⚠️  Missões com placeholders na descrição: {desc_with_placeholders.count()}")
if desc_with_placeholders.exists():
    for m in desc_with_placeholders[:5]:
        print(f"   ❌ ID {m.id}: {m.description[:80]}...")
else:
    print("   ✅ Nenhum placeholder encontrado nas descrições")

# Verificar validation_type
print("\n📋 Missões por validation_type:")
from django.db.models import Count
validation_counts = Mission.objects.values('validation_type').annotate(
    count=Count('id')
).order_by('validation_type')
for vc in validation_counts:
    print(f"   • {vc['validation_type']}: {vc['count']}")

# Amostras de cada tipo
print("\n🎯 AMOSTRAS DE MISSÕES GERADAS:")
print("="*80)

for mission_type in ['ONBOARDING', 'TPS_IMPROVEMENT', 'RDR_REDUCTION', 'ILI_BUILDING']:
    missions = Mission.objects.filter(mission_type=mission_type)[:2]
    if missions.exists():
        print(f"\n{mission_type}:")
        for m in missions:
            print(f"   📌 {m.title}")
            print(f"      {m.description[:100]}...")
            print(f"      validation_type: {m.validation_type}")
            if m.mission_type == 'TPS_IMPROVEMENT':
                print(f"      target_tps: {m.target_tps}")
            elif m.mission_type == 'RDR_REDUCTION':
                print(f"      target_rdr: {m.target_rdr}")
            elif m.mission_type == 'ILI_BUILDING':
                print(f"      min_ili: {m.min_ili}")

print("\n" + "="*80)
print("✅ TESTE CONCLUÍDO!")
print("="*80)
