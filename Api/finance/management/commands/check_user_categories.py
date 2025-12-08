"""
Script para verificar categorias do usuário atual
"""
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from finance.models import Category

User = get_user_model()


class Command(BaseCommand):
    help = 'Lista categorias de um usuário específico'

    def add_arguments(self, parser):
        parser.add_argument('--username', type=str, help='Username do usuário')

    def handle(self, *args, **options):
        username = options.get('username')
        
        if username:
            try:
                user = User.objects.get(username=username)
            except User.DoesNotExist:
                self.stdout.write(self.style.ERROR(f'Usuário "{username}" não encontrado'))
                return
        else:
            # Listar todos os usuários
            users = User.objects.all()
            self.stdout.write(f'\n👥 USUÁRIOS NO SISTEMA: {users.count()}\n')
            for u in users:
                cat_count = Category.objects.filter(user=u).count()
                self.stdout.write(f'   - {u.username} ({u.email}) - {cat_count} categorias próprias')
            return
        
        self.stdout.write(f'\n📋 CATEGORIAS DO USUÁRIO: {user.username}\n')
        
        # Categorias próprias do usuário
        user_cats = Category.objects.filter(user=user).order_by('type', 'name')
        
        if user_cats.exists():
            self.stdout.write(f'\n🔵 Categorias PRÓPRIAS ({user_cats.count()}):')
            for cat in user_cats:
                color_status = f'🎨 {cat.color}' if cat.color else '⚪ sem cor'
                self.stdout.write(f'    ID {cat.id}: {cat.name} ({cat.type}) [{color_status}]')
        else:
            self.stdout.write('\n✅ Usuário não tem categorias próprias (usa apenas globais)')
        
        # Verificar se há duplicatas entre categorias do usuário e globais
        global_names = set(Category.objects.filter(user__isnull=True).values_list('name', 'type'))
        user_names = set(Category.objects.filter(user=user).values_list('name', 'type'))
        
        overlap = global_names & user_names
        if overlap:
            self.stdout.write(self.style.WARNING(f'\n⚠️ DUPLICATAS (usuário tem categorias com mesmo nome das globais):'))
            for name, type_ in overlap:
                self.stdout.write(self.style.WARNING(f'   - {name} ({type_})'))
        
        # Mostrar o que a API retornaria
        from django.db.models import Q
        api_result = Category.objects.filter(Q(user=user) | Q(user=None)).order_by('name')
        self.stdout.write(f'\n📡 API retornaria {api_result.count()} categorias para este usuário')
