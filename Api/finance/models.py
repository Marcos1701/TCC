from decimal import Decimal

from django.conf import settings
from django.db import models
from django.utils import timezone


class UserProfile(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    level = models.PositiveIntegerField(default=1)
    experience_points = models.PositiveIntegerField(default=0)
    target_tps = models.PositiveIntegerField(default=15, help_text="meta básica de poupança em %")
    target_rdr = models.PositiveIntegerField(default=35, help_text="meta de dívida/renda em %")
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
    cached_total_debt = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Total de dívidas em cache",
    )
    indicators_updated_at = models.DateTimeField(
        null=True, 
        blank=True,
        help_text="Última atualização dos indicadores em cache",
    )

    def __str__(self) -> str:
        return f"Perfil {self.user}"  # pragma: no cover

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
        DEBT = "DEBT", "Dívida"

    class CategoryGroup(models.TextChoices):
        REGULAR_INCOME = "REGULAR_INCOME", "Renda principal"
        EXTRA_INCOME = "EXTRA_INCOME", "Renda extra"
        SAVINGS = "SAVINGS", "Poupança / Reserva"
        INVESTMENT = "INVESTMENT", "Investimentos"
        ESSENTIAL_EXPENSE = "ESSENTIAL_EXPENSE", "Despesas essenciais"
        LIFESTYLE_EXPENSE = "LIFESTYLE_EXPENSE", "Estilo de vida"
        DEBT = "DEBT", "Dívidas"
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


class Transaction(models.Model):
    class TransactionType(models.TextChoices):
        INCOME = "INCOME", "Receita"
        EXPENSE = "EXPENSE", "Despesa"
        DEBT_PAYMENT = "DEBT_PAYMENT", "Pagamento de dívida"

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
        
        # Para receitas, usar outgoing; para dívidas, usar incoming
        if self.type == self.TransactionType.INCOME:
            return outgoing
        elif self.category and self.category.type == Category.CategoryType.DEBT:
            return incoming
        
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
    Usado principalmente para pagamento de dívidas: vincular receita → dívida.
    
    Exemplo:
    - Receita (Salário) R$ 5.000 → Dívida (Cartão) R$ 2.000
    - Após vinculação:
      - Salário tem R$ 3.000 disponíveis
      - Cartão tem R$ 0 devendo
    """
    
    class LinkType(models.TextChoices):
        DEBT_PAYMENT = "DEBT_PAYMENT", "Pagamento de dívida"
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
        default=LinkType.DEBT_PAYMENT
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
        
        # 4. Validar tipo de transação para DEBT_PAYMENT
        if self.link_type == self.LinkType.DEBT_PAYMENT:
            # Source deve ser receita
            if self.source_transaction.type != Transaction.TransactionType.INCOME:
                raise ValidationError(
                    "Para pagamento de dívida, a transação de origem deve ser uma receita (INCOME)."
                )
            
            # Target deve ter categoria de dívida
            if not self.target_transaction.category or \
               self.target_transaction.category.type != Category.CategoryType.DEBT:
                raise ValidationError(
                    "Para pagamento de dívida, a transação de destino deve ser uma dívida."
                )
        
        # 5. Validar valor disponível com lock (previne race conditions)
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
                
                # Validar amount disponível na target (se for dívida)
                if target.category and target.category.type == Category.CategoryType.DEBT:
                    if self.linked_amount > target.available_amount:
                        raise ValidationError(
                            f"Valor vinculado (R$ {self.linked_amount}) excede o devido "
                            f"na dívida (R$ {target.available_amount})"
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
