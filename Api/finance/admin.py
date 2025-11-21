from django.contrib import admin
from django.utils.html import format_html
from django.db.models import Count, Sum, Q
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
    Friendship,
    UserDailySnapshot,
    UserMonthlySnapshot,
    MissionProgressSnapshot,
    AdminActionLog,
    Achievement,
    UserAchievement,
)


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = (
        "user", 
        "level_badge", 
        "experience_points", 
        "targets_summary",
        "indicators_status",
        "first_access_badge",
    )
    list_filter = ("level", "is_first_access", "indicators_updated_at")
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
            "fields": ("user", "is_first_access")
        }),
        ("Gamificação", {
            "fields": ("level", "experience_points"),
        }),
        ("Metas", {
            "fields": ("target_tps", "target_rdr", "target_ili"),
        }),
        ("Indicadores em Cache", {
            "fields": (
                "cached_tps",
                "cached_rdr",
                "cached_ili",
                "cached_total_income",
                "cached_total_expense",
                "indicators_updated_at",
            ),
            "classes": ("collapse",),
        }),
    )
    
    def level_badge(self, obj):
        if obj.level >= 50:
            color = "#d4af37"
        elif obj.level >= 25:
            color = "#c0c0c0"
        elif obj.level >= 10:
            color = "#cd7f32"
        else:
            color = "#6c757d"
        
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 8px; '
            'border-radius: 3px; font-weight: bold;">Nv. {}</span>',
            color, obj.level
        )
    level_badge.short_description = "Nível"
    level_badge.admin_order_field = "level"
    
    def targets_summary(self, obj):
        return format_html(
            'TPS: {}% | RDR: {}% | ILI: {} meses',
            obj.target_tps, obj.target_rdr, obj.target_ili
        )
    targets_summary.short_description = "Metas"
    
    def indicators_status(self, obj):
        if not obj.indicators_updated_at:
            return format_html(
                '<span style="color: #dc3545;">Não calculado</span>'
            )
        
        now = timezone.now()
        delta = now - obj.indicators_updated_at
        
        if delta.days > 1:
            color = "#ffc107"
            status = f"{delta.days} dias atrás"
        elif delta.seconds > 3600:
            color = "#28a745"
            status = f"{delta.seconds // 3600}h atrás"
        else:
            color = "#28a745"
            status = "Atualizado"
        
        return format_html(
            '<span style="color: {};">{}</span>',
            color, status
        )
    indicators_status.short_description = "Cache"
    indicators_status.admin_order_field = "indicators_updated_at"
    
    def first_access_badge(self, obj):
        if obj.is_first_access:
            return format_html(
                '<span style="background-color: #007bff; color: white; padding: 3px 8px; '
                'border-radius: 3px; font-size: 11px;">Novo</span>'
            )
        return ""
    first_access_badge.short_description = "Status"
    first_access_badge.admin_order_field = "is_first_access"
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.select_related('user')


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = (
        "name", 
        "type_badge", 
        "user", 
        "transactions_count",
        "is_default_badge",
        "created_at",
    )
    list_filter = ("type", "is_system_default", "created_at")
    search_fields = ("name", "user__username", "user__email")
    readonly_fields = ("created_at",)
    
    fieldsets = (
        ("Dados Básicos", {
            "fields": ("name", "type", "user")
        }),
        ("Configurações", {
            "fields": ("is_system_default",),
            "description": "Categorias criadas automaticamente"
        }),
        ("Auditoria", {
            "fields": ("created_at",),
            "classes": ("collapse",)
        }),
    )
    
    def type_badge(self, obj):
        if obj.type == "income":
            return format_html(
                '<span style="background-color: #28a745; color: white; padding: 3px 8px; '
                'border-radius: 3px; font-weight: bold;">Receita</span>'
            )
        else:
            return format_html(
                '<span style="background-color: #dc3545; color: white; padding: 3px 8px; '
                'border-radius: 3px; font-weight: bold;">Despesa</span>'
            )
    type_badge.short_description = "Tipo"
    type_badge.admin_order_field = "type"
    
    def is_default_badge(self, obj):
        if obj.is_system_default:
            return format_html(
                '<span style="color: #007bff;">Padrão</span>'
            )
        return ""
    is_default_badge.short_description = "Sistema"
    is_default_badge.admin_order_field = "is_system_default"
    
    def transactions_count(self, obj):
        count = obj.transaction_set.count()
        if count > 0:
            return format_html(
                '<span style="color: #007bff; font-weight: bold;">{} transações</span>',
                count
            )
        return format_html('<span style="color: #6c757d;">-</span>')
    transactions_count.short_description = "Uso"
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.select_related('user').prefetch_related('transaction_set')


