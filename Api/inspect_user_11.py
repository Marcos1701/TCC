
import os
import django
from decimal import Decimal
from django.db.models import Sum

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from finance.models import Transaction, Category
from finance.services.indicators import calculate_summary
from django.contrib.auth import get_user_model

User = get_user_model()

def inspect_user_11():
    try:
        user = User.objects.get(id=11)
        print(f"User found: {user.username} (ID: 11)")
    except User.DoesNotExist:
        print("User ID 11 not found.")
        return

    # 1. Inspect Savings Transactions
    print("\n--- Savings Transactions (Group: SAVINGS) ---")
    reserve_txs = Transaction.objects.filter(
        user=user, 
        category__group=Category.CategoryGroup.SAVINGS
    )
    
    reserve_deposits = Decimal("0")
    reserve_withdrawals = Decimal("0")
    
    for tx in reserve_txs:
        print(f"[{tx.date}] Type: {tx.type}, Amount: {tx.amount}, Desc: {tx.description}, Cat: {tx.category.name}")
        
        # Current Logic Simulation
        if tx.type == Transaction.TransactionType.INCOME:
            reserve_deposits += tx.amount
        elif tx.type == Transaction.TransactionType.EXPENSE:
            reserve_withdrawals += tx.amount

    print(f"\n--- Current Logic Calculation ---")
    print(f"Reserve Deposits (INCOME): {reserve_deposits}")
    print(f"Reserve Withdrawals (EXPENSE): {reserve_withdrawals}")
    print(f"Calculated Reserve Balance: {reserve_deposits - reserve_withdrawals}")
    
    # 2. Inspect Essential Expenses
    print("\n--- Essential Expenses (Last 30 Days) ---")
    # Using simple logic from calculate_summary
    from django.utils import timezone
    from datetime import timedelta
    
    today = timezone.now().date()
    start_date = today - timedelta(days=30)
    
    essential_expense = Transaction.objects.filter(
        user=user,
        category__group=Category.CategoryGroup.ESSENTIAL_EXPENSE,
        type=Transaction.TransactionType.EXPENSE,
        date__gte=start_date,
        date__lte=today,
    ).aggregate(total=Sum("amount"))["total"] or Decimal("0")
    
    print(f"Essential Expense (30d): {essential_expense}")
    
    # 3. Final ILI
    if essential_expense > 0:
        ili = (reserve_deposits - reserve_withdrawals) / essential_expense
        print(f"Calculated ILI: {ili}")
    else:
        print("Calculated ILI: Undefined (Essential Expense is 0)")

if __name__ == '__main__':
    inspect_user_11()
