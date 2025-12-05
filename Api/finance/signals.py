from django.conf import settings
from django.contrib.auth.models import User
from django.db import transaction
from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver
import uuid

from .models import Category, Transaction, TransactionLink, Goal, UserProfile


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
        
        {'name': 'Cartão de Crédito', 'type': 'DEBT', 'group': 'DEBT', 'color': '#F44336'},
        {'name': 'Empréstimo', 'type': 'DEBT', 'group': 'DEBT', 'color': '#D32F2F'},
        
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
    """
    if created:
        from django.db import transaction as db_transaction
        
        def update_after_commit():
            from .services import update_mission_progress, assign_missions_automatically
            
            update_mission_progress(instance.user)
            assign_missions_automatically(instance.user)
        
        db_transaction.on_commit(update_after_commit)


@receiver(post_save, sender=Transaction)
def update_goals_on_transaction_change(sender, instance, **kwargs):
    """
    Atualiza metas do tipo SAVINGS quando uma transação é criada ou atualizada.
    
    O modelo Goal atual suporta:
    - SAVINGS: Juntar dinheiro (atualizado automaticamente)
    - EMERGENCY_FUND: Fundo de emergência (atualizado automaticamente)
    - EXPENSE_REDUCTION: Reduzir gastos (atualização manual)
    - INCOME_INCREASE: Aumentar receita (atualização manual)
    - CUSTOM: Meta personalizada (atualização manual)
    """
    from .services import update_goal_progress
    from .models import Goal, Category
    
    # Buscar metas SAVINGS e EMERGENCY_FUND do usuário
    auto_update_goals = Goal.objects.filter(
        user=instance.user, 
        goal_type__in=[Goal.GoalType.SAVINGS, Goal.GoalType.EMERGENCY_FUND]
    )
    
    for goal in auto_update_goals:
        # Atualiza se transação é em categoria SAVINGS ou INVESTMENT
        if instance.category and instance.category.group in [
            Category.CategoryGroup.SAVINGS,
            Category.CategoryGroup.INVESTMENT
        ]:
            update_goal_progress(goal)


from django.db.models.signals import post_delete


@receiver(post_delete, sender=Transaction)
def update_goals_on_transaction_delete(sender, instance, **kwargs):
    """
    Atualiza metas com auto_update quando uma transação é deletada.
    Verifica se o usuário ainda existe antes de atualizar (para evitar erros em deleções em cascata).
    """
    from .services import update_all_active_goals
    
    # Verifica se o usuário ainda existe antes de tentar atualizar
    # (evita erro quando transações são deletadas em cascata ao deletar usuário)
    try:
        if instance.user_id and instance.user:
            update_all_active_goals(instance.user)
    except User.DoesNotExist:
        # Usuário foi deletado, não há metas para atualizar
        pass


# ======= Signals para garantir UUID em novos registros =======

@receiver(pre_save, sender=Transaction)
def ensure_transaction_uuid(sender, instance, **kwargs):
    """Garante que toda transação tenha UUID antes de salvar."""
    if not instance.id:
        instance.id = uuid.uuid4()


@receiver(pre_save, sender=Goal)
def ensure_goal_uuid(sender, instance, **kwargs):
    """Garante que toda meta tenha UUID antes de salvar."""
    if not instance.id:
        instance.id = uuid.uuid4()


@receiver(pre_save, sender=TransactionLink)
def ensure_transaction_link_uuid(sender, instance, **kwargs):
    """Garante que todo link tenha UUID antes de salvar."""
    if not instance.id:
        instance.id = uuid.uuid4()