@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = (
        "description", 
        "type_badge", 
        "amount_display", 
        "date", 
        "user",
        "category",
        "recurrence_badge",
    )
    list_filter = (
        "type", 
        "date", 
        "is_recurring",
        "category__type",
    )
    search_fields = (
        "description", 
        "user__username", 
        "user__email",
        "category__name",
    )
    autocomplete_fields = ("category",)
    date_hierarchy = "date"
    readonly_fields = ("created_at", "updated_at")
    
    fieldsets = (
        ("Dados da Transação", {
            "fields": ("description", "type", "amount", "date", "user", "category")
        }),
        ("Recorrência", {
            "fields": ("is_recurring", "recurrence_value", "recurrence_unit", "recurrence_end_date"),
            "classes": ("collapse",),
            "description": "Configuração de repetição"
        }),
        ("Auditoria", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )
    
    def type_badge(self, obj):
        if obj.type == "INCOME":
            return format_html(
                '<span style="background-color: #28a745; color: white; padding: 2px 6px; '
                'border-radius: 3px; font-size: 11px;">Receita</span>'
            )
        else:
            return format_html(
                '<span style="background-color: #dc3545; color: white; padding: 2px 6px; '
                'border-radius: 3px; font-size: 11px;">Despesa</span>'
            )
    type_badge.short_description = "Tipo"
    type_badge.admin_order_field = "type"
    
    def amount_display(self, obj):
        color = "#28a745" if obj.type == "INCOME" else "#dc3545"
        symbol = "+" if obj.type == "INCOME" else "-"
        return format_html(
            '<span style="color: {}; font-weight: bold;">{} R$ {:.2f}</span>',
            color, symbol, obj.amount
        )
    amount_display.short_description = "Valor"
    amount_display.admin_order_field = "amount"
    
    def recurrence_badge(self, obj):
        if obj.is_recurring and obj.recurrence_unit:
            labels = {
                "DAYS": "Dias",
                "WEEKS": "Semanas",
                "MONTHS": "Meses",
            }
            label = labels.get(obj.recurrence_unit, obj.recurrence_unit)
            if obj.recurrence_value:
                label = f"{obj.recurrence_value} {label}"
            return format_html(
                '<span style="background-color: #17a2b8; color: white; padding: 2px 6px; '
                'border-radius: 3px; font-size: 11px;">{}</span>',
                label
            )
        return ""
    recurrence_badge.short_description = "Recorrência"
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.select_related('user', 'category')


@admin.register(TransactionLink)
class TransactionLinkAdmin(admin.ModelAdmin):
    list_display = (
        'id', 
        'user', 
        'get_source_description', 
        'get_target_description', 
        'linked_amount_display', 
        'link_type_badge', 
        'recurring_badge',
        'created_at',
    )
    list_filter = ('link_type', 'is_recurring', 'created_at')
    search_fields = ('user__username', 'description', 'id')
    readonly_fields = ('created_at', 'updated_at', 'source_transaction_uuid', 'target_transaction_uuid')
    date_hierarchy = 'created_at'
    autocomplete_fields = ('user',)
    
    fieldsets = (
        ("Dados do Vínculo", {
            "fields": ("user", "description", "link_type", "linked_amount")
        }),
        ("Transações Vinculadas", {
            "fields": ("source_transaction_uuid", "target_transaction_uuid"),
            "description": "Origem e destino"
        }),
        ("Configurações", {
            "fields": ("is_recurring",),
        }),
        ("Auditoria", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )
    
    def get_source_description(self, obj):
        try:
            transaction = Transaction.objects.get(id=obj.source_transaction_uuid)
            return format_html(
                '<span title="{}">{}</span>',
                f"R$ {transaction.amount:.2f} em {transaction.date}",
                transaction.description[:50]
            )
        except Transaction.DoesNotExist:
            return format_html('<span style="color: #dc3545;">-</span>')
    get_source_description.short_description = "Origem"
    
    def get_target_description(self, obj):
        try:
            transaction = Transaction.objects.get(id=obj.target_transaction_uuid)
            return format_html(
                '<span title="{}">{}</span>',
                f"R$ {transaction.amount:.2f} em {transaction.date}",
                transaction.description[:50]
            )
        except Transaction.DoesNotExist:
            return format_html('<span style="color: #dc3545;">-</span>')
    get_target_description.short_description = "Destino"
    
    def linked_amount_display(self, obj):
        return format_html(
            '<span style="font-weight: bold;">R$ {:.2f}</span>',
            obj.linked_amount
        )
    linked_amount_display.short_description = "Valor"
    linked_amount_display.admin_order_field = "linked_amount"
    
    def link_type_badge(self, obj):
        labels = {
            "transfer": ("Transferência", "#17a2b8"),
            "payment": ("Pagamento", "#28a745"),
            "investment": ("Investimento", "#ffc107"),
            "loan": ("Empréstimo", "#dc3545"),
        }
        label, color = labels.get(obj.link_type, (obj.link_type, "#6c757d"))
        return format_html(
            '<span style="background-color: {}; color: white; padding: 2px 6px; '
            'border-radius: 3px; font-size: 11px;">{}</span>',
            color, label
        )
    link_type_badge.short_description = "Tipo"
    link_type_badge.admin_order_field = "link_type"
    
    def recurring_badge(self, obj):
        if obj.is_recurring:
            return format_html(
                '<span style="color: #007bff;">Recorrente</span>'
            )
        return ""
    recurring_badge.short_description = "Recorrente"
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.select_related('user')


@admin.register(Goal)
class GoalAdmin(admin.ModelAdmin):
    list_display = (
        "title", 
        "user", 
        "progress_bar", 
        "target_amount_display",
        "deadline",
        "status_badge",
    )
    list_filter = ("deadline", "created_at")
    search_fields = ("title", "user__username", "user__email", "description")
    readonly_fields = ("created_at", "updated_at", "current_amount")
    date_hierarchy = "deadline"
    
    fieldsets = (
        ("Dados da Meta", {
            "fields": ("user", "title", "description")
        }),
        ("Valores", {
            "fields": ("target_amount", "current_amount", "initial_amount"),
        }),
        ("Prazo", {
            "fields": ("deadline",),
        }),
        ("Categorias Rastreadas", {
            "fields": ("tracked_categories",),
            "classes": ("collapse",),
        }),
        ("Auditoria", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )
    
    def target_amount_display(self, obj):
        return format_html(
            '<span style="font-weight: bold;">R$ {:.2f}</span>',
            obj.target_amount
        )
    target_amount_display.short_description = "Valor Alvo"
    target_amount_display.admin_order_field = "target_amount"
    
    def progress_bar(self, obj):
        if obj.target_amount <= 0:
            percentage = 0
        else:
            percentage = min((obj.current_amount / obj.target_amount) * 100, 100)
        
        if percentage >= 100:
            color = "#28a745"
        elif percentage >= 75:
            color = "#17a2b8"
        elif percentage >= 50:
            color = "#ffc107"
        else:
            color = "#dc3545"
        
        return format_html(
            '<div style="width: 100px; background-color: #e9ecef; border-radius: 3px; overflow: hidden;">'
            '<div style="width: {}%; background-color: {}; color: white; text-align: center; '
            'padding: 2px 0; font-size: 10px; font-weight: bold;">{:.0f}%</div>'
            '</div>',
            percentage, color, percentage
        )
    progress_bar.short_description = "Progresso"
    
    def status_badge(self, obj):
        now = timezone.now().date()
        percentage = (obj.current_amount / obj.target_amount * 100) if obj.target_amount > 0 else 0
        
        if percentage >= 100:
            return format_html(
                '<span style="background-color: #28a745; color: white; padding: 3px 8px; '
                'border-radius: 3px; font-weight: bold;">Concluída</span>'
            )
        elif obj.deadline and obj.deadline < now:
            return format_html(
                '<span style="background-color: #dc3545; color: white; padding: 3px 8px; '
                'border-radius: 3px; font-weight: bold;">Vencida</span>'
            )
        elif obj.deadline and (obj.deadline - now).days <= 7:
            return format_html(
                '<span style="background-color: #ffc107; color: black; padding: 3px 8px; '
                'border-radius: 3px; font-weight: bold;">Urgente</span>'
            )
        else:
            return format_html(
                '<span style="background-color: #17a2b8; color: white; padding: 3px 8px; '
                'border-radius: 3px; font-weight: bold;">Em Andamento</span>'
            )
    status_badge.short_description = "Status"
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.select_related('user').prefetch_related('tracked_categories')


@admin.register(Mission)
class MissionAdmin(admin.ModelAdmin):
    list_display = (
        "title", 
        "difficulty_badge", 
        "reward_points_display",
        "type_info",
        "active_badge",
        "users_progress",
    )
    list_filter = ("difficulty", "is_active", "mission_type", "created_at")
    search_fields = ("title", "description", "mission_type")
    readonly_fields = ("created_at", "updated_at")
    
    fieldsets = (
        ("Dados Básicos", {
            "fields": ("title", "description", "difficulty", "is_active")
        }),
        ("Configuração da Missão", {
            "fields": (
                "mission_type",
                "target_value",
                "reward_points",
                "duration_days",
            ),
        }),
        ("Critérios de Indicadores", {
            "fields": ("min_ili", "max_ili", "min_tps", "max_tps", "min_rdr", "max_rdr"),
            "classes": ("collapse",),
        }),
        ("Dicas e Orientações", {
            "fields": ("tips",),
            "classes": ("collapse",),
        }),
        ("Auditoria", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )
    
    def difficulty_badge(self, obj):
        badges = {
            "easy": ("Fácil", "#28a745"),
            "medium": ("Média", "#ffc107"),
            "hard": ("Difícil", "#dc3545"),
            "expert": ("Expert", "#6f42c1"),
        }
        label, color = badges.get(obj.difficulty, (obj.difficulty.upper(), "#6c757d"))
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 8px; '
            'border-radius: 3px; font-weight: bold;">{}</span>',
            color, label
        )
    difficulty_badge.short_description = "Dificuldade"
    difficulty_badge.admin_order_field = "difficulty"
    
    def reward_points_display(self, obj):
        return format_html(
            '<span style="color: #ffc107; font-weight: bold;">{} XP</span>',
            obj.reward_points
        )
    reward_points_display.short_description = "Recompensa"
    reward_points_display.admin_order_field = "reward_points"
    
    def type_info(self, obj):
        info = obj.mission_type
        if obj.target_value:
            info += f" ({obj.target_value})"
        
        return format_html('<span>{}</span>', info)
    type_info.short_description = "Tipo"
    
    def active_badge(self, obj):
        if obj.is_active:
            return format_html(
                '<span style="color: #28a745; font-weight: bold;">Ativa</span>'
            )
        return format_html(
            '<span style="color: #6c757d;">Inativa</span>'
        )
    active_badge.short_description = "Status"
    active_badge.admin_order_field = "is_active"
    
    def users_progress(self, obj):
        count = obj.missionprogress_set.count()
        completed = obj.missionprogress_set.filter(status='completed').count()
        
        if count > 0:
            return format_html(
                '<span title="{} concluídas">{} usuários</span>',
                completed, count
            )
        return format_html('<span style="color: #6c757d;">-</span>')
    users_progress.short_description = "Usuários"
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.prefetch_related('missionprogress_set')


@admin.register(MissionProgress)
class MissionProgressAdmin(admin.ModelAdmin):
    list_display = (
        "user", 
        "mission_info", 
        "status_badge",
        "progress_bar", 
        "updated_at",
    )
    list_filter = ("status", "mission__difficulty", "updated_at")
    search_fields = ("user__username", "mission__title")
    autocomplete_fields = ("user", "mission")
    readonly_fields = ("started_at", "completed_at", "updated_at")
    date_hierarchy = "updated_at"
    
    fieldsets = (
        ("Progresso", {
            "fields": ("user", "mission", "status", "progress")
        }),
        ("Datas", {
            "fields": ("started_at", "completed_at", "updated_at"),
        }),
    )
    
    def mission_info(self, obj):
        return format_html(
            '<strong>{}</strong><br/>'
            '<span style="font-size: 11px; color: #6c757d;">{} - {} XP</span>',
            obj.mission.title[:50],
            obj.mission.get_difficulty_display(),
            obj.mission.reward_points
        )
    mission_info.short_description = "Missão"
    
    def status_badge(self, obj):
        badges = {
            "not_started": ("Não Iniciada", "#6c757d"),
            "in_progress": ("Em Progresso", "#007bff"),
            "completed": ("Concluída", "#28a745"),
            "failed": ("Falhou", "#dc3545"),
        }
        label, color = badges.get(obj.status, (obj.status, "#6c757d"))
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 8px; '
            'border-radius: 3px; font-weight: bold;">{}</span>',
            color, label
        )
    status_badge.short_description = "Status"
    status_badge.admin_order_field = "status"
    
    def progress_bar(self, obj):
        percentage = min(obj.progress, 100)
        
        if percentage >= 100:
            color = "#28a745"
        elif percentage >= 75:
            color = "#17a2b8"
        elif percentage >= 50:
            color = "#ffc107"
        else:
            color = "#007bff"
        
        return format_html(
            '<div style="width: 120px; background-color: #e9ecef; border-radius: 3px; overflow: hidden;">'
            '<div style="width: {}%; background-color: {}; color: white; text-align: center; '
            'padding: 2px 0; font-size: 10px; font-weight: bold;">{:.0f}%</div>'
            '</div>',
            percentage, color, percentage
        )
    progress_bar.short_description = "Progresso"
    progress_bar.admin_order_field = "progress"
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.select_related('user', 'mission')


@admin.register(XPTransaction)
class XPTransactionAdmin(admin.ModelAdmin):
    list_display = (
        "user", 
        "get_mission_title", 
        "points_display",
        "level_transition", 
        "created_at",
    )
    list_filter = ("created_at", "level_after", "level_before")
    search_fields = ("user__username", "user__email")
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
            "fields": (
                "points_awarded",
                ("xp_before", "xp_after"),
            ),
        }),
        ("Nível", {
            "fields": (
                ("level_before", "level_after"),
            ),
        }),
        ("Auditoria", {
            "fields": ("created_at",),
        }),
    )
    
    def get_mission_title(self, obj):
        if obj.mission_progress and obj.mission_progress.mission:
            return format_html(
                '<span title="{}">{}</span>',
                obj.mission_progress.mission.description[:100],
                obj.mission_progress.mission.title
            )
        return format_html('<span style="color: #6c757d;">-</span>')
    get_mission_title.short_description = "Missão"
    
    def points_display(self, obj):
        return format_html(
            '<span style="color: #ffc107; font-weight: bold;">+{} XP</span>',
            obj.points_awarded
        )
    points_display.short_description = "Pontos"
    points_display.admin_order_field = "points_awarded"
    
    def level_transition(self, obj):
        if obj.level_before == obj.level_after:
            return format_html(
                '<span style="color: #6c757d;">Nível {}</span>',
                obj.level_after
            )
        return format_html(
            '<span style="color: #28a745; font-weight: bold;">{} → {}</span>',
            obj.level_before, obj.level_after
        )
    level_transition.short_description = "Nível"
    
    def has_add_permission(self, request):
        return False
    
    def has_change_permission(self, request, obj=None):
        return False
    
    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.select_related('user', 'mission_progress__mission')


