# Generated manually on 2025-11-05

from django.db import migrations


def mark_existing_users_as_not_first_access(apps, schema_editor):
    """
    Marca usuários existentes (que já têm transações) como is_first_access=False.
    Apenas usuários novos sem transações devem ter is_first_access=True.
    """
    UserProfile = apps.get_model('finance', 'UserProfile')
    Transaction = apps.get_model('finance', 'Transaction')
    
    # Para cada perfil existente
    for profile in UserProfile.objects.all():
        # Verifica se o usuário tem pelo menos uma transação
        has_transactions = Transaction.objects.filter(user=profile.user).exists()
        
        # Se tem transações, não é primeiro acesso
        if has_transactions:
            profile.is_first_access = False
            profile.save(update_fields=['is_first_access'])


def reverse_migration(apps, schema_editor):
    """
    Reverter: marcar todos como primeiro acesso novamente.
    """
    UserProfile = apps.get_model('finance', 'UserProfile')
    UserProfile.objects.all().update(is_first_access=True)


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0022_add_is_first_access_field'),
    ]

    operations = [
        migrations.RunPython(
            mark_existing_users_as_not_first_access,
            reverse_migration,
        ),
    ]
