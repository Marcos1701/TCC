from django.contrib import admin

from .models import Category, Goal, Mission, MissionProgress, Transaction, TransactionLink, UserProfile, XPTransaction, Friendship


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ("user", "level", "experience_points", "target_tps", "target_rdr")
    search_fields = ("user__username", "user__email")


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ("name", "type", "user", "created_at")
    list_filter = ("type",)
    search_fields = ("name", "user__username", "user__email")


@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ("description", "type", "amount", "date", "user")
    list_filter = ("type", "date")
    search_fields = ("description", "user__username", "user__email")
    autocomplete_fields = ("category",)


@admin.register(TransactionLink)
class TransactionLinkAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'source_description', 'target_description', 'linked_amount', 'link_type', 'created_at')
    list_filter = ('link_type', 'is_recurring', 'created_at')
    search_fields = ('user__username', 'description', 'source_transaction__description', 'target_transaction__description')
    readonly_fields = ('created_at', 'updated_at')
    date_hierarchy = 'created_at'
    autocomplete_fields = ('user', 'source_transaction', 'target_transaction')
    
    def source_description(self, obj):
        return obj.source_transaction.description
    source_description.short_description = 'Origem'
    
    def target_description(self, obj):
        return obj.target_transaction.description
    target_description.short_description = 'Destino'


@admin.register(Goal)
class GoalAdmin(admin.ModelAdmin):
    list_display = ("title", "user", "target_amount", "current_amount", "deadline")
    search_fields = ("title", "user__username", "user__email")


@admin.register(Mission)
class MissionAdmin(admin.ModelAdmin):
    list_display = ("title", "difficulty", "reward_points", "is_active")
    list_filter = ("difficulty", "is_active")
    search_fields = ("title",)


@admin.register(MissionProgress)
class MissionProgressAdmin(admin.ModelAdmin):
    list_display = ("user", "mission", "status", "progress", "updated_at")
    list_filter = ("status",)
    search_fields = ("user__username", "mission__title")
    autocomplete_fields = ("user", "mission")


@admin.register(XPTransaction)
class XPTransactionAdmin(admin.ModelAdmin):
    list_display = ("user", "mission_title", "points_awarded", "level_transition", "created_at")
    list_filter = ("created_at", "level_after")
    search_fields = ("user__username", "user__email", "mission_progress__mission__title")
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
    
    def mission_title(self, obj):
        """Exibe o título da missão."""
        return obj.mission_progress.mission.title
    mission_title.short_description = "Missão"
    
    def level_transition(self, obj):
        """Exibe transição de nível de forma legível."""
        if obj.level_before == obj.level_after:
            return f"Nível {obj.level_after}"
        return f"{obj.level_before} → {obj.level_after}"
    level_transition.short_description = "Nível"
    
    def has_add_permission(self, request):
        """Não permite criação manual de registros de XP."""
        return False
    
    def has_change_permission(self, request, obj=None):
        """Não permite edição de registros de XP."""
        return False


@admin.register(Friendship)
class FriendshipAdmin(admin.ModelAdmin):
    list_display = ("user", "friend", "status", "created_at", "accepted_at")
    list_filter = ("status", "created_at", "accepted_at")
    search_fields = ("user__username", "user__email", "friend__username", "friend__email")
    readonly_fields = ("created_at", "accepted_at")
    autocomplete_fields = ("user", "friend")
    date_hierarchy = "created_at"
    
    def get_queryset(self, request):
        """Otimiza queries com select_related."""
        qs = super().get_queryset(request)
        return qs.select_related('user', 'friend')
