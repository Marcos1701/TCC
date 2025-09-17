from django.conf import settings
from django.db import transaction
from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import Category, UserProfile

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


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def sync_user_profile(sender, instance, **kwargs):
    UserProfile.objects.get_or_create(user=instance)