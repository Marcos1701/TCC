"""Script para recalcular progresso das missões ativas."""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from finance.models import MissionProgress

print("="*80)
print("RECALCULANDO PROGRESSO DAS MISSÕES ATIVAS")
print("="*80)

# Buscar todas as missões ativas
active_progress = MissionProgress.objects.filter(
    status__in=['PENDING', 'ACTIVE']
).select_related('mission', 'user')

print(f"\n📊 Total de missões ativas: {active_progress.count()}\n")

updated_count = 0
error_count = 0

for mp in active_progress:
    try:
        print(f"\n🔄 User {mp.user_id} - Missão '{mp.mission.title[:50]}'")
        print(f"   Status: {mp.status} | Progresso: {mp.progress}%")
        
        old_progress = mp.progress
        old_status = mp.status
        
        # Usar método update_progress que já existe no modelo
        mp.update_progress()
        
        # Recarregar do banco
        mp.refresh_from_db()
        
        if mp.status != old_status or mp.progress != old_progress:
            print(f"   ✅ Atualizado: {old_progress}% -> {mp.progress}% | Status: {old_status} -> {mp.status}")
            updated_count += 1
        else:
            print(f"   ℹ️  Sem mudanças")
        
    except Exception as e:
        print(f"   ❌ Erro: {str(e)}")
        import traceback
        traceback.print_exc()
        error_count += 1
        continue

print("\n" + "="*80)
print(f"✨ RECÁLCULO CONCLUÍDO!")
print(f"   • Atualizadas: {updated_count}")
print(f"   • Erros: {error_count}")
print("="*80)
