"""
Testes para os novos validadores do sistema de missões (Sprint 2).

Testa os 8 novos validadores implementados:
- CategoryReductionValidator
- CategoryLimitValidator
- GoalProgressValidator
- GoalContributionValidator
- TransactionConsistencyValidator
- PaymentDisciplineValidator
- IndicatorMaintenanceValidator
- MultiCriteriaValidator
"""

from decimal import Decimal
from datetime import timedelta
from django.test import TestCase
from django.utils import timezone
from django.contrib.auth import get_user_model

from finance.models import (
    Mission,
    MissionProgress,
    Category,
    Goal,
    Transaction,
)
from finance.mission_types import (
    CategoryReductionValidator,
    CategoryLimitValidator,
    GoalProgressValidator,
    GoalContributionValidator,
    TransactionConsistencyValidator,
    PaymentDisciplineValidator,
    IndicatorMaintenanceValidator,
    MultiCriteriaValidator,
    MissionValidatorFactory,
)

User = get_user_model()


class CategoryReductionValidatorTest(TestCase):
    """Testes para CategoryReductionValidator."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        # UserProfile é criado automaticamente pelo signal
        
        # Get existing category (created by signal)
        self.category = Category.objects.get(
            user=self.user,
            name='Alimentação',
            type='EXPENSE'
        )
        
        self.mission = Mission.objects.create(
            title='Reduzir Alimentação',
            description='Reduzir gastos em 15%',
            mission_type='CATEGORY_REDUCTION',
            validation_type='CATEGORY_REDUCTION',
            target_category=self.category,
            target_reduction_percent=Decimal('15.00'),
            duration_days=30,
            reward_points=300
        )
        
        self.mission_progress = MissionProgress.objects.create(
            user=self.user,
            mission=self.mission,
            status=MissionProgress.Status.ACTIVE,
            started_at=timezone.now()
        )
    
    def test_reduction_achieved(self):
        """Testa quando a redução foi atingida."""
        # Período de referência (30 dias antes)
        reference_start = self.mission_progress.started_at - timedelta(days=30)
        
        # R$ 1000 no período de referência
        for i in range(10):
            Transaction.objects.create(
                user=self.user,
                category=self.category,
                type='EXPENSE',
                amount=Decimal('100.00'),
                date=(reference_start + timedelta(days=i)).date(),
                description=f'Gasto ref {i}'
            )
        
        # R$ 800 no período atual (20% de redução)
        for i in range(8):
            Transaction.objects.create(
                user=self.user,
                category=self.category,
                type='EXPENSE',
                amount=Decimal('100.00'),
                date=(self.mission_progress.started_at + timedelta(days=i)).date(),
                description=f'Gasto atual {i}'
            )
        
        validator = CategoryReductionValidator(
            self.mission,
            self.user,
            self.mission_progress
        )
        
        result = validator.calculate_progress()
        
        self.assertTrue(result['is_completed'])
        self.assertGreaterEqual(result['metrics']['reduction_percent'], 15)
        self.assertEqual(result['metrics']['category_name'], 'Alimentação')
    
    def test_reduction_not_achieved(self):
        """Testa quando a redução não foi atingida."""
        reference_start = self.mission_progress.started_at - timedelta(days=30)
        
        # R$ 1000 no período de referência
        for i in range(10):
            Transaction.objects.create(
                user=self.user,
                category=self.category,
                type='EXPENSE',
                amount=Decimal('100.00'),
                date=(reference_start + timedelta(days=i)).date(),
                description=f'Gasto ref {i}'
            )
        
        # R$ 950 no período atual (apenas 5% de redução)
        for i in range(19):
            Transaction.objects.create(
                user=self.user,
                category=self.category,
                type='EXPENSE',
                amount=Decimal('50.00'),
                date=(self.mission_progress.started_at + timedelta(days=i)).date(),
                description=f'Gasto atual {i}'
            )
        
        validator = CategoryReductionValidator(
            self.mission,
            self.user,
            self.mission_progress
        )
        
        result = validator.calculate_progress()
        
        self.assertFalse(result['is_completed'])
        self.assertLess(result['metrics']['reduction_percent'], 15)


class CategoryLimitValidatorTest(TestCase):
    """Testes para CategoryLimitValidator."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser2',
            email='test2@example.com',
            password='testpass123'
        )
        # UserProfile é criado automaticamente pelo signal
        
        # Get existing category (created by signal)
        self.category = Category.objects.get(
            user=self.user,
            name='Lazer',
            type='EXPENSE'
        )
        
        self.mission = Mission.objects.create(
            title='Limite de Lazer',
            description='Máximo R$ 500',
            mission_type='CATEGORY_SPENDING_LIMIT',
            validation_type='CATEGORY_LIMIT',
            target_category=self.category,
            category_spending_limit=Decimal('500.00'),
            duration_days=30,
            reward_points=250
        )
        
        self.mission_progress = MissionProgress.objects.create(
            user=self.user,
            mission=self.mission,
            status=MissionProgress.Status.ACTIVE,
            started_at=timezone.now() - timedelta(days=20)  # 20 dias atrás
        )
    
    def test_within_limit(self):
        """Testa quando está dentro do limite."""
        # R$ 400 gastos (dentro do limite de R$ 500)
        for i in range(4):
            Transaction.objects.create(
                user=self.user,
                category=self.category,
                type='EXPENSE',
                amount=Decimal('100.00'),
                date=(self.mission_progress.started_at + timedelta(days=i*5)).date(),
                description=f'Lazer {i}'
            )
        
        validator = CategoryLimitValidator(
            self.mission,
            self.user,
            self.mission_progress
        )
        
        result = validator.calculate_progress()
        
        self.assertFalse(result['metrics']['exceeded'])
        self.assertGreater(result['metrics']['remaining'], 0)
    
    def test_exceeded_limit(self):
        """Testa quando excedeu o limite."""
        # R$ 600 gastos (excedeu limite de R$ 500)
        for i in range(6):
            Transaction.objects.create(
                user=self.user,
                category=self.category,
                type='EXPENSE',
                amount=Decimal('100.00'),
                date=(self.mission_progress.started_at + timedelta(days=i*3)).date(),
                description=f'Lazer {i}'
            )
        
        validator = CategoryLimitValidator(
            self.mission,
            self.user,
            self.mission_progress
        )
        
        result = validator.calculate_progress()
        
        self.assertTrue(result['metrics']['exceeded'])
        self.assertEqual(result['progress_percentage'], 0)
        self.assertFalse(result['is_completed'])


