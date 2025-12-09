
import os
import django
from decimal import Decimal

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from finance.services.indicators import calculate_summary, invalidate_indicators_cache
from django.contrib.auth import get_user_model

User = get_user_model()

def verify_fix():
    try:
        user = User.objects.get(id=11)
        print(f"User: {user.username} (ID: 11)")
        
        # Invalidate cache to force recalculation with NEW logic
        invalidate_indicators_cache(user)
        
        summary = calculate_summary(user)
        
        print("\n--- New Calculation Results ---")
        print(f"TPS: {summary['tps']}%")
        print(f"RDR: {summary['rdr']}%")
        print(f"ILI: {summary['ili']}")
        
        if summary['ili'] > 0:
            print("\n[SUCCESS] ILI is positive.")
        else:
            print("\n[FAIL] ILI is still non-positive.")
            
    except User.DoesNotExist:
        print("User 11 not found")

if __name__ == '__main__':
    verify_fix()
