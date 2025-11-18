"""Script para corrigir missões com placeholders {target}."""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from finance.models import Mission

# Buscar missões com placeholder
missions_with_placeholder = Mission.objects.filter(title__contains='{target}')
print(f'Missões com placeholder no título: {missions_with_placeholder.count()}')

for mission in missions_with_placeholder:
    print(f'\n=== Missão ID {mission.id} ===')
    print(f'Título: {mission.title}')
    print(f'Descrição: {mission.description}')
    print(f'Tipo: {mission.mission_type}')
    print(f'Min ILI: {mission.min_ili}')
    print(f'Max ILI: {mission.max_ili}')
    print(f'Target category: {mission.target_category}')
    print(f'Target goal: {mission.target_goal_id}')

print('\n\n=== CORRIGINDO MISSÕES ===')

# Corrigir cada missão substituindo {target} pelo valor real
fixed_count = 0
for mission in missions_with_placeholder:
    # Para missões ILI_BUILDING, usar min_ili ou max_ili como target
    if mission.mission_type == 'ILI_BUILDING':
        target = mission.min_ili or mission.max_ili or 3
    else:
        target = 3  # Default 3 se não especificado
    
    old_title = mission.title
    old_description = mission.description
    
    # Substituir placeholder
    mission.title = mission.title.replace('{target}', str(int(target)))
    mission.description = mission.description.replace('{target}', str(int(target)))
    
    mission.save()
    fixed_count += 1
    
    print(f'\n✅ Missão {mission.id} corrigida:')
    print(f'  Título: {old_title} -> {mission.title}')

print(f'\n\n🎉 Total corrigido: {fixed_count} missões')