@admin.register(Friendship)
class FriendshipAdmin(admin.ModelAdmin):
    list_display = (
        "user", 
        "friend", 
        "status_badge", 
        "created_at", 
        "accepted_at",
    )
    list_filter = ("status", "created_at", "accepted_at")
    search_fields = (
        "user__username", 
        "user__email", 
        "friend__username", 
        "friend__email",
    )
    readonly_fields = ("created_at", "accepted_at")
    autocomplete_fields = ("user", "friend")
    date_hierarchy = "created_at"
    
    fieldsets = (
        ("Amizade", {
            "fields": (("user", "friend"), "status")
        }),
        ("Datas", {
            "fields": ("created_at", "accepted_at"),
        }),
    )
    
    def status_badge(self, obj):
        badges = {
            "pending": ("Pendente", "#ffc107"),
            "accepted": ("Aceita", "#28a745"),
            "rejected": ("Rejeitada", "#dc3545"),
            "blocked": ("Bloqueada", "#6c757d"),
        }
        label, color = badges.get(obj.status, (obj.status, "#6c757d"))
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 8px; '
            'border-radius: 3px; font-weight: bold;">{}</span>',
            color, label
        )
    status_badge.short_description = "Status"
    status_badge.admin_order_field = "status"
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.select_related('user', 'friend')


