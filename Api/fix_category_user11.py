
import os
import django
from decimal import Decimal

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from finance.models import Transaction, Category
from django.contrib.auth import get_user_model

User = get_user_model()

def fix_transaction_category():
    user = User.objects.get(id=11)
    
    # 1. Update the category of the "Fatua" to NOT be Essential
    # We can create a new category or use an existing one that is NOT Essential (e.g. OTHER or LIFESTYLE or just generic EXPENSE)
    # The text puts debts in "Pagamentos de Dívidas", which are separate.
    # In the system, debts often don't have a specific "DEBT" group, but they must NOT be ESSENTIAL for ILI.
    
    # Let's verify existing categories for the user or default
    # Or just update the existing category group if it's specific to this transaction?
    
    # Find the transaction
    try:
        tx = Transaction.objects.get(
            user=user, 
            amount=Decimal('900.00'), 
            description__icontains='cartão'
        )
        print(f"Found transaction: {tx.description} ({tx.amount}) - Cat: {tx.category.name} ({tx.category.group})")
        
        # Check if the category is used by verified essentials
        # If the category is "Despesas Essenciais" generic, we shouldn't change the GROUP of the category, but change the CATEGORY of the transaction.
        
        # Let's create specific categories if they match the text
        # The text implies:
        # - Aluguel (Essential)
        # - Alimentação (Essential)
        # - Transporte (Essential)
        # - Contas de Consumo / Lazer (Non-essential)
        # - Dívidas (Non-essential for ILI context?)
        
        # Creating a specific category for "Pagamento de Dívidas" (Group: OTHER or maybe user defined)
        # We need a group that is NOT SAVINGS and NOT ESSENTIAL.
        # "OTHER" works.
        
        debt_cat, _ = Category.objects.get_or_create(
            user=user,
            name="Pagamento de Dívidas",
            type=Category.CategoryType.EXPENSE,
            defaults={'group': Category.CategoryGroup.OTHER, 'color': '#555555'}
        )
        
        tx.category = debt_cat
        tx.save()
        print(f"Updated transaction category to: {debt_cat.name} (Group: {debt_cat.group})")
        
    except Transaction.DoesNotExist:
        print("Transaction 900.00 not found")
    except Transaction.MultipleObjectsReturned:
        print("Multiple 900.00 transactions found")


if __name__ == '__main__':
    fix_transaction_category()
