"""
Script para corrigir categorias duplicadas de usuários.

Quando um usuário tem uma categoria com o mesmo nome de uma global,
migra as transações para a global e remove a duplicata do usuário.

Uso:
    python manage.py fix_user_duplicate_categories          # Dry-run
    python manage.py fix_user_duplicate_categories --execute  # Executa
    python manage.py fix_user_duplicate_categories --username=Marcos --execute  # Para um usuário específico
"""
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.db import transaction as db_transaction
from django.db.models import Q
from finance.models import Category, Transaction

User = get_user_model()


class Command(BaseCommand):
    help = 'Corrige categorias duplicadas de usuários migrando para globais'

    def add_arguments(self, parser):
        parser.add_argument(
            '--execute',
            action='store_true',
            help='Executa as correções (sem esta flag, apenas mostra o que seria feito)',
        )
        parser.add_argument(
            '--username',
            type=str,
            help='Username específico para corrigir (sem isso, corrige todos)',
        )

    def handle(self, *args, **options):
        execute = options['execute']
        username = options.get('username')
        
        if not execute:
            self.stdout.write(self.style.WARNING(
                '\n⚠️  MODO DRY-RUN: Nenhuma alteração será feita.\n'
                '   Use --execute para aplicar as correções.\n'
            ))
        
        # Determinar quais usuários processar
        if username:
            try:
                users = [User.objects.get(username=username)]
            except User.DoesNotExist:
                self.stdout.write(self.style.ERROR(f'Usuário "{username}" não encontrado'))
                return
        else:
            # Usuários que têm categorias próprias
            users = User.objects.filter(
                id__in=Category.objects.filter(user__isnull=False).values_list('user_id', flat=True).distinct()
            )
        
        total_migrated = 0
        total_removed = 0
        
        for user in users:
            result = self._fix_user_categories(user, execute)
            total_migrated += result['transactions']
            total_removed += result['categories']
        
        # Resumo
        self.stdout.write('\n' + '=' * 60)
        if execute:
            self.stdout.write(self.style.SUCCESS(
                f'✅ CONCLUÍDO!\n'
                f'   📝 {total_migrated} transações migradas\n'
                f'   🗑️  {total_removed} categorias duplicadas removidas'
            ))
        else:
            self.stdout.write(self.style.WARNING(
                f'📊 RESUMO DO DRY-RUN:\n'
                f'   📝 {total_migrated} transações SERIAM migradas\n'
                f'   🗑️  {total_removed} categorias SERIAM removidas\n\n'
                f'   Execute com --execute para aplicar.'
            ))
        self.stdout.write('=' * 60)

    def _fix_user_categories(self, user, execute):
        """Corrige categorias duplicadas de um usuário"""
        result = {'transactions': 0, 'categories': 0}
        
        # Pegar nomes das categorias globais
        global_cats = {
            (cat.name.lower(), cat.type): cat 
            for cat in Category.objects.filter(user__isnull=True)
        }
        
        # Pegar categorias do usuário
        user_cats = Category.objects.filter(user=user)
        
        duplicates = []
        for user_cat in user_cats:
            key = (user_cat.name.lower(), user_cat.type)
            if key in global_cats:
                duplicates.append((user_cat, global_cats[key]))
        
        if not duplicates:
            return result
        
        self.stdout.write(f'\n👤 Usuário: {user.username}')
        
        for user_cat, global_cat in duplicates:
            # Contar transações
            tx_count = Transaction.objects.filter(category=user_cat).count()
            
            self.stdout.write(f'   🔄 "{user_cat.name}" ({user_cat.type})')
            self.stdout.write(f'      User ID {user_cat.id} → Global ID {global_cat.id}')
            self.stdout.write(f'      📝 {tx_count} transações')
            
            if execute:
                with db_transaction.atomic():
                    # Migrar transações
                    if tx_count > 0:
                        Transaction.objects.filter(category=user_cat).update(category=global_cat)
                        self.stdout.write(self.style.SUCCESS(f'      ✅ Transações migradas'))
                    
                    # Remover categoria do usuário
                    user_cat.delete()
                    self.stdout.write(self.style.SUCCESS(f'      🗑️  Categoria removida'))
            
            result['transactions'] += tx_count
            result['categories'] += 1
        
        return result
