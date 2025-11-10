from decimal import Decimal

from django.conf import settings
from django.db import models
from django.utils import timezone


class UserProfile(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    level = models.PositiveIntegerField(default=1)
    experience_points = models.PositiveIntegerField(default=0)
    target_tps = models.PositiveIntegerField(default=15, help_text="meta básica de poupança em %")
    target_rdr = models.PositiveIntegerField(default=35, help_text="meta de despesas recorrentes/renda em %")
    target_ili = models.DecimalField(
        max_digits=4,
        decimal_places=1,
        default=Decimal("6.0"),
        help_text="meta de liquidez imediata em meses",
    )
    is_first_access = models.BooleanField(
        default=True,
        help_text="Indica se é o primeiro acesso do usuário (para onboarding)",
    )
    
    # Cache de indicadores para otimização
    cached_tps = models.DecimalField(
        max_digits=6, 
        decimal_places=2, 
        null=True, 
        blank=True,
        help_text="TPS em cache",
    )
    cached_rdr = models.DecimalField(
        max_digits=6, 
        decimal_places=2, 
        null=True, 
        blank=True,
        help_text="RDR em cache",
    )
    cached_ili = models.DecimalField(
        max_digits=6, 
        decimal_places=2, 
        null=True, 
        blank=True,
        help_text="ILI em cache",
    )
    cached_total_income = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Total de receitas em cache",
    )
    cached_total_expense = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Total de despesas em cache",
    )
    indicators_updated_at = models.DateTimeField(
        null=True, 
        blank=True,
        help_text="Última atualização dos indicadores em cache",
    )

    def __str__(self) -> str:
        return f"Perfil {self.user}"  # pragma: no cover
    
    def clean(self):
        """Validações de modelo para UserProfile."""
        from django.core.exceptions import ValidationError
        from decimal import Decimal
        
        # 1. Validar level positivo
        if self.level < 1:
            raise ValidationError({
                'level': 'O nível deve ser no mínimo 1.'
            })
        
        # 2. Validar level máximo razoável
        if self.level > 1000:
            raise ValidationError({
                'level': 'O nível não pode exceder 1000.'
            })
        
        # 3. Validar experience_points não negativo
        if self.experience_points < 0:
            raise ValidationError({
                'experience_points': 'Os pontos de experiência não podem ser negativos.'
            })
        
        # 4. Validar target_tps entre 0 e 100
        if self.target_tps < 0 or self.target_tps > 100:
            raise ValidationError({
                'target_tps': 'A meta de TPS deve estar entre 0 e 100%.'
            })
        
        # 5. Validar target_rdr entre 0 e 100
        if self.target_rdr < 0 or self.target_rdr > 100:
            raise ValidationError({
                'target_rdr': 'A meta de RDR deve estar entre 0 e 100%.'
            })
        
        # 6. Validar target_ili não negativo e razoável
        if self.target_ili < Decimal('0'):
            raise ValidationError({
                'target_ili': 'A meta de ILI não pode ser negativa.'
            })
        
        if self.target_ili > Decimal('100'):
            raise ValidationError({
                'target_ili': 'A meta de ILI não deve exceder 100 meses.'
            })
        
        # 7. Validar cached indicators não negativos
        if self.cached_tps is not None and self.cached_tps < Decimal('0'):
            raise ValidationError({
                'cached_tps': 'TPS em cache não pode ser negativo.'
            })
        
        if self.cached_rdr is not None and self.cached_rdr < Decimal('0'):
            raise ValidationError({
                'cached_rdr': 'RDR em cache não pode ser negativo.'
            })
        
        if self.cached_ili is not None and self.cached_ili < Decimal('0'):
            raise ValidationError({
                'cached_ili': 'ILI em cache não pode ser negativo.'
            })
        
        # 8. Validar cached totals não negativos
        if self.cached_total_income is not None and self.cached_total_income < Decimal('0'):
            raise ValidationError({
                'cached_total_income': 'Total de receitas em cache não pode ser negativo.'
            })
        
        if self.cached_total_expense is not None and self.cached_total_expense < Decimal('0'):
            raise ValidationError({
                'cached_total_expense': 'Total de despesas em cache não pode ser negativo.'
            })
        
        # 9. Validar que indicators_updated_at não é no futuro
        if self.indicators_updated_at:
            from django.utils import timezone
            if self.indicators_updated_at > timezone.now():
                raise ValidationError({
                    'indicators_updated_at': 'Data de atualização dos indicadores não pode ser no futuro.'
                })
        
        # 10. Validar coerência entre level e experience_points
        # Cada nível requer 150 + (level-1) * 50 XP
        expected_min_xp = 0
        for lvl in range(1, self.level):
            expected_min_xp += 150 + (lvl - 1) * 50
        
        if self.experience_points < expected_min_xp:
            raise ValidationError({
                'experience_points': f'XP insuficiente para o nível {self.level}. Mínimo necessário: {expected_min_xp}.'
            })

    @property
    def next_level_threshold(self) -> int:
        base = 150 + (self.level - 1) * 50
        return max(base, 150)
    
    def should_recalculate_indicators(self) -> bool:
        """Verifica se os indicadores precisam ser recalculados (cache expirado)."""
        if self.indicators_updated_at is None:
            return True
        # Recalcular se passou mais de 5 minutos desde última atualização
        from django.utils import timezone
        time_since_update = timezone.now() - self.indicators_updated_at
        return time_since_update.total_seconds() > 300  # 5 minutos