@admin.register(UserDailySnapshot)
class UserDailySnapshotAdmin(admin.ModelAdmin):
    list_display = (
        "user",
        "snapshot_date",
        "indicators_summary",
        "balance_display",
    )
    list_filter = ("snapshot_date",)
    search_fields = ("user__username", "user__email")
    readonly_fields = (
        "user",
        "snapshot_date",
        "total_income",
        "total_expense",
        "total_debt",
        "available_balance",
        "tps",
        "rdr",
        "ili",
    )
    date_hierarchy = "snapshot_date"
    
    fieldsets = (
        ("Identificação", {
            "fields": ("user", "snapshot_date")
        }),
        ("Financeiro", {
            "fields": ("total_income", "total_expense", "total_debt", "available_balance"),
        }),
        ("Indicadores", {
            "fields": ("tps", "rdr", "ili"),
        }),
    )
    
    def indicators_summary(self, obj):
        tps_val = f"{obj.tps:.1f}%" if obj.tps is not None else "N/A"
        rdr_val = f"{obj.rdr:.1f}%" if obj.rdr is not None else "N/A"
        ili_val = f"{obj.ili:.1f}" if obj.ili is not None else "N/A"
        
        return format_html(
            '<span style="font-size: 11px;">'
            'TPS: {} | RDR: {} | ILI: {}'
            '</span>',
            tps_val, rdr_val, ili_val
        )
    indicators_summary.short_description = "Indicadores"
    
    def balance_display(self, obj):
        color = "#28a745" if obj.available_balance >= 0 else "#dc3545"
        return format_html(
            '<span style="color: {}; font-weight: bold;">R$ {:.2f}</span>',
            color, obj.available_balance
        )
    balance_display.short_description = "Saldo"
    balance_display.admin_order_field = "available_balance"
    
    def has_add_permission(self, request):
        return False
    
    def has_change_permission(self, request, obj=None):
        return False
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.select_related('user')


