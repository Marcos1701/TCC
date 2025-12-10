"""
Comando para criar um único usuário de teste com perfil financeiro customizável,
simulando transações, missões concluídas e XP adequado ao perfil.

Uso:
    python manage.py seed_single_user --email usuario@email.com --username usuario --name "Nome Usuario" --password senha123 --profile medio
    
Perfis disponíveis:
    - critico: Situação financeira crítica (RDR alto, TPS negativo, ILI baixo)
    - medio: Situação financeira intermediária (RDR ok, TPS moderado, ILI médio)
    - otimo: Situação financeira ótima (RDR baixo, TPS alto, ILI alto)
"""

from datetime import timedelta
from decimal import Decimal
import random

from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils import timezone
from finance.models import (
    Transaction, Category, TransactionLink, 
    Mission, MissionProgress, UserProfile
)
from finance.models.admin import XPTransaction
from finance.services import calculate_summary, invalidate_indicators_cache
from finance.services.base import _xp_threshold

User = get_user_model()


# Definição dos perfis financeiros
PROFILE_DEFINITIONS = {
    'critico': {
        'profile_type': 'CRITICO',
        'description': 'Situação financeira crítica',
        'income': 3000,
        'reserve_months': 0.1,  # Quase sem reserva
        'debt_ratio': 0.6,     # 60% da renda vai para dívida
        'expense_profile': {'essential': 0.7, 'lifestyle': 0.4},  # Gasta 110%
        'missions_completed': 2,  # Poucas missões concluídas
        'target_level': 2,
    },
    'medio': {
        'profile_type': 'MEDIO',
        'description': 'Situação financeira intermediária',
        'income': 7000,
        'reserve_months': 4,
        'debt_ratio': 0.25,
        'expense_profile': {'essential': 0.5, 'lifestyle': 0.35},  # Gasta 85%
        'missions_completed': 5,  # Quantidade moderada de missões
        'target_level': 5,
    },
    'otimo': {
        'profile_type': 'OTIMO',
        'description': 'Situação financeira ótima',
        'income': 15000,
        'reserve_months': 12,
        'debt_ratio': 0.0,
        'expense_profile': {'essential': 0.3, 'lifestyle': 0.3},  # Gasta 60%
        'missions_completed': 10,  # Muitas missões concluídas
        'target_level': 10,
    },
}


