"""
Painel Administrativo - Sistema de Educação Financeira Gamificada

Este módulo configura o painel administrativo do Django para gerenciamento
do sistema. Projetado para uso pelo desenvolvedor durante o desenvolvimento
e apresentação do TCC.

Modelos registrados:
    - UserProfile: Perfis de usuários e dados de gamificação
    - Category: Categorias de transações financeiras
    - Transaction: Transações financeiras (receitas/despesas)
    - TransactionLink: Vínculos entre transações
    - Goal: Metas financeiras dos usuários
    - Mission: Missões do sistema de gamificação
    - MissionProgress: Progresso dos usuários nas missões
    - XPTransaction: Histórico de XP ganho (somente leitura)
    - AdminActionLog: Log de ações administrativas (somente leitura)
"""

from django.contrib import admin
from django.utils import timezone

from .models import (
    Category,
    Goal,
    Mission,
    MissionProgress,
    Transaction,
    TransactionLink,
    UserProfile,
    XPTransaction,
    AdminActionLog,
)


# =============================================================================
# CONFIGURAÇÃO DO SITE ADMIN
# =============================================================================

admin.site.site_header = "Sistema de Educação Financeira - TCC"
admin.site.site_title = "Admin TCC"
admin.site.index_title = "Painel de Gerenciamento"


# =============================================================================
# USUÁRIOS E GAMIFICAÇÃO
# =============================================================================

@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    """
    Gerenciamento de perfis de usuários.
    
    Exibe informações de gamificação (nível, XP) e indicadores financeiros
    calculados (TPS, RDR, ILI).
    """
    
    list_display = (
        "user",
        "nivel",
        "experience_points",
        "metas_usuario",
        "is_first_access",
    )
    list_filter = ("level", "is_first_access")
    search_fields = ("user__username", "user__email")
    readonly_fields = (
        "experience_points",
        "level",
        "cached_tps",
        "cached_rdr",
        "cached_ili",
        "cached_total_income",
        "cached_total_expense",
        "indicators_updated_at",
    )

    fieldsets = (
        ("Usuário", {
            "fields": ("user", "is_first_access"),
        }),
        ("Gamificação", {
            "fields": ("level", "experience_points"),
            "description": "Nível e experiência acumulada pelo usuário.",
        }),
        ("Metas Pessoais", {
            "fields": ("target_tps", "target_rdr", "target_ili"),
            "description": (
                "TPS = Taxa de Poupança (%), "
                "RDR = Razão de Despesas Recorrentes (%), "
                "ILI = Índice de Liquidez Imediata (meses)"
            ),
        }),
        ("Cache de Indicadores", {
            "fields": (
                "cached_tps",
                "cached_rdr",
                "cached_ili",
                "cached_total_income",
                "cached_total_expense",
                "indicators_updated_at",
            ),
            "classes": ("collapse",),
            "description": "Valores calculados em cache para performance.",
        }),
    )

    @admin.display(description="Nível", ordering="level")
    def nivel(self, obj):
        """Exibe o nível do usuário."""
        return f"Nv. {obj.level}"

    @admin.display(description="Metas")
    def metas_usuario(self, obj):
        """Exibe as metas do usuário de forma resumida."""
        return f"TPS: {obj.target_tps}% | RDR: {obj.target_rdr}% | ILI: {obj.target_ili}m"

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user')


# =============================================================================
# CATEGORIAS E TRANSAÇÕES
# =============================================================================

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    """
    Gerenciamento de categorias de transações.
    
    Categorias podem ser de receita (income) ou despesa (expense).
    Categorias padrão do sistema são marcadas como is_system_default.
    """
    
    list_display = (
        "name",
        "tipo",
        "user",
        "is_system_default",
        "created_at",
    )
    list_filter = ("type", "is_system_default")
    search_fields = ("name", "user__username")
    readonly_fields = ("created_at",)

    fieldsets = (
        ("Categoria", {
            "fields": ("name", "type", "user"),
        }),
        ("Sistema", {
            "fields": ("is_system_default",),
            "description": "Categorias padrão são criadas automaticamente para novos usuários.",
        }),
        ("Datas", {
            "fields": ("created_at",),
            "classes": ("collapse",),
        }),
    )

    @admin.display(description="Tipo", ordering="type")
    def tipo(self, obj):
        """Exibe o tipo da categoria."""
        return "Receita" if obj.type == "income" else "Despesa"

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user')