@admin.register(UserMonthlySnapshot)
class UserMonthlySnapshotAdmin(admin.ModelAdmin):
    list_display = (
        "user",
        "month_year",
        "financial_summary",
    )
    list_filter = ("month", "year")
    search_fields = ("user__username", "user__email")
    readonly_fields = (
        "user",
        "month",
        "year",
        "total_income",
        "total_expense",
        "total_savings",
        "avg_tps",
        "avg_rdr",
        "avg_ili",
        "top_category",
        "top_category_amount",
        "consistency_rate",
    )
    
    fieldsets = (
        ("Período", {
            "fields": ("user", "month", "year")
        }),
        ("Financeiro", {
            "fields": ("total_income", "total_expense", "total_savings", "top_category", "top_category_amount"),
        }),
        ("Indicadores Médios", {
            "fields": ("avg_tps", "avg_rdr", "avg_ili"),
        }),
        ("Consistência", {
            "fields": ("consistency_rate",),
        }),
    )
    
    def month_year(self, obj):
        months = [
            "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
            "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
        ]
        return f"{months[obj.month - 1]}/{obj.year}"
    month_year.short_description = "Período"
    month_year.admin_order_field = "year"
    
    def financial_summary(self, obj):
        balance = obj.total_income - obj.total_expense
        color = "#28a745" if balance >= 0 else "#dc3545"
        
        return format_html(
            '<div style="font-size: 11px;">'
            'Receitas: R$ {:.2f}<br/>'
            'Despesas: R$ {:.2f}<br/>'
            '<strong style="color: {};">Saldo: R$ {:.2f}</strong>'
            '</div>',
            obj.total_income, obj.total_expense, color, balance
        )
    financial_summary.short_description = "Resumo Financeiro"
    
    def has_add_permission(self, request):
        return False
    
    def has_change_permission(self, request, obj=None):
        return False
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.select_related('user')


