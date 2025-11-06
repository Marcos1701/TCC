"""
Script de Validação do Sistema UUID
Executa uma série de verificações para garantir que o sistema está funcionando corretamente.

Uso:
    python manage.py shell < validate_uuid_system.py
    
    OU
    
    python manage.py shell
    >>> exec(open('validate_uuid_system.py').read())
"""

from django.contrib.auth import get_user_model
from finance.models import Transaction, Goal, TransactionLink, Friendship
from decimal import Decimal
import uuid

User = get_user_model()

print("\n" + "="*70)
print("🔍 VALIDAÇÃO DO SISTEMA UUID")
print("="*70 + "\n")

# ============================================================================
# 1. VERIFICAR MODELOS TÊM CAMPO UUID
# ============================================================================
print("📋 1. Verificando campos UUID nos modelos...")
models_with_uuid = [Transaction, Goal, TransactionLink, Friendship]
for model in models_with_uuid:
    has_uuid = hasattr(model, 'uuid')
    status = "✅" if has_uuid else "❌"
    print(f"   {status} {model.__name__}.uuid: {'Presente' if has_uuid else 'AUSENTE'}")

# ============================================================================
# 2. VERIFICAR REGISTROS COM UUID
# ============================================================================
print("\n📊 2. Verificando registros com UUID...")

def check_uuid_coverage(model):
    total = model.objects.count()
    with_uuid = model.objects.exclude(uuid__isnull=True).count()
    coverage = (with_uuid / total * 100) if total > 0 else 0
    status = "✅" if coverage == 100 else "⚠️" if coverage > 0 else "❌"
    print(f"   {status} {model.__name__}: {with_uuid}/{total} ({coverage:.1f}%)")
    return coverage

for model in models_with_uuid:
    check_uuid_coverage(model)

# ============================================================================
# 3. TESTAR AUTO-GERAÇÃO DE UUID
# ============================================================================
print("\n🔧 3. Testando auto-geração de UUID...")
try:
    # Criar usuário de teste se não existir
    test_user, created = User.objects.get_or_create(
        username='uuid_test_user',
        defaults={'email': 'uuid_test@example.com'}
    )
    
    # Criar transação sem UUID explícito
    transaction = Transaction.objects.create(
        user=test_user,
        description="Teste Auto-UUID",
        amount=Decimal("100.00"),
        type=Transaction.TransactionType.INCOME,
        date="2025-01-01"
    )
    
    if transaction.uuid:
        print(f"   ✅ UUID auto-gerado: {transaction.uuid}")
        transaction.delete()
    else:
        print(f"   ❌ UUID NÃO foi auto-gerado!")
        
except Exception as e:
    print(f"   ❌ Erro ao testar auto-geração: {str(e)}")

# ============================================================================
# 4. VERIFICAR UNICIDADE DE UUIDS
# ============================================================================
print("\n🔐 4. Verificando unicidade de UUIDs...")

def check_uuid_uniqueness(model):
    total_uuids = model.objects.exclude(uuid__isnull=True).count()
    unique_uuids = model.objects.exclude(uuid__isnull=True).values('uuid').distinct().count()
    
    if total_uuids == unique_uuids:
        print(f"   ✅ {model.__name__}: Todos os UUIDs são únicos ({unique_uuids})")
        return True
    else:
        duplicates = total_uuids - unique_uuids
        print(f"   ❌ {model.__name__}: {duplicates} UUID(s) duplicado(s)!")
        return False

all_unique = True
for model in models_with_uuid:
    if not check_uuid_uniqueness(model):
        all_unique = False

