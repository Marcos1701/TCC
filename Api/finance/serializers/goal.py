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
    
    # Campos calculados
    target_category_names = serializers.SerializerMethodField()
    target_category_name = serializers.SerializerMethodField()
    
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
            "target_categories",
            "target_category_names",
            "target_category",  # Compatibilidade (write_only)
            "target_category_name",  # Compatibilidade (read_only)
            "tracking_period_months",
            "deadline",
            "progress_percentage",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "current_amount", "created_at", "updated_at")
        # Nota: target_categories e target_category são adicionados dinamicamente no __init__
        extra_kwargs = {
            'target_categories': {'required': False},
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        from ..models import Category
        
        # Adiciona campos de categoria dinamicamente para evitar problema de queryset
        self.fields['target_categories'] = serializers.PrimaryKeyRelatedField(
            many=True,
            queryset=Category.objects.all(),
            required=False
        )
        self.fields['target_category'] = serializers.PrimaryKeyRelatedField(
            queryset=Category.objects.all(),
            required=False,
            write_only=True,
            allow_null=True
        )

    def get_target_category_names(self, obj):
        """Retorna lista de nomes das categorias alvo."""
        return [cat.name for cat in obj.target_categories.all()]
    
    def get_target_category_name(self, obj):
        """Compatibilidade: retorna nome da primeira categoria."""
        first_cat = obj.target_categories.first()
        return first_cat.name if first_cat else None

    def create(self, validated_data):
        # Extrai categorias antes de criar
        target_categories = validated_data.pop('target_categories', [])
        target_category = validated_data.pop('target_category', None)
        
        validated_data["user"] = self.context["request"].user
        goal = super().create(validated_data)
        
        # Adiciona categorias ao M2M
        if target_categories:
            goal.target_categories.set(target_categories)
        elif target_category:
            # Compatibilidade: aceita categoria única
            goal.target_categories.add(target_category)
        
        return goal
    
    def update(self, instance, validated_data):
        # Extrai categorias antes de atualizar
        target_categories = validated_data.pop('target_categories', None)
        target_category = validated_data.pop('target_category', None)
        
        instance = super().update(instance, validated_data)
        
        # Atualiza categorias se fornecidas
        if target_categories is not None:
            instance.target_categories.set(target_categories)
        elif target_category is not None:
            # Compatibilidade: aceita categoria única
            instance.target_categories.set([target_category])
        
        return instance
    
    def validate(self, attrs):
        goal_type = attrs.get('goal_type', self.instance.goal_type if self.instance else None)
        request = self.context.get('request')
        
        # Combina categorias de ambos os campos
        target_categories = attrs.get('target_categories', [])
        target_category = attrs.get('target_category')
        
        if target_category and not target_categories:
            target_categories = [target_category]
        
        # Validações específicas por tipo
        if goal_type == Goal.GoalType.EXPENSE_REDUCTION:
            # Validar que pelo menos uma categoria foi fornecida
            if not target_categories:
                raise serializers.ValidationError({
                    'target_categories': 'Metas de redução de gastos requerem pelo menos uma categoria alvo.'
                })
            
            # Validar limite de 5 categorias
            if len(target_categories) > 5:
                raise serializers.ValidationError({
                    'target_categories': 'Máximo de 5 categorias por meta.'
                })
            
            # Validar ownership e tipo de cada categoria
            from ..models import Category
            for category in target_categories:
                # Verificar se a categoria pertence ao usuário ou é global
                if not Category.objects.filter(
                    models.Q(id=category.id, user=request.user) | 
                    models.Q(id=category.id, user__isnull=True)
                ).exists():
                    raise serializers.ValidationError({
                        'target_categories': f'Você não pode usar a categoria "{category.name}" que não é sua.'
                    })
                
                # Validar que é categoria de despesa
                if category.type != 'EXPENSE':
                    raise serializers.ValidationError({
                        'target_categories': f'A categoria "{category.name}" deve ser de despesas (não de receitas).'
                    })
            
            # Validar baseline amount
            if not attrs.get('baseline_amount') or attrs.get('baseline_amount') <= 0:
                raise serializers.ValidationError({
                    'baseline_amount': 'Informe o gasto médio mensal atual nestas categorias.'
                })
            
            # Validar que target_amount seja menor que baseline (redução real)
            target_amount = attrs.get('target_amount')
            baseline_amount = attrs.get('baseline_amount')
            if target_amount and baseline_amount and target_amount >= baseline_amount:
                raise serializers.ValidationError({
                    'target_amount': f'A meta de redução (R$ {target_amount:.2f}) deve ser menor que o gasto atual (R$ {baseline_amount:.2f}).'
                })
        
        elif goal_type == Goal.GoalType.INCOME_INCREASE:
            if not attrs.get('baseline_amount') or attrs.get('baseline_amount') <= 0:
                raise serializers.ValidationError({
                    'baseline_amount': 'Informe sua receita média mensal atual para comparação.'
                })
        
        logger.info(f"[GOAL SERIALIZER] Validating attrs: {attrs}")
        return attrs
