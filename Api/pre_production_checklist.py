"""
Checklist de Validação Pré-Produção - Sistema UUID
Execute todas as verificações antes de prosseguir com Primary Key Migration

Uso:
    python manage.py shell
    >>> exec(open('pre_production_checklist.py').read())
"""

print("\n" + "="*70)
print("CHECKLIST DE VALIDACAO PRE-PRODUCAO - SISTEMA UUID")
print("="*70 + "\n")

# ============================================================================
# VERIFICACOES AUTOMATICAS
# ============================================================================

from django.contrib.auth import get_user_model
from finance.models import Transaction, Goal, TransactionLink, Friendship
from decimal import Decimal
import sys

User = get_user_model()

checklist = {
    'critical': [],
    'warnings': [],
    'passed': []
}

def check(name, condition, critical=True):
    """Adiciona check ao checklist."""
    if condition:
        checklist['passed'].append(name)
        print(f"   OK {name}")
        return True
    else:
        if critical:
            checklist['critical'].append(name)
            print(f"   CRITICO - {name}")
        else:
            checklist['warnings'].append(name)
            print(f"   AVISO - {name}")
        return False

print("1. Verificando Migrations...")
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
).count()
check("Todas as migrations UUID aplicadas", applied == len(uuid_migrations))

print("\n2. Verificando Cobertura UUID...")
for model in [Transaction, Goal, TransactionLink, Friendship]:
    total = model.objects.count()
    if total > 0:
        with_uuid = model.objects.exclude(uuid__isnull=True).count()
        coverage = (with_uuid / total * 100)
        check(
            f"{model.__name__}: {coverage:.0f}% com UUID",
            coverage == 100,
            critical=(coverage < 90)
        )
    else:
        check(f"{model.__name__}: Sem dados para verificar", True, critical=False)

print("\n3. Verificando Indices...")
from django.db import connection
with connection.cursor() as cursor:
    cursor.execute("""
        SELECT COUNT(*) 
        FROM pg_indexes 
        WHERE tablename LIKE 'finance_%' 
            AND indexname LIKE '%uuid%'
    """)
    uuid_indexes = cursor.fetchone()[0]
    check(f"{uuid_indexes} indices UUID encontrados", uuid_indexes >= 4)

print("\n4. Verificando TransactionLink FK UUID...")
if TransactionLink.objects.exists():
    sample = TransactionLink.objects.first()
    check(
        "TransactionLink tem source_transaction_uuid",
        hasattr(sample, 'source_transaction_uuid')
    )
    check(
        "TransactionLink tem target_transaction_uuid", 
        hasattr(sample, 'target_transaction_uuid')
    )
    
    # Testar properties
    try:
        _ = sample.source_transaction
        check("Property source_transaction funciona", True)
    except:
        check("Property source_transaction funciona", False)
    
    try:
        _ = sample.target_transaction
        check("Property target_transaction funciona", True)
    except:
        check("Property target_transaction funciona", False)

print("\n5. Testando Auto-geracao UUID...")
try:
    test_user = User.objects.first()
    if test_user:
        t = Transaction.objects.create(
            user=test_user,
            description="TEST_UUID_AUTO",
            amount=Decimal("1.00"),
            type=Transaction.TransactionType.INCOME,
            date="2025-01-01"
        )
        check("UUID auto-gerado em create", t.uuid is not None)
        t.delete()
    else:
        check("Usuario de teste disponivel", False, critical=False)
except Exception as e:
    check(f"Auto-geracao UUID funciona: {str(e)}", False)

print("\n6. Verificando Testes...")
import subprocess
try:
    result = subprocess.run(
        ['python', 'manage.py', 'test', 'finance.tests.test_uuid_integration', '--verbosity=0'],
        capture_output=True,
        text=True,
        timeout=180
    )
    tests_passed = result.returncode == 0
    check("Suite de testes UUID passa", tests_passed)
except Exception as e:
    check(f"Testes executados: {str(e)}", False, critical=False)

# ============================================================================
# VERIFICACOES MANUAIS
# ============================================================================

print("\n" + "="*70)
print("VERIFICACOES MANUAIS NECESSARIAS")
print("="*70)

manual_checks = [
    {
        'id': 'M1',
        'task': 'Backup completo do banco de dados criado',
        'command': 'pg_dump -U postgres -d finance_db > backup_$(date +%Y%m%d).sql',
        'critical': True
    },
    {
        'id': 'M2', 
        'task': 'Testado em ambiente de staging/desenvolvimento',
        'command': 'python manage.py runserver --settings=config.settings_staging',
        'critical': True
    },
    {
        'id': 'M3',
        'task': 'Frontend testado com UUIDs',
        'command': 'flutter test && flutter run',
        'critical': True
    },
    {
        'id': 'M4',
        'task': 'Endpoints criticos testados manualmente',
        'command': 'curl -X GET https://api/transactions/ -H "Authorization: Bearer <token>"',
        'critical': True
    },
    {
        'id': 'M5',
        'task': 'Plano de rollback documentado e testado',
        'command': 'python manage.py migrate finance 0026',
        'critical': True
    },
    {
        'id': 'M6',
        'task': 'Equipe informada sobre mudanca',
        'command': 'N/A',
        'critical': False
    },
    {
        'id': 'M7',
        'task': 'Janela de manutencao agendada (se necessario)',
        'command': 'N/A',
        'critical': False
    },
]

for check_item in manual_checks:
    criticality = "CRITICO" if check_item['critical'] else "RECOMENDADO"
    print(f"\n[{check_item['id']}] {criticality}")
    print(f"    Tarefa: {check_item['task']}")
    print(f"    Comando: {check_item['command']}")

# ============================================================================
# RESUMO
# ============================================================================

print("\n" + "="*70)
print("RESUMO DO CHECKLIST")
print("="*70)

print(f"\nPASSOU: {len(checklist['passed'])} checks")
print(f"AVISOS: {len(checklist['warnings'])} checks")
print(f"CRITICOS: {len(checklist['critical'])} checks")

if checklist['critical']:
    print("\n FALHAS CRITICAS DETECTADAS:")
    for item in checklist['critical']:
        print(f"   - {item}")
    print("\n   Corrija todos os problemas criticos antes de prosseguir!")
    sys.exit(1)
elif checklist['warnings']:
    print("\n AVISOS DETECTADOS:")
    for item in checklist['warnings']:
        print(f"   - {item}")
    print("\n   Revise os avisos antes de prosseguir.")
else:
    print("\n VERIFICACOES AUTOMATICAS PASSARAM!")

print("\n" + "="*70)
print("PROXIMOS PASSOS")
print("="*70)

print("""
1. Complete todas as verificacoes manuais listadas acima
2. Garanta que o backup esta seguro e testado
3. Teste o rollback em ambiente de desenvolvimento
4. Se tudo estiver OK, prossiga com:
   
   python manage.py shell
   >>> exec(open('apply_primary_key_migration.py').read())

5. Ou manualmente:
   - Criar migration para PK UUID
   - Testar em staging
   - Aplicar em producao com janela de manutencao

IMPORTANTE: A proxima etapa e IRREVERSIVEL sem restore de backup!
""")

print("="*70 + "\n")
