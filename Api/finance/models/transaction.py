"""
Modelos Transaction e TransactionLink - Transações financeiras e vinculações.
"""

from datetime import timedelta
from decimal import Decimal
import uuid

from django.conf import settings
from django.db import models
from django.db.models import Sum
from django.utils import timezone

from .base import (
    MAX_AMOUNT,
    MAX_DESCRIPTION_LENGTH,
    MAX_RECURRENCE_VALUE,
    MAX_FUTURE_DATE_YEARS,
)
from .category import Category


class Transaction(models.Model):
    """
    Transação financeira (receita ou despesa).
    
    Usa UUID como chave primária para melhor integração com frontend.
    """
    
    class TransactionType(models.TextChoices):
        INCOME = "INCOME", "Receita"
        EXPENSE = "EXPENSE", "Despesa"

    class RecurrenceUnit(models.TextChoices):
        DAYS = "DAYS", "Dias"
        WEEKS = "WEEKS", "Semanas"
        MONTHS = "MONTHS", "Meses"

    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
        help_text="Identificador único universal (UUID v4)"
    )
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name="transactions"
    )
    category = models.ForeignKey(
        Category, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name="transactions"
    )
    type = models.CharField(
        max_length=14, 
        choices=TransactionType.choices, 
        db_index=True
    )
    description = models.CharField(max_length=MAX_DESCRIPTION_LENGTH)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    date = models.DateField(default=timezone.now, db_index=True)
    is_recurring = models.BooleanField(default=False)
    recurrence_value = models.PositiveIntegerField(null=True, blank=True)
    recurrence_unit = models.CharField(
        max_length=10,
        choices=RecurrenceUnit.choices,
        null=True,
        blank=True,
    )
    recurrence_end_date = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("-date", "-created_at")
        verbose_name = "Transação"
        verbose_name_plural = "Transações"
        indexes = [
            models.Index(fields=['user', 'date']),
            models.Index(fields=['user', 'type']),
            models.Index(fields=['user', 'category']),
            models.Index(fields=['user', '-date', '-created_at']),
            models.Index(fields=['user', 'deleted_at']),
        ]

    def soft_delete(self):
        self.deleted_at = timezone.now()
        self.save(update_fields=['deleted_at'])

    def __str__(self) -> str:
        return f"{self.description} ({self.amount})"

    def clean(self):
        from django.core.exceptions import ValidationError
        
        self._validate_amount()
        self._validate_description()
        self._validate_recurrence()
        self._validate_category_ownership()
        self._validate_category_type_compatibility()
        self._validate_date()

    def _validate_amount(self):
        from django.core.exceptions import ValidationError
        
        if self.amount is not None and self.amount <= 0:
            raise ValidationError({
                'amount': 'O valor da transação deve ser maior que zero.'
            })
        
        if self.amount is not None and self.amount > MAX_AMOUNT:
            raise ValidationError({
                'amount': f'O valor da transação excede o limite máximo (R$ {MAX_AMOUNT:,.2f}).'
            })

    def _validate_description(self):
        from django.core.exceptions import ValidationError
        
        if self.description and len(self.description.strip()) == 0:
            raise ValidationError({
                'description': 'A descrição não pode ser vazia.'
            })
        
        if self.description and len(self.description) > MAX_DESCRIPTION_LENGTH:
            raise ValidationError({
                'description': f'A descrição não pode ter mais de {MAX_DESCRIPTION_LENGTH} caracteres.'
            })

    def _validate_recurrence(self):
        from django.core.exceptions import ValidationError
        
        if self.is_recurring:
            if not self.recurrence_value:
                raise ValidationError({
                    'recurrence_value': 'Valor de recorrência é obrigatório para transações recorrentes.'
                })
            if not self.recurrence_unit:
                raise ValidationError({
                    'recurrence_unit': 'Unidade de recorrência é obrigatória para transações recorrentes.'
                })
            if self.recurrence_value < 1:
                raise ValidationError({
                    'recurrence_value': 'Valor de recorrência deve ser maior que zero.'
                })
            if self.recurrence_value > MAX_RECURRENCE_VALUE:
                raise ValidationError({
                    'recurrence_value': f'Valor de recorrência não pode exceder {MAX_RECURRENCE_VALUE}.'
                })
        
        if self.recurrence_end_date and self.date:
            if self.recurrence_end_date < self.date:
                raise ValidationError({
                    'recurrence_end_date': 'Data de fim da recorrência não pode ser anterior à data da transação.'
                })

    def _validate_category_ownership(self):
        from django.core.exceptions import ValidationError
        
        if self.category:
            if self.category.user is not None and self.category.user != self.user:
                raise ValidationError({
                    'category': 'A categoria deve pertencer ao mesmo usuário da transação.'
                })

    def _validate_category_type_compatibility(self):
        from django.core.exceptions import ValidationError
        
        if self.category:
            if self.type == self.TransactionType.INCOME and self.category.type != Category.CategoryType.INCOME:
                raise ValidationError({
                    'category': 'Receitas devem usar categorias do tipo INCOME.'
                })
            if self.type == self.TransactionType.EXPENSE and self.category.type == Category.CategoryType.INCOME:
                raise ValidationError({
                    'category': 'Despesas não podem usar categorias do tipo INCOME.'
                })

    def _validate_date(self):
        from django.core.exceptions import ValidationError
        
        if self.date:
            max_future_date = timezone.now().date() + timedelta(days=MAX_FUTURE_DATE_YEARS * 365)
            if self.date > max_future_date:
                raise ValidationError({
                    'date': f'A data não pode ser mais de {MAX_FUTURE_DATE_YEARS} anos no futuro.'
                })

    @property
    def linked_amount(self) -> Decimal:
        outgoing = TransactionLink.objects.filter(
            source_transaction_uuid=self.id
        ).aggregate(total=Sum('linked_amount'))['total'] or Decimal('0')
        
        if self.type == self.TransactionType.INCOME:
            return outgoing
        
        return Decimal('0')
    
    @property
    def outgoing_links(self):
        return TransactionLink.objects.filter(source_transaction_uuid=self.id)
    
    @property
    def incoming_links(self):
        return TransactionLink.objects.filter(target_transaction_uuid=self.id)
    
    @property
    def available_amount(self) -> Decimal:
        return self.amount - self.linked_amount
    
    @property
    def link_percentage(self) -> Decimal:
        if self.amount == 0:
            return Decimal('0')
        return (self.linked_amount / self.amount) * Decimal('100')


