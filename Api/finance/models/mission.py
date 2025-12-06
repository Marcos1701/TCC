
from decimal import Decimal

from django.conf import settings
from django.db import models
from django.utils import timezone

from .base import (
    MAX_TITLE_LENGTH,
    MAX_DURATION_DAYS,
    MAX_REWARD_POINTS,
)


class Mission(models.Model):
    
    class Difficulty(models.TextChoices):
        EASY = "EASY", "Fácil"
        MEDIUM = "MEDIUM", "Média"
        HARD = "HARD", "Difícil"

    class MissionType(models.TextChoices):
        ONBOARDING = "ONBOARDING", "Primeiros Passos"
        TPS_IMPROVEMENT = "TPS_IMPROVEMENT", "Aumentar Poupança (TPS)"
        RDR_REDUCTION = "RDR_REDUCTION", "Reduzir Gastos Recorrentes (RDR)"
        ILI_BUILDING = "ILI_BUILDING", "Construir Reserva (ILI)"
        CATEGORY_REDUCTION = "CATEGORY_REDUCTION", "Reduzir Gastos em Categoria"
    
    class ValidationType(models.TextChoices):
        TRANSACTION_COUNT = "TRANSACTION_COUNT", "Registrar X Transações"
        INDICATOR_THRESHOLD = "INDICATOR_THRESHOLD", "Atingir Valor de Indicador"
        CATEGORY_REDUCTION = "CATEGORY_REDUCTION", "Reduzir % em Categoria"
        TEMPORAL = "TEMPORAL", "Manter Critério por Período"

    title = models.CharField(max_length=MAX_TITLE_LENGTH)
    description = models.TextField()
    reward_points = models.PositiveIntegerField(default=50)
    difficulty = models.CharField(
        max_length=8, 
        choices=Difficulty.choices, 
        default=Difficulty.MEDIUM
    )
    mission_type = models.CharField(
        max_length=30,
        choices=MissionType.choices,
        default=MissionType.ONBOARDING,
        help_text="Tipo de missão que determina quando será aplicada",
    )
    priority = models.PositiveIntegerField(
        default=1,
        help_text="Ordem de prioridade para aplicação automática (menor = mais prioritário)",
    )
    target_tps = models.PositiveIntegerField(
        null=True, blank=True, 
        help_text="TPS mínimo necessário (se aplicável)"
    )
    target_rdr = models.PositiveIntegerField(
        null=True, blank=True, 
        help_text="RDR máximo permitido (se aplicável)"
    )
    min_ili = models.DecimalField(
        max_digits=4, decimal_places=1, 
        null=True, blank=True, 
        help_text="ILI mínimo necessário"
    )
    max_ili = models.DecimalField(
        max_digits=4, decimal_places=1, 
        null=True, blank=True, 
        help_text="ILI máximo permitido"
    )
    min_transactions = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Número mínimo de transações registradas para desbloquear esta missão",
    )
    duration_days = models.PositiveIntegerField(default=30)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    validation_type = models.CharField(
        max_length=35,
        choices=ValidationType.choices,
        default=ValidationType.TRANSACTION_COUNT,
        help_text="Tipo de validação que determina como o progresso é calculado",
    )
    
    requires_consecutive_days = models.BooleanField(
        default=False,
        help_text="Se requer X dias CONSECUTIVOS atendendo critério",
    )
    min_consecutive_days = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Número mínimo de dias consecutivos",
    )
    
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
    

    
    savings_increase_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Valor em R$ para aumentar poupança",
    )
    
    requires_daily_action = models.BooleanField(
        default=False,
        help_text="Se requer ação diária (registrar transação, etc)",
    )
    min_daily_actions = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Número mínimo de ações diárias necessárias",
    )
    
    impacts = models.JSONField(
        default=list,
        blank=True,
        help_text="Lista de impactos ao completar (título, descrição, ícone, cor)",
    )
    
    tips = models.JSONField(
        default=list,
        blank=True,
        help_text="Lista de dicas contextuais (título, descrição, prioridade)",
    )
    
    min_transaction_frequency = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Frequência mínima de transações por semana (para missões de consistência)",
    )
    
    transaction_type_filter = models.CharField(
        max_length=10,
        choices=[
            ('ALL', 'Todas'),
            ('INCOME', 'Receitas'),
            ('EXPENSE', 'Despesas'),
            ('TRANSFER', 'Transferências'),
        ],
        default='ALL',
        help_text="Tipo de transação a ser considerado na validação",
    )
    
    target_categories = models.ManyToManyField(
        'Category',
        blank=True,
        related_name='target_missions',
        help_text="Categorias alvo para missões que envolvem múltiplas categorias",
    )
    

    
    requires_payment_tracking = models.BooleanField(
        default=False,
        help_text="Se a missão requer rastreamento de pagamentos (campo is_paid nas transações)",
    )
    
    min_payments_count = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Número mínimo de pagamentos a serem rastreados",
    )
    
    is_system_generated = models.BooleanField(
        default=False,
        help_text="Se a missão foi gerada automaticamente pelo sistema",
    )
    
    generation_context = models.JSONField(
        default=dict,
        blank=True,
        help_text="Contexto de geração automática (dados usados para criar a missão)",
    )

    class Meta:
        ordering = ("priority", "title")
        verbose_name = "Missão"
        verbose_name_plural = "Missões"

    def __str__(self) -> str:
        return self.title

    def clean(self):
        from django.core.exceptions import ValidationError
        
        self._validate_reward_and_duration()
        self._validate_title_and_description()
        self._validate_indicators()
        self._validate_temporal_fields()
        self._validate_consistency_fields()

    def _validate_reward_and_duration(self):
        from django.core.exceptions import ValidationError
        
        if self.reward_points is not None and self.reward_points <= 0:
            raise ValidationError({
                'reward_points': 'A recompensa de pontos deve ser maior que zero.'
            })
        
        if self.reward_points is not None and self.reward_points > MAX_REWARD_POINTS:
            raise ValidationError({
                'reward_points': f'A recompensa não pode exceder {MAX_REWARD_POINTS} pontos.'
            })
        
        if self.duration_days is not None and self.duration_days <= 0:
            raise ValidationError({
                'duration_days': 'A duração deve ser maior que zero dias.'
            })
        
        if self.duration_days is not None and self.duration_days > MAX_DURATION_DAYS:
            raise ValidationError({
                'duration_days': f'A duração não pode exceder {MAX_DURATION_DAYS} dias.'
            })

    def _validate_title_and_description(self):
        from django.core.exceptions import ValidationError
        
        if self.title and len(self.title.strip()) == 0:
            raise ValidationError({
                'title': 'O título não pode ser vazio.'
            })
        
        if self.description and len(self.description.strip()) == 0:
            raise ValidationError({
                'description': 'A descrição não pode ser vazia.'
            })

    def _validate_indicators(self):
        from django.core.exceptions import ValidationError
        
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
        
        if self.min_ili is not None and self.max_ili is not None:
            if self.min_ili > self.max_ili:
                raise ValidationError({
                    'min_ili': 'ILI mínimo não pode ser maior que ILI máximo.'
                })
        
        if self.priority is not None and self.priority < 1:
            raise ValidationError({
                'priority': 'Prioridade deve ser maior ou igual a 1.'
            })

    def _validate_temporal_fields(self):
        from django.core.exceptions import ValidationError
        
        if self.requires_consecutive_days:
            if not self.min_consecutive_days or self.min_consecutive_days < 1:
                raise ValidationError({
                    'min_consecutive_days': 'Número mínimo de dias consecutivos é obrigatório.'
                })
            if self.min_consecutive_days > self.duration_days:
                raise ValidationError({
                    'min_consecutive_days': 'Dias consecutivos não pode exceder duração da missão.'
                })
        
        if self.savings_increase_amount is not None and self.savings_increase_amount <= 0:
            raise ValidationError({
                'savings_increase_amount': 'Aumento de poupança deve ser positivo.'
            })
        
        if self.validation_type == self.ValidationType.TEMPORAL:
            if self.duration_days < 7:
                raise ValidationError({
                    'duration_days': 'Missões temporais devem ter pelo menos 7 dias de duração.'
                })

    def _validate_consistency_fields(self):
        from django.core.exceptions import ValidationError
        
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
        ACTIVE = "ACTIVE", "Em Andamento"
        COMPLETED = "COMPLETED", "Concluída"
        FAILED = "FAILED", "Não Concluída"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name="mission_progress"
    )
    mission = models.ForeignKey(
        Mission, 
        on_delete=models.CASCADE, 
        related_name="progress"
    )
    status = models.CharField(
        max_length=10, 
        choices=Status.choices, 
        default=Status.PENDING
    )
    progress = models.DecimalField(
        max_digits=5, 
        decimal_places=2, 
        default=Decimal("0.00")
    )
    initial_tps = models.DecimalField(
        max_digits=5, decimal_places=2, 
        null=True, blank=True
    )
    initial_rdr = models.DecimalField(
        max_digits=5, decimal_places=2, 
        null=True, blank=True
    )
    initial_ili = models.DecimalField(
        max_digits=5, decimal_places=2, 
        null=True, blank=True
    )
    initial_transaction_count = models.PositiveIntegerField(default=0)
    started_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)
    
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
    

    
    initial_savings_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Total em poupança quando missão começou",
    )
    
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
    
    validation_details = models.JSONField(
        default=dict,
        help_text="Detalhes de como validação está sendo feita",
    )

    class Meta:
        unique_together = ("user", "mission")
        ordering = ("mission__priority", "mission__title")
        verbose_name = "Progresso de Missão"
        verbose_name_plural = "Progressos de Missões"

    def __str__(self) -> str:
        return f"{self.user} - {self.mission}"

    def clean(self):
        from django.core.exceptions import ValidationError
        
        self._validate_progress()
        self._validate_status_transitions()
        self._validate_completion()
        self._validate_dates()
        self._validate_initial_indicators()
        self._validate_streaks()
        self._validate_savings()
        self._validate_baseline()

    def _validate_progress(self):
        from django.core.exceptions import ValidationError
        
        if self.progress < Decimal('0'):
            raise ValidationError({
                'progress': 'O progresso não pode ser negativo.'
            })
        
        if self.progress > Decimal('100'):
            raise ValidationError({
                'progress': 'O progresso não pode exceder 100%.'
            })

    def _validate_status_transitions(self):
        from django.core.exceptions import ValidationError
        
        if self.pk:
            try:
                old_instance = MissionProgress.objects.get(pk=self.pk)
                if old_instance.status == self.Status.COMPLETED and \
                   self.status == self.Status.ACTIVE:
                    raise ValidationError({
                        'status': 'Uma missão concluída não pode voltar para em progresso.'
                    })
                
                if old_instance.status == self.Status.FAILED and \
                   self.status == self.Status.COMPLETED:
                    raise ValidationError({
                        'status': 'Uma missão falha não pode ser marcada como concluída.'
                    })
            except MissionProgress.DoesNotExist:
                pass

    def _validate_completion(self):
        from django.core.exceptions import ValidationError
        
        if self.status == self.Status.COMPLETED and self.progress < Decimal('100'):
            raise ValidationError({
                'status': 'Missão só pode ser concluída quando progresso atingir 100%.'
            })
        
        if self.completed_at and self.status != self.Status.COMPLETED:
            raise ValidationError({
                'completed_at': 'Data de conclusão só deve ser definida para missões concluídas.'
            })

    def _validate_dates(self):
        from django.core.exceptions import ValidationError
        
        if self.completed_at:
            if self.completed_at > timezone.now():
                raise ValidationError({
                    'completed_at': 'Data de conclusão não pode ser no futuro.'
                })
        
        if self.started_at and self.completed_at:
            if self.started_at >= self.completed_at:
                raise ValidationError({
                    'completed_at': 'Data de conclusão deve ser posterior ao início.'
                })

    def _validate_initial_indicators(self):
        from django.core.exceptions import ValidationError
        
        indicators = [
            ('initial_tps', 'TPS inicial'),
            ('initial_rdr', 'RDR inicial'),
            ('initial_ili', 'ILI inicial'),
        ]
        
        for field_name, display_name in indicators:
            value = getattr(self, field_name)
            if value is not None and value < Decimal('0'):
                raise ValidationError({
                    field_name: f'{display_name} não pode ser negativo.'
                })

    def _validate_streaks(self):
        from django.core.exceptions import ValidationError
        
        if self.current_streak < 0:
            raise ValidationError({
                'current_streak': 'Streak atual não pode ser negativo.'
            })
        
        if self.max_streak < self.current_streak:
            raise ValidationError({
                'max_streak': 'Streak máximo deve ser maior ou igual ao streak atual.'
            })
        
        if self.days_met_criteria < 0:
            raise ValidationError({
                'days_met_criteria': 'Dias que atendeu critério não pode ser negativo.'
            })
        
        if self.days_violated_criteria < 0:
            raise ValidationError({
                'days_violated_criteria': 'Dias que violou critério não pode ser negativo.'
            })

    def _validate_savings(self):
        from django.core.exceptions import ValidationError
        
        if self.initial_savings_amount is not None and self.initial_savings_amount < Decimal('0'):
            raise ValidationError({
                'initial_savings_amount': 'Valor inicial de poupança não pode ser negativo.'
            })

    def _validate_baseline(self):
        from django.core.exceptions import ValidationError
        
        if self.baseline_period_days < 1 or self.baseline_period_days > MAX_DURATION_DAYS:
            raise ValidationError({
                'baseline_period_days': f'Período de baseline deve estar entre 1 e {MAX_DURATION_DAYS} dias.'
            })