@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    """
    Gerenciamento de transações financeiras.
    
    Transações podem ser receitas (INCOME) ou despesas (EXPENSE).
    Suporta recorrência para transações periódicas.
    """
    
    list_display = (
        "description",
        "tipo",
        "valor",
        "date",
        "user",
        "category",
        "is_recurring",
    )
    list_filter = ("type", "is_recurring", "date")
    search_fields = ("description", "user__username", "category__name")
    autocomplete_fields = ("category",)
    date_hierarchy = "date"
    readonly_fields = ("created_at", "updated_at")

    fieldsets = (
        ("Transação", {
            "fields": ("description", "type", "amount", "date", "user", "category"),
        }),
        ("Recorrência", {
            "fields": ("is_recurring", "recurrence_value", "recurrence_unit", "recurrence_end_date"),
            "classes": ("collapse",),
            "description": "Configure para transações que se repetem periodicamente.",
        }),
        ("Datas", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",),
        }),
    )

    @admin.display(description="Tipo", ordering="type")
    def tipo(self, obj):
        """Exibe o tipo da transação."""
        return "Receita" if obj.type == "INCOME" else "Despesa"

    @admin.display(description="Valor", ordering="amount")
    def valor(self, obj):
        """Exibe o valor formatado."""
        sinal = "+" if obj.type == "INCOME" else "-"
        return f"{sinal} R$ {obj.amount:.2f}"

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user', 'category')


@admin.register(TransactionLink)
class TransactionLinkAdmin(admin.ModelAdmin):
    """
    Gerenciamento de vínculos entre transações.
    
    Usado para representar transferências, pagamentos, 
    investimentos ou empréstimos entre contas/categorias.
    """
    
    list_display = (
        "id",
        "user",
        "link_type",
        "valor_vinculado",
        "is_recurring",
        "created_at",
    )
    list_filter = ("link_type", "is_recurring")
    search_fields = ("user__username", "description")
    readonly_fields = ("created_at", "updated_at", "source_transaction_uuid", "target_transaction_uuid")
    date_hierarchy = "created_at"

    fieldsets = (
        ("Vínculo", {
            "fields": ("user", "description", "link_type", "linked_amount"),
        }),
        ("Transações", {
            "fields": ("source_transaction_uuid", "target_transaction_uuid"),
            "description": "UUIDs das transações de origem e destino.",
        }),
        ("Configuração", {
            "fields": ("is_recurring",),
        }),
        ("Datas", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",),
        }),
    )

    @admin.display(description="Valor", ordering="linked_amount")
    def valor_vinculado(self, obj):
        """Exibe o valor vinculado formatado."""
        return f"R$ {obj.linked_amount:.2f}"

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user')


# =============================================================================
# METAS FINANCEIRAS
# =============================================================================

@admin.register(Goal)
class GoalAdmin(admin.ModelAdmin):
    """
    Gerenciamento de metas financeiras.
    
    Metas possuem valor alvo, prazo e podem rastrear
    categorias específicas para calcular o progresso.
    """
    
    list_display = (
        "title",
        "user",
        "progresso",
        "valor_alvo",
        "deadline",
        "status",
    )
    list_filter = ("deadline",)
    search_fields = ("title", "user__username", "description")
    readonly_fields = ("created_at", "updated_at", "current_amount")
    date_hierarchy = "deadline"

    fieldsets = (
        ("Meta", {
            "fields": ("user", "title", "description"),
        }),
        ("Valores", {
            "fields": ("target_amount", "current_amount", "initial_amount"),
            "description": "Valor alvo e progresso atual.",
        }),
        ("Prazo", {
            "fields": ("deadline",),
        }),
        ("Categorias Rastreadas", {
            "fields": ("tracked_categories",),
            "classes": ("collapse",),
            "description": "Categorias que contribuem para esta meta.",
        }),
        ("Datas", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",),
        }),
    )

    @admin.display(description="Valor Alvo", ordering="target_amount")
    def valor_alvo(self, obj):
        """Exibe o valor alvo formatado."""
        return f"R$ {obj.target_amount:.2f}"

    @admin.display(description="Progresso")
    def progresso(self, obj):
        """Exibe o progresso percentual da meta."""
        if obj.target_amount <= 0:
            return "0%"
        percentual = min((obj.current_amount / obj.target_amount) * 100, 100)
        return f"{percentual:.0f}%"

    @admin.display(description="Status")
    def status(self, obj):
        """Exibe o status da meta."""
        if obj.target_amount <= 0:
            return "Inválida"
        
        percentual = (obj.current_amount / obj.target_amount) * 100
        now = timezone.now().date()
        
        if percentual >= 100:
            return "Concluída"
        elif obj.deadline and obj.deadline < now:
            return "Vencida"
        elif obj.deadline and (obj.deadline - now).days <= 7:
            return "Urgente"
        return "Em andamento"

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user')


