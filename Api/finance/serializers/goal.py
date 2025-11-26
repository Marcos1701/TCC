"""
Serializers para o modelo Goal.
"""

import logging

from .base import serializers, Goal


logger = logging.getLogger(__name__)


class GoalSerializer(serializers.ModelSerializer):
    """Serializer para metas financeiras."""
    
    progress_percentage = serializers.FloatField(read_only=True)
    
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
            "progress_percentage",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")

    def create(self, validated_data):
        validated_data["user"] = self.context["request"].user
        return super().create(validated_data)
    
    def validate(self, attrs):
        logger.info(f"[GOAL SERIALIZER] Validating attrs: {attrs}")
        return attrs
