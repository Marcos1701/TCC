"""
Serializers para o modelo Goal.
"""

import logging

from django.db.models import Q

from .base import serializers, Category, Goal


logger = logging.getLogger(__name__)


class GoalSerializer(serializers.ModelSerializer):
    """Serializer para metas financeiras."""
    
    progress_percentage = serializers.FloatField(read_only=True)
    category_name = serializers.CharField(source='target_category.name', read_only=True, allow_null=True)
    tracked_category_ids = serializers.PrimaryKeyRelatedField(
        many=True,
        queryset=Category.objects.all(),
        source='tracked_categories',
        required=False,
        allow_null=True,
        write_only=True
    )
    tracked_categories_data = serializers.SerializerMethodField(read_only=True)
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request and request.user.is_authenticated:
            category_queryset = Category.objects.filter(
                Q(user=request.user) | Q(user__isnull=True)
            )
            self.fields["tracked_category_ids"].queryset = category_queryset
            if "target_category" in self.fields:
                self.fields["target_category"].queryset = category_queryset
    
    class Meta:
        model = Goal
        fields = (
            "id",
            "title",
            "description",
            "target_amount",
            "current_amount",
            "initial_amount",
            "deadline",
            "goal_type",
            "target_category",
            "category_name",
            "tracked_category_ids",
            "tracked_categories_data",
            "auto_update",
            "tracking_period",
            "is_reduction_goal",
            "progress_percentage",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")
    
    def get_tracked_categories_data(self, obj):
        return [
            {
                'id': cat.id,
                'name': cat.name,
                'color': cat.color,
                'type': cat.type,
                'group': cat.group,
            }
            for cat in obj.tracked_categories.all()
        ]

    def create(self, validated_data):
        tracked_categories = validated_data.pop('tracked_categories', [])
        validated_data["user"] = self.context["request"].user
        goal = super().create(validated_data)
        
        if tracked_categories:
            goal.tracked_categories.set(tracked_categories)
        
        return goal
    
    def update(self, instance, validated_data):
        tracked_categories = validated_data.pop('tracked_categories', None)
        goal = super().update(instance, validated_data)
        
        if tracked_categories is not None:
            goal.tracked_categories.set(tracked_categories)
        
        return goal
    
    def validate(self, attrs):
        logger.info(f"[GOAL SERIALIZER] Validating attrs: {attrs}")
        
        goal_type = attrs.get('goal_type', Goal.GoalType.CUSTOM)
        target_category = attrs.get('target_category')
        tracked_categories = attrs.get('tracked_categories', [])
        
        logger.info(f"[GOAL SERIALIZER] goal_type={goal_type}, target_category={target_category}, tracked_categories={len(tracked_categories)}")
        
        if goal_type in [Goal.GoalType.CATEGORY_EXPENSE, Goal.GoalType.CATEGORY_INCOME]:
            if not target_category and not tracked_categories:
                logger.error(f"[GOAL SERIALIZER] Validation failed: goal_type={goal_type} requires target_category or tracked_categories")
                raise serializers.ValidationError({
                    'target_category': 'Metas por categoria precisam de pelo menos uma categoria vinculada (target_category ou tracked_categories).'
                })
        
        return attrs