class Command(BaseCommand):
    help = 'Cria um único usuário de teste com perfil financeiro customizável, simulando transações, missões concluídas e XP'

    def add_arguments(self, parser):
        parser.add_argument(
            '--email',
            type=str,
            default='teste@example.com',
            help='Email do usuário'
        )
        parser.add_argument(
            '--username',
            type=str,
            default='testuser',
            help='Username do usuário'
        )
        parser.add_argument(
            '--name',
            type=str,
            default='Usuário Teste',
            help='Nome completo do usuário'
        )
        parser.add_argument(
            '--password',
            type=str,
            default='teste1234',
            help='Senha do usuário'
        )
        parser.add_argument(
            '--profile',
            type=str,
            choices=['critico', 'medio', 'otimo'],
            default='medio',
            help='Perfil financeiro do usuário (critico, medio, otimo). Padrão: medio'
        )
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Limpar dados existentes do usuário antes de criar novos'
        )

    def handle(self, *args, **options):
        email = options['email']
        username = options['username']
        name = options['name']
        password = options['password']
        profile_key = options['profile']
        clear_existing = options['clear']

        profile_data = PROFILE_DEFINITIONS[profile_key]

        self.stdout.write(f'\n🚀 Criando usuário de teste...')
        self.stdout.write(f'   Email: {email}')
        self.stdout.write(f'   Username: {username}')
        self.stdout.write(f'   Nome: {name}')
        self.stdout.write(f'   Perfil: {profile_data["profile_type"]} ({profile_data["description"]})')
        self.stdout.write('')

        # 1. Criar ou buscar usuário
        user = self._create_or_get_user(username, email, password, name)
        
        # 2. Limpar dados antigos se solicitado ou se o usuário já existe
        if clear_existing:
            self._clear_user_data(user)

        # 3. Garantir que categorias padrão existam
        self._ensure_categories()

        # 4. Gerar histórico de transações
        self.stdout.write('📊 Gerando histórico financeiro...')
        self._generate_financial_history(user, profile_data)

        # 5. Recalcular indicadores
        invalidate_indicators_cache(user)
        calculate_summary(user)
        self.stdout.write(self.style.SUCCESS('   ✅ Indicadores financeiros calculados'))

        # 6. Simular missões concluídas e XP
        self.stdout.write('\n🎯 Simulando missões e XP...')
        self._simulate_missions_and_xp(user, profile_data)

        # 7. Verificar perfil do usuário
        profile = UserProfile.objects.get(user=user)
        
        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS('='*50))
        self.stdout.write(self.style.SUCCESS('✅ Usuário criado com sucesso!'))
        self.stdout.write(self.style.SUCCESS('='*50))
        self.stdout.write(f'   📧 Email: {email}')
        self.stdout.write(f'   👤 Username: {username}')
        self.stdout.write(f'   🔑 Senha: {password}')
        self.stdout.write(f'   📈 Nível: {profile.level}')
        self.stdout.write(f'   ⭐ XP: {profile.experience_points}/{_xp_threshold(profile.level)}')
        self.stdout.write(f'   🎯 Missões concluídas: {MissionProgress.objects.filter(user=user, status=MissionProgress.Status.COMPLETED).count()}')
        self.stdout.write('')

    def _create_or_get_user(self, username, email, password, name):
        """Cria ou busca usuário existente"""
        try:
            user = User.objects.get(username=username)
            self.stdout.write(f'   ⚠️  Usuário "{username}" já existe - atualizando...')
            user.email = email
            user.set_password(password)
            user.first_name = name.split()[0] if name else ''
            user.last_name = ' '.join(name.split()[1:]) if name and len(name.split()) > 1 else ''
            user.save()
        except User.DoesNotExist:
            user = User.objects.create_user(
                username=username,
                email=email,
                password=password,
                first_name=name.split()[0] if name else '',
                last_name=' '.join(name.split()[1:]) if name and len(name.split()) > 1 else ''
            )
            self.stdout.write(self.style.SUCCESS(f'   ✅ Usuário "{username}" criado'))
        
        # Garantir que o UserProfile existe
        UserProfile.objects.get_or_create(user=user)
        
        return user

    def _clear_user_data(self, user):
        """Limpa dados existentes do usuário"""
        Transaction.objects.filter(user=user).delete()
        Category.objects.filter(user=user).delete()
        MissionProgress.objects.filter(user=user).delete()
        XPTransaction.objects.filter(user=user).delete()
        
        # Reset do perfil
        profile = UserProfile.objects.get(user=user)
        profile.level = 1
        profile.experience_points = 0
        profile.save()
        
        self.stdout.write('   🧹 Dados anteriores limpos')

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

    def _generate_financial_history(self, user, profile_data):
        """Gera histórico financeiro para o usuário"""
        today = timezone.now().date()
        income = Decimal(str(profile_data['income']))

        # 1. Criar reserva inicial (histórico antigo para contar no ILI)
        if profile_data['reserve_months'] > 0:
            est_essential = income * Decimal(str(profile_data['expense_profile']['essential']))
            reserve_amount = (est_essential * Decimal(str(profile_data['reserve_months']))).quantize(Decimal("0.01"))
            
            self._create_transaction(
                user=user,
                description='Saldo Inicial Investimentos',
                amount=reserve_amount,
                date=today - timedelta(days=120),
                type='INCOME',
                category_name='Resgate de Investimento',
                category_group='SAVINGS'
            )
            self.stdout.write(f'   💰 Reserva inicial: R$ {reserve_amount:,.2f}')

        # 2. Gerar histórico dos últimos 3 meses
        for i in range(3):
            month_date = today - timedelta(days=30 * (2 - i))
            month_date = month_date.replace(day=5)
            self._generate_monthly_data(user, month_date, profile_data)
        
        tx_count = Transaction.objects.filter(user=user).count()
        self.stdout.write(f'   📝 {tx_count} transações criadas (3 meses de histórico)')

    def _generate_monthly_data(self, user, date_ref, profile_data):
        """Gera dados de um mês"""
        income = Decimal(str(profile_data['income']))
        
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
        if profile_data['debt_ratio'] > 0:
            debt_amount = (income * Decimal(str(profile_data['debt_ratio']))).quantize(Decimal("0.01"))
            
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
                except Exception:
                    pass

        # 3. Despesas Essenciais
        essential_total = (income * Decimal(str(profile_data['expense_profile']['essential']))).quantize(Decimal("0.01"))
        self._create_transaction(user, 'Aluguel', (essential_total * Decimal('0.5')).quantize(Decimal("0.01")), date_ref + timedelta(days=5), 'EXPENSE', 'Aluguel', 'ESSENTIAL_EXPENSE')
        self._create_transaction(user, 'Supermercado', (essential_total * Decimal('0.3')).quantize(Decimal("0.01")), date_ref + timedelta(days=10), 'EXPENSE', 'Supermercado', 'ESSENTIAL_EXPENSE')
        self._create_transaction(user, 'Energia Elétrica', (essential_total * Decimal('0.2')).quantize(Decimal("0.01")), date_ref + timedelta(days=15), 'EXPENSE', 'Energia Elétrica', 'ESSENTIAL_EXPENSE')

        # 4. Despesas Estilo de Vida
        lifestyle_total = (income * Decimal(str(profile_data['expense_profile']['lifestyle']))).quantize(Decimal("0.01"))
        self._create_transaction(user, 'Jantar Fora', (lifestyle_total * Decimal('0.4')).quantize(Decimal("0.01")), date_ref + timedelta(days=12), 'EXPENSE', 'Restaurantes', 'LIFESTYLE_EXPENSE')
        self._create_transaction(user, 'Vestuário', (lifestyle_total * Decimal('0.6')).quantize(Decimal("0.01")), date_ref + timedelta(days=20), 'EXPENSE', 'Vestuário', 'LIFESTYLE_EXPENSE')

    def _create_transaction(self, user, description, amount, date, type, category_name, category_group):
        """Cria uma transação"""
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

    def _simulate_missions_and_xp(self, user, profile_data):
        """Simula missões concluídas e XP adequado ao perfil"""
        target_level = profile_data['target_level']
        missions_to_complete = profile_data['missions_completed']

        # 1. Buscar missões disponíveis
        available_missions = list(Mission.objects.filter(is_active=True).order_by('priority', 'difficulty')[:missions_to_complete + 3])
        
        if not available_missions:
            self.stdout.write('   ⚠️  Nenhuma missão disponível no sistema. Execute seed_default_missions primeiro.')
            return

        # 2. Completar missões de acordo com o perfil
        completed_count = 0
        total_xp_earned = 0

        for mission in available_missions[:missions_to_complete]:
            # Criar MissionProgress como completada
            progress, created = MissionProgress.objects.get_or_create(
                user=user,
                mission=mission,
                defaults={
                    'status': MissionProgress.Status.COMPLETED,
                    'progress': Decimal('100.00'),
                    'started_at': timezone.now() - timedelta(days=random.randint(7, 30)),
                    'completed_at': timezone.now() - timedelta(days=random.randint(1, 6)),
                }
            )
            
            if created:
                completed_count += 1
                total_xp_earned += mission.reward_points
                self.stdout.write(f'   ✅ Missão concluída: "{mission.title}" (+{mission.reward_points} XP)')
            else:
                # Atualizar para completada se já existia
                if progress.status != MissionProgress.Status.COMPLETED:
                    progress.status = MissionProgress.Status.COMPLETED
                    progress.progress = Decimal('100.00')
                    progress.completed_at = timezone.now() - timedelta(days=random.randint(1, 6))
                    progress.save()
                    completed_count += 1
                    total_xp_earned += mission.reward_points
                    self.stdout.write(f'   ✅ Missão atualizada: "{mission.title}" (+{mission.reward_points} XP)')

        # 3. Aplicar XP e nível ao perfil
        profile = UserProfile.objects.get(user=user)
        
        # Calcular XP necessário para o nível alvo
        xp_needed_for_level = sum(_xp_threshold(lvl) for lvl in range(1, target_level))
        
        # Adicionar XP parcial para o nível atual (entre 40-80% do threshold)
        current_level_threshold = _xp_threshold(target_level)
        partial_xp = int(current_level_threshold * random.uniform(0.4, 0.8))
        
        # Definir nível e XP
        profile.level = target_level
        profile.experience_points = partial_xp
        profile.is_first_access = False  # Marcar como não sendo primeiro acesso
        profile.save()

        self.stdout.write(f'   🎮 Nível configurado: {profile.level}')
        self.stdout.write(f'   ⭐ XP atual: {profile.experience_points}/{current_level_threshold}')

        # 4. Criar histórico de XP para missões completadas
        for progress in MissionProgress.objects.filter(user=user, status=MissionProgress.Status.COMPLETED):
            # Verificar se já existe XPTransaction para esta missão
            if not XPTransaction.objects.filter(user=user, mission_progress=progress).exists():
                XPTransaction.objects.create(
                    user=user,
                    mission_progress=progress,
                    points_awarded=progress.mission.reward_points,
                    level_before=max(1, profile.level - 1),
                    level_after=profile.level,
                    xp_before=0,
                    xp_after=profile.experience_points
                )

        self.stdout.write(self.style.SUCCESS(f'   ✅ {completed_count} missões concluídas simuladas'))
