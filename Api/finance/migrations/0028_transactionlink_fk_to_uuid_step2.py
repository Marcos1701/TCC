# Generated migration for TransactionLink FK to UUID - Step 2: Populate temporary UUID fields

from django.db import migrations


def populate_uuid_fk_fields(apps, schema_editor):
    """
    Popula os campos UUID temporários com os UUIDs das transações vinculadas.
    """
    TransactionLink = apps.get_model('finance', 'TransactionLink')
    
    links_updated = 0
    links_without_uuid = 0
    
    # Processar em lotes de 1000
    batch_size = 1000
    links = TransactionLink.objects.select_related(
        'source_transaction', 
        'target_transaction'
    ).all()
    
    batch = []
    for link in links.iterator(chunk_size=batch_size):
        # Verificar se as transações têm UUID
        if link.source_transaction.uuid and link.target_transaction.uuid:
            link.source_transaction_uuid_temp = link.source_transaction.uuid
            link.target_transaction_uuid_temp = link.target_transaction.uuid
            batch.append(link)
            links_updated += 1
        else:
            links_without_uuid += 1
            print(f"TransactionLink {link.id}: source ou target sem UUID")
        
        # Salvar em lotes
        if len(batch) >= batch_size:
            TransactionLink.objects.bulk_update(
                batch, 
                ['source_transaction_uuid_temp', 'target_transaction_uuid_temp'],
                batch_size=batch_size
            )
            batch = []
    
    # Salvar lote final
    if batch:
        TransactionLink.objects.bulk_update(
            batch, 
            ['source_transaction_uuid_temp', 'target_transaction_uuid_temp'],
            batch_size=batch_size
        )
    
    print(f"\nMigração de FK para UUID - Step 2:")
    print(f"   - Links atualizados: {links_updated}")
    if links_without_uuid > 0:
        print(f"   Links sem UUID nas transações: {links_without_uuid}")
        print(f"   Execute python manage.py shell e rode:")
        print(f"   from finance.models import Transaction")
        print(f"   Transaction.objects.filter(uuid__isnull=True).update(uuid=uuid.uuid4())")


def reverse_populate(apps, schema_editor):
    """Rollback: limpar campos temporários."""
    TransactionLink = apps.get_model('finance', 'TransactionLink')
    TransactionLink.objects.update(
        source_transaction_uuid_temp=None,
        target_transaction_uuid_temp=None
    )


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0027_transactionlink_fk_to_uuid_step1'),
    ]

    operations = [
        migrations.RunPython(populate_uuid_fk_fields, reverse_populate),
    ]
