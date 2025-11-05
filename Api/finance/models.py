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
        null=True,
        blank=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("user", "name", "type")
        ordering = ("name",)

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
        outgoing = self.outgoing_links.aggregate(
            total=Sum('linked_amount')
        )['total'] or Decimal('0')
        
        # Soma links de entrada (quando esta é a target)
        incoming = self.incoming_links.aggregate(
            total=Sum('linked_amount')
        )['total'] or Decimal('0')
        
        # Para receitas, usar outgoing; para dívidas, usar incoming
        if self.type == self.TransactionType.INCOME:
            return outgoing
        elif self.category and self.category.type == Category.CategoryType.DEBT:
            return incoming
        
        return Decimal('0')
    
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
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='transaction_links',
        help_text="Usuário proprietário da vinculação"
    )
    
    # Transação de origem (de onde vem o dinheiro)
    source_transaction = models.ForeignKey(
        Transaction,
        on_delete=models.CASCADE,
        related_name='outgoing_links',
        help_text="Transação de origem (normalmente uma receita)"
    )
    
    # Transação de destino (para onde vai o dinheiro)
    target_transaction = models.ForeignKey(
        Transaction,
        on_delete=models.CASCADE,
        related_name='incoming_links',
        help_text="Transação de destino (normalmente uma dívida)"
    )
    
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
            models.Index(fields=['source_transaction']),
            models.Index(fields=['target_transaction']),
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
        """Validações personalizadas."""
        from django.core.exceptions import ValidationError
        
        # Validar que source e target pertencem ao mesmo usuário
        if self.source_transaction.user != self.target_transaction.user:
            raise ValidationError("As transações devem pertencer ao mesmo usuário.")
        
        # Validar que user da vinculação é o mesmo das transações
        if self.user != self.source_transaction.user:
            raise ValidationError("Usuário da vinculação deve ser o mesmo das transações.")
        
        # Validar que linked_amount não excede o disponível na source
        if self.linked_amount > self.source_transaction.available_amount:
            raise ValidationError(
                f"Valor vinculado (R$ {self.linked_amount}) excede o disponível na transação de origem (R$ {self.source_transaction.available_amount})"
            )
        
        # Validar que linked_amount não excede o devido na target (se for dívida)
        if self.target_transaction.category and self.target_transaction.category.type == Category.CategoryType.DEBT:
            if self.linked_amount > self.target_transaction.available_amount:
                raise ValidationError(
                    f"Valor vinculado (R$ {self.linked_amount}) excede o devido na dívida (R$ {self.target_transaction.available_amount})"
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


class Friendship(models.Model):
    """
    Modelo para gerenciar relacionamentos de amizade entre usuários.
    Permite sistema de ranking entre amigos e interações sociais.
    """
    
    class FriendshipStatus(models.TextChoices):
        PENDING = "PENDING", "Pendente"
        ACCEPTED = "ACCEPTED", "Aceito"
        REJECTED = "REJECTED", "Rejeitado"
    
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