class Category(models.Model):
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

    name = models.CharField(max_length=100)
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
        help_text="Usuário proprietário desta categoria",
    )
    is_system_default = models.BooleanField(
        default=False,
        help_text="Categoria padrão do sistema (criada automaticamente para novos usuários)",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("user", "name", "type")
        ordering = ("name",)
        indexes = [
            models.Index(fields=['user', 'type']),
            models.Index(fields=['user', 'is_system_default']),
        ]

    def __str__(self) -> str:
        owner = self.user or "padrão"
        return f"{self.name} ({owner})"  # pragma: no cover
    
    def clean(self):
        """Validações de modelo para Category."""
        from django.core.exceptions import ValidationError
        import re
        
        # 1. Validar nome não vazio
        if not self.name or len(self.name.strip()) == 0:
            raise ValidationError({
                'name': 'O nome da categoria não pode ser vazio.'
            })
        
        # 2. Validar comprimento máximo do nome
        if len(self.name) > 100:
            raise ValidationError({
                'name': 'O nome da categoria não pode exceder 100 caracteres.'
            })
        
        # 3. Validar formato de cor (hex)
        if self.color:
            if not re.match(r'^#[0-9A-Fa-f]{6}$', self.color):
                raise ValidationError({
                    'color': 'A cor deve estar no formato hexadecimal (#RRGGBB).'
                })
        
        # 4. Validar coerência entre type e group
        type_group_map = {
            self.CategoryType.INCOME: [
                self.CategoryGroup.REGULAR_INCOME,
                self.CategoryGroup.EXTRA_INCOME,
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
                    'group': f'O grupo "{self.get_group_display()}" não é compatível com o tipo "{self.get_type_display()}".'
                })
        
        # 5. Validar que categoria de sistema não pode ser modificada pelo usuário
        if self.pk and self.is_system_default:
            try:
                old_instance = Category.objects.get(pk=self.pk)
                # Permitir apenas mudanças em color e group para categorias de sistema
                if (old_instance.name != self.name or 
                    old_instance.type != self.type or
                    old_instance.user != self.user):
                    raise ValidationError({
                        'is_system_default': 'Categorias padrão do sistema não podem ter nome, tipo ou proprietário alterados.'
                    })
            except Category.DoesNotExist:
                pass
        
        # 6. Validar unicidade case-insensitive do nome para o mesmo usuário
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


class Transaction(models.Model):
    class TransactionType(models.TextChoices):
        INCOME = "INCOME", "Receita"
        EXPENSE = "EXPENSE", "Despesa"

    class RecurrenceUnit(models.TextChoices):
        DAYS = "DAYS", "Dias"
        WEEKS = "WEEKS", "Semanas"
        MONTHS = "MONTHS", "Meses"

    # UUID como Primary Key
    id = models.UUIDField(
        primary_key=True,
        default=None,
        editable=False,
        help_text="Identificador único universal (UUID v4)"
    )
    
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="transactions")
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True, related_name="transactions")
    type = models.CharField(max_length=14, choices=TransactionType.choices, db_index=True)
    description = models.CharField(max_length=255)
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

    class Meta:
        ordering = ("-date", "-created_at")
        indexes = [
            models.Index(fields=['user', 'date']),
            models.Index(fields=['user', 'type']),
            models.Index(fields=['user', 'category']),
            models.Index(fields=['user', '-date', '-created_at']),  # Para listagens otimizadas
        ]
        # Constraints serão adicionadas via migration 0024

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.description} ({self.amount})"
    
    def clean(self):
        """Validações de modelo para Transaction."""
        from django.core.exceptions import ValidationError
        
        # 1. Validar amount positivo
        if self.amount is not None and self.amount <= 0:
            raise ValidationError({
                'amount': 'O valor da transação deve ser maior que zero.'
            })
        
        # 2. Validar amount máximo
        if self.amount is not None and self.amount > Decimal('999999999.99'):
            raise ValidationError({
                'amount': 'O valor da transação excede o limite máximo (R$ 999.999.999,99).'
            })
        
        # 3. Validar descrição não vazia
        if self.description and len(self.description.strip()) == 0:
            raise ValidationError({
                'description': 'A descrição não pode ser vazia.'
            })
        
        # 4. Validar tamanho máximo da descrição
        if self.description and len(self.description) > 255:
            raise ValidationError({
                'description': 'A descrição não pode ter mais de 255 caracteres.'
            })
        
        # 5. Validar recorrência
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
            if self.recurrence_value > 365:
                raise ValidationError({
                    'recurrence_value': 'Valor de recorrência não pode exceder 365.'
                })
        
        # 6. Validar data de fim de recorrência
        if self.recurrence_end_date and self.date:
            if self.recurrence_end_date < self.date:
                raise ValidationError({
                    'recurrence_end_date': 'Data de fim da recorrência não pode ser anterior à data da transação.'
                })
        
        # 7. Validar categoria pertence ao usuário
        if self.category and self.category.user != self.user:
            raise ValidationError({
                'category': 'A categoria deve pertencer ao mesmo usuário da transação.'
            })
        
        # 8. Validar tipo de categoria compatível
        if self.category:
            if self.type == self.TransactionType.INCOME and self.category.type != Category.CategoryType.INCOME:
                raise ValidationError({
                    'category': 'Receitas devem usar categorias do tipo INCOME.'
                })
            if self.type == self.TransactionType.EXPENSE and self.category.type == Category.CategoryType.INCOME:
                raise ValidationError({
                    'category': 'Despesas não podem usar categorias do tipo INCOME.'
                })
        
        # 9. Validar data não muito no futuro (máximo 5 anos)
        if self.date:
            from datetime import timedelta
            max_future_date = timezone.now().date() + timedelta(days=5*365)
            if self.date > max_future_date:
                raise ValidationError({
                    'date': 'A data não pode ser mais de 5 anos no futuro.'
                })
    
    @property
    def linked_amount(self) -> Decimal:
        """
        Retorna o valor total vinculado desta transação.
        - Para receitas (source): soma dos outgoing_links
        - Para dívidas (target): soma dos incoming_links
        """
        from django.db.models import Sum
        
        # Soma links de saída (quando esta é a source)
        outgoing = TransactionLink.objects.filter(
            source_transaction_uuid=self.id
        ).aggregate(total=Sum('linked_amount'))['total'] or Decimal('0')
        
        # Soma links de entrada (quando esta é a target)
        incoming = TransactionLink.objects.filter(
            target_transaction_uuid=self.id
        ).aggregate(total=Sum('linked_amount'))['total'] or Decimal('0')
        
        # Para receitas, usar outgoing
        if self.type == self.TransactionType.INCOME:
            return outgoing
        
        return Decimal('0')
    
    @property
    def outgoing_links(self):
        """Helper para compatibilidade: retorna links de saída (source)."""
        return TransactionLink.objects.filter(source_transaction_uuid=self.id)
    
    @property
    def incoming_links(self):
        """Helper para compatibilidade: retorna links de entrada (target)."""
        return TransactionLink.objects.filter(target_transaction_uuid=self.id)
    
    @property
    def available_amount(self) -> Decimal:
        """
        Retorna o valor disponível desta transação (não vinculado).
        - Para receitas: amount - linked_amount (quanto ainda pode ser usado)
        - Para dívidas: amount - linked_amount (quanto ainda deve)
        """
        return self.amount - self.linked_amount
    
    @property
    def link_percentage(self) -> Decimal:
        """
        Retorna o percentual vinculado (0-100).
        Útil para exibir barras de progresso.
        """
        if self.amount == 0:
            return Decimal('0')
        return (self.linked_amount / self.amount) * Decimal('100')