class GoalProgressValidatorTest(TestCase):
    """Testes para GoalProgressValidator."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser3',
            email='test3@example.com',
            password='testpass123'
        )
        # UserProfile é criado automaticamente pelo signal
        
        self.goal = Goal.objects.create(
            user=self.user,
            title='Casa Própria',
            target_amount=Decimal('100000.00'),
            current_amount=Decimal('50000.00')  # 50% de progresso
        )
        
        self.mission = Mission.objects.create(
            title='Atingir 75% da Meta',
            description='Alcance 75% de progresso',
            mission_type='GOAL_ACHIEVEMENT',
            validation_type='GOAL_PROGRESS',
            target_goal=self.goal,
            goal_progress_target=Decimal('75.00'),
            duration_days=60,
            reward_points=500
        )
        
        self.mission_progress = MissionProgress.objects.create(
            user=self.user,
            mission=self.mission,
            status=MissionProgress.Status.ACTIVE,
            started_at=timezone.now()
        )
    
    def test_goal_progress_achieved(self):
        """Testa quando o progresso da meta foi atingido."""
        # Atualizar meta para 80% de progresso
        self.goal.current_amount = Decimal('80000.00')
        self.goal.save()
        
        validator = GoalProgressValidator(
            self.mission,
            self.user,
            self.mission_progress
        )
        
        result = validator.calculate_progress()
        
        self.assertTrue(result['is_completed'])
        self.assertGreaterEqual(result['metrics']['goal_progress'], 75)
        self.assertEqual(result['metrics']['goal_name'], 'Casa Própria')
    
    def test_goal_progress_not_achieved(self):
        """Testa quando o progresso ainda não foi atingido."""
        # Meta continua em 50%
        validator = GoalProgressValidator(
            self.mission,
            self.user,
            self.mission_progress
        )
        
        result = validator.calculate_progress()
        
        self.assertFalse(result['is_completed'])
        self.assertLess(result['metrics']['goal_progress'], 75)


class TransactionConsistencyValidatorTest(TestCase):
    """Testes para TransactionConsistencyValidator."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser4',
            email='test4@example.com',
            password='testpass123'
        )
        # UserProfile é criado automaticamente pelo signal
        
        self.mission = Mission.objects.create(
            title='Consistência Semanal',
            description='3 transações por semana durante 4 semanas',
            mission_type='INCOME_TRACKING',
            validation_type='TRANSACTION_CONSISTENCY',
            min_transaction_frequency=3,
            transaction_type_filter='ALL',
            duration_days=28,  # 4 semanas
            reward_points=350
        )
        
        self.mission_progress = MissionProgress.objects.create(
            user=self.user,
            mission=self.mission,
            status=MissionProgress.Status.ACTIVE,
            started_at=timezone.now() - timedelta(days=14)  # 2 semanas atrás
        )
    
    def test_consistency_achieved(self):
        """Testa quando a consistência foi mantida."""
        # Criar 4 transações por semana durante 2 semanas
        for week in range(2):
            for day in range(4):
                Transaction.objects.create(
                    user=self.user,
                    type=Transaction.TransactionType.EXPENSE,
                    amount=Decimal('50.00'),
                    date=(self.mission_progress.started_at + timedelta(days=week*7 + day)).date(),
                    description=f'Transação semana {week} dia {day}'
                )
        
        validator = TransactionConsistencyValidator(
            self.mission,
            self.user,
            self.mission_progress
        )
        
        result = validator.calculate_progress()
        
        self.assertGreaterEqual(result['metrics']['weeks_meeting_criteria'], 2)
        self.assertEqual(result['metrics']['min_frequency'], 3)


