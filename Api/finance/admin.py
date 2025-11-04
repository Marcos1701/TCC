from django.contrib import admin

from .models import Category, Goal, Mission, MissionProgress, Transaction, UserProfile, XPTransaction


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
