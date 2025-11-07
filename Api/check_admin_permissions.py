"""
Script para verificar se o usuário tem permissões de admin.
"""
import os
import sys
import django

# Configurar Django
sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from finance.models import User

def check_admin_users():
    """Verifica usuários com permissões de admin."""
    
    print("=" * 60)
    print("VERIFICAÇÃO DE USUÁRIOS ADMIN")
    print("=" * 60)
    
    total_users = User.objects.count()
    print(f"\nTotal de usuários: {total_users}")
    
    if total_users == 0:
        print("\n⚠️  ATENÇÃO: Nenhum usuário encontrado no banco!")
        print("Execute: python manage.py createsuperuser")
        return
    
    # Listar todos os usuários
    print("\n" + "-" * 60)
    print("LISTA DE USUÁRIOS:")
    print("-" * 60)
    
    for user in User.objects.all():
        print(f"\nUsername: {user.username}")
        print(f"  Email: {user.email}")
        print(f"  Staff: {user.is_staff}")
        print(f"  Superuser: {user.is_superuser}")
        print(f"  Ativo: {user.is_active}")
        
        if user.is_staff or user.is_superuser:
            print(f"  ✓ TEM ACESSO AO ADMIN")
        else:
            print(f"  ✗ NÃO TEM ACESSO AO ADMIN")
    
    # Contar admins
    admins = User.objects.filter(is_staff=True)
    superusers = User.objects.filter(is_superuser=True)
    
    print("\n" + "=" * 60)
    print("RESUMO:")
    print(f"- Total de usuários: {total_users}")
    print(f"- Staff (admins): {admins.count()}")
    print(f"- Superusers: {superusers.count()}")
    print("=" * 60)
    
    if admins.count() == 0:
        print("\n⚠️  PROBLEMA: Nenhum usuário admin encontrado!")
        print("\nPara criar um admin, execute:")
        print("  python manage.py createsuperuser")
        print("\nOu torne um usuário existente admin:")
        if total_users > 0:
            first_user = User.objects.first()
            print(f"  python manage.py shell -c \"from finance.models import User; u = User.objects.get(username='{first_user.username}'); u.is_staff = True; u.is_superuser = True; u.save(); print('Admin criado!')\"")

if __name__ == '__main__':
    from django.conf import settings
    
    print("\nConfiguração do banco:")
    print(f"- ENGINE: {settings.DATABASES['default']['ENGINE']}")
    print(f"- NAME: {settings.DATABASES['default']['NAME']}")
    print(f"- HOST: {settings.DATABASES['default'].get('HOST', 'localhost')}")
    print()
    
    check_admin_users()
