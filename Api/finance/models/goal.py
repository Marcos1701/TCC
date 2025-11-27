"""
Modelo Goal - Metas financeiras do usuário.
"""

from datetime import timedelta
from decimal import Decimal
import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone

from .base import (
    MAX_AMOUNT,
    MAX_TITLE_LENGTH,
    MAX_DEADLINE_YEARS,
)


class Goal(models.Model):
    """
    Meta financeira do usuário.
    
    Tipos de metas:
    - SAVINGS: Juntar dinheiro (acumular valor)
    - EXPENSE_REDUCTION: Reduzir gastos em uma categoria
    - INCOME_INCREASE: Aumentar receita
    - EMERGENCY_FUND: Fundo de emergência (reserva de X meses)
    - CUSTOM: Meta personalizada (atualização manual)
    """
    
    class GoalType(models.TextChoices):
        SAVINGS = "SAVINGS", "Juntar Dinheiro"
        EXPENSE_REDUCTION = "EXPENSE_REDUCTION", "Reduzir Gastos"
        INCOME_INCREASE = "INCOME_INCREASE", "Aumentar Receita"
        EMERGENCY_FUND = "EMERGENCY_FUND", "Fundo de Emergência"
        CUSTOM = "CUSTOM", "Personalizada"

    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
        help_text="Identificador único universal (UUID v4)"
    )
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name="goals"
    )
    title = models.CharField(max_length=MAX_TITLE_LENGTH)
    description = models.TextField(blank=True)
    target_amount = models.DecimalField(max_digits=12, decimal_places=2)
    current_amount = models.DecimalField(
        max_digits=12, 
        decimal_places=2, 
        default=Decimal("0.00")
    )
    initial_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal("0.00"),
        help_text="Valor inicial da meta (transações anteriores à criação)"
    )
    deadline = models.DateField(null=True, blank=True)
    
    goal_type = models.CharField(
        max_length=20,
        choices=GoalType.choices,
        default=GoalType.CUSTOM,
        help_text="Tipo da meta"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-created_at",)
        verbose_name = "Meta"
        verbose_name_plural = "Metas"

    def __str__(self) -> str:
        return f"{self.title} ({self.user})"

    def clean(self):
        from django.core.exceptions import ValidationError
        
        self._validate_amounts()
        self._validate_title()
        self._validate_deadline()

    def _validate_amounts(self):
        from django.core.exceptions import ValidationError
        
        if self.target_amount is not None and self.target_amount <= 0:
            raise ValidationError({
                'target_amount': 'O valor alvo da meta deve ser maior que zero.'
            })
        
        if self.target_amount is not None and self.target_amount > MAX_AMOUNT:
            raise ValidationError({
                'target_amount': f'O valor alvo excede o limite máximo (R$ {MAX_AMOUNT:,.2f}).'
            })
        
        if self.current_amount is not None and self.current_amount < 0:
            raise ValidationError({
                'current_amount': 'O valor atual não pode ser negativo.'
            })
        
        if self.initial_amount is not None and self.initial_amount < 0:
            raise ValidationError({
                'initial_amount': 'O valor inicial não pode ser negativo.'
            })

    def _validate_title(self):
        from django.core.exceptions import ValidationError
        
        if self.title and len(self.title.strip()) == 0:
            raise ValidationError({
                'title': 'O título não pode ser vazio.'
            })
        
        if self.title and len(self.title) > MAX_TITLE_LENGTH:
            raise ValidationError({
                'title': f'O título não pode ter mais de {MAX_TITLE_LENGTH} caracteres.'
            })

    def _validate_deadline(self):
        from django.core.exceptions import ValidationError
        
        if self.deadline:
            if self.deadline < timezone.now().date():
                raise ValidationError({
                    'deadline': 'A data limite deve ser no futuro.'
                })
            max_deadline = timezone.now().date() + timedelta(days=MAX_DEADLINE_YEARS * 365)
            if self.deadline > max_deadline:
                raise ValidationError({
                    'deadline': f'A data limite não pode ser mais de {MAX_DEADLINE_YEARS} anos no futuro.'
                })

    @property
    def progress_percentage(self) -> float:
        if self.target_amount == 0:
            return 0.0
        return min(100.0, (float(self.current_amount) / float(self.target_amount)) * 100.0)
