from decimal import Decimal
from django.test import TestCase
from django.contrib.auth import get_user_model
from finance.models import Transaction, Category
from finance.payment_validator import PaymentValidator

User = get_user_model()


class PaymentValidatorTests(TestCase):
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            password='testpass123'
        )
        
        self.category_income = Category.objects.create(
            name='Salário',
            type=Category.CategoryType.INCOME,
            user=self.user
        )
        
        self.category_expense = Category.objects.create(
            name='Contas',
            type=Category.CategoryType.EXPENSE,
            user=self.user
        )
        
        self.income = Transaction.objects.create(
            user=self.user,
            category=self.category_income,
            type=Transaction.TransactionType.INCOME,
            description='Salário Março',
            amount=Decimal('5000.00'),
            date='2025-03-01'
        )
        
        self.expense = Transaction.objects.create(
            user=self.user,
            category=self.category_expense,
            type=Transaction.TransactionType.EXPENSE,
            description='Conta de Luz',
            amount=Decimal('200.00'),
            date='2025-03-05'
        )
    
    def test_valid_payment(self):
        validator = PaymentValidator(self.user)
        is_valid, errors = validator.validate_payment(
            self.income,
            self.expense,
            Decimal('200.00')
        )
        
        self.assertTrue(is_valid)
        self.assertEqual(len(errors), 0)
    
    def test_insufficient_balance(self):
        validator = PaymentValidator(self.user)
        is_valid, errors = validator.validate_payment(
            self.income,
            self.expense,
            Decimal('6000.00')
        )
        
        self.assertFalse(is_valid)
        self.assertIn('insufficient_balance', errors)
    
    def test_negative_amount(self):
        validator = PaymentValidator(self.user)
        is_valid, errors = validator.validate_payment(
            self.income,
            self.expense,
            Decimal('-100.00')
        )
        
        self.assertFalse(is_valid)
        self.assertIn('amount', errors)
    
    def test_wrong_transaction_types(self):
        validator = PaymentValidator(self.user)
        is_valid, errors = validator.validate_payment(
            self.expense,
            self.income,
            Decimal('100.00')
        )
        
        self.assertFalse(is_valid)
        self.assertIn('source_type', errors)
    
    def test_same_transaction(self):
        validator = PaymentValidator(self.user)
        is_valid, errors = validator.validate_payment(
            self.income,
            self.income,
            Decimal('100.00')
        )
        
        self.assertFalse(is_valid)
        self.assertIn('same_transaction', errors)
