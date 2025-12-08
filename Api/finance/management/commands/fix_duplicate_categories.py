"""
Script temporário para corrigir categorias duplicadas.

1. Migra todas as transações e itens relacionados das categorias duplicadas para as corretas
2. Remove as categorias duplicadas

Uso:
    python manage.py fix_duplicate_categories          # Apenas mostra o que seria feito (dry-run)
    python manage.py fix_duplicate_categories --execute  # Executa as correções

IMPORTANTE: Faça backup do banco antes de executar com --execute
"""

from django.core.management.base import BaseCommand
from django.db import transaction
from finance.models import Category, Transaction


class Command(BaseCommand):
    help = 'Corrige categorias duplicadas migrando transações e removendo duplicatas'

    # Mapeamento: nome incorreto -> nome correto
    CATEGORY_MAPPING = {
        # INCOME
        ('Investimentos', 'INCOME'): ('Resgate de Investimento', 'INCOME'),
        
        # EXPENSE
        ('Mercado', 'EXPENSE'): ('Supermercado', 'EXPENSE'),
        ('Energia', 'EXPENSE'): ('Energia Elétrica', 'EXPENSE'),
        ('Internet', 'EXPENSE'): ('Telefone & Internet', 'EXPENSE'),
        ('Farmácia', 'EXPENSE'): ('Saúde & Farmácia', 'EXPENSE'),
        ('Lazer', 'EXPENSE'): ('Lazer e Entretenimento', 'EXPENSE'),
        ('Viagem', 'EXPENSE'): ('Viagens', 'EXPENSE'),
        ('Assinaturas', 'EXPENSE'): ('Serviços de Streaming', 'EXPENSE'),
        ('Compras', 'EXPENSE'): ('Vestuário', 'EXPENSE'),
        ('Pagamento Empréstimo', 'EXPENSE'): ('Pagamento de Empréstimo', 'EXPENSE'),
        ('Pagamento Cartão', 'EXPENSE'): ('Pagamento de Cartão', 'EXPENSE'),
    }

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

        total_transactions_migrated = 0
        total_categories_removed = 0

        for (old_name, old_type), (new_name, new_type) in self.CATEGORY_MAPPING.items():
            result = self._migrate_category(old_name, old_type, new_name, new_type, execute)
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

    def _migrate_category(self, old_name, old_type, new_name, new_type, execute):
        """Migra transações de uma categoria duplicada para a correta"""
        result = {'transactions': 0, 'categories_removed': 0}

        # Buscar categoria incorreta (duplicada) - global (user=None)
        old_categories = Category.objects.filter(
            name=old_name,
            type=old_type,
            user__isnull=True
        )

        if not old_categories.exists():
            return result

        # Buscar categoria correta
        new_category = Category.objects.filter(
            name=new_name,
            type=new_type,
            user__isnull=True
        ).first()

        if not new_category:
            self.stdout.write(self.style.ERROR(
                f'❌ Categoria correta "{new_name}" ({new_type}) não encontrada! '
                f'Execute seed_default_categories primeiro.'
            ))
            return result

        self.stdout.write(f'\n🔄 Migrando: "{old_name}" → "{new_name}" ({old_type})')

        for old_cat in old_categories:
            # Contar transações afetadas
            affected_transactions = Transaction.objects.filter(category=old_cat)
            tx_count = affected_transactions.count()

            if tx_count > 0:
                self.stdout.write(f'   📝 {tx_count} transações encontradas')
                
                if execute:
                    with transaction.atomic():
                        # Migrar transações
                        affected_transactions.update(category=new_category)
                        self.stdout.write(self.style.SUCCESS(f'   ✅ Transações migradas'))
                
                result['transactions'] += tx_count

            # Remover categoria duplicada
            if execute:
                old_cat.delete()
                self.stdout.write(self.style.SUCCESS(f'   🗑️  Categoria "{old_name}" (ID: {old_cat.id}) removida'))
            else:
                self.stdout.write(f'   🗑️  Categoria "{old_name}" (ID: {old_cat.id}) SERIA removida')
            
            result['categories_removed'] += 1

        return result