class TransactionLink(models.Model):
    """
    Representa uma vinculação entre transações que se anulam parcial ou totalmente.
    Usado principalmente para pagamento de despesas: vincular receita → despesa.
    
    Exemplo:
    - Receita (Salário) R$ 5.000 → Despesa (Conta de Luz) R$ 200
    - Após vinculação:
      - Salário tem R$ 4.800 disponíveis
      - Conta de Luz está paga
    """
    
    class LinkType(models.TextChoices):
        EXPENSE_PAYMENT = "EXPENSE_PAYMENT", "Pagamento de despesa"
        INTERNAL_TRANSFER = "INTERNAL_TRANSFER", "Transferência interna"
        SAVINGS_ALLOCATION = "SAVINGS_ALLOCATION", "Alocação para poupança"
    
    # UUID como Primary Key
    id = models.UUIDField(
        primary_key=True,
        default=None,
        editable=False,
        help_text="Identificador único universal (UUID v4)"
    )
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='transaction_links',
        help_text="Usuário proprietário da vinculação"
    )
    
    # UUID da transação de origem (de onde vem o dinheiro)
    # NOTA: Agora usa UUID em vez de FK tradicional
    source_transaction_uuid = models.UUIDField(
        db_index=True,
        help_text="UUID da transação de origem (normalmente uma receita)"
    )
    
    # UUID da transação de destino (para onde vai o dinheiro)
    # NOTA: Agora usa UUID em vez de FK tradicional
    target_transaction_uuid = models.UUIDField(
        db_index=True,
        help_text="UUID da transação de destino (normalmente uma dívida)"
    )
    
    # Propriedades para acessar as transações via UUID (com cache)
    @property
    def source_transaction(self):
        """Retorna a transação de origem via lookup de UUID."""
        if not hasattr(self, '_source_transaction_cache'):
            self._source_transaction_cache = Transaction.objects.get(
                id=self.source_transaction_uuid
            )
        return self._source_transaction_cache
    
    @source_transaction.setter
    def source_transaction(self, value):
        """Define a transação de origem (aceita objeto Transaction)."""
        if value is None:
            self.source_transaction_uuid = None
            self._source_transaction_cache = None
        else:
            self.source_transaction_uuid = value.id
            self._source_transaction_cache = value
    
    @property
    def target_transaction(self):
        """Retorna a transação de destino via lookup de UUID."""
        if not hasattr(self, '_target_transaction_cache'):
            self._target_transaction_cache = Transaction.objects.get(
                id=self.target_transaction_uuid
            )
        return self._target_transaction_cache
    
    @target_transaction.setter
    def target_transaction(self, value):
        """Define a transação de destino (aceita objeto Transaction)."""
        if value is None:
            self.target_transaction_uuid = None
            self._target_transaction_cache = None
        else:
            self.target_transaction_uuid = value.id
            self._target_transaction_cache = value
    
    # Valor vinculado (pode ser parcial)
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
    
    # Metadados
    description = models.CharField(
        max_length=255,
        blank=True,
        help_text="Descrição opcional da vinculação"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # Vincular recorrências se aplicável
    is_recurring = models.BooleanField(
        default=False,
        help_text="Se True, vincular automaticamente transações recorrentes futuras"
    )
    
    class Meta:
        ordering = ('-created_at',)
        indexes = [
            models.Index(fields=['user', 'created_at']),
            models.Index(fields=['source_transaction_uuid']),
            models.Index(fields=['target_transaction_uuid']),
            models.Index(fields=['user', 'source_transaction_uuid'], name='trl_user_src_uuid_idx'),
            models.Index(fields=['user', 'target_transaction_uuid'], name='trl_user_tgt_uuid_idx'),
        ]
        # Prevenir vinculações duplicadas
        constraints = [
            models.CheckConstraint(
                check=models.Q(linked_amount__gt=0),
                name='linked_amount_positive'
            )
        ]
    
    def __str__(self) -> str:
        return f"{self.source_transaction.description} → {self.target_transaction.description} (R$ {self.linked_amount})"
    
    def clean(self):
        """
        Validações personalizadas robustas.
        ATUALIZADO: Inclui proteção contra race conditions e validações adicionais.
        """
        from django.core.exceptions import ValidationError
        from django.db import transaction as db_transaction
        
        # 1. Validar que não está vinculando transação consigo mesma
        if self.source_transaction_uuid == self.target_transaction_uuid:
            raise ValidationError(
                "Não é possível vincular uma transação consigo mesma."
            )
        
        # 2. Validar que source e target pertencem ao mesmo usuário
        if self.source_transaction.user != self.target_transaction.user:
            raise ValidationError(
                "As transações devem pertencer ao mesmo usuário."
            )
        
        # 3. Validar que user da vinculação é o mesmo das transações
        if self.user != self.source_transaction.user:
            raise ValidationError(
                "Usuário da vinculação deve ser o mesmo das transações."
            )
        
        # 4. Validar tipo de transação para diferentes link_types
        if self.link_type == self.LinkType.EXPENSE_PAYMENT:
            # Source deve ser receita
            if self.source_transaction.type != Transaction.TransactionType.INCOME:
                raise ValidationError(
                    "Para pagamento de despesa, a transação de origem deve ser uma receita (INCOME)."
                )
            
            # Target deve ser uma despesa
            if self.target_transaction.type != Transaction.TransactionType.EXPENSE:
                raise ValidationError(
                    "Para pagamento de despesa, a transação de destino deve ser uma despesa (EXPENSE)."
                )
        
        elif self.link_type == self.LinkType.EXPENSE_PAYMENT:
            # Source deve ser receita
            if self.source_transaction.type != Transaction.TransactionType.INCOME:
                raise ValidationError(
                    "Para pagamento de despesa, a transação de origem deve ser uma receita (INCOME)."
                )
            
            # Target deve ser despesa
            if self.target_transaction.type != Transaction.TransactionType.EXPENSE:
                raise ValidationError(
                    "Para pagamento de despesa, a transação de destino deve ser uma despesa (EXPENSE)."
                )
        
        # 5. Validar amount positivo
        if self.linked_amount <= 0:
            raise ValidationError(
                "O valor vinculado deve ser maior que zero."
            )
        
        # 6. Validar valor disponível com lock (previne race conditions)
        try:
            with db_transaction.atomic():
                # Recarregar transações com SELECT FOR UPDATE
                source = Transaction.objects.select_for_update().get(
                    id=self.source_transaction_uuid
                )
                target = Transaction.objects.select_for_update().get(
                    id=self.target_transaction_uuid
                )
                
                # Validar amount disponível na source
                if self.linked_amount > source.available_amount:
                    raise ValidationError(
                        f"Valor vinculado (R$ {self.linked_amount}) excede o disponível "
                        f"na transação de origem (R$ {source.available_amount})"
                    )
                
                # Validar amount disponível na target (para despesas)
                if target.type == Transaction.TransactionType.EXPENSE:
                    if self.linked_amount > target.available_amount:
                        raise ValidationError(
                            f"Valor vinculado (R$ {self.linked_amount}) excede o pendente "
                            f"na transação de destino (R$ {target.available_amount})"
                        )
        except Transaction.DoesNotExist as e:
            raise ValidationError(f"Transação não encontrada: {e}")
        
        # 6. Validar que linked_amount é positivo
        if self.linked_amount <= 0:
            raise ValidationError(
                "O valor vinculado deve ser maior que zero."
            )
    
    def save(self, *args, **kwargs):
        self.full_clean()
        super().save(*args, **kwargs)


class Goal(models.Model):
    """
    Modelo de Metas Financeiras.
    
    Tipos de metas:
    - SAVINGS: Juntar dinheiro (pode monitorar categorias específicas via tracked_categories)
    - CATEGORY_EXPENSE: Reduzir gastos em categoria específica
    - CATEGORY_INCOME: Aumentar receita em categoria específica
    - DEBT_REDUCTION: Reduzir dívidas (pode monitorar categorias específicas via tracked_categories)
    - CUSTOM: Meta personalizada (atualização manual)
    """
    
    class GoalType(models.TextChoices):
        SAVINGS = "SAVINGS", "Juntar Dinheiro"
        CATEGORY_EXPENSE = "CATEGORY_EXPENSE", "Reduzir Gastos"
        CATEGORY_INCOME = "CATEGORY_INCOME", "Aumentar Receita"
        DEBT_REDUCTION = "DEBT_REDUCTION", "Reduzir Dívidas"
        CUSTOM = "CUSTOM", "Personalizada"
    
    class TrackingPeriod(models.TextChoices):
        MONTHLY = "MONTHLY", "Mensal"
        QUARTERLY = "QUARTERLY", "Trimestral"
        TOTAL = "TOTAL", "Total"
    
    # UUID como Primary Key
    id = models.UUIDField(
        primary_key=True,
        default=None,
        editable=False,
        help_text="Identificador único universal (UUID v4)"
    )
    
    # Campos básicos
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="goals")
    title = models.CharField(max_length=150)
    description = models.TextField(blank=True)
    target_amount = models.DecimalField(max_digits=12, decimal_places=2)
    current_amount = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    initial_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal("0.00"),
        help_text="Valor inicial da meta (transações anteriores à criação)"
    )
    deadline = models.DateField(null=True, blank=True)
    
    # Novos campos para metas avançadas
    goal_type = models.CharField(
        max_length=20,
        choices=GoalType.choices,
        default=GoalType.CUSTOM,
        help_text="Tipo da meta"
    )
    target_category = models.ForeignKey(
        Category,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="goals",
        help_text="Categoria principal vinculada (para metas CATEGORY_* - retrocompatibilidade)"
    )
    tracked_categories = models.ManyToManyField(
        Category,
        blank=True,
        related_name="tracked_in_goals",
        help_text="Categorias monitoradas para atualização automática (usado em metas como Juntar Dinheiro)"
    )
    auto_update = models.BooleanField(
        default=False,
        help_text="Atualizar automaticamente com base nas transações"
    )
    tracking_period = models.CharField(
        max_length=10,
        choices=TrackingPeriod.choices,
        default=TrackingPeriod.TOTAL,
        help_text="Período de rastreamento"
    )
    is_reduction_goal = models.BooleanField(
        default=False,
        help_text="True se o objetivo é reduzir (gastos/dívidas)"
    )
    
    # Metadados
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.title} ({self.user})"
    
    def clean(self):
        """Validações de modelo para Goal."""
        from django.core.exceptions import ValidationError
        
        # 1. Validar target_amount positivo
        if self.target_amount is not None and self.target_amount <= 0:
            raise ValidationError({
                'target_amount': 'O valor alvo da meta deve ser maior que zero.'
            })
        
        # 2. Validar target_amount máximo
        if self.target_amount is not None and self.target_amount > Decimal('999999999.99'):
            raise ValidationError({
                'target_amount': 'O valor alvo excede o limite máximo (R$ 999.999.999,99).'
            })
        
        # 3. Validar current_amount não negativo
        if self.current_amount is not None and self.current_amount < 0:
            raise ValidationError({
                'current_amount': 'O valor atual não pode ser negativo.'
            })
        
        # 4. Validar initial_amount não negativo
        if self.initial_amount is not None and self.initial_amount < 0:
            raise ValidationError({
                'initial_amount': 'O valor inicial não pode ser negativo.'
            })
        
        # 5. Validar título não vazio
        if self.title and len(self.title.strip()) == 0:
            raise ValidationError({
                'title': 'O título não pode ser vazio.'
            })
        
        # 6. Validar tamanho do título
        if self.title and len(self.title) > 150:
            raise ValidationError({
                'title': 'O título não pode ter mais de 150 caracteres.'
            })
        
        # 7. Validar deadline no futuro
        if self.deadline:
            if self.deadline < timezone.now().date():
                raise ValidationError({
                    'deadline': 'A data limite deve ser no futuro.'
                })
            # Limite máximo de 10 anos no futuro
            from datetime import timedelta
            max_deadline = timezone.now().date() + timedelta(days=10*365)
            if self.deadline > max_deadline:
                raise ValidationError({
                    'deadline': 'A data limite não pode ser mais de 10 anos no futuro.'
                })
        
        # 8. Validar target_category pertence ao usuário
        if self.target_category and self.target_category.user != self.user:
            raise ValidationError({
                'target_category': 'A categoria alvo deve pertencer ao mesmo usuário.'
            })
        
        # 9. Validar goal_type com target_category
        if self.goal_type in [self.GoalType.CATEGORY_EXPENSE, self.GoalType.CATEGORY_INCOME]:
            if not self.target_category:
                raise ValidationError({
                    'target_category': f'Meta do tipo {self.get_goal_type_display()} requer uma categoria alvo.'
                })
        
        # 10. Validar tipo de categoria compatível com goal_type
        if self.target_category and self.goal_type == self.GoalType.CATEGORY_EXPENSE:
            if self.target_category.type != Category.CategoryType.EXPENSE:
                raise ValidationError({
                    'target_category': 'Meta de redução de gastos requer categoria do tipo EXPENSE.'
                })
        
        if self.target_category and self.goal_type == self.GoalType.CATEGORY_INCOME:
            if self.target_category.type != Category.CategoryType.INCOME:
                raise ValidationError({
                    'target_category': 'Meta de aumento de receita requer categoria do tipo INCOME.'
                })
        
        # 11. Validar is_reduction_goal coerente
        if self.goal_type in [self.GoalType.CATEGORY_EXPENSE, self.GoalType.DEBT_REDUCTION]:
            if not self.is_reduction_goal:
                raise ValidationError({
                    'is_reduction_goal': 'Metas de redução devem ter is_reduction_goal=True.'
                })
        
        # 12. Validar current_amount não excede target em metas não-redução
        if not self.is_reduction_goal:
            if self.current_amount is not None and self.target_amount is not None:
                if self.current_amount > self.target_amount * Decimal('1.5'):  # Tolera 50% a mais
                    raise ValidationError({
                        'current_amount': 'O valor atual excede significativamente o valor alvo.'
                    })
    
    @property
    def progress_percentage(self) -> float:
        """Calcula a porcentagem de progresso da meta."""
        if self.target_amount == 0:
            return 0.0
        return min(100.0, (float(self.current_amount) / float(self.target_amount)) * 100.0)
    
    def get_tracking_date_range(self):
        """Retorna o intervalo de datas para rastreamento baseado no período."""
        from django.utils import timezone
        
        end_date = self.deadline or timezone.now().date()
        
        if self.tracking_period == self.TrackingPeriod.MONTHLY:
            # Primeiro dia do mês atual
            start_date = timezone.now().replace(day=1).date()
        elif self.tracking_period == self.TrackingPeriod.QUARTERLY:
            # Primeiro dia do trimestre atual
            current = timezone.now()
            quarter_month = ((current.month - 1) // 3) * 3 + 1
            start_date = current.replace(month=quarter_month, day=1).date()
        else:  # TOTAL
            start_date = self.created_at.date()
        
        return start_date, end_date
    
    def get_related_transactions(self):
        """Retorna as transações relacionadas a esta meta."""
        start_date, end_date = self.get_tracking_date_range()
        
        # Base queryset
        qs = Transaction.objects.filter(
            user=self.user,
            date__range=[start_date, end_date]
        )
        
        # Filtrar por tipo de meta
        if self.goal_type == self.GoalType.SAVINGS:
            # Se há categorias específicas sendo monitoradas, usa elas
            if self.tracked_categories.exists():
                qs = qs.filter(category__in=self.tracked_categories.all())
            else:
                # Comportamento padrão: SAVINGS e INVESTMENT
                qs = qs.filter(
                    category__group__in=[Category.CategoryGroup.SAVINGS, Category.CategoryGroup.INVESTMENT]
                )
        elif self.goal_type == self.GoalType.CATEGORY_EXPENSE:
            # Gastos em categoria específica (retrocompatibilidade com target_category)
            if self.target_category:
                qs = qs.filter(
                    category=self.target_category,
                    type=Transaction.TransactionType.EXPENSE
                )
            else:
                return Transaction.objects.none()
        elif self.goal_type == self.GoalType.CATEGORY_INCOME:
            # Receitas em categoria específica (retrocompatibilidade com target_category)
            if self.target_category:
                qs = qs.filter(
                    category=self.target_category,
                    type=Transaction.TransactionType.INCOME
                )
            else:
                return Transaction.objects.none()
        elif self.goal_type == self.GoalType.DEBT_REDUCTION:
            # Se há categorias específicas sendo monitoradas, usa elas
            if self.tracked_categories.exists():
                qs = qs.filter(category__in=self.tracked_categories.all())
            else:
                # Comportamento padrão: todas as dívidas
                qs = qs.filter(
                    category__group=Category.CategoryGroup.DEBT
                )
        else:  # CUSTOM
            # Para metas personalizadas com atualização automática,
            # monitorar categorias específicas se definidas
            if self.tracked_categories.exists():
                qs = qs.filter(category__in=self.tracked_categories.all())
            else:
                # Sem categorias definidas, não retorna transações
                return Transaction.objects.none()
        
        return qs.order_by('-date')


class Mission(models.Model):
    class Difficulty(models.TextChoices):
        EASY = "EASY", "Fácil"
        MEDIUM = "MEDIUM", "Média"
        HARD = "HARD", "Difícil"

    class MissionType(models.TextChoices):
        ONBOARDING = "ONBOARDING", "Integração inicial"
        TPS_IMPROVEMENT = "TPS_IMPROVEMENT", "Melhoria de poupança"
        RDR_REDUCTION = "RDR_REDUCTION", "Redução de dívidas"
        ILI_BUILDING = "ILI_BUILDING", "Construção de reserva"
        ADVANCED = "ADVANCED", "Avançado"
    
    class ValidationType(models.TextChoices):
        SNAPSHOT = "SNAPSHOT", "Comparação pontual (inicial vs atual)"
        TEMPORAL = "TEMPORAL", "Manter critério por período"
        CATEGORY_REDUCTION = "CATEGORY_REDUCTION", "Reduzir gasto em categoria"
        CATEGORY_LIMIT = "CATEGORY_LIMIT", "Não exceder limite em categoria"
        GOAL_PROGRESS = "GOAL_PROGRESS", "Progredir em meta específica"
        SAVINGS_INCREASE = "SAVINGS_INCREASE", "Aumentar poupança"
        CONSISTENCY = "CONSISTENCY", "Manter consistência/streak"

    title = models.CharField(max_length=150)
    description = models.TextField()
    reward_points = models.PositiveIntegerField(default=50)
    difficulty = models.CharField(max_length=8, choices=Difficulty.choices, default=Difficulty.MEDIUM)
    mission_type = models.CharField(
        max_length=20,
        choices=MissionType.choices,
        default=MissionType.ONBOARDING,
        help_text="Tipo de missão que determina quando será aplicada",
    )
    priority = models.PositiveIntegerField(
        default=1,
        help_text="Ordem de prioridade para aplicação automática (menor = mais prioritário)",
    )
    target_tps = models.PositiveIntegerField(null=True, blank=True, help_text="TPS mínimo necessário (se aplicável)")
    target_rdr = models.PositiveIntegerField(null=True, blank=True, help_text="RDR máximo permitido (se aplicável)")
    min_ili = models.DecimalField(max_digits=4, decimal_places=1, null=True, blank=True, help_text="ILI mínimo necessário")
    max_ili = models.DecimalField(max_digits=4, decimal_places=1, null=True, blank=True, help_text="ILI máximo permitido")
    min_transactions = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Número mínimo de transações registradas para desbloquear esta missão",
    )
    duration_days = models.PositiveIntegerField(default=30)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # === NOVOS CAMPOS PARA VALIDAÇÃO AVANÇADA ===
    
    # Tipo refinado de validação
    validation_type = models.CharField(
        max_length=30,
        choices=ValidationType.choices,
        default=ValidationType.SNAPSHOT,
        help_text="Tipo de validação que determina como o progresso é calculado",
    )
    
    # Para validação temporal
    requires_consecutive_days = models.BooleanField(
        default=False,
        help_text="Se requer X dias CONSECUTIVOS atendendo critério",
    )
    min_consecutive_days = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Número mínimo de dias consecutivos",
    )
    
    # Para missões de categoria
    target_category = models.ForeignKey(
        'Category',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='missions',
        help_text="Categoria alvo para missões de redução/limite",
    )
    target_reduction_percent = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="% de redução alvo (ex: 15 = reduzir 15%)",
    )
    category_spending_limit = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Limite de gasto em reais para a categoria",
    )
    
    # Para missões de meta
    target_goal = models.ForeignKey(
        'Goal',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='missions',
        help_text="Meta alvo (se missão for sobre meta específica)",
    )
    goal_progress_target = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="% de progresso alvo na meta (ex: 80 = completar 80%)",
    )
    
    # Para missões de poupança
    savings_increase_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Valor em R$ para aumentar poupança",
    )
    
    # Para missões de consistência
    requires_daily_action = models.BooleanField(
        default=False,
        help_text="Se requer ação diária (registrar transação, etc)",
    )
    min_daily_actions = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Número mínimo de ações diárias necessárias",
    )

    class Meta:
        ordering = ("priority", "title")

    def __str__(self) -> str:  # pragma: no cover
        return self.title
    
    def clean(self):
        """Validações de modelo para Mission."""
        from django.core.exceptions import ValidationError
        
        # 1. Validar reward_points positivo
        if self.reward_points is not None and self.reward_points <= 0:
            raise ValidationError({
                'reward_points': 'A recompensa de pontos deve ser maior que zero.'
            })
        
        # 2. Validar reward_points máximo
        if self.reward_points is not None and self.reward_points > 10000:
            raise ValidationError({
                'reward_points': 'A recompensa não pode exceder 10.000 pontos.'
            })
        
        # 3. Validar duration_days positivo
        if self.duration_days is not None and self.duration_days <= 0:
            raise ValidationError({
                'duration_days': 'A duração deve ser maior que zero dias.'
            })
        
        # 4. Validar duration_days máximo
        if self.duration_days is not None and self.duration_days > 365:
            raise ValidationError({
                'duration_days': 'A duração não pode exceder 365 dias.'
            })
        
        # 5. Validar título não vazio
        if self.title and len(self.title.strip()) == 0:
            raise ValidationError({
                'title': 'O título não pode ser vazio.'
            })
        
        # 6. Validar descrição não vazia
        if self.description and len(self.description.strip()) == 0:
            raise ValidationError({
                'description': 'A descrição não pode ser vazia.'
            })
        
        # 7. Validar ranges de indicadores
        if self.target_tps is not None and (self.target_tps < 0 or self.target_tps > 100):
            raise ValidationError({
                'target_tps': 'TPS deve estar entre 0 e 100%.'
            })
        
        if self.target_rdr is not None and (self.target_rdr < 0 or self.target_rdr > 100):
            raise ValidationError({
                'target_rdr': 'RDR deve estar entre 0 e 100%.'
            })
        
        if self.min_ili is not None and self.min_ili < 0:
            raise ValidationError({
                'min_ili': 'ILI mínimo não pode ser negativo.'
            })
        
        if self.max_ili is not None and self.max_ili < 0:
            raise ValidationError({
                'max_ili': 'ILI máximo não pode ser negativo.'
            })
        
        # 8. Validar min < max para ILI
        if self.min_ili is not None and self.max_ili is not None:
            if self.min_ili > self.max_ili:
                raise ValidationError({
                    'min_ili': 'ILI mínimo não pode ser maior que ILI máximo.'
                })
        
        # 9. Validar priority positiva
        if self.priority is not None and self.priority < 1:
            raise ValidationError({
                'priority': 'Prioridade deve ser maior ou igual a 1.'
            })
        
        # 10. Validar campos de validação temporal
        if self.requires_consecutive_days:
            if not self.min_consecutive_days or self.min_consecutive_days < 1:
                raise ValidationError({
                    'min_consecutive_days': 'Número mínimo de dias consecutivos é obrigatório.'
                })
            if self.min_consecutive_days > self.duration_days:
                raise ValidationError({
                    'min_consecutive_days': 'Dias consecutivos não pode exceder duração da missão.'
                })
        
        # 11. Validar valores de categoria
        if self.target_category_amount is not None and self.target_category_amount < 0:
            raise ValidationError({
                'target_category_amount': 'Valor alvo não pode ser negativo.'
            })
        
        if self.savings_increase_amount is not None and self.savings_increase_amount <= 0:
            raise ValidationError({
                'savings_increase_amount': 'Aumento de poupança deve ser positivo.'
            })
        
        # 12. Validar validação temporal
        if self.validation_type == self.ValidationType.TEMPORAL:
            if self.duration_days < 7:
                raise ValidationError({
                    'duration_days': 'Missões temporais devem ter pelo menos 7 dias de duração.'
                })
        
        # 13. Validar missões de consistência
        if self.requires_daily_action:
            if not self.min_daily_actions or self.min_daily_actions < 1:
                raise ValidationError({
                    'min_daily_actions': 'Número mínimo de ações diárias é obrigatório.'
                })
            if self.min_daily_actions > 100:
                raise ValidationError({
                    'min_daily_actions': 'Número de ações diárias não pode exceder 100.'
                })


