
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
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        
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
        reference_start = self.mission_progress.started_at - timedelta(days=30)
        
        for i in range(10):
            Transaction.objects.create(
                user=self.user,
                category=self.category,
                type='EXPENSE',
                amount=Decimal('100.00'),
                date=(reference_start + timedelta(days=i)).date(),
                description=f'Gasto ref {i}'
            )
        
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
        reference_start = self.mission_progress.started_at - timedelta(days=30)
        
        for i in range(10):
            Transaction.objects.create(
                user=self.user,
                category=self.category,
                type='EXPENSE',
                amount=Decimal('100.00'),
                date=(reference_start + timedelta(days=i)).date(),
                description=f'Gasto ref {i}'
            )
        
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
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser2',
            email='test2@example.com',
            password='testpass123'
        )
        
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
            started_at=timezone.now() - timedelta(days=20)
        )
    
    def test_within_limit(self):
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
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser3',
            email='test3@example.com',
            password='testpass123'
        )
        
        self.goal = Goal.objects.create(
            user=self.user,
            title='Casa Própria',
            target_amount=Decimal('100000.00'),
            current_amount=Decimal('50000.00')
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
        validator = GoalProgressValidator(
            self.mission,
            self.user,
            self.mission_progress
        )
        
        result = validator.calculate_progress()
        
        self.assertFalse(result['is_completed'])
        self.assertLess(result['metrics']['goal_progress'], 75)


class TransactionConsistencyValidatorTest(TestCase):
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser4',
            email='test4@example.com',
            password='testpass123'
        )
        
        self.mission = Mission.objects.create(
            title='Consistência Semanal',
            description='3 transações por semana durante 4 semanas',
            mission_type='INCOME_TRACKING',
            validation_type='TRANSACTION_CONSISTENCY',
            min_transaction_frequency=3,
            transaction_type_filter='ALL',
            duration_days=28,
            reward_points=350
        )
        
        self.mission_progress = MissionProgress.objects.create(
            user=self.user,
            mission=self.mission,
            status=MissionProgress.Status.ACTIVE,
            started_at=timezone.now() - timedelta(days=14)
        )
    
    def test_consistency_achieved(self):
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
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='factorytest',
            email='factory@example.com',
            password='testpass123'
        )
    
    def test_factory_creates_correct_validator(self):
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
        
        self.assertIsInstance(validator, MultiCriteriaValidator)
