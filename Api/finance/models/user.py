
from decimal import Decimal

from django.conf import settings
from django.db import models
from django.utils import timezone

from .base import (
    MAX_LEVEL,
    MIN_LEVEL,
    CACHE_EXPIRATION_SECONDS,
)


class UserProfile(models.Model):
    
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE
    )
    level = models.PositiveIntegerField(default=1)
    experience_points = models.PositiveIntegerField(default=0)
    target_tps = models.PositiveIntegerField(
        default=15, 
        help_text="meta básica de poupança em %"
    )
    target_rdr = models.PositiveIntegerField(
        default=35, 
        help_text="meta de despesas recorrentes/renda em %"
    )
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

    class Meta:
        verbose_name = "Perfil de Usuário"
        verbose_name_plural = "Perfis de Usuários"

    def __str__(self) -> str:
        return f"Perfil {self.user}"

    def clean(self):
        from django.core.exceptions import ValidationError
        
        if self.level < MIN_LEVEL:
            raise ValidationError({
                'level': f'Nível deve ser no mínimo {MIN_LEVEL}.'
            })
        
        if self.level > MAX_LEVEL:
            raise ValidationError({
                'level': f'Nível não pode exceder {MAX_LEVEL}.'
            })
        
        if self.experience_points < 0:
            raise ValidationError({
                'experience_points': 'Pontos de experiência não podem ser negativos.'
            })
        
        if self.target_tps < 0 or self.target_tps > 100:
            raise ValidationError({
                'target_tps': 'Meta de TPS deve estar entre 0 e 100%.'
            })
        
        if self.target_rdr < 0 or self.target_rdr > 100:
            raise ValidationError({
                'target_rdr': 'Meta de RDR deve estar entre 0 e 100%.'
            })
        
        if self.target_ili < Decimal('0'):
            raise ValidationError({
                'target_ili': 'Meta de ILI não pode ser negativa.'
            })
        
        if self.target_ili > Decimal('100'):
            raise ValidationError({
                'target_ili': 'Meta de ILI não deve exceder 100 meses.'
            })
        
        self._validate_cached_values()
        self._validate_indicators_date()
        self._validate_xp_for_level()

    def _validate_cached_values(self):
        from django.core.exceptions import ValidationError
        
        cached_fields = [
            ('cached_tps', 'TPS em cache'),
            ('cached_rdr', 'RDR em cache'),
            ('cached_ili', 'ILI em cache'),
            ('cached_total_income', 'Total de receitas em cache'),
            ('cached_total_expense', 'Total de despesas em cache'),
        ]
        
        for field_name, display_name in cached_fields:
            value = getattr(self, field_name)
            if value is not None and value < Decimal('0'):
                raise ValidationError({
                    field_name: f'{display_name} não pode ser negativo.'
                })

    def _validate_indicators_date(self):
        from django.core.exceptions import ValidationError
        
        if self.indicators_updated_at and self.indicators_updated_at > timezone.now():
            raise ValidationError({
                'indicators_updated_at': 'Data de atualização dos indicadores não pode ser no futuro.'
            })

    def _validate_xp_for_level(self):
        from django.core.exceptions import ValidationError
        
        current_threshold = 150 + (self.level - 1) * 50
        if self.experience_points >= current_threshold:
            raise ValidationError({
                'experience_points': (
                    f'XP atual ({self.experience_points}) excede o threshold do nível '
                    f'{self.level} ({current_threshold}). O usuário deveria ter subido de nível.'
                )
            })

    @property
    def next_level_threshold(self) -> int:
        base = 150 + (self.level - 1) * 50
        return max(base, 150)
    
    def should_recalculate_indicators(self) -> bool:
        if self.indicators_updated_at is None:
            return True
        time_since_update = timezone.now() - self.indicators_updated_at
        ttl = getattr(settings, 'INDICATORS_CACHE_TTL', CACHE_EXPIRATION_SECONDS)
        return time_since_update.total_seconds() > ttl