class MissionProgress(models.Model):
    class Status(models.TextChoices):
        PENDING = "PENDING", "Pendente"
        ACTIVE = "ACTIVE", "Em andamento"
        COMPLETED = "COMPLETED", "Concluída"
        FAILED = "FAILED", "Falhou"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="mission_progress")
    mission = models.ForeignKey(Mission, on_delete=models.CASCADE, related_name="progress")
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    progress = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal("0.00"))
    initial_tps = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    initial_rdr = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    initial_ili = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    initial_transaction_count = models.PositiveIntegerField(default=0)
    started_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # === NOVOS CAMPOS PARA RASTREAMENTO AVANÇADO ===
    
    # Baseline de categoria (salvo ao iniciar)
    baseline_category_spending = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Gasto médio na categoria antes da missão começar",
    )
    baseline_period_days = models.PositiveIntegerField(
        default=30,
        help_text="Número de dias usados para calcular baseline",
    )
    
    # Para missões de meta
    initial_goal_progress = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="% de progresso da meta quando missão começou",
    )
    
    # Para missões de poupança
    initial_savings_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Total em poupança quando missão começou",
    )
    
    # Rastreamento de streak/consistência
    current_streak = models.PositiveIntegerField(
        default=0,
        help_text="Dias consecutivos atuais atendendo critério",
    )
    max_streak = models.PositiveIntegerField(
        default=0,
        help_text="Maior streak alcançado nesta missão",
    )
    days_met_criteria = models.PositiveIntegerField(
        default=0,
        help_text="Total de dias que atendeu critério (não necessariamente consecutivos)",
    )
    days_violated_criteria = models.PositiveIntegerField(
        default=0,
        help_text="Total de dias que violou critério",
    )
    last_violation_date = models.DateField(
        null=True,
        blank=True,
        help_text="Data da última violação de critério",
    )
    
    # Metadados de validação
    validation_details = models.JSONField(
        default=dict,
        help_text="Detalhes de como validação está sendo feita",
    )

    class Meta:
        unique_together = ("user", "mission")
        ordering = ("mission__priority", "mission__title")

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.user} - {self.mission}"
    
    def clean(self):
        """Validações de modelo para MissionProgress."""
        from django.core.exceptions import ValidationError
        from decimal import Decimal
        
        # 1. Validar que progress está entre 0 e 100
        if self.progress < Decimal('0'):
            raise ValidationError({
                'progress': 'O progresso não pode ser negativo.'
            })
        
        if self.progress > Decimal('100'):
            raise ValidationError({
                'progress': 'O progresso não pode exceder 100%.'
            })
        
        # 2. Validar transitions de status válidas
        if self.pk:  # Se é update
            try:
                old_instance = MissionProgress.objects.get(pk=self.pk)
                # Se estava COMPLETED, não pode voltar para IN_PROGRESS
                if old_instance.status == self.MissionStatus.COMPLETED and \
                   self.status == self.MissionStatus.IN_PROGRESS:
                    raise ValidationError({
                        'status': 'Uma missão concluída não pode voltar para em progresso.'
                    })
                
                # Se estava FAILED, não pode ir para COMPLETED
                if old_instance.status == self.MissionStatus.FAILED and \
                   self.status == self.MissionStatus.COMPLETED:
                    raise ValidationError({
                        'status': 'Uma missão falha não pode ser marcada como concluída.'
                    })
            except MissionProgress.DoesNotExist:
                pass
        
        # 3. Validar que se status é COMPLETED, progress deve ser 100
        if self.status == self.MissionStatus.COMPLETED and self.progress < Decimal('100'):
            raise ValidationError({
                'status': 'Missão só pode ser concluída quando progresso atingir 100%.'
            })
        
        # 4. Validar que completed_at é set apenas se status é COMPLETED
        if self.completed_at and self.status != self.MissionStatus.COMPLETED:
            raise ValidationError({
                'completed_at': 'Data de conclusão só deve ser definida para missões concluídas.'
            })
        
        # 5. Validar que completed_at não é no futuro
        if self.completed_at:
            from django.utils import timezone
            if self.completed_at > timezone.now():
                raise ValidationError({
                    'completed_at': 'Data de conclusão não pode ser no futuro.'
                })
        
        # 6. Validar que started_at < completed_at
        if self.started_at and self.completed_at:
            if self.started_at >= self.completed_at:
                raise ValidationError({
                    'completed_at': 'Data de conclusão deve ser posterior ao início.'
                })
        
        # 7. Validar indicadores não negativos
        if self.current_tps is not None and self.current_tps < Decimal('0'):
            raise ValidationError({
                'current_tps': 'TPS não pode ser negativo.'
            })
        
        if self.current_rdr is not None and self.current_rdr < Decimal('0'):
            raise ValidationError({
                'current_rdr': 'RDR não pode ser negativo.'
            })
        
        if self.current_ili is not None and self.current_ili < Decimal('0'):
            raise ValidationError({
                'current_ili': 'ILI não pode ser negativo.'
            })
        
        # 8. Validar streaks
        if self.current_streak < 0:
            raise ValidationError({
                'current_streak': 'Streak atual não pode ser negativo.'
            })
        
        if self.max_streak < self.current_streak:
            raise ValidationError({
                'max_streak': 'Streak máximo deve ser maior ou igual ao streak atual.'
            })
        
        # 9. Validar days_met_criteria e days_violated_criteria
        if self.days_met_criteria < 0:
            raise ValidationError({
                'days_met_criteria': 'Dias que atendeu critério não pode ser negativo.'
            })
        
        if self.days_violated_criteria < 0:
            raise ValidationError({
                'days_violated_criteria': 'Dias que violou critério não pode ser negativo.'
            })
        
        # 10. Validar initial_goal_progress entre 0 e 100
        if self.initial_goal_progress is not None:
            if self.initial_goal_progress < Decimal('0') or self.initial_goal_progress > Decimal('100'):
                raise ValidationError({
                    'initial_goal_progress': 'Progresso inicial da meta deve estar entre 0 e 100%.'
                })
        
        # 11. Validar initial_savings_amount não negativo
        if self.initial_savings_amount is not None and self.initial_savings_amount < Decimal('0'):
            raise ValidationError({
                'initial_savings_amount': 'Valor inicial de poupança não pode ser negativo.'
            })
        
        # 12. Validar baseline_period_days razoável
        if self.baseline_period_days < 1 or self.baseline_period_days > 365:
            raise ValidationError({
                'baseline_period_days': 'Período de baseline deve estar entre 1 e 365 dias.'
            })


