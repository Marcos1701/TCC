"""
Script para detectar e corrigir TODAS as categorias duplicadas no sistema.

Detecta duplicatas comparando nome + tipo, e mantém apenas a categoria que tem cor definida
(ou a primeira criada caso ambas tenham ou não tenham cor).

Uso:
    python manage.py fix_all_duplicate_categories          # Analisa duplicatas (dry-run)
    python manage.py fix_all_duplicate_categories --execute  # Executa as correções
"""

from django.core.management.base import BaseCommand
from django.db import transaction
from django.db.models import Count
from finance.models import Category, Transaction


class Command(BaseCommand):
    help = 'Detecta e corrige TODAS as categorias duplicadas'

    def add_arguments(self, parser):
        parser.add_argument(
            '--execute',
            action='store_true',
            help='Executa as correções. Sem esta flag, apenas mostra o que seria feito (dry-run)',
        )

    def handle(self, *args, **options):
        execute = options['execute']
        
        if not execute:
            self.stdout.write(self.style.WARNING(
                '\n⚠️  MODO DRY-RUN: Nenhuma alteração será feita.\n'
                '   Use --execute para aplicar as correções.\n'
            ))
        else:
            self.stdout.write(self.style.WARNING(
                '\n⚠️  MODO EXECUÇÃO: As alterações serão aplicadas!\n'
            ))

        # Listar todas as categorias para análise
        self.stdout.write('\n📋 ANÁLISE DE CATEGORIAS:\n')
        self._list_all_categories()

        # Encontrar duplicatas
        self.stdout.write('\n🔍 BUSCANDO DUPLICATAS...\n')
        duplicates = self._find_duplicates()
        
        if not duplicates:
            self.stdout.write(self.style.SUCCESS('✅ Nenhuma duplicata encontrada!'))
            return

        total_transactions_migrated = 0
        total_categories_removed = 0

        for (name, type_), category_ids in duplicates.items():
            result = self._fix_duplicate_group(name, type_, category_ids, execute)
            total_transactions_migrated += result['transactions']
            total_categories_removed += result['categories_removed']

        # Resumo final
        self.stdout.write('')
        self.stdout.write('=' * 60)
        if execute:
            self.stdout.write(self.style.SUCCESS(
                f'✅ CONCLUÍDO!\n'
                f'   📝 {total_transactions_migrated} transações migradas\n'
                f'   🗑️  {total_categories_removed} categorias duplicadas removidas'
            ))
        else:
            self.stdout.write(self.style.WARNING(
                f'📊 RESUMO DO DRY-RUN:\n'
                f'   📝 {total_transactions_migrated} transações SERIAM migradas\n'
                f'   🗑️  {total_categories_removed} categorias SERIAM removidas\n\n'
                f'   Execute com --execute para aplicar as correções.'
            ))
        self.stdout.write('=' * 60)

    def _list_all_categories(self):
        """Lista todas as categorias globais para análise"""
        categories = Category.objects.filter(user__isnull=True).order_by('type', 'name')
        
        current_type = None
        for cat in categories:
            if cat.type != current_type:
                current_type = cat.type
                self.stdout.write(f'\n  {current_type}:')
            
            color_status = f'🎨 {cat.color}' if cat.color else '⚪ sem cor'
            tx_count = Transaction.objects.filter(category=cat).count()
            self.stdout.write(f'    - {cat.name} (ID: {cat.id}) [{color_status}] - {tx_count} transações')

    def _find_duplicates(self):
        """Encontra todas as categorias duplicadas (mesmo nome + tipo)"""
        duplicates = {}
        
        # Buscar categorias globais agrupadas por nome e tipo
        categories = Category.objects.filter(user__isnull=True).values('name', 'type').annotate(
            count=Count('id')
        ).filter(count__gt=1)
        
        for item in categories:
            name = item['name']
            type_ = item['type']
            
            # Buscar todas as categorias com este nome/tipo
            cats = Category.objects.filter(
                name=name,
                type=type_,
                user__isnull=True
            ).order_by('id')
            
            duplicates[(name, type_)] = list(cats.values_list('id', flat=True))
            self.stdout.write(f'  ⚠️  "{name}" ({type_}): {len(cats)} duplicatas encontradas')
        
        return duplicates

    def _fix_duplicate_group(self, name, type_, category_ids, execute):
        """Corrige um grupo de categorias duplicadas"""
        result = {'transactions': 0, 'categories_removed': 0}
        
        # Buscar todas as categorias do grupo
        categories = list(Category.objects.filter(id__in=category_ids).order_by('id'))
        
        if len(categories) < 2:
            return result
        
        # Escolher a categoria principal: preferir a que tem cor definida
        primary = None
        for cat in categories:
            if cat.color and len(cat.color) > 1:  # Tem cor válida
                primary = cat
                break
        
        # Se nenhuma tem cor, usar a primeira (mais antiga)
        if not primary:
            primary = categories[0]
        
        duplicates_to_remove = [c for c in categories if c.id != primary.id]
        
        self.stdout.write(f'\n🔄 Corrigindo: "{name}" ({type_})')
        self.stdout.write(f'   ✅ Mantendo: ID {primary.id} (cor: {primary.color or "sem cor"})')
        
        for dup in duplicates_to_remove:
            # Contar e migrar transações
            affected_transactions = Transaction.objects.filter(category=dup)
            tx_count = affected_transactions.count()
            
            if tx_count > 0:
                self.stdout.write(f'   📝 {tx_count} transações de ID {dup.id} → ID {primary.id}')
                
                if execute:
                    with transaction.atomic():
                        affected_transactions.update(category=primary)
                
                result['transactions'] += tx_count
            
            # Remover duplicata
            if execute:
                dup.delete()
                self.stdout.write(self.style.SUCCESS(f'   🗑️  Categoria ID {dup.id} removida'))
            else:
                self.stdout.write(f'   🗑️  Categoria ID {dup.id} SERIA removida')
            
            result['categories_removed'] += 1
        
        return result
