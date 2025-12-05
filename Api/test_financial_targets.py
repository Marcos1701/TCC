"""
Script de teste para validar a funcionalidade de metas financeiras personalizáveis.
"""
import os
import sys
import django

# Setup Django
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from django.contrib.auth import get_user_model
from finance.models import UserProfile

User = get_user_model()

def test_financial_targets():
    """Testa a atualização de metas financeiras no UserProfile."""
    print("=" * 60)
    print("TESTE: Metas Financeiras Personalizáveis")
    print("=" * 60)
    
    # Buscar um usuário de teste (primeiro usuário disponível)
    user = User.objects.first()
    if not user:
        print("❌ Nenhum usuário encontrado para teste!")
        return False
    
    print(f"\n✅ Usuário de teste: {user.email}")
    
    # Obter ou criar perfil
    profile, created = UserProfile.objects.get_or_create(user=user)
    
    print(f"\n📊 Valores ANTES da atualização:")
    print(f"   - target_tps: {profile.target_tps}%")
    print(f"   - target_rdr: {profile.target_rdr}%")
    print(f"   - target_ili: {profile.target_ili} meses")
    
    # Salvar valores originais para restaurar depois
    original_tps = profile.target_tps
    original_rdr = profile.target_rdr
    original_ili = profile.target_ili
    
    # Testar atualização de metas
    new_tps = 25
    new_rdr = 40
    new_ili = 8.5
    
    print(f"\n🔄 Atualizando para:")
    print(f"   - target_tps: {new_tps}%")
    print(f"   - target_rdr: {new_rdr}%")
    print(f"   - target_ili: {new_ili} meses")
    
    profile.target_tps = new_tps
    profile.target_rdr = new_rdr
    profile.target_ili = new_ili
    profile.save()
    
    # Recarregar e verificar
    profile.refresh_from_db()
    
    print(f"\n📊 Valores DEPOIS da atualização:")
    print(f"   - target_tps: {profile.target_tps}%")
    print(f"   - target_rdr: {profile.target_rdr}%")
    print(f"   - target_ili: {profile.target_ili} meses")
    
    # Validar
    success = True
    if profile.target_tps != new_tps:
        print(f"❌ FALHA: target_tps esperado {new_tps}, obtido {profile.target_tps}")
        success = False
    if profile.target_rdr != new_rdr:
        print(f"❌ FALHA: target_rdr esperado {new_rdr}, obtido {profile.target_rdr}")
        success = False
    if float(profile.target_ili) != new_ili:
        print(f"❌ FALHA: target_ili esperado {new_ili}, obtido {profile.target_ili}")
        success = False
    
    if success:
        print("\n✅ SUCESSO: Metas financeiras atualizadas corretamente!")
    
    # Restaurar valores originais
    print(f"\n🔄 Restaurando valores originais...")
    profile.target_tps = original_tps
    profile.target_rdr = original_rdr
    profile.target_ili = original_ili
    profile.save()
    
    profile.refresh_from_db()
    print(f"   - target_tps: {profile.target_tps}%")
    print(f"   - target_rdr: {profile.target_rdr}%")
    print(f"   - target_ili: {profile.target_ili} meses")
    
    print("\n" + "=" * 60)
    return success

if __name__ == '__main__':
    result = test_financial_targets()
    sys.exit(0 if result else 1)
