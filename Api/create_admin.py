"""
Script para criar usuário administrador para testes de IA.

Uso:
    python create_admin.py
"""

import os
import sys
import django

# Setup Django
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth import get_user_model

User = get_user_model()


def create_admin_user():
    """Cria usuário admin para testes."""
    
    # Verificar se já existe admin
    if User.objects.filter(is_superuser=True).exists():
        print("✓ Já existe um superusuário no sistema.")
        admin = User.objects.filter(is_superuser=True).first()
        print(f"  Email: {admin.email}")
        print(f"  Username: {admin.username}")
        
        resposta = input("\nDeseja criar outro admin? (s/n): ").lower()
        if resposta != 's':
            return
    
    print("\n=== Criar Usuário Administrador ===\n")
    
    # Coletar dados
    email = input("Email: ").strip()
    username = input("Username (opcional, pressione Enter para usar email): ").strip()
    password = input("Senha: ").strip()
    
    if not username:
        username = email.split('@')[0]
    
    # Validações básicas
    if not email or not password:
        print("\n❌ Email e senha são obrigatórios!")
        return
    
    if User.objects.filter(email=email).exists():
        print(f"\n❌ Já existe um usuário com o email {email}")
        return
    
    if User.objects.filter(username=username).exists():
        print(f"\n❌ Já existe um usuário com o username {username}")
        return
    
    # Criar usuário
    try:
        user = User.objects.create_user(
            username=username,
            email=email,
            password=password
        )
        user.is_staff = True
        user.is_superuser = True
        user.save()
        
        print(f"\n✅ Superusuário criado com sucesso!")
        print(f"   Email: {user.email}")
        print(f"   Username: {user.username}")
        print(f"   is_staff: {user.is_staff}")
        print(f"   is_superuser: {user.is_superuser}")
        
        print("\n📝 Você pode usar estas credenciais para:")
        print("   1. Acessar o Django Admin: http://localhost:8000/admin/")
        print("   2. Gerar missões via API: POST /api/missions/generate_ai_missions/")
        
    except Exception as e:
        print(f"\n❌ Erro ao criar usuário: {e}")


if __name__ == '__main__':
    create_admin_user()