# ============================================================================
# 5. VERIFICAR TRANSACTIONLINK COM UUID FKS
# ============================================================================
print("\n🔗 5. Verificando TransactionLink com UUID FKs...")
try:
    link_count = TransactionLink.objects.count()
    if link_count > 0:
        sample_link = TransactionLink.objects.first()
        
        # Verificar campos UUID
        has_source_uuid = hasattr(sample_link, 'source_transaction_uuid')
        has_target_uuid = hasattr(sample_link, 'target_transaction_uuid')
        
        print(f"   ✅ Total de links: {link_count}")
        print(f"   {'✅' if has_source_uuid else '❌'} source_transaction_uuid: {'Presente' if has_source_uuid else 'AUSENTE'}")
        print(f"   {'✅' if has_target_uuid else '❌'} target_transaction_uuid: {'Presente' if has_target_uuid else 'AUSENTE'}")
        
        # Testar acesso via property
        if has_source_uuid and sample_link.source_transaction_uuid:
            try:
                source = sample_link.source_transaction
                print(f"   ✅ Property source_transaction funciona: {source.description}")
            except Exception as e:
                print(f"   ❌ Erro ao acessar source_transaction: {str(e)}")
        
        if has_target_uuid and sample_link.target_transaction_uuid:
            try:
                target = sample_link.target_transaction
                print(f"   ✅ Property target_transaction funciona: {target.description}")
            except Exception as e:
                print(f"   ❌ Erro ao acessar target_transaction: {str(e)}")
    else:
        print(f"   ⚠️  Nenhum TransactionLink encontrado")
except Exception as e:
    print(f"   ❌ Erro ao verificar TransactionLink: {str(e)}")

# ============================================================================
# 6. VERIFICAR ÍNDICES
# ============================================================================
print("\n📇 6. Verificando índices UUID...")
from django.db import connection

def check_indexes():
    with connection.cursor() as cursor:
        # PostgreSQL
        cursor.execute("""
            SELECT 
                tablename, 
                indexname 
            FROM pg_indexes 
            WHERE tablename LIKE 'finance_%' 
                AND indexname LIKE '%uuid%'
        """)
        indexes = cursor.fetchall()
        
        if indexes:
            print(f"   ✅ {len(indexes)} índice(s) UUID encontrado(s):")
            for table, index in indexes:
                print(f"      - {table}.{index}")
        else:
            print(f"   ⚠️  Nenhum índice UUID encontrado")

try:
    check_indexes()
except Exception as e:
    print(f"   ⚠️  Não foi possível verificar índices: {str(e)}")

# ============================================================================
# 7. VERIFICAR MIGRATIONS APLICADAS
# ============================================================================
print("\n🗃️  7. Verificando migrations aplicadas...")
from django.db.migrations.recorder import MigrationRecorder

uuid_migrations = [
    '0025_add_uuid_fields',
    '0026_populate_uuids',
    '0027_transactionlink_fk_to_uuid_step1',
    '0028_transactionlink_fk_to_uuid_step2',
    '0029_transactionlink_fk_to_uuid_step3',
]

applied = MigrationRecorder.Migration.objects.filter(
    app='finance',
    name__in=uuid_migrations
)

print(f"   Migrations UUID esperadas: {len(uuid_migrations)}")
print(f"   Migrations UUID aplicadas: {applied.count()}")

for migration_name in uuid_migrations:
    is_applied = applied.filter(name=migration_name).exists()
    status = "✅" if is_applied else "❌"
    print(f"   {status} {migration_name}")

# ============================================================================
# RESUMO FINAL
# ============================================================================
print("\n" + "="*70)
print("📊 RESUMO DA VALIDAÇÃO")
print("="*70)

# Contadores
issues = []

# Verificar cobertura
for model in models_with_uuid:
    total = model.objects.count()
    with_uuid = model.objects.exclude(uuid__isnull=True).count()
    if total > 0 and with_uuid < total:
        issues.append(f"{model.__name__}: {total - with_uuid} registro(s) sem UUID")

# Verificar unicidade
for model in models_with_uuid:
    total_uuids = model.objects.exclude(uuid__isnull=True).count()
    unique_uuids = model.objects.exclude(uuid__isnull=True).values('uuid').distinct().count()
    if total_uuids != unique_uuids:
        issues.append(f"{model.__name__}: UUIDs duplicados detectados")

# Verificar migrations
if applied.count() < len(uuid_migrations):
    issues.append(f"Migrations pendentes: {len(uuid_migrations) - applied.count()}")

if not issues:
    print("\n✅ SISTEMA VALIDADO COM SUCESSO!")
    print("   Todos os checks passaram. Sistema pronto para produção.")
else:
    print(f"\n⚠️  {len(issues)} PROBLEMA(S) DETECTADO(S):")
    for issue in issues:
        print(f"   • {issue}")
    print("\n   Corrija os problemas antes de prosseguir.")

print("\n" + "="*70 + "\n")

# Cleanup
if 'test_user' in locals() and created:
    test_user.delete()
    print("🧹 Usuário de teste removido.\n")