class XPTransaction(models.Model):
    """
    Modelo de auditoria para rastrear concessões de XP.
    Facilita debugging e análise de progressão de usuários.
    """
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="xp_transactions",
    )
    mission_progress = models.ForeignKey(
        MissionProgress,
        on_delete=models.CASCADE,
        related_name="xp_transactions",
    )
    points_awarded = models.PositiveIntegerField(
        help_text="Quantidade de XP concedida",
    )
    level_before = models.PositiveIntegerField(
        help_text="Nível do usuário antes da recompensa",
    )
    level_after = models.PositiveIntegerField(
        help_text="Nível do usuário após a recompensa",
    )
    xp_before = models.PositiveIntegerField(
        help_text="XP do usuário antes da recompensa",
    )
    xp_after = models.PositiveIntegerField(
        help_text="XP do usuário após a recompensa",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at",)
        indexes = [
            models.Index(fields=['user', '-created_at']),
        ]

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.user} - {self.points_awarded} XP - {self.mission_progress.mission.title}"


class UserDailySnapshot(models.Model):
    """
    Snapshot diário dos indicadores financeiros do usuário.
    
    Criado automaticamente todo dia às 23:59 via Celery Beat.
    Serve como fonte de verdade para análise histórica e validação de missões.
    """
    
    # Identificação
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='daily_snapshots',
    )
    snapshot_date = models.DateField(
        help_text="Data do snapshot (YYYY-MM-DD)",
    )
    
    # Indicadores principais
    tps = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        help_text="Taxa de Poupança Pessoal do dia (%)",
    )
    rdr = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        help_text="Razão Dívida-Receita do dia (%)",
    )
    ili = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        help_text="Índice de Liquidez Imediata (meses)",
    )
    
    # Totais financeiros
    total_income = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        help_text="Total de receitas (acumulado do mês)",
    )
    total_expense = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        help_text="Total de despesas (acumulado do mês)",
    )
    total_debt = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        help_text="Total de dívidas",
    )
    available_balance = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        help_text="Saldo disponível (receitas - despesas - dívidas)",
    )
    
    # Gastos por categoria (JSON)
    category_spending = models.JSONField(
        default=dict,
        help_text="Gastos por categoria no mês atual até esta data",
    )
    # Exemplo: {
    #   "alimentacao": {"total": 500.00, "count": 15},
    #   "transporte": {"total": 300.00, "count": 8}
    # }
    
    # Poupança e investimentos
    savings_added_today = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        help_text="Valor adicionado a poupança/investimentos hoje",
    )
    savings_total = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        help_text="Total acumulado em poupança/investimentos",
    )
    
    # Progresso de metas
    goals_progress = models.JSONField(
        default=dict,
        help_text="Progresso de cada meta ativa",
    )
    # Exemplo: {
    #   "goal_uuid_1": {"name": "Emergência", "progress": 45.5, "current": 2275, "target": 5000},
    #   "goal_uuid_2": {"name": "Férias", "progress": 78.0, "current": 3900, "target": 5000}
    # }
    
    # Métricas de comportamento
    transactions_registered_today = models.BooleanField(
        default=False,
        help_text="Se registrou pelo menos 1 transação hoje",
    )
    transaction_count_today = models.PositiveIntegerField(
        default=0,
        help_text="Número de transações registradas hoje",
    )
    total_transactions_lifetime = models.PositiveIntegerField(
        default=0,
        help_text="Total de transações desde sempre",
    )
    
    # Violações de orçamento
    budget_exceeded = models.BooleanField(
        default=False,
        help_text="Se excedeu orçamento em alguma categoria hoje",
    )
    budget_violations = models.JSONField(
        default=list,
        help_text="Categorias que excederam orçamento",
    )
    # Exemplo: ["alimentacao", "lazer"]
    
    # Metadados
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        unique_together = ('user', 'snapshot_date')
        ordering = ['-snapshot_date']
        indexes = [
            models.Index(fields=['user', '-snapshot_date']),
            models.Index(fields=['snapshot_date']),
        ]
    
    def __str__(self) -> str:  # pragma: no cover
        return f"{self.user.username} - {self.snapshot_date}"


