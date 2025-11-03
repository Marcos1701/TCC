from django.conf import settings
from django.db import transaction
from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import Category, Transaction, UserProfile

# lista curtinha só pra dar o pontapé inicial
DEFAULT_CATEGORIES = {
    Category.CategoryType.INCOME: ["Salário", "Freela", "Outros ganhos"],
    Category.CategoryType.EXPENSE: [
        "Alimentação",
        "Transporte",
        "Lazer",
        "Moradia",
        "Educação",
    ],
    Category.CategoryType.DEBT: ["Cartão", "Empréstimo", "Financiamento"],
}


def _ensure_default_categories(user):
    for cat_type, names in DEFAULT_CATEGORIES.items():
        for name in names:
            Category.objects.get_or_create(user=user, name=name, type=cat_type)


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def create_user_profile(sender, instance, created, **kwargs):
    if created:
        with transaction.atomic():
            UserProfile.objects.create(user=instance)
            _ensure_default_categories(instance)
            # Atribuir missões iniciais
            from .services import assign_missions_automatically
            assign_missions_automatically(instance)


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