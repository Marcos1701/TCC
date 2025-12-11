
from django.conf import settings
from django.db import models


class XPTransaction(models.Model):
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="xp_transactions",
    )
    mission_progress = models.ForeignKey(
        'MissionProgress',
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
        verbose_name = "Transação de XP"
        verbose_name_plural = "Transações de XP"
        indexes = [
            models.Index(fields=['user', '-created_at']),
        ]

    def __str__(self) -> str:
        return f"{self.user} - {self.points_awarded} XP - {self.mission_progress.mission.title}"


class AdminActionLog(models.Model):
    
    class ActionType(models.TextChoices):
        USER_DEACTIVATED = 'USER_DEACTIVATED', 'Usuário Desativado'
        USER_REACTIVATED = 'USER_REACTIVATED', 'Usuário Reativado'
        XP_ADJUSTED = 'XP_ADJUSTED', 'XP Ajustado'
        LEVEL_ADJUSTED = 'LEVEL_ADJUSTED', 'Nível Ajustado'
        PROFILE_UPDATED = 'PROFILE_UPDATED', 'Perfil Atualizado'
        MISSIONS_RESET = 'MISSIONS_RESET', 'Missões Resetadas'
        TRANSACTIONS_DELETED = 'TRANSACTIONS_DELETED', 'Transações Deletadas'
        OTHER = 'OTHER', 'Outro'
    
    admin_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='admin_actions_performed',
        help_text="Administrador que realizou a ação"
    )
    
    target_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='admin_actions_received',
        help_text="Usuário que recebeu a ação"
    )
    
    action_type = models.CharField(
        max_length=30,
        choices=ActionType.choices,
        help_text="Tipo de ação realizada"
    )
    
    old_value = models.TextField(
        blank=True,
        null=True,
        help_text="Valor anterior (JSON se necessário)"
    )
    
    new_value = models.TextField(
        blank=True,
        null=True,
        help_text="Novo valor (JSON se necessário)"
    )
    
    reason = models.TextField(
        blank=True,
        help_text="Motivo/justificativa da ação"
    )
    
    timestamp = models.DateTimeField(
        auto_now_add=True,
        help_text="Data e hora da ação"
    )
    
    ip_address = models.GenericIPAddressField(
        blank=True,
        null=True,
        help_text="IP do administrador"
    )
    
    class Meta:
        ordering = ['-timestamp']
        verbose_name = 'Log de Ação Administrativa'
        verbose_name_plural = 'Logs de Ações Administrativas'
        indexes = [
            models.Index(fields=['-timestamp']),
            models.Index(fields=['target_user', '-timestamp']),
            models.Index(fields=['admin_user', '-timestamp']),
            models.Index(fields=['action_type', '-timestamp']),
        ]
    
    def __str__(self):
        admin_name = self.admin_user.username if self.admin_user else 'Sistema'
        return f"{admin_name} -> {self.target_user.username}: {self.get_action_type_display()} ({self.timestamp.strftime('%d/%m/%Y %H:%M')})"
    
    @classmethod
    def log_action(cls, admin_user, target_user, action_type, old_value=None, new_value=None, reason='', ip_address=None):
        import json
        
        if old_value and not isinstance(old_value, str):
            old_value = json.dumps(old_value, ensure_ascii=False)
        
        if new_value and not isinstance(new_value, str):
            new_value = json.dumps(new_value, ensure_ascii=False)
        
        return cls.objects.create(
            admin_user=admin_user,
            target_user=target_user,
            action_type=action_type,
            old_value=old_value,
            new_value=new_value,
            reason=reason,
            ip_address=ip_address
        )
