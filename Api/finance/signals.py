from django.conf import settings
from django.contrib.auth.models import User
from django.db import transaction
from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver
import uuid

from .models import Category, Transaction, TransactionLink, UserProfile


def _ensure_default_categories(user):
    default_categories = [
        {'name': 'Salário', 'type': 'INCOME', 'group': 'REGULAR_INCOME', 'color': '#4CAF50'},
        {'name': 'Freelance', 'type': 'INCOME', 'group': 'EXTRA_INCOME', 'color': '#8BC34A'},
        {'name': 'Investimentos', 'type': 'INCOME', 'group': 'INVESTMENT', 'color': '#009688'},
        
        {'name': 'Alimentação', 'type': 'EXPENSE', 'group': 'ESSENTIAL_EXPENSE', 'color': '#FF9800'},
        {'name': 'Moradia', 'type': 'EXPENSE', 'group': 'ESSENTIAL_EXPENSE', 'color': '#FF5722'},
        {'name': 'Transporte', 'type': 'EXPENSE', 'group': 'ESSENTIAL_EXPENSE', 'color': '#2196F3'},
        {'name': 'Saúde', 'type': 'EXPENSE', 'group': 'ESSENTIAL_EXPENSE', 'color': '#F44336'},
        
        {'name': 'Lazer', 'type': 'EXPENSE', 'group': 'LIFESTYLE_EXPENSE', 'color': '#9C27B0'},
        {'name': 'Educação', 'type': 'EXPENSE', 'group': 'LIFESTYLE_EXPENSE', 'color': '#3F51B5'},
        {'name': 'Vestuário', 'type': 'EXPENSE', 'group': 'LIFESTYLE_EXPENSE', 'color': '#E91E63'},
        
        {'name': 'Reserva de Emergência', 'type': 'EXPENSE', 'group': 'SAVINGS', 'color': '#00BCD4'},
        {'name': 'Investimentos', 'type': 'EXPENSE', 'group': 'INVESTMENT', 'color': '#009688'},
        
        {'name': 'Cartão de Crédito', 'type': 'EXPENSE', 'group': 'ESSENTIAL_EXPENSE', 'color': '#F44336'},
        {'name': 'Empréstimo', 'type': 'EXPENSE', 'group': 'ESSENTIAL_EXPENSE', 'color': '#D32F2F'},
        
        {'name': 'Outros', 'type': 'EXPENSE', 'group': 'OTHER', 'color': '#9E9E9E'},
    ]
    
    created_count = 0
    for cat_data in default_categories:
        exists = Category.objects.filter(
            user=user,
            name=cat_data['name'],
            type=cat_data['type']
        ).exists()
        
        if not exists:
            Category.objects.create(
                user=user,
                is_system_default=True,
                **cat_data
            )
            created_count += 1
    
    if created_count > 0:
        import logging
        logger = logging.getLogger(__name__)
        logger.info(f"Created {created_count} default categories for user {user.id}")


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def create_user_profile(sender, instance, created, **kwargs):
    if created:
        with transaction.atomic():
            UserProfile.objects.create(user=instance)
            _ensure_default_categories(instance)
            
            from .services import assign_missions_automatically
            assign_missions_automatically(instance)
            
            import logging
            logger = logging.getLogger(__name__)
            logger.info(
                f"New user profile created: User {instance.id} ({instance.username}) - "
                f"is_first_access=True (onboarding enabled)"
            )


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def sync_user_profile(sender, instance, **kwargs):
    UserProfile.objects.get_or_create(user=instance)


@receiver(post_save, sender=Transaction)
def update_missions_on_transaction(sender, instance, created, **kwargs):
    """
    Atualiza progresso das missões e atribui novas quando necessário após cada transação.
    Executa após commit para evitar race conditions.
    Transações agendadas (futuras) não atualizam progresso até a data efetiva.
    """
    if created:
        from django.db import transaction as db_transaction
        
        def update_after_commit():
            from .services import update_mission_progress, assign_missions_automatically
            
            # Only update mission progress for non-scheduled (past/present) transactions
            if not instance.is_scheduled:
                update_mission_progress(instance.user)
            
            # Always assign new missions regardless of transaction date
            assign_missions_automatically(instance.user)
        
        db_transaction.on_commit(update_after_commit)


# ======= Signals para garantir UUID em novos registros =======

@receiver(pre_save, sender=Transaction)
def ensure_transaction_uuid(sender, instance, **kwargs):
    """Garante que toda transação tenha UUID antes de salvar."""
    if not instance.id:
        instance.id = uuid.uuid4()


@receiver(pre_save, sender=TransactionLink)
def ensure_transaction_link_uuid(sender, instance, **kwargs):
    """Garante que todo link tenha UUID antes de salvar."""
    if not instance.id:
        instance.id = uuid.uuid4()
