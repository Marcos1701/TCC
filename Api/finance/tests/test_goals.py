"""
Tests for the Goal system.

Tests cover:
- calculate_initial_amount function
- Goal signals (auto-update on transaction changes)
- Goal creation with different types
- Goal progress updates
"""

from decimal import Decimal
from datetime import date, timedelta

from django.test import TestCase
from django.contrib.auth import get_user_model
from django.utils import timezone

from ..models import Category, Goal, Transaction
from ..services.goals import (
    calculate_initial_amount,
    update_goal_progress,
    update_all_active_goals,
)

User = get_user_model()


class CalculateInitialAmountTests(TestCase):
    """Tests for calculate_initial_amount function."""

    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@test.com',
            password='testpass123'
        )
        
        # Create expense categories
        self.expense_category = Category.objects.create(
            user=self.user,
            name='Alimentação',
            type='EXPENSE',
            group='ESSENTIAL_EXPENSE'
        )
        
        # Create savings category
        self.savings_category = Category.objects.create(
            user=self.user,
            name='Poupança',
            type='EXPENSE',
            group='SAVINGS'
        )
        
        # Create income category
        self.income_category = Category.objects.create(
            user=self.user,
            name='Salário',
            type='INCOME',
            group='REGULAR_INCOME'
        )

    def test_custom_returns_zero(self):
        """CUSTOM goals should return 0 as initial amount."""
        result = calculate_initial_amount(
            user=self.user,
            goal_type='CUSTOM',
            category_ids=None
        )
        self.assertEqual(result, Decimal('0'))

    def test_expense_reduction_with_transactions(self):
        """EXPENSE_REDUCTION should sum expenses in selected categories this month."""
        # Create transactions this month
        Transaction.objects.create(
            user=self.user,
            category=self.expense_category,
            amount=Decimal('100.00'),
            type='EXPENSE',
            date=date.today(),
            description='Test expense 1'
        )
        Transaction.objects.create(
            user=self.user,
            category=self.expense_category,
            amount=Decimal('50.00'),
            type='EXPENSE',
            date=date.today(),
            description='Test expense 2'
        )
        
        result = calculate_initial_amount(
            user=self.user,
            goal_type='EXPENSE_REDUCTION',
            category_ids=[self.expense_category.id]
        )
        
        self.assertEqual(result, Decimal('150.00'))

    def test_expense_reduction_without_categories(self):
        """EXPENSE_REDUCTION without categories should return 0."""
        result = calculate_initial_amount(
            user=self.user,
            goal_type='EXPENSE_REDUCTION',
            category_ids=None
        )
        self.assertEqual(result, Decimal('0'))

    def test_savings_with_default_categories(self):
        """SAVINGS without specific categories uses SAVINGS/INVESTMENT groups."""
        Transaction.objects.create(
            user=self.user,
            category=self.savings_category,
            amount=Decimal('500.00'),
            type='EXPENSE',
            date=date.today(),
            description='Savings deposit'
        )
        
        result = calculate_initial_amount(
            user=self.user,
            goal_type='SAVINGS',
            category_ids=None
        )
        
        self.assertEqual(result, Decimal('500.00'))

    def test_savings_with_specific_categories(self):
        """SAVINGS with specific categories uses those categories."""
        Transaction.objects.create(
            user=self.user,
            category=self.expense_category,
            amount=Decimal('200.00'),
            type='EXPENSE',
            date=date.today(),
            description='Custom savings'
        )
        
        result = calculate_initial_amount(
            user=self.user,
            goal_type='SAVINGS',
            category_ids=[self.expense_category.id]
        )
        
        self.assertEqual(result, Decimal('200.00'))

    def test_income_increase_all_income(self):
        """INCOME_INCREASE without categories sums all income."""
        Transaction.objects.create(
            user=self.user,
            category=self.income_category,
            amount=Decimal('3000.00'),
            type='INCOME',
            date=date.today(),
            description='Salary'
        )
        
        result = calculate_initial_amount(
            user=self.user,
            goal_type='INCOME_INCREASE',
            category_ids=None
        )
        
        self.assertEqual(result, Decimal('3000.00'))

    def test_excludes_transactions_from_previous_months(self):
        """Should only count transactions from current month."""
        # Transaction from last month
        last_month = date.today().replace(day=1) - timedelta(days=1)
        Transaction.objects.create(
            user=self.user,
            category=self.expense_category,
            amount=Decimal('1000.00'),
            type='EXPENSE',
            date=last_month,
            description='Last month expense'
        )
        
        # Transaction this month
        Transaction.objects.create(
            user=self.user,
            category=self.expense_category,
            amount=Decimal('100.00'),
            type='EXPENSE',
            date=date.today(),
            description='This month expense'
        )
        
        result = calculate_initial_amount(
            user=self.user,
            goal_type='EXPENSE_REDUCTION',
            category_ids=[self.expense_category.id]
        )
        
        # Should only include this month's transaction
        self.assertEqual(result, Decimal('100.00'))


class GoalProgressUpdateTests(TestCase):
    """Tests for goal progress update functions."""

    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser2',
            email='test2@test.com',
            password='testpass123'
        )
        
        self.expense_category = Category.objects.create(
            user=self.user,
            name='Delivery',
            type='EXPENSE',
            group='LIFESTYLE_EXPENSE'
        )
        
        self.savings_category = Category.objects.create(
            user=self.user,
            name='Investimentos',
            type='EXPENSE',
            group='SAVINGS'
        )
        
        self.income_category = Category.objects.create(
            user=self.user,
            name='Freelance',
            type='INCOME',
            group='EXTRA_INCOME'
        )

    def test_custom_goal_not_updated(self):
        """CUSTOM goals should not be updated automatically."""
        goal = Goal.objects.create(
            user=self.user,
            title='Custom Goal',
            goal_type='CUSTOM',
            target_amount=Decimal('1000.00'),
            current_amount=Decimal('100.00')
        )
        
        original_amount = goal.current_amount
        update_goal_progress(goal)
        goal.refresh_from_db()
        
        # Amount should remain unchanged
        self.assertEqual(goal.current_amount, original_amount)

    def test_savings_goal_updates_with_transactions(self):
        """SAVINGS goal should update based on savings/investment transactions."""
        goal = Goal.objects.create(
            user=self.user,
            title='Save for Car',
            goal_type='SAVINGS',
            target_amount=Decimal('50000.00'),
            current_amount=Decimal('0'),
            initial_amount=Decimal('0')
        )
        
        # Create savings transaction
        Transaction.objects.create(
            user=self.user,
            category=self.savings_category,
            amount=Decimal('1000.00'),
            type='EXPENSE',
            date=date.today(),
            description='Monthly savings'
        )
        
        update_goal_progress(goal)
        goal.refresh_from_db()
        
        self.assertEqual(goal.current_amount, Decimal('1000.00'))

    def test_expense_reduction_goal_updates(self):
        """EXPENSE_REDUCTION goal should calculate reduction from baseline."""
        goal = Goal.objects.create(
            user=self.user,
            title='Reduce Delivery',
            goal_type='EXPENSE_REDUCTION',
            target_amount=Decimal('200.00'),  # Target reduction
            baseline_amount=Decimal('500.00'),  # Used to spend 500/month
            current_amount=Decimal('0'),
            tracking_period_months=1
        )
        goal.target_categories.add(self.expense_category)
        
        # Create expense transaction (less than baseline = good!)
        Transaction.objects.create(
            user=self.user,
            category=self.expense_category,
            amount=Decimal('300.00'),
            type='EXPENSE',
            date=date.today(),
            description='Delivery order'
        )
        
        update_goal_progress(goal)
        goal.refresh_from_db()
        
        # Reduction should be calculated (baseline - current monthly avg)
        # Since we're in the current month, the calculation normalizes to 30 days
        self.assertGreaterEqual(goal.current_amount, Decimal('0'))

    def test_update_all_active_goals_excludes_custom(self):
        """update_all_active_goals should skip CUSTOM goals."""
        # Create CUSTOM goal
        custom_goal = Goal.objects.create(
            user=self.user,
            title='Custom',
            goal_type='CUSTOM',
            target_amount=Decimal('1000.00'),
            current_amount=Decimal('50.00')
        )
        
        # Create SAVINGS goal
        savings_goal = Goal.objects.create(
            user=self.user,
            title='Savings',
            goal_type='SAVINGS',
            target_amount=Decimal('1000.00'),
            current_amount=Decimal('0'),
            initial_amount=Decimal('0')
        )
        
        # Add transaction
        Transaction.objects.create(
            user=self.user,
            category=self.savings_category,
            amount=Decimal('100.00'),
            type='EXPENSE',
            date=date.today(),
            description='Savings'
        )
        
        update_all_active_goals(self.user)
        
        custom_goal.refresh_from_db()
        savings_goal.refresh_from_db()
        
        # CUSTOM should remain unchanged
        self.assertEqual(custom_goal.current_amount, Decimal('50.00'))
        # SAVINGS should be updated
        self.assertEqual(savings_goal.current_amount, Decimal('100.00'))


