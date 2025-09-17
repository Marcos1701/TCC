from django.contrib import admin

from .models import Category, Goal, Mission, MissionProgress, Transaction, UserProfile


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
