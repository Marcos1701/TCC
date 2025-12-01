"""
Serializers para o modelo Goal.
"""

import logging

from django.db import models
from .base import serializers, Goal



logger = logging.getLogger(__name__)


class GoalSerializer(serializers.ModelSerializer):
    """Serializer para metas financeiras."""
    
    progress_percentage = serializers.FloatField(read_only=True)
    target_category_name = serializers.CharField(
        source='target_category.name',
        read_only=True,
        allow_null=True
    )
    
    class Meta:
        model = Goal
        fields = (
            "id",
            "title",
            "description",
            "goal_type",
            "target_amount",
            "current_amount",
            "initial_amount",
            "baseline_amount",
            "target_category",
            "target_category_name",
            "tracking_period_months",
            "deadline",
            "progress_percentage",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "current_amount", "created_at", "updated_at")

    def create(self, validated_data):
        validated_data["user"] = self.context["request"].user
        return super().create(validated_data)
    
    def validate(self, attrs):
        goal_type = attrs.get('goal_type', self.instance.goal_type if self.instance else None)
        request = self.context.get('request')
        
        # Validações específicas por tipo
        if goal_type == Goal.GoalType.EXPENSE_REDUCTION:
            target_category = attrs.get('target_category')
            
            # Validar que a categoria foi fornecida
            if not target_category:
                raise serializers.ValidationError({
                    'target_category': 'Metas de redução de gastos requerem uma categoria alvo.'
                })
            
            # Validar ownership da categoria
            if target_category and request:
                from ..models import Category
                # Verificar se a categoria pertence ao usuário ou é global (user=None)
                if not Category.objects.filter(
                    models.Q(id=target_category.id, user=request.user) | 
                    models.Q(id=target_category.id, user__isnull=True)
                ).exists():
                    raise serializers.ValidationError({
                        'target_category': 'Você não pode usar uma categoria que não é sua.'
                    })
            
            # Validar que é categoria de despesa
            if target_category and target_category.type != 'EXPENSE':
                raise serializers.ValidationError({
                    'target_category': 'A categoria alvo deve ser de despesas (não de receitas).'
                })
            
            # Validar baseline amount
            if not attrs.get('baseline_amount') or attrs.get('baseline_amount') <= 0:
                raise serializers.ValidationError({
                    'baseline_amount': 'Informe o gasto médio mensal atual nesta categoria.'
                })
        
        elif goal_type == Goal.GoalType.INCOME_INCREASE:
            if not attrs.get('baseline_amount') or attrs.get('baseline_amount') <= 0:
                raise serializers.ValidationError({
                    'baseline_amount': 'Informe sua receita média mensal atual para comparação.'
                })
        
        logger.info(f"[GOAL SERIALIZER] Validating attrs: {attrs}")
        return attrs

