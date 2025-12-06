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
            user=self.user, name="Savings", type=Category.CategoryType.EXPENSE,
            group=Category.CategoryGroup.SAVINGS
        )

    def test_indicators_last_30_days_window(self):
        today = timezone.now().date()
        old_date = today - timedelta(days=40)
        recent_date = today - timedelta(days=5)

        Transaction.objects.create(
            user=self.user, amount=Decimal("5000"), type=Transaction.TransactionType.INCOME,
            date=old_date, category=self.cat_income, description="Old Salary"
        )
        Transaction.objects.create(
            user=self.user, amount=Decimal("3000"), type=Transaction.TransactionType.INCOME,
            date=recent_date, category=self.cat_income, description="Recent Salary"
        )

        Transaction.objects.create(
            user=self.user, amount=Decimal("1000"), type=Transaction.TransactionType.EXPENSE,
            date=old_date, category=self.cat_expense, description="Old Food"
        )
        Transaction.objects.create(
            user=self.user, amount=Decimal("500"), type=Transaction.TransactionType.EXPENSE,
            date=recent_date, category=self.cat_expense, description="Recent Food"
        )

        Transaction.objects.create(
            user=self.user, amount=Decimal("1200"), type=Transaction.TransactionType.EXPENSE,
            date=old_date, category=self.cat_essential, description="Old Rent"
        )
        Transaction.objects.create(
            user=self.user, amount=Decimal("800"), type=Transaction.TransactionType.EXPENSE,
            date=recent_date, category=self.cat_essential, description="Recent Rent"
        )

        Transaction.objects.create(
            user=self.user, amount=Decimal("1000"), type=Transaction.TransactionType.INCOME,
            date=old_date, category=self.cat_savings, description="Old Savings Deposit"
        )
        
        invalidate_indicators_cache(self.user)
        summary = calculate_summary(self.user)
        
        
        self.assertEqual(summary['total_income'], Decimal("3000.00"))
        
        self.assertEqual(summary['total_expense'], Decimal("1300.00"))
        
        self.assertEqual(summary['tps'], Decimal("56.67"))
        
        self.assertEqual(summary['ili'], Decimal("1.25"))

    def test_rdr_calculation(self):
        today = timezone.now().date()
        recent_date = today - timedelta(days=5)

        income = Transaction.objects.create(
            user=self.user, amount=Decimal("5000"), type=Transaction.TransactionType.INCOME,
            date=recent_date, category=self.cat_income, description="Salary"
        )

        bill = Transaction.objects.create(
            user=self.user, amount=Decimal("1000"), type=Transaction.TransactionType.EXPENSE,
            date=recent_date, category=self.cat_expense, description="Credit Card Bill"
        )
        
        TransactionLink.objects.create(
            user=self.user,
            source_transaction_uuid=income.id,
            target_transaction_uuid=bill.id,
            linked_amount=Decimal("1000"),
            link_type=TransactionLink.LinkType.EXPENSE_PAYMENT
        )

        invalidate_indicators_cache(self.user)
        summary = calculate_summary(self.user)

        self.assertEqual(summary['rdr'], Decimal("20.00"))
