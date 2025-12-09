
import os
import django
from decimal import Decimal

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from finance.models import Transaction, Category
from django.contrib.auth import get_user_model

User = get_user_model()

def inspect_essential_expenses():
    try:
        user = User.objects.get(id=11)
        print(f"User: {user.username} (ID: 11)")
        
        ess_cat_group = Category.CategoryGroup.ESSENTIAL_EXPENSE
        
        print(f"\n--- Checking transactions in CategoryGroup: {ess_cat_group} ---")
        
        txs = Transaction.objects.filter(
            user=user,
            category__group=ess_cat_group,
            type=Transaction.TransactionType.EXPENSE
        )
        
        total = Decimal("0")
        for tx in txs:
            print(f"- Amount: {tx.amount} | Desc: {tx.description} | Cat: {tx.category.name}")
            total += tx.amount
            
        print(f"\nTotal Essential Expenses: {total}")
        
    except User.DoesNotExist:
        print("User 11 not found")

if __name__ == '__main__':
    inspect_essential_expenses()
