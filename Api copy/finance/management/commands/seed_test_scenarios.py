from datetime import timedelta
from decimal import Decimal
import random

from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils import timezone
from finance.models import Transaction, Category, TransactionLink
from finance.services import calculate_summary, invalidate_indicators_cache

User = get_user_model()

class Command(BaseCommand):
    help = 'Cria 3 cenários de teste: Usuário Crítico, Médio e Ótimo com histórico e indicadores realistas'

    def handle(self, *args, **kwargs):
        self.stdout.write('Criando cenários de teste...')

        today = timezone.now().date()
        
        # Definição dos perfis
        users_data = [
            {
                'username': 'teste1', 
                'email': 'teste1@gmail.com', 
                'profile_type': 'CRITICO', # RDR alto (>50%), TPS baixo/negativo, ILI baixo
                'income': 3000,
                'reserve_months': 0.1, # Quase sem reserva
                'debt_ratio': 0.6,    # 60% da renda vai para dívida
                'expense_profile': {'essential': 0.7, 'lifestyle': 0.4} # Gasta 110% do que ganha
            },
            {
                'username': 'teste2', 
                'email': 'teste2@gmail.com', 
                'profile_type': 'MEDIO',   # RDR ok (~20-30%), TPS ok (~10%), ILI ok (~3-4 meses)
                'income': 7000,
                'reserve_months': 4,
                'debt_ratio': 0.25,
                'expense_profile': {'essential': 0.5, 'lifestyle': 0.35} # Gasta 85%
            },
            {
                'username': 'teste3', 
                'email': 'teste3@gmail.com', 
                'profile_type': 'OTIMO',   # RDR baixo (0-5%), TPS alto (>30%), ILI alto (>12 meses)
                'income': 15000,
                'reserve_months': 12,
                'debt_ratio': 0.0,
                'expense_profile': {'essential': 0.3, 'lifestyle': 0.3} # Gasta 60%
            },
        ]

        self._ensure_categories()

        for u_data in users_data:
            user = self._create_user(u_data['username'], u_data['email'])
            self.stdout.write(f'Gerando dados para {u_data["username"]} ({u_data["profile_type"]})...')
            
            # Limpar dados antigos desse usuário para evitar duplicidade se rodar 2x
            Transaction.objects.filter(user=user).delete()
            Category.objects.filter(user=user).delete()

            # 1. Criar Reserva Inicial (Histórico antigo para contar no IL, mas não no TPS mensal)
            if u_data['reserve_months'] > 0:
                est_essential = Decimal(str(u_data['income'])) * Decimal(str(u_data['expense_profile']['essential']))
                reserve_amount = (est_essential * Decimal(str(u_data['reserve_months']))).quantize(Decimal("0.01"))
                
                self._create_transaction(
                    user=user,
                    description='Saldo Inicial Investimentos',
                    amount=reserve_amount,
                    date=today - timedelta(days=120),
                    type='INCOME',
                    category_name='Resgate de Investimento',
                    category_group='SAVINGS'
                )

            # 2. Gerar histórico recente (3 meses)
            for i in range(3):
                month_date = today - timedelta(days=30 * (2 - i))
                month_date = month_date.replace(day=5)
                self._generate_monthly_data(user, month_date, u_data)
            
            # Recalcular indicadores
            invalidate_indicators_cache(user)
            calculate_summary(user)

        self.stdout.write(self.style.SUCCESS('Cenários criados com sucesso! Senha padrão: teste1234'))

    def _create_user(self, username, email):
        user, created = User.objects.get_or_create(username=username, email=email)
        user.set_password('teste1234')
        user.save()
        return user

    def _ensure_categories(self):
        """Verifica se as categorias padrão existem. Não cria novas para evitar duplicatas.
        
        As categorias devem ser criadas via seed_default_categories.py
        """
        # Lista das categorias usadas por este script (nomes devem corresponder a seed_default_categories)
        required_categories = [
            ('Salário', 'INCOME'),
            ('Freelance', 'INCOME'),
            ('Rendimentos', 'INCOME'),
            ('Resgate de Investimento', 'INCOME'),
            ('Aluguel', 'EXPENSE'),
            ('Condomínio', 'EXPENSE'),
            ('Supermercado', 'EXPENSE'),
            ('Energia Elétrica', 'EXPENSE'),
            ('Transporte', 'EXPENSE'),
            ('Educação', 'EXPENSE'),
            ('Restaurantes', 'EXPENSE'),
            ('Lazer e Entretenimento', 'EXPENSE'),
            ('Vestuário', 'EXPENSE'),
            ('Pagamento de Empréstimo', 'EXPENSE'),
            ('Pagamento de Cartão', 'EXPENSE'),
        ]
        
        missing = []
        for name, type_ in required_categories:
            if not Category.objects.filter(name=name, type=type_, user__isnull=True).exists():
                missing.append(name)
        
        if missing:
            self.stdout.write(self.style.WARNING(
                f'⚠️  Categorias faltando: {missing}. Execute seed_default_categories primeiro.'
            ))

    def _generate_monthly_data(self, user, date_ref, user_data):
        income = Decimal(str(user_data['income']))
        
        # 1. Receita Principal
        salary_tx = self._create_transaction(
            user=user,
            description='Salário Mensal',
            amount=income,
            date=date_ref,
            type='INCOME',
            category_name='Salário',
            category_group='REGULAR_INCOME'
        )

        # 2. Despesa com Dívida (Para RDR)
        if user_data['debt_ratio'] > 0:
            debt_amount = (income * Decimal(str(user_data['debt_ratio']))).quantize(Decimal("0.01"))
            
            debt_tx = self._create_transaction(
                user=user,
                description='Pagamento de Empréstimo',
                amount=debt_amount,
                date=date_ref + timedelta(days=1),
                type='EXPENSE',
                category_name='Pagamento de Empréstimo',
                category_group='OTHER'
            )
            
            if debt_amount <= salary_tx.available_amount:
                try:
                    TransactionLink.objects.create(
                        user=user,
                        source_transaction_uuid=salary_tx.id,
                        target_transaction_uuid=debt_tx.id,
                        linked_amount=debt_amount,
                        link_type=TransactionLink.LinkType.EXPENSE_PAYMENT,
                        description='Pagamento mensal de dívida'
                    )
                except Exception as e:
                    self.stdout.write(self.style.ERROR(f"Erro ao criar link: {e}"))

        # 3. Despesas Essenciais
        essential_total = (income * Decimal(str(user_data['expense_profile']['essential']))).quantize(Decimal("0.01"))
        # Distribui
        self._create_transaction(user, 'Aluguel', (essential_total * Decimal('0.5')).quantize(Decimal("0.01")), date_ref + timedelta(days=5), 'EXPENSE', 'Aluguel', 'ESSENTIAL_EXPENSE')
        self._create_transaction(user, 'Supermercado', (essential_total * Decimal('0.3')).quantize(Decimal("0.01")), date_ref + timedelta(days=10), 'EXPENSE', 'Supermercado', 'ESSENTIAL_EXPENSE')
        self._create_transaction(user, 'Energia Elétrica', (essential_total * Decimal('0.2')).quantize(Decimal("0.01")), date_ref + timedelta(days=15), 'EXPENSE', 'Energia Elétrica', 'ESSENTIAL_EXPENSE')

        # 4. Despesas Estilo de Vida
        lifestyle_total = (income * Decimal(str(user_data['expense_profile']['lifestyle']))).quantize(Decimal("0.01"))
        self._create_transaction(user, 'Jantar Fora', (lifestyle_total * Decimal('0.4')).quantize(Decimal("0.01")), date_ref + timedelta(days=12), 'EXPENSE', 'Restaurantes', 'LIFESTYLE_EXPENSE')
        self._create_transaction(user, 'Vestuário', (lifestyle_total * Decimal('0.6')).quantize(Decimal("0.01")), date_ref + timedelta(days=20), 'EXPENSE', 'Vestuário', 'LIFESTYLE_EXPENSE')

    def _create_transaction(self, user, description, amount, date, type, category_name, category_group):
        cat = Category.objects.filter(name=category_name, type=type).first()
        if not cat:
            cat = Category.objects.filter(type=type).first()
        
        return Transaction.objects.create(
            user=user,
            description=description,
            amount=amount,
            date=date,
            type=type,
            category=cat
        )
