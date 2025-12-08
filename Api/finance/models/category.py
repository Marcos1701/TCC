"""
Modelo Category - Categorias de transações financeiras.
"""

import re

from django.conf import settings
from django.db import models

from .base import MAX_CATEGORY_NAME_LENGTH


class Category(models.Model):
    """
    Categoria para classificação de transações financeiras.
    
    Pode ser global (user=None) ou específica de um usuário.
    """
    
    class CategoryType(models.TextChoices):
        INCOME = "INCOME", "Receita"
        EXPENSE = "EXPENSE", "Despesa"

    class CategoryGroup(models.TextChoices):
        REGULAR_INCOME = "REGULAR_INCOME", "Renda principal"
        EXTRA_INCOME = "EXTRA_INCOME", "Renda extra"
        SAVINGS = "SAVINGS", "Poupança / Reserva"
        INVESTMENT = "INVESTMENT", "Investimentos"
        ESSENTIAL_EXPENSE = "ESSENTIAL_EXPENSE", "Despesas essenciais"
        LIFESTYLE_EXPENSE = "LIFESTYLE_EXPENSE", "Estilo de vida"
        GOAL = "GOAL", "Metas e sonhos"
        OTHER = "OTHER", "Outros"

    name = models.CharField(max_length=MAX_CATEGORY_NAME_LENGTH)
    type = models.CharField(max_length=10, choices=CategoryType.choices)
    color = models.CharField(max_length=7, blank=True)
    group = models.CharField(
        max_length=24,
        choices=CategoryGroup.choices,
        default=CategoryGroup.OTHER,
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="categories",
        null=True,
        blank=True,
        help_text="Usuário proprietário desta categoria (null = categoria global/padrão)",
    )
    is_system_default = models.BooleanField(
        default=False,
        help_text="Categoria padrão do sistema (criada automaticamente para novos usuários)",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("user", "name", "type")
        ordering = ("name",)
        verbose_name = "Categoria"
        verbose_name_plural = "Categorias"
        indexes = [
            models.Index(fields=['user', 'type']),
            models.Index(fields=['user', 'is_system_default']),
        ]

    def __str__(self) -> str:
        owner = self.user or "padrão"
        return f"{self.name} ({owner})"

    def clean(self):
        from django.core.exceptions import ValidationError
        
        self._validate_name()
        self._validate_color()
        self._validate_type_group_compatibility()
        self._validate_system_default_immutability()
        self._validate_unique_for_user()

    def _validate_name(self):
        from django.core.exceptions import ValidationError
        
        if not self.name or len(self.name.strip()) == 0:
            raise ValidationError({
                'name': 'Nome da categoria não pode ser vazio.'
            })
        
        if len(self.name) > MAX_CATEGORY_NAME_LENGTH:
            raise ValidationError({
                'name': f'Nome da categoria não pode exceder {MAX_CATEGORY_NAME_LENGTH} caracteres.'
            })

    def _validate_color(self):
        from django.core.exceptions import ValidationError
        
        if self.color and not re.match(r'^#[0-9A-Fa-f]{6}$', self.color):
            raise ValidationError({
                'color': 'Cor deve estar no formato hexadecimal (#RRGGBB).'
            })

    def _validate_type_group_compatibility(self):
        from django.core.exceptions import ValidationError
        
        type_group_map = {
            self.CategoryType.INCOME: [
                self.CategoryGroup.REGULAR_INCOME,
                self.CategoryGroup.EXTRA_INCOME,
                self.CategoryGroup.SAVINGS,
                self.CategoryGroup.INVESTMENT,
                self.CategoryGroup.OTHER,
            ],
            self.CategoryType.EXPENSE: [
                self.CategoryGroup.ESSENTIAL_EXPENSE,
                self.CategoryGroup.LIFESTYLE_EXPENSE,
                self.CategoryGroup.SAVINGS,
                self.CategoryGroup.INVESTMENT,
                self.CategoryGroup.GOAL,
                self.CategoryGroup.OTHER,
            ],
        }
        
        if self.type in type_group_map:
            valid_groups = type_group_map[self.type]
            if self.group not in valid_groups:
                raise ValidationError({
                    'group': f'Grupo "{self.get_group_display()}" incompatível com tipo "{self.get_type_display()}".'
                })

    def _validate_system_default_immutability(self):
        from django.core.exceptions import ValidationError
        
        if self.pk and self.is_system_default:
            try:
                old_instance = Category.objects.get(pk=self.pk)
                if (old_instance.name != self.name or 
                    old_instance.type != self.type or
                    old_instance.user != self.user):
                    raise ValidationError({
                        'is_system_default': 'Categorias padrão do sistema não podem ter nome, tipo ou proprietário alterados.'
                    })
            except Category.DoesNotExist:
                pass

    def _validate_unique_for_user(self):
        from django.core.exceptions import ValidationError
        
        if self.user:
            existing = Category.objects.filter(
                user=self.user,
                name__iexact=self.name.strip(),
                type=self.type
            ).exclude(pk=self.pk)
            
            if existing.exists():
                raise ValidationError({
                    'name': f'Já existe uma categoria "{self.name}" do tipo {self.get_type_display()} para este usuário.'
                })