# =============================================================================
# SISTEMA DE MISSÕES (GAMIFICAÇÃO)
# =============================================================================

@admin.register(Mission)
class MissionAdmin(admin.ModelAdmin):
    """
    Gerenciamento de missões do sistema de gamificação.
    
    Tipos de Missão:
        - ONBOARDING: Primeiros passos (registrar transações iniciais)
        - TPS_IMPROVEMENT: Aumentar Taxa de Poupança
        - RDR_REDUCTION: Reduzir gastos recorrentes  
        - ILI_BUILDING: Construir reserva de emergência
        - CATEGORY_REDUCTION: Reduzir gastos em categoria específica
        - GOAL_ACHIEVEMENT: Progredir em meta financeira
    """
    
    list_display = (
        "title",
        "mission_type",
        "difficulty",
        "recompensa",
        "duracao",
        "is_active",
        "usuarios",
    )
    list_filter = ("difficulty", "is_active", "mission_type", "is_system_generated")
    search_fields = ("title", "description")
    readonly_fields = ("created_at", "updated_at", "is_system_generated", "generation_context")
    autocomplete_fields = ("target_category", "target_goal")

    fieldsets = (
        ("Informações Básicas", {
            "fields": ("title", "description", "difficulty", "is_active"),
        }),
        ("Tipo e Recompensa", {
            "fields": ("mission_type", "reward_points", "duration_days"),
            "description": (
                "Guia de XP: Fácil (25-75 XP), Média (75-150 XP), Difícil (150-300 XP). "
                "Duração: Fácil (7-14 dias), Média (14-30 dias), Difícil (30-60 dias)."
            ),
        }),
        ("Critérios de Indicadores", {
            "fields": ("target_tps", "target_rdr", "min_ili", "max_ili", "min_transactions"),
            "classes": ("collapse",),
            "description": (
                "TPS_IMPROVEMENT: target_tps | "
                "RDR_REDUCTION: target_rdr | "
                "ILI_BUILDING: min_ili | "
                "ONBOARDING: min_transactions"
            ),
        }),
        ("Missões de Categoria", {
            "fields": ("target_category", "target_reduction_percent"),
            "classes": ("collapse",),
            "description": "Para missões do tipo CATEGORY_REDUCTION.",
        }),
        ("Missões de Meta", {
            "fields": ("target_goal", "goal_progress_target"),
            "classes": ("collapse",),
            "description": "Para missões do tipo GOAL_ACHIEVEMENT.",
        }),
        ("Dicas", {
            "fields": ("tips",),
            "classes": ("collapse",),
            "description": 'JSON: [{"title": "Título", "description": "Texto"}]',
        }),
        ("Sistema", {
            "fields": ("is_system_generated", "generation_context", "created_at", "updated_at"),
            "classes": ("collapse",),
        }),
    )

    @admin.display(description="Recompensa", ordering="reward_points")
    def recompensa(self, obj):
        """Exibe a recompensa em XP."""
        return f"{obj.reward_points} XP"

    @admin.display(description="Duração", ordering="duration_days")
    def duracao(self, obj):
        """Exibe a duração em dias."""
        return f"{obj.duration_days} dias"

    @admin.display(description="Usuários")
    def usuarios(self, obj):
        """Exibe quantidade de usuários que iniciaram/completaram a missão."""
        total = obj.missionprogress_set.count()
        concluidas = obj.missionprogress_set.filter(status='completed').count()
        if total > 0:
            return f"{total} ({concluidas} concl.)"
        return "-"

    def get_queryset(self, request):
        return super().get_queryset(request).prefetch_related('missionprogress_set')


