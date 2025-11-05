# Generated data migration to populate UUIDs for existing records

import uuid
from django.db import migrations


def generate_uuids(apps, schema_editor):
    """
    Gera UUIDs para todos os registros existentes que não têm.
    Isso garante que registros antigos também tenham UUIDs únicos.
    """
    # Importar modelos
    Transaction = apps.get_model('finance', 'Transaction')
    Goal = apps.get_model('finance', 'Goal')
    TransactionLink = apps.get_model('finance', 'TransactionLink')
    Friendship = apps.get_model('finance', 'Friendship')
    
    # Contadores para logging
    counts = {
        'transactions': 0,
        'goals': 0,
        'transaction_links': 0,
        'friendships': 0,
    }
    
    # Popular UUIDs para Transaction
    for transaction in Transaction.objects.filter(uuid__isnull=True):
        transaction.uuid = uuid.uuid4()
        transaction.save(update_fields=['uuid'])
        counts['transactions'] += 1
    
    # Popular UUIDs para Goal
    for goal in Goal.objects.filter(uuid__isnull=True):
        goal.uuid = uuid.uuid4()
        goal.save(update_fields=['uuid'])
        counts['goals'] += 1
    
    # Popular UUIDs para TransactionLink
    for link in TransactionLink.objects.filter(uuid__isnull=True):
        link.uuid = uuid.uuid4()
        link.save(update_fields=['uuid'])
        counts['transaction_links'] += 1
    
    # Popular UUIDs para Friendship
    for friendship in Friendship.objects.filter(uuid__isnull=True):
        friendship.uuid = uuid.uuid4()
        friendship.save(update_fields=['uuid'])
        counts['friendships'] += 1
    
    # Log dos resultados
    print(f"\n✅ UUIDs gerados com sucesso:")
    print(f"   - Transactions: {counts['transactions']}")
    print(f"   - Goals: {counts['goals']}")
    print(f"   - TransactionLinks: {counts['transaction_links']}")
    print(f"   - Friendships: {counts['friendships']}")
    print(f"   Total: {sum(counts.values())}\n")


def reverse_uuids(apps, schema_editor):
    """
    Reverte a migration limpando os UUIDs.
    Usado em caso de rollback.
    """
    Transaction = apps.get_model('finance', 'Transaction')
    Goal = apps.get_model('finance', 'Goal')
    TransactionLink = apps.get_model('finance', 'TransactionLink')
    Friendship = apps.get_model('finance', 'Friendship')
    
    Transaction.objects.all().update(uuid=None)
    Goal.objects.all().update(uuid=None)
    TransactionLink.objects.all().update(uuid=None)
    Friendship.objects.all().update(uuid=None)
    
    print("\n⚠️ UUIDs removidos (rollback)\n")


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0025_add_uuid_fields'),
    ]

    operations = [
        migrations.RunPython(generate_uuids, reverse_uuids),
    ]
