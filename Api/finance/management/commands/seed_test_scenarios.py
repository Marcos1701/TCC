from datetime import timedelta
from decimal import Decimal
import random

from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils import timezone
from finance.models import Transaction, Category
from finance.services import calculate_summary, invalidate_indicators_cache

User = get_user_model()

class Command(BaseCommand):
    help = 'Cria 3 cenários de teste: Usuário Crítico, Médio e Ótimo com histórico de 3 meses'

    def handle(self, *args, **kwargs):
        self.stdout.write('Criando cenários de teste...')

        # Data base: hoje
        today = timezone.now().date()
        
        # 1. Criação dos Usuários
        users_data = [
            {
                'username': 'teste1', 
                'email': 'teste1@gmail.com', 
                'profile_type': 'CRITICO',
                'income': 2500,
                'expense_ratio': 1.2  # Gasta 20% a mais do que ganha
            },
            {
                'username': 'teste2', 
                'email': 'teste2@gmail.com', 
                'profile_type': 'MEDIO',
                'income': 5000,
                'expense_ratio': 0.85 # Gasta 85% do que ganha (poupa pouco)
            },
            {
                'username': 'teste3', 
                'email': 'teste3@gmail.com', 
                'profile_type': 'OTIMO',
                'income': 12000,
                'expense_ratio': 0.4  # Gasta só 40% (poupa muito)
            },
        ]

        # Criar categorias padrão se não existirem
        self._ensure_categories()

        for u_data in users_data:
            user = self._create_user(u_data['username'], u_data['email'])
            self.stdout.write(f'Gerando dados para {u_data["username"]} ({u_data["profile_type"]})...')
            
            # Gerar histórico de 3 meses
            for i in range(3):
                month_date = today - timedelta(days=30 * (2 - i)) # 2 meses atrás, 1 mês atrás, atual
                self._generate_monthly_data(user, month_date, u_data)
            
            # Recalcular indicadores
            invalidate_indicators_cache(user)
            calculate_summary(user)

        self.stdout.write(self.style.SUCCESS('Cenários criados com sucesso! Senha padrão: teste'))

    def _create_user(self, username, email):
        user, created = User.objects.get_or_create(username=username, email=email)
        user.set_password('teste1234')
        user.save()
        if created:
            self.stdout.write(f'- Usuário {username} criado.')
        else:
            self.stdout.write(f'- Usuário {username} já existia (dados serão adicionados).')
        return user

    def _ensure_categories(self):
        # Busca ou cria categorias básicas para o script
        # Usa filter().first() para evitar erro de múltiplos objetos
        cats = [
            ('Salário', 'INCOME'),
            ('Aluguel', 'EXPENSE'),
            ('Mercado', 'EXPENSE'),
            ('Lazer', 'EXPENSE'),
            ('Dívida Cartão', 'EXPENSE'),
        ]
        for name, type_ in cats:
            if not Category.objects.filter(name=name, type=type_).exists():
                Category.objects.create(name=name, type=type_)

    def _generate_monthly_data(self, user, date_ref, user_data):
        # 1. Receita (Salário)
        salario_cat = Category.objects.filter(type='INCOME', name='Salário').first()
        Transaction.objects.create(
            user=user,
            description='Salário Mensal',
            amount=Decimal(user_data['income']),
            date=date_ref.replace(day=5),
            type='INCOME',
            category=salario_cat
        )

        # 2. Despesas
        total_expense = Decimal(user_data['income']) * Decimal(user_data['expense_ratio'])
        
        if user_data['profile_type'] == 'CRITICO':
            self._create_expense(user, 'Aluguel', total_expense * Decimal('0.4'), date_ref.replace(day=10))
            self._create_expense(user, 'Mercado', total_expense * Decimal('0.3'), date_ref.replace(day=15))
            self._create_expense(user, 'Dívida Cartão', total_expense * Decimal('0.3'), date_ref.replace(day=20))
            
        elif user_data['profile_type'] == 'MEDIO':
            self._create_expense(user, 'Aluguel', total_expense * Decimal('0.3'), date_ref.replace(day=10))
            self._create_expense(user, 'Mercado', total_expense * Decimal('0.3'), date_ref.replace(day=15))
            self._create_expense(user, 'Lazer', total_expense * Decimal('0.4'), date_ref.replace(day=20))

        elif user_data['profile_type'] == 'OTIMO':
            self._create_expense(user, 'Aluguel', total_expense * Decimal('0.5'), date_ref.replace(day=10))
            self._create_expense(user, 'Mercado', total_expense * Decimal('0.3'), date_ref.replace(day=15))
            self._create_expense(user, 'Lazer', total_expense * Decimal('0.2'), date_ref.replace(day=25))

    def _create_expense(self, user, cat_name, amount, date):
        cat = Category.objects.filter(type='EXPENSE', name=cat_name).first()
        if not cat:
            cat = Category.objects.filter(type='EXPENSE').first()
            
        Transaction.objects.create(
            user=user,
            description=f'Pgto {cat_name}',
            amount=amount,
            date=date,
            type='EXPENSE',
            category=cat
        )