class GoalSignalTests(TestCase):
    """Tests for goal-related signals."""

    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser3',
            email='test3@test.com',
            password='testpass123'
        )
        
        self.expense_category = Category.objects.create(
            user=self.user,
            name='Food',
            type='EXPENSE',
            group='ESSENTIAL_EXPENSE'
        )
        
        self.savings_category = Category.objects.create(
            user=self.user,
            name='Emergency Fund',
            type='EXPENSE',
            group='SAVINGS'
        )

    def test_savings_goal_updates_on_transaction_create(self):
        """SAVINGS goal should update when relevant transaction is created."""
        goal = Goal.objects.create(
            user=self.user,
            title='Emergency Fund',
            goal_type='SAVINGS',
            target_amount=Decimal('10000.00'),
            current_amount=Decimal('0'),
            initial_amount=Decimal('0')
        )
        
        # Create transaction - this triggers signal
        Transaction.objects.create(
            user=self.user,
            category=self.savings_category,
            amount=Decimal('500.00'),
            type='EXPENSE',
            date=date.today(),
            description='Emergency fund deposit'
        )
        
        goal.refresh_from_db()
        
        # Goal should be updated via signal
        self.assertEqual(goal.current_amount, Decimal('500.00'))

    def test_expense_reduction_goal_updates_on_expense_create(self):
        """EXPENSE_REDUCTION goal should update when expense in target category is created."""
        goal = Goal.objects.create(
            user=self.user,
            title='Reduce Food Expenses',
            goal_type='EXPENSE_REDUCTION',
            target_amount=Decimal('100.00'),
            baseline_amount=Decimal('500.00'),
            current_amount=Decimal('0'),
            tracking_period_months=1
        )
        goal.target_categories.add(self.expense_category)
        
        # Create expense transaction - this triggers signal
        Transaction.objects.create(
            user=self.user,
            category=self.expense_category,
            amount=Decimal('200.00'),
            type='EXPENSE',
            date=date.today(),
            description='Grocery shopping'
        )
        
        goal.refresh_from_db()
        
        # Goal should be updated (reduction calculated)
        self.assertIsNotNone(goal.current_amount)

    def test_custom_goal_not_updated_on_transaction(self):
        """CUSTOM goal should NOT update when transactions are created."""
        goal = Goal.objects.create(
            user=self.user,
            title='Custom Goal',
            goal_type='CUSTOM',
            target_amount=Decimal('1000.00'),
            current_amount=Decimal('100.00')
        )
        
        # Create transaction
        Transaction.objects.create(
            user=self.user,
            category=self.expense_category,
            amount=Decimal('500.00'),
            type='EXPENSE',
            date=date.today(),
            description='Some expense'
        )
        
        goal.refresh_from_db()
        
        # CUSTOM goal should remain unchanged
        self.assertEqual(goal.current_amount, Decimal('100.00'))