@admin.register(MissionProgress)
class MissionProgressAdmin(admin.ModelAdmin):
    """
    Gerenciamento do progresso de usuários nas missões.
    
    Status:
        - not_started: Não iniciada
        - in_progress: Em progresso
        - completed: Concluída
        - failed: Falhou
    """
    
    list_display = (
        "user",
        "missao",
        "status",
        "progresso",
        "updated_at",
    )
    list_filter = ("status", "mission__difficulty")
    search_fields = ("user__username", "mission__title")
    autocomplete_fields = ("user", "mission")
    readonly_fields = ("started_at", "completed_at", "updated_at")
    date_hierarchy = "updated_at"

    fieldsets = (
        ("Progresso", {
            "fields": ("user", "mission", "status", "progress"),
        }),
        ("Datas", {
            "fields": ("started_at", "completed_at", "updated_at"),
        }),
    )

    @admin.display(description="Missão")
    def missao(self, obj):
        """Exibe informações resumidas da missão."""
        return f"{obj.mission.title} ({obj.mission.reward_points} XP)"

    @admin.display(description="Progresso", ordering="progress")
    def progresso(self, obj):
        """Exibe o progresso percentual."""
        return f"{min(obj.progress, 100):.0f}%"

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user', 'mission')


# =============================================================================
# LOGS E HISTÓRICO (SOMENTE LEITURA)
# =============================================================================

@admin.register(XPTransaction)
class XPTransactionAdmin(admin.ModelAdmin):
    """
    Histórico de transações de XP.
    
    Registra cada ganho de XP por completar missões,
    incluindo transição de nível quando aplicável.
    
    Este modelo é somente leitura - registros são criados
    automaticamente pelo sistema.
    """
    
    list_display = (
        "user",
        "missao",
        "xp_ganho",
        "transicao_nivel",
        "created_at",
    )
    list_filter = ("created_at",)
    search_fields = ("user__username",)
    readonly_fields = (
        "user",
        "mission_progress",
        "points_awarded",
        "level_before",
        "level_after",
        "xp_before",
        "xp_after",
        "created_at",
    )
    date_hierarchy = "created_at"

    fieldsets = (
        ("Dados", {
            "fields": ("user", "mission_progress"),
        }),
        ("XP", {
            "fields": ("points_awarded", "xp_before", "xp_after"),
        }),
        ("Nível", {
            "fields": ("level_before", "level_after"),
        }),
        ("Data", {
            "fields": ("created_at",),
        }),
    )

    @admin.display(description="Missão")
    def missao(self, obj):
        """Exibe o título da missão relacionada."""
        if obj.mission_progress and obj.mission_progress.mission:
            return obj.mission_progress.mission.title
        return "-"

    @admin.display(description="XP Ganho", ordering="points_awarded")
    def xp_ganho(self, obj):
        """Exibe o XP ganho."""
        return f"+{obj.points_awarded} XP"

    @admin.display(description="Nível")
    def transicao_nivel(self, obj):
        """Exibe a transição de nível, se houver."""
        if obj.level_before == obj.level_after:
            return f"Nível {obj.level_after}"
        return f"{obj.level_before} → {obj.level_after}"

    def has_add_permission(self, request):
        """Desabilita criação manual."""
        return False

    def has_change_permission(self, request, obj=None):
        """Desabilita edição."""
        return False

    def has_delete_permission(self, request, obj=None):
        """Permite exclusão apenas para superusuários."""
        return request.user.is_superuser

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user', 'mission_progress__mission')


@admin.register(AdminActionLog)
class AdminActionLogAdmin(admin.ModelAdmin):
    """
    Log de ações administrativas.
    
    Registra ações realizadas por administradores,
    como desativação de usuários ou ajustes de XP.
    
    Este modelo é somente leitura - registros são criados
    automaticamente pelo sistema.
    """
    
    list_display = (
        "admin_user",
        "action_type",
        "target_user",
        "timestamp",
    )
    list_filter = ("action_type", "timestamp")
    search_fields = (
        "admin_user__username",
        "target_user__username",
        "reason",
    )
    readonly_fields = (
        "admin_user",
        "action_type",
        "target_user",
        "old_value",
        "new_value",
        "reason",
        "timestamp",
        "ip_address",
    )
    date_hierarchy = "timestamp"

    fieldsets = (
        ("Ação", {
            "fields": ("admin_user", "action_type", "reason"),
        }),
        ("Alvo", {
            "fields": ("target_user",),
        }),
        ("Valores", {
            "fields": ("old_value", "new_value"),
            "classes": ("collapse",),
        }),
        ("Metadados", {
            "fields": ("timestamp", "ip_address"),
            "classes": ("collapse",),
        }),
    )

    def has_add_permission(self, request):
        """Desabilita criação manual."""
        return False

    def has_change_permission(self, request, obj=None):
        """Desabilita edição."""
        return False

    def has_delete_permission(self, request, obj=None):
        """Permite exclusão apenas para superusuários."""
        return request.user.is_superuser

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('admin_user', 'target_user')
