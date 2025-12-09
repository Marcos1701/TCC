
import os
import django
from decimal import Decimal
from datetime import timedelta
from django.utils import timezone

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from finance.models import Transaction, Category
from finance.services.indicators import calculate_summary
from django.contrib.auth import get_user_model

User = get_user_model()

def reproduce_ili_issue():
    # 1. Setup User and Categories
    user, _ = User.objects.get_or_create(username='ili_test_user', email='ili@test.com')
    
    # Ensure categories exist
    savings_cat, _ = Category.objects.get_or_create(
        user=user, 
        name='Minha Poupança', 
        type=Category.CategoryType.EXPENSE,
        defaults={'group': Category.CategoryGroup.SAVINGS, 'color': '#00FF00'}
    )
    # Ensure correct group setting if retrieved
    if savings_cat.group != Category.CategoryGroup.SAVINGS:
        savings_cat.group = Category.CategoryGroup.SAVINGS
        savings_cat.save()

    essential_cat, _ = Category.objects.get_or_create(
        user=user, 
        name='Aluguel', 
        type=Category.CategoryType.EXPENSE,
        defaults={'group': Category.CategoryGroup.ESSENTIAL_EXPENSE, 'color': '#FF0000'}
    )
    if essential_cat.group != Category.CategoryGroup.ESSENTIAL_EXPENSE:
        essential_cat.group = Category.CategoryGroup.ESSENTIAL_EXPENSE
        essential_cat.save()

    # Clear previous transactions
    Transaction.objects.filter(user=user).delete()
    
    today = timezone.now().date()
    
    # 2. Add Transactions (Similar to João's example)
    # Income (Salary)
    Transaction.objects.create(
        user=user,
        amount=Decimal('5000.00'),
        type=Transaction.TransactionType.INCOME,
        description='Salario',
        date=today
    )
    
    # Essential Expense (Rent) - To give denominator for ILI
    Transaction.objects.create(
        user=user,
        amount=Decimal('2300.00'),
        type=Transaction.TransactionType.EXPENSE,
        category=essential_cat,
        description='Aluguel',
        date=today
    )
    
    # Savings "Deposit" (User registers as Expense from checking account)
    # This is the key: Expense -> Savings
    Transaction.objects.create(
        user=user,
        amount=Decimal('6000.00'),
        type=Transaction.TransactionType.EXPENSE,
        category=savings_cat,
        description='Deposito Reserva',
        date=today
    )
    
    # 3. Calculate Indicators
    # Needs to invalidate cache first just in case
    # calculate_summary checks profile.should_recalculate_indicators()
    # We can force invalidation manually or creation triggers it?
    # Creation triggers invalidate_user_dashboard_cache, so it should be fine.
    
    summary = calculate_summary(user)
    
    print(f"--- ILI Check ---")
    print(f"TPS: {summary['tps']}%")
    print(f"RDR: {summary['rdr']}%")
    print(f"ILI: {summary['ili']}")
    print(f"Total Income: {summary['total_income']}")
    print(f"Total Expense: {summary['total_expense']}")

    # 4. Analysis
    ili = summary['ili']
    expected_ili = Decimal('6000') / Decimal('2300') # ~2.6
    
    if ili < 0:
        print(f"\n[FAIL] ILI is negative! ({ili})")
        print("Reason: Expense categorized as SAVINGS is treated as withdrawal (subtraction).")
    elif abs(ili - expected_ili) < Decimal('0.1'):
        print(f"\n[PASS] ILI is correct (~2.6).")
    else:
        print(f"\n[?] ILI is positive but unexpected value: {ili}")

if __name__ == '__main__':
    try:
        reproduce_ili_issue()
    except Exception as e:
        print(e)
