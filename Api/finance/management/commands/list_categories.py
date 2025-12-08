"""
Script para listar todas as categorias globais e verificar duplicatas
"""
from django.core.management.base import BaseCommand
from finance.models import Category


class Command(BaseCommand):
    help = 'Lista todas as categorias globais'

    def handle(self, *args, **options):
        self.stdout.write('\n📋 CATEGORIAS GLOBAIS (user=None):\n')
        
        categories = Category.objects.filter(user__isnull=True).order_by('type', 'name')
        
        current_type = None
        for cat in categories:
            if cat.type != current_type:
                current_type = cat.type
                self.stdout.write(f'\n  {current_type}:')
            
            color_status = f'🎨 {cat.color}' if cat.color else '⚪ sem cor'
            self.stdout.write(f'    ID {cat.id}: {cat.name} [{color_status}]')
        
        self.stdout.write(f'\n\n📊 Total: {categories.count()} categorias globais')
        
        # Verificar duplicatas
        self.stdout.write('\n🔍 VERIFICANDO DUPLICATAS...\n')
        
        from django.db.models import Count
        duplicates = Category.objects.filter(user__isnull=True).values('name', 'type').annotate(
            count=Count('id')
        ).filter(count__gt=1)
        
        if duplicates.exists():
            for d in duplicates:
                self.stdout.write(self.style.ERROR(f"  ⚠️ DUPLICATA: {d['name']} ({d['type']}) - {d['count']} ocorrências"))
        else:
            self.stdout.write(self.style.SUCCESS('  ✅ Nenhuma duplicata encontrada no banco!'))