@admin.register(AdminActionLog)
class AdminActionLogAdmin(admin.ModelAdmin):
    list_display = (
        "admin_user",
        "action_type_badge",
        "target_user",
        "timestamp",
    )
    list_filter = ("action_type", "timestamp")
    search_fields = (
        "admin_user__username",
        "admin_user__email",
        "target_user__username",
        "target_user__email",
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
            "fields": ("admin_user", "action_type", "reason")
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
    
    def action_type_badge(self, obj):
        badges = {
            "USER_DEACTIVATED": ("Desativado", "#dc3545"),
            "USER_REACTIVATED": ("Reativado", "#28a745"),
            "XP_ADJUSTED": ("XP Ajustado", "#ffc107"),
            "LEVEL_ADJUSTED": ("Nível Ajustado", "#17a2b8"),
            "PROFILE_UPDATED": ("Perfil Atualizado", "#007bff"),
            "MISSIONS_RESET": ("Missões Resetadas", "#6f42c1"),
            "TRANSACTIONS_DELETED": ("Transações Deletadas", "#dc3545"),
            "OTHER": ("Outro", "#6c757d"),
        }
        label, color = badges.get(obj.action_type, (obj.action_type, "#6c757d"))
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 8px; '
            'border-radius: 3px; font-size: 11px;">{}</span>',
            color, label
        )
    action_type_badge.short_description = "Tipo"
    action_type_badge.admin_order_field = "action_type"
    
    def has_add_permission(self, request):
        return False
    
    def has_change_permission(self, request, obj=None):
        return False
    
    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.select_related('admin_user', 'target_user')