class UserMonthlySnapshot(models.Model):
    """
    Snapshot mensal consolidado.
    
    Criado automaticamente no último dia do mês.
    Útil para análises de longo prazo sem precisar agregar diários.
    """
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='monthly_snapshots',
    )
    year = models.PositiveIntegerField()
    month = models.PositiveIntegerField()  # 1-12
    
    # Médias mensais
    avg_tps = models.DecimalField(max_digits=6, decimal_places=2)
    avg_rdr = models.DecimalField(max_digits=6, decimal_places=2)
    avg_ili = models.DecimalField(max_digits=6, decimal_places=2)
    
    # Totais do mês
    total_income = models.DecimalField(max_digits=12, decimal_places=2)
    total_expense = models.DecimalField(max_digits=12, decimal_places=2)
    total_savings = models.DecimalField(max_digits=12, decimal_places=2)
    
    # Categoria mais gasta
    top_category = models.CharField(max_length=100, blank=True)
    top_category_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
    )
    
    # Gastos por categoria (consolidado)
    category_spending = models.JSONField(default=dict)
    
    # Consistência
    days_with_transactions = models.PositiveIntegerField(
        default=0,
        help_text="Quantos dias do mês registrou transações",
    )
    days_in_month = models.PositiveIntegerField(default=30)
    consistency_rate = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        help_text="% de dias com registro (days_with_transactions / days_in_month)",
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ('user', 'year', 'month')
        ordering = ['-year', '-month']
    
    def __str__(self) -> str:  # pragma: no cover
        return f"{self.user.username} - {self.year}/{self.month:02d}"