class TransactionLink(models.Model):
    """
    Vinculação entre transações (ex: receita pagando despesa).
    
    Permite rastrear de onde veio o dinheiro para cada pagamento.
    """
    
    class LinkType(models.TextChoices):
        EXPENSE_PAYMENT = "EXPENSE_PAYMENT", "Pagamento de despesa"
        INTERNAL_TRANSFER = "INTERNAL_TRANSFER", "Transferência interna"
        SAVINGS_ALLOCATION = "SAVINGS_ALLOCATION", "Alocação para poupança"

    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
        help_text="Identificador único universal (UUID v4)"
    )
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='transaction_links',
        help_text="Usuário proprietário da vinculação"
    )
    
    source_transaction_uuid = models.UUIDField(
        db_index=True,
        help_text="UUID da transação de origem (normalmente uma receita)"
    )
    
    target_transaction_uuid = models.UUIDField(
        db_index=True,
        help_text="UUID da transação de destino (normalmente uma dívida)"
    )
    
    linked_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        help_text="Valor que está sendo transferido/vinculado"
    )
    
    link_type = models.CharField(
        max_length=20,
        choices=LinkType.choices,
        default=LinkType.EXPENSE_PAYMENT
    )
    
    description = models.CharField(
        max_length=MAX_DESCRIPTION_LENGTH,
        blank=True,
        help_text="Descrição opcional da vinculação"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    is_recurring = models.BooleanField(
        default=False,
        help_text="Se True, vincular automaticamente transações recorrentes futuras"
    )

    class Meta:
        ordering = ('-created_at',)
        verbose_name = "Vínculo de Transação"
        verbose_name_plural = "Vínculos de Transações"
        indexes = [
            models.Index(fields=['user', 'created_at']),
            models.Index(fields=['source_transaction_uuid']),
            models.Index(fields=['target_transaction_uuid']),
            models.Index(fields=['user', 'source_transaction_uuid'], name='trl_user_src_uuid_idx'),
            models.Index(fields=['user', 'target_transaction_uuid'], name='trl_user_tgt_uuid_idx'),
        ]
        constraints = [
            models.CheckConstraint(
                check=models.Q(linked_amount__gt=0),
                name='linked_amount_positive'
            )
        ]

    def __str__(self) -> str:
        return f"{self.source_transaction.description} → {self.target_transaction.description} (R$ {self.linked_amount})"

    @property
    def source_transaction(self):
        if not hasattr(self, '_source_transaction_cache'):
            self._source_transaction_cache = Transaction.objects.get(
                id=self.source_transaction_uuid
            )
        return self._source_transaction_cache
    
    @source_transaction.setter
    def source_transaction(self, value):
        if value is None:
            self.source_transaction_uuid = None
            self._source_transaction_cache = None
        else:
            self.source_transaction_uuid = value.id
            self._source_transaction_cache = value
    
    @property
    def target_transaction(self):
        if not hasattr(self, '_target_transaction_cache'):
            self._target_transaction_cache = Transaction.objects.get(
                id=self.target_transaction_uuid
            )
        return self._target_transaction_cache
    
    @target_transaction.setter
    def target_transaction(self, value):
        if value is None:
            self.target_transaction_uuid = None
            self._target_transaction_cache = None
        else:
            self.target_transaction_uuid = value.id
            self._target_transaction_cache = value

    def clean(self):
        from django.core.exceptions import ValidationError
        from django.db import transaction as db_transaction
        
        if self.source_transaction_uuid == self.target_transaction_uuid:
            raise ValidationError(
                "Não é possível vincular uma transação consigo mesma."
            )
        
        if self.source_transaction.user != self.target_transaction.user:
            raise ValidationError(
                "As transações devem pertencer ao mesmo usuário."
            )
        
        if self.user != self.source_transaction.user:
            raise ValidationError(
                "Usuário da vinculação deve ser o mesmo das transações."
            )
        
        if self.link_type == self.LinkType.EXPENSE_PAYMENT:
            if self.source_transaction.type != Transaction.TransactionType.INCOME:
                raise ValidationError(
                    "Para pagamento de despesa, a transação de origem deve ser uma receita (INCOME)."
                )
            
            if self.target_transaction.type != Transaction.TransactionType.EXPENSE:
                raise ValidationError(
                    "Para pagamento de despesa, a transação de destino deve ser uma despesa (EXPENSE)."
                )
        
        if self.linked_amount <= 0:
            raise ValidationError(
                "O valor vinculado deve ser maior que zero."
            )
        
        try:
            with db_transaction.atomic():
                source = Transaction.objects.select_for_update().get(
                    id=self.source_transaction_uuid
                )
                target = Transaction.objects.select_for_update().get(
                    id=self.target_transaction_uuid
                )
                
                if self.linked_amount > source.available_amount:
                    raise ValidationError(
                        f"Valor vinculado (R$ {self.linked_amount}) excede o disponível "
                        f"na transação de origem (R$ {source.available_amount})"
                    )
                
                if target.type == Transaction.TransactionType.EXPENSE:
                    if self.linked_amount > target.available_amount:
                        raise ValidationError(
                            f"Valor vinculado (R$ {self.linked_amount}) excede o pendente "
                            f"na transação de destino (R$ {target.available_amount})"
                        )
        except Transaction.DoesNotExist as e:
            raise ValidationError(f"Transação não encontrada: {e}")
    
    def save(self, *args, **kwargs):
        self.full_clean()
        super().save(*args, **kwargs)
