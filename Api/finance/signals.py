from django.conf import settings
from django.db import transaction
from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver
import uuid

from .models import Category, Transaction, TransactionLink, Goal, Friendship, UserProfile


def _ensure_default_categories(user):
    """
    Não cria mais categorias para novos usuários.
    As categorias padrão do sistema (user=None) são compartilhadas por todos.
    Usuários podem criar suas próprias categorias personalizadas quando necessário.
    """
    # Removida criação automática - usuários usam categorias do sistema
    pass


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def create_user_profile(sender, instance, created, **kwargs):
    """
    Cria perfil de usuário ao criar nova conta.
    Marca is_first_access=True para novos usuários (onboarding).
    """
    if created:
        with transaction.atomic():
            # Criar perfil com is_first_access=True (default do modelo)
            UserProfile.objects.create(user=instance)
            _ensure_default_categories(instance)
            
            # Atribuir missões iniciais
            from .services import assign_missions_automatically
            assign_missions_automatically(instance)
            
            # Log para auditoria
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
    """
    if created:
        from .services import update_mission_progress, assign_missions_automatically
        
        # Atualizar progresso das missões existentes
        update_mission_progress(instance.user)
        
        # Verificar se precisa atribuir novas missões
        assign_missions_automatically(instance.user)


@receiver(post_save, sender=Transaction)
def update_goals_on_transaction_change(sender, instance, **kwargs):
    """
    Atualiza metas com auto_update quando uma transação é criada ou atualizada.
    """
    from .services import update_all_active_goals
    update_all_active_goals(instance.user)


from django.db.models.signals import post_delete


@receiver(post_delete, sender=Transaction)
def update_goals_on_transaction_delete(sender, instance, **kwargs):
    """
    Atualiza metas com auto_update quando uma transação é deletada.
    """
    from .services import update_all_active_goals
    update_all_active_goals(instance.user)


# ======= Signals para garantir UUID em novos registros =======

@receiver(pre_save, sender=Transaction)
def ensure_transaction_uuid(sender, instance, **kwargs):
    """Garante que toda transação tenha UUID antes de salvar."""
    if not instance.uuid:
        instance.uuid = uuid.uuid4()


@receiver(pre_save, sender=Goal)
def ensure_goal_uuid(sender, instance, **kwargs):
    """Garante que toda meta tenha UUID antes de salvar."""
    if not instance.uuid:
        instance.uuid = uuid.uuid4()


@receiver(pre_save, sender=TransactionLink)
def ensure_transaction_link_uuid(sender, instance, **kwargs):
    """Garante que todo link tenha UUID antes de salvar."""
    if not instance.uuid:
        instance.uuid = uuid.uuid4()


@receiver(pre_save, sender=Friendship)
def ensure_friendship_uuid(sender, instance, **kwargs):
    """Garante que toda amizade tenha UUID antes de salvar."""
    if not instance.uuid:
        instance.uuid = uuid.uuid4()