@admin.register(MissionProgressSnapshot)
class MissionProgressSnapshotAdmin(admin.ModelAdmin):
    list_display = (
        "mission_progress",
        "snapshot_date",
        "criteria_status",
    )
    list_filter = ("snapshot_date", "met_criteria")
    search_fields = (
        "mission_progress__user__username",
        "mission_progress__mission__title",
    )
    readonly_fields = (
        "mission_progress",
        "snapshot_date",
        "tps_value",
        "rdr_value",
        "ili_value",
        "category_spending",
        "goal_progress",
        "savings_amount",
        "met_criteria",
    )
    date_hierarchy = "snapshot_date"
    
    fieldsets = (
        ("Identificação", {
            "fields": ("mission_progress", "snapshot_date")
        }),
        ("Indicadores", {
            "fields": ("tps_value", "rdr_value", "ili_value"),
        }),
        ("Valores Específicos", {
            "fields": ("category_spending", "goal_progress", "savings_amount"),
            "classes": ("collapse",),
        }),
        ("Validação", {
            "fields": ("met_criteria",),
        }),
    )
    
    def criteria_status(self, obj):
        if obj.met_criteria:
            return format_html(
                '<span style="background-color: #28a745; color: white; padding: 2px 8px; '
                'border-radius: 3px; font-size: 11px;">Atendido</span>'
            )
        return format_html(
            '<span style="background-color: #dc3545; color: white; padding: 2px 8px; '
            'border-radius: 3px; font-size: 11px;">Não atendido</span>'
        )
    criteria_status.short_description = "Status"
    
    def has_add_permission(self, request):
        return False
    
    def has_change_permission(self, request, obj=None):
        return False
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.select_related('mission_progress__user', 'mission_progress__mission')