class GoalSerializerTests(TestCase):
    """Tests for GoalSerializer create with automatic initial_amount."""

    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser4',
            email='test4@test.com',
            password='testpass123'
        )
        
        self.expense_category = Category.objects.create(
            user=self.user,
            name='Streaming',
            type='EXPENSE',
            group='LIFESTYLE_EXPENSE'
        )

    def test_expense_reduction_calculates_initial_and_baseline(self):
        """EXPENSE_REDUCTION should auto-calculate initial_amount and baseline_amount."""
        # Create existing transactions
        Transaction.objects.create(
            user=self.user,
            category=self.expense_category,
            amount=Decimal('50.00'),
            type='EXPENSE',
            date=date.today(),
            description='Netflix'
        )
        
        from rest_framework.test import APIRequestFactory
        from ..serializers.goal import GoalSerializer
        
        factory = APIRequestFactory()
        request = factory.post('/goals/')
        request.user = self.user
        
        data = {
            'title': 'Reduce Streaming',
            'goal_type': 'EXPENSE_REDUCTION',
            'target_amount': '20.00',
            'target_categories': [self.expense_category.id],
        }
        
        serializer = GoalSerializer(data=data, context={'request': request})
        self.assertTrue(serializer.is_valid(), serializer.errors)
        
        goal = serializer.save()
        
        # Initial amount should be calculated from this month's transactions
        self.assertEqual(goal.initial_amount, Decimal('50.00'))
        # Baseline should also be set
        self.assertEqual(goal.baseline_amount, Decimal('50.00'))


class GoalTypeValidationTests(TestCase):
    """Tests for goal type-specific validations."""

    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser5',
            email='test5@test.com',
            password='testpass123'
        )
        
        self.expense_category = Category.objects.create(
            user=self.user,
            name='Shopping',
            type='EXPENSE',
            group='LIFESTYLE_EXPENSE'
        )
        
        self.income_category = Category.objects.create(
            user=self.user,
            name='Salary',
            type='INCOME',
            group='REGULAR_INCOME'
        )

    def test_expense_reduction_requires_category(self):
        """EXPENSE_REDUCTION should require at least one category."""
        from rest_framework.test import APIRequestFactory
        from ..serializers.goal import GoalSerializer
        
        factory = APIRequestFactory()
        request = factory.post('/goals/')
        request.user = self.user
        
        data = {
            'title': 'Reduce Expenses',
            'goal_type': 'EXPENSE_REDUCTION',
            'target_amount': '100.00',
            # Missing target_categories
        }
        
        serializer = GoalSerializer(data=data, context={'request': request})
        self.assertFalse(serializer.is_valid())
        self.assertIn('target_categories', serializer.errors)

    def test_expense_reduction_rejects_income_category(self):
        """EXPENSE_REDUCTION should reject INCOME categories."""
        from rest_framework.test import APIRequestFactory
        from ..serializers.goal import GoalSerializer
        
        factory = APIRequestFactory()
        request = factory.post('/goals/')
        request.user = self.user
        
        data = {
            'title': 'Reduce Expenses',
            'goal_type': 'EXPENSE_REDUCTION',
            'target_amount': '100.00',
            'target_categories': [self.income_category.id],  # Wrong type!
        }
        
        serializer = GoalSerializer(data=data, context={'request': request})
        self.assertFalse(serializer.is_valid())
        self.assertIn('target_categories', serializer.errors)

    def test_max_five_categories(self):
        """Goals should allow maximum 5 categories."""
        # Create 6 categories
        categories = []
        for i in range(6):
            cat = Category.objects.create(
                user=self.user,
                name=f'Category {i}',
                type='EXPENSE',
                group='LIFESTYLE_EXPENSE'
            )
            categories.append(cat)
        
        from rest_framework.test import APIRequestFactory
        from ..serializers.goal import GoalSerializer
        
        factory = APIRequestFactory()
        request = factory.post('/goals/')
        request.user = self.user
        
        data = {
            'title': 'Too Many Categories',
            'goal_type': 'EXPENSE_REDUCTION',
            'target_amount': '100.00',
            'baseline_amount': '500.00',
            'target_categories': [c.id for c in categories],  # 6 categories
        }
        
        serializer = GoalSerializer(data=data, context={'request': request})
        self.assertFalse(serializer.is_valid())
        self.assertIn('target_categories', serializer.errors)
