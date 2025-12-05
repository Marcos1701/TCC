from decimal import Decimal
from datetime import timedelta
from django.test import TestCase
from django.utils import timezone
from django.contrib.auth import get_user_model
from finance.models import Transaction, Category, UserProfile, TransactionLink
from finance.services.indicators import calculate_summary, invalidate_indicators_cache

User = get_user_model()

class IndicatorsTest(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='password123',
            first_name='Test User'
        )
        self.profile, _ = UserProfile.objects.get_or_create(user=self.user)
        
        # Categories
        self.cat_income = Category.objects.create(
            user=self.user, name="Salary", type=Category.CategoryType.INCOME
        )
        self.cat_expense = Category.objects.create(
            user=self.user, name="Food", type=Category.CategoryType.EXPENSE
        )
        self.cat_essential = Category.objects.create(
            user=self.user, name="Rent", type=Category.CategoryType.EXPENSE,
            group=Category.CategoryGroup.ESSENTIAL_EXPENSE
        )
        self.cat_savings = Category.objects.create(
            user=self.user, name="Savings", type=Category.CategoryType.EXPENSE, # Treated as transfer/expense in system usually
            group=Category.CategoryGroup.SAVINGS
        )

    def test_indicators_last_30_days_window(self):
        """
        Verify that indicators only consider transactions from the last 30 days.
        """
        today = timezone.now().date()
        old_date = today - timedelta(days=40) # Outside 30 days
        recent_date = today - timedelta(days=5) # Inside 30 days

        # 1. Income
        # Old income (should be ignored)
        Transaction.objects.create(
            user=self.user, amount=Decimal("5000"), type=Transaction.TransactionType.INCOME,
            date=old_date, category=self.cat_income, description="Old Salary"
        )
        # Recent income (should be counted)
        Transaction.objects.create(
            user=self.user, amount=Decimal("3000"), type=Transaction.TransactionType.INCOME,
            date=recent_date, category=self.cat_income, description="Recent Salary"
        )

        # 2. Expense
        # Old expense (should be ignored)
        Transaction.objects.create(
            user=self.user, amount=Decimal("1000"), type=Transaction.TransactionType.EXPENSE,
            date=old_date, category=self.cat_expense, description="Old Food"
        )
        # Recent expense (should be counted)
        Transaction.objects.create(
            user=self.user, amount=Decimal("500"), type=Transaction.TransactionType.EXPENSE,
            date=recent_date, category=self.cat_expense, description="Recent Food"
        )

        # 3. Essential Expense (for ILI)
        # Old essential (should be ignored)
        Transaction.objects.create(
            user=self.user, amount=Decimal("1200"), type=Transaction.TransactionType.EXPENSE,
            date=old_date, category=self.cat_essential, description="Old Rent"
        )
        # Recent essential (should be counted)
        Transaction.objects.create(
            user=self.user, amount=Decimal("800"), type=Transaction.TransactionType.EXPENSE,
            date=recent_date, category=self.cat_essential, description="Recent Rent"
        )

        # 4. Savings (Reserve) - Cumulative (Lifetime)
        # Savings are usually cumulative, so date shouldn't matter for the NUMERATOR of ILI (Reserve Balance)
        # But let's verify logic. Usually reserve is balance of SAVINGS group.
        Transaction.objects.create(
            user=self.user, amount=Decimal("1000"), type=Transaction.TransactionType.INCOME,
            date=old_date, category=self.cat_savings, description="Old Savings Deposit"
        )
        
        # Recalculate
        invalidate_indicators_cache(self.user)
        summary = calculate_summary(self.user)
        
        # Assertions
        
        # Total Income (Last 30 Days) -> Should be 3000
        self.assertEqual(summary['total_income'], Decimal("3000.00"))
        
        # Total Expense (Last 30 Days) -> Should be 500 + 800 = 1300
        self.assertEqual(summary['total_expense'], Decimal("1300.00"))
        
        # TPS = (Income - Expense) / Income = (3000 - 1300) / 3000 = 1700 / 3000 = 56.67%
        self.assertEqual(summary['tps'], Decimal("56.67"))
        
        # ILI = Reserve / Essential Expenses (Last 30 Days)
        # Reserve = 1000 (Lifetime)
        # Essential (Last 30 Days) = 800
        # ILI = 1000 / 800 = 1.25
        self.assertEqual(summary['ili'], Decimal("1.25"))

    def test_rdr_calculation(self):
        """
        Verify RDR uses debt payments from the last 30 days.
        """
        today = timezone.now().date()
        recent_date = today - timedelta(days=5)

        # Income: 5000 (Source of payment)
        income = Transaction.objects.create(
            user=self.user, amount=Decimal("5000"), type=Transaction.TransactionType.INCOME,
            date=recent_date, category=self.cat_income, description="Salary"
        )

        # Debt (Expense) - e.g. Credit Card Bill
        bill = Transaction.objects.create(
            user=self.user, amount=Decimal("1000"), type=Transaction.TransactionType.EXPENSE,
            date=recent_date, category=self.cat_expense, description="Credit Card Bill"
        )
        
        # Link Income -> Expense (Payment)
        TransactionLink.objects.create(
            user=self.user,
            source_transaction_uuid=income.id,
            target_transaction_uuid=bill.id,
            linked_amount=Decimal("1000"),
            link_type=TransactionLink.LinkType.EXPENSE_PAYMENT
        )

        invalidate_indicators_cache(self.user)
        summary = calculate_summary(self.user)

        # RDR = Debt Payments / Income = 1000 / 5000 = 20.00%
        self.assertEqual(summary['rdr'], Decimal("20.00"))
