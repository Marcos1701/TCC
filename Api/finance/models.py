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

    def __str__(self) -> str:
        return f"Perfil {self.user}"  # pragma: no cover

    @property
    def next_level_threshold(self) -> int:
        base = 150 + (self.level - 1) * 50
        return max(base, 150)


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
    type = models.CharField(max_length=14, choices=TransactionType.choices)
    description = models.CharField(max_length=255)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    date = models.DateField(default=timezone.now)
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

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.description} ({self.amount})"


class Goal(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="goals")
    title = models.CharField(max_length=150)
    description = models.TextField(blank=True)
    target_amount = models.DecimalField(max_digits=12, decimal_places=2)
    current_amount = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    deadline = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("deadline", "title")

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.title} ({self.user})"


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