@admin.register(Achievement)
class AchievementAdmin(admin.ModelAdmin):
    list_display = (
        "icon_title",
        "category_badge",
        "tier_badge",
        "xp_reward_display",
        "active_badge",
        "ai_generated_badge",
        "users_unlocked",
    )
    list_filter = ("category", "tier", "is_active", "is_ai_generated")
    search_fields = ("title", "description")
    readonly_fields = ("created_at", "updated_at")
    
    fieldsets = (
        ("Dados Básicos", {
            "fields": ("title", "description", "icon")
        }),
        ("Classificação", {
            "fields": ("category", "tier", "priority"),
        }),
        ("Recompensa", {
            "fields": ("xp_reward",),
        }),
        ("Critérios de Desbloqueio", {
            "fields": ("criteria",),
        }),
        ("Configurações", {
            "fields": ("is_active", "is_ai_generated"),
        }),
        ("Auditoria", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )
    
    def icon_title(self, obj):
        return format_html(
            '<span style="font-size: 16px;">{} {}</span>',
            obj.icon, obj.title
        )
    icon_title.short_description = "Conquista"
    
    def category_badge(self, obj):
        colors = {
            "FINANCIAL": "#28a745",
            "SOCIAL": "#17a2b8",
            "MISSION": "#ffc107",
            "STREAK": "#dc3545",
            "GENERAL": "#6c757d",
        }
        color = colors.get(obj.category, "#6c757d")
        return format_html(
            '<span style="background-color: {}; color: white; padding: 2px 6px; '
            'border-radius: 3px; font-size: 11px;">{}</span>',
            color, obj.get_category_display()
        )
    category_badge.short_description = "Categoria"
    category_badge.admin_order_field = "category"
    
    def tier_badge(self, obj):
        colors = {
            "BEGINNER": "#28a745",
            "INTERMEDIATE": "#ffc107",
            "ADVANCED": "#dc3545",
        }
        color = colors.get(obj.tier, "#6c757d")
        return format_html(
            '<span style="background-color: {}; color: white; padding: 2px 6px; '
            'border-radius: 3px; font-size: 11px;">{}</span>',
            color, obj.get_tier_display()
        )
    tier_badge.short_description = "Nível"
    tier_badge.admin_order_field = "tier"
    
    def xp_reward_display(self, obj):
        return format_html(
            '<span style="color: #ffc107; font-weight: bold;">{} XP</span>',
            obj.xp_reward
        )
    xp_reward_display.short_description = "Recompensa"
    xp_reward_display.admin_order_field = "xp_reward"
    
    def active_badge(self, obj):
        if obj.is_active:
            return format_html('<span style="color: #28a745;">Ativa</span>')
        return format_html('<span style="color: #6c757d;">Inativa</span>')
    active_badge.short_description = "Status"
    active_badge.admin_order_field = "is_active"
    
    def ai_generated_badge(self, obj):
        if obj.is_ai_generated:
            return format_html(
                '<span style="background-color: #6f42c1; color: white; padding: 2px 6px; '
                'border-radius: 3px; font-size: 11px;">IA</span>'
            )
        return ""
    ai_generated_badge.short_description = "Origem"
    
    def users_unlocked(self, obj):
        count = obj.user_achievements.filter(is_unlocked=True).count()
        total = obj.user_achievements.count()
        
        if count > 0:
            return format_html(
                '<span style="font-weight: bold;">{} / {} usuários</span>',
                count, total
            )
        return format_html('<span style="color: #6c757d;">-</span>')
    users_unlocked.short_description = "Desbloques"
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.prefetch_related('user_achievements')


@admin.register(UserAchievement)
class UserAchievementAdmin(admin.ModelAdmin):
    list_display = (
        "user",
        "achievement_info",
        "progress_bar",
        "unlocked_badge",
        "unlocked_at",
    )
    list_filter = ("is_unlocked", "unlocked_at", "achievement__category", "achievement__tier")
    search_fields = (
        "user__username",
        "user__email",
        "achievement__title",
    )
    autocomplete_fields = ("user", "achievement")
    readonly_fields = ("unlocked_at", "created_at", "updated_at")
    date_hierarchy = "unlocked_at"
    
    fieldsets = (
        ("Relacionamento", {
            "fields": ("user", "achievement")
        }),
        ("Progresso", {
            "fields": ("is_unlocked", "progress", "progress_max"),
        }),
        ("Datas", {
            "fields": ("unlocked_at", "created_at", "updated_at"),
        }),
    )
    
    def achievement_info(self, obj):
        return format_html(
            '<strong>{} {}</strong><br/>'
            '<span style="font-size: 11px; color: #6c757d;">{} - {} XP</span>',
            obj.achievement.icon,
            obj.achievement.title,
            obj.achievement.get_tier_display(),
            obj.achievement.xp_reward
        )
    achievement_info.short_description = "Conquista"
    
    def progress_bar(self, obj):
        if obj.is_unlocked:
            percentage = 100
            color = "#28a745"
        else:
            if obj.progress_max > 0:
                percentage = min((obj.progress / obj.progress_max) * 100, 100)
            else:
                percentage = 0
            
            if percentage >= 75:
                color = "#17a2b8"
            elif percentage >= 50:
                color = "#ffc107"
            else:
                color = "#007bff"
        
        return format_html(
            '<div style="width: 120px; background-color: #e9ecef; border-radius: 3px; overflow: hidden;">'
            '<div style="width: {}%; background-color: {}; color: white; text-align: center; '
            'padding: 2px 0; font-size: 10px; font-weight: bold;">{:.0f}%</div>'
            '</div>'
            '<span style="font-size: 11px; color: #6c757d; margin-left: 5px;">{}/{}</span>',
            percentage, color, percentage,
            obj.progress, obj.progress_max
        )
    progress_bar.short_description = "Progresso"
    
    def unlocked_badge(self, obj):
        if obj.is_unlocked:
            return format_html(
                '<span style="background-color: #28a745; color: white; padding: 3px 8px; '
                'border-radius: 3px; font-weight: bold;">Desbloqueada</span>'
            )
        return format_html(
            '<span style="background-color: #6c757d; color: white; padding: 3px 8px; '
            'border-radius: 3px;">Bloqueada</span>'
        )
    unlocked_badge.short_description = "Status"
    unlocked_badge.admin_order_field = "is_unlocked"
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.select_related('user', 'achievement')
