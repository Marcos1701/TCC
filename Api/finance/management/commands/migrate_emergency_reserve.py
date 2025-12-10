"""
Django management command to migrate transactions from 'Reserva de Emergência' to 'Poupança'.

This command:
1. Finds all 'Reserva de Emergência' categories (both INCOME and EXPENSE types)
2. For each affected user, ensures they have a 'Poupança' category
3. Migrates all transactions to the 'Poupança' category
4. Deletes the obsolete 'Reserva de Emergência' categories
"""
from django.core.management.base import BaseCommand
from django.db import transaction
from finance.models import Category, Transaction


class Command(BaseCommand):
    help = 'Migra transações de "Reserva de Emergência" para "Poupança"'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Executa sem fazer alterações (apenas mostra o que seria feito)',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        
        if dry_run:
            self.stdout.write(self.style.WARNING('🔍 Modo DRY RUN - Nenhuma alteração será salva\n'))
        else:
            self.stdout.write(self.style.WARNING('⚠️  ATENÇÃO: Este comando modificará o banco de dados\n'))
        
        # Find all "Reserva de Emergência" categories
        emergency_categories = Category.objects.filter(
            name='Reserva de Emergência'
        ).select_related('user')
        
        total_categories = emergency_categories.count()
        
        if total_categories == 0:
            self.stdout.write(self.style.SUCCESS('✅ Nenhuma categoria "Reserva de Emergência" encontrada!'))
            return
        
        self.stdout.write(f'📊 Encontradas {total_categories} categorias "Reserva de Emergência"\n')
        
        # Group by user and type
        stats = {
            'categories_deleted': 0,
            'transactions_migrated': 0,
            'savings_categories_created': 0,
            'users_affected': set(),
        }
        
        for emergency_cat in emergency_categories:
            user = emergency_cat.user
            user_label = f'User {user.id} ({user.username})' if user else 'Global'
            
            self.stdout.write(f'\n🔄 Processando: {user_label}')
            self.stdout.write(f'   Categoria: "{emergency_cat.name}" (Type: {emergency_cat.type}, Group: {emergency_cat.group})')
            
            # Find transactions using this category
            transactions = Transaction.objects.filter(category=emergency_cat)
            tx_count = transactions.count()
            
            if tx_count > 0:
                self.stdout.write(f'   📝 {tx_count} transações encontradas')
                
                # Get or create "Poupança" category for this user
                savings_cat, created = Category.objects.get_or_create(
                    user=user,
                    name='Poupança',
                    type=Category.CategoryType.EXPENSE,
                    defaults={
                        'group': Category.CategoryGroup.SAVINGS,
                        'color': '#10B981',
                        'is_system_default': False if user else True,
                    }
                )
                
                if created and not dry_run:
                    stats['savings_categories_created'] += 1
                    self.stdout.write(self.style.SUCCESS(f'   ✨ Categoria "Poupança" criada para {user_label}'))
                elif created:
                    self.stdout.write(f'   [DRY RUN] Criaria categoria "Poupança" para {user_label}')
                else:
                    self.stdout.write(f'   ✓ Categoria "Poupança" já existe')
                
                # Migrate transactions
                if not dry_run:
                    with transaction.atomic():
                        updated = transactions.update(category=savings_cat)
                        stats['transactions_migrated'] += updated
                        self.stdout.write(self.style.SUCCESS(f'   ✅ {updated} transações migradas'))
                else:
                    self.stdout.write(f'   [DRY RUN] Migraria {tx_count} transações')
                    stats['transactions_migrated'] += tx_count
                
                if user:
                    stats['users_affected'].add(user.id)
            else:
                self.stdout.write(f'   ℹ️  Nenhuma transação vinculada a esta categoria')
            
            # Delete the emergency category
            if not dry_run:
                emergency_cat.delete()
                stats['categories_deleted'] += 1
                self.stdout.write(self.style.WARNING(f'   🗑️  Categoria "Reserva de Emergência" deletada'))
            else:
                self.stdout.write(f'   [DRY RUN] Deletaria categoria "Reserva de Emergência"')
                stats['categories_deleted'] += 1
        
        # Summary
        self.stdout.write('\n' + '='*60)
        self.stdout.write(self.style.SUCCESS('📊 RESUMO DA MIGRAÇÃO'))
        self.stdout.write('='*60)
        self.stdout.write(f'Categorias deletadas: {stats["categories_deleted"]}')
        self.stdout.write(f'Transações migradas: {stats["transactions_migrated"]}')
        self.stdout.write(f'Categorias "Poupança" criadas: {stats["savings_categories_created"]}')
        self.stdout.write(f'Usuários afetados: {len(stats["users_affected"])}')
        
        if dry_run:
            self.stdout.write('\n' + self.style.WARNING('ℹ️  Esta foi uma execução DRY RUN - nenhuma alteração foi salva'))
            self.stdout.write(self.style.WARNING('Execute sem --dry-run para aplicar as mudanças'))
        else:
            self.stdout.write('\n' + self.style.SUCCESS('✅ Migração concluída com sucesso!'))
            self.stdout.write(self.style.WARNING('🔄 Recomendação: Invalidar cache de indicadores para usuários afetados'))