class MissionProgressSnapshot(models.Model):
    """
    Snapshot diário do progresso de uma missão específica.
    
    Criado automaticamente para cada missão ativa.
    Permite validação temporal e detecção de violações.
    """
    
    mission_progress = models.ForeignKey(
        'MissionProgress',
        on_delete=models.CASCADE,
        related_name='snapshots',
    )
    snapshot_date = models.DateField()
    
    # Valores dos indicadores neste dia
    tps_value = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        null=True,
        blank=True,
    )
    rdr_value = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        null=True,
        blank=True,
    )
    ili_value = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        null=True,
        blank=True,
    )
    
    # Para missões de categoria
    category_spending = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Gasto na categoria alvo neste dia/período",
    )
    
    # Para missões de meta
    goal_progress = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="% de progresso da meta neste dia",
    )
    goal_current_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
    )
    
    # Para missões de poupança
    savings_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Total em poupança neste dia",
    )
    
    # Validação de critério
    met_criteria = models.BooleanField(
        default=False,
        help_text="Se atendeu os critérios da missão neste dia",
    )
    criteria_details = models.JSONField(
        default=dict,
        help_text="Detalhes de quais critérios foram atendidos",
    )
    # Exemplo: {
    #   "tps_target": {"required": 20, "actual": 22, "met": true},
    #   "consecutive_days": 5
    # }
    
    # Dias consecutivos até este ponto
    consecutive_days_met = models.PositiveIntegerField(
        default=0,
        help_text="Quantos dias consecutivos atendeu critério até hoje",
    )
    
    # Progresso calculado (0-100%)
    progress_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=0,
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ('mission_progress', 'snapshot_date')
        ordering = ['snapshot_date']
        indexes = [
            models.Index(fields=['mission_progress', 'snapshot_date']),
            models.Index(fields=['snapshot_date']),
        ]
    
    def __str__(self) -> str:  # pragma: no cover
        return f"{self.mission_progress} - {self.snapshot_date}"