class MissionValidatorFactoryTest(TestCase):
    """Testes para MissionValidatorFactory."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='factorytest',
            email='factory@example.com',
            password='testpass123'
        )
        # UserProfile é criado automaticamente pelo signal
    
    def test_factory_creates_correct_validator(self):
        """Testa se o factory cria o validador correto para cada tipo."""
        mission = Mission.objects.create(
            title='Teste',
            description='Teste',
            mission_type='CATEGORY_REDUCTION',
            validation_type='CATEGORY_REDUCTION',
            duration_days=30,
            reward_points=100
        )
        
        mission_progress = MissionProgress.objects.create(
            user=self.user,
            mission=mission,
            status=MissionProgress.Status.ACTIVE,
            started_at=timezone.now()
        )
        
        validator = MissionValidatorFactory.create_validator(
            mission,
            self.user,
            mission_progress
        )
        
        self.assertIsInstance(validator, CategoryReductionValidator)
    
    def test_factory_fallback_to_multicriteria(self):
        """Testa se o factory usa MultiCriteriaValidator como fallback."""
        mission = Mission.objects.create(
            title='Teste Desconhecido',
            description='Teste',
            mission_type='UNKNOWN_TYPE',
            validation_type='UNKNOWN_VALIDATION',
            duration_days=30,
            reward_points=100
        )
        
        mission_progress = MissionProgress.objects.create(
            user=self.user,
            mission=mission,
            status=MissionProgress.Status.ACTIVE,
            started_at=timezone.now()
        )
        
        validator = MissionValidatorFactory.create_validator(
            mission,
            self.user,
            mission_progress
        )
        
        # Deve usar MultiCriteriaValidator como fallback
        self.assertIsInstance(validator, MultiCriteriaValidator)