class Friendship(models.Model):
    """
    Modelo para gerenciar relacionamentos de amizade entre usuários.
    Permite sistema de ranking entre amigos e interações sociais.
    """
    
    class FriendshipStatus(models.TextChoices):
        PENDING = "PENDING", "Pendente"
        ACCEPTED = "ACCEPTED", "Aceito"
        REJECTED = "REJECTED", "Rejeitado"
    
    # UUID como Primary Key
    id = models.UUIDField(
        primary_key=True,
        default=None,
        editable=False,
        help_text="Identificador único universal (UUID v4)"
    )
    
    # Usuário que enviou a solicitação
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="friendship_requests_sent",
        help_text="Usuário que enviou a solicitação de amizade"
    )
    
    # Usuário que recebeu a solicitação
    friend = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="friendship_requests_received",
        help_text="Usuário que recebeu a solicitação de amizade"
    )
    
    status = models.CharField(
        max_length=10,
        choices=FriendshipStatus.choices,
        default=FriendshipStatus.PENDING,
        help_text="Status da solicitação de amizade"
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Data de criação da solicitação"
    )
    
    accepted_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Data em que a solicitação foi aceita"
    )

    class Meta:
        ordering = ("-created_at",)
        unique_together = [('user', 'friend')]
        indexes = [
            models.Index(fields=['user', 'status']),
            models.Index(fields=['friend', 'status']),
            models.Index(fields=['status', '-created_at']),
        ]

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.user.username} -> {self.friend.username} ({self.get_status_display()})"
    
    def clean(self):
        """Validações personalizadas."""
        from django.core.exceptions import ValidationError
        
        # Não pode enviar solicitação para si mesmo
        if self.user == self.friend:
            raise ValidationError("Não é possível enviar solicitação de amizade para si mesmo.")
        
        # Verificar se já existe uma solicitação pendente ou aceita na direção oposta
        existing = Friendship.objects.filter(
            user=self.friend,
            friend=self.user,
            status__in=[self.FriendshipStatus.PENDING, self.FriendshipStatus.ACCEPTED]
        ).exclude(pk=self.pk).exists()
        
        if existing:
            raise ValidationError("Já existe uma solicitação de amizade entre esses usuários.")
    
    def save(self, *args, **kwargs):
        self.full_clean()
        super().save(*args, **kwargs)
    
    def accept(self):
        """Aceita a solicitação de amizade."""
        self.status = self.FriendshipStatus.ACCEPTED
        self.accepted_at = timezone.now()
        self.save(update_fields=['status', 'accepted_at'])
    
    def reject(self):
        """Rejeita a solicitação de amizade."""
        self.status = self.FriendshipStatus.REJECTED
        self.save(update_fields=['status'])
    
    @classmethod
    def are_friends(cls, user1, user2) -> bool:
        """Verifica se dois usuários são amigos."""
        return cls.objects.filter(
            models.Q(user=user1, friend=user2) | models.Q(user=user2, friend=user1),
            status=cls.FriendshipStatus.ACCEPTED
        ).exists()
    
    @classmethod
    def get_friends_ids(cls, user) -> list:
        """Retorna lista de IDs dos amigos de um usuário."""
        from django.db.models import Q
        
        friendships = cls.objects.filter(
            Q(user=user) | Q(friend=user),
            status=cls.FriendshipStatus.ACCEPTED
        ).select_related('user', 'friend')
        
        friends_ids = []
        for friendship in friendships:
            if friendship.user == user:
                friends_ids.append(friendship.friend.id)
            else:
                friends_ids.append(friendship.user.id)
        
        return friends_ids
