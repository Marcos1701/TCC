"""
Views para gerenciamento de metas financeiras.
"""

import logging

from django.db.models import Case, DecimalField, F, When
from rest_framework import permissions, viewsets
from rest_framework.pagination import PageNumberPagination
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response

from .base import (
    Goal,
    GoalSerializer,
    IsOwnerPermission,
    MissionProgress,
    TransactionSerializer,
    invalidate_user_dashboard_cache,
)

logger = logging.getLogger(__name__)


class GoalViewSet(viewsets.ModelViewSet):
    """
    ViewSet para gerenciamento de objetivos financeiros.
    Usa UUID como identificador primário.
    """
    serializer_class = GoalSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerPermission]
    pagination_class = PageNumberPagination  # Adiciona paginação padrão

    def get_queryset(self):
        return Goal.objects.filter(
            user=self.request.user
        ).order_by("-created_at")
    
    def perform_create(self, serializer):
        """Criar meta com validações adicionais."""
        user = self.request.user
        data = serializer.validated_data
        
        logger.info(f"[GOAL CREATE] User: {user.username}")
        logger.info(f"[GOAL CREATE] Validated data: {data}")
        
        active_goals = Goal.objects.filter(user=user).annotate(
            progress=Case(
                When(target_amount=0, then=0),
                default=(F('current_amount') * 100.0 / F('target_amount')),
                output_field=DecimalField()
            )
        ).filter(progress__lt=100).count()
        
        if active_goals >= 50:
            raise ValidationError({
                'non_field_errors': 'Você atingiu o limite de 50 metas ativas. Complete ou exclua metas antigas.'
            })
        
        title = data.get('title', '').strip()
        goal_type = data.get('goal_type')
        
        existing = Goal.objects.filter(
            user=user,
            title__iexact=title,
            goal_type=goal_type,
        ).annotate(
            progress=Case(
                When(target_amount=0, then=0),
                default=(F('current_amount') * 100.0 / F('target_amount')),
                output_field=DecimalField()
            )
        ).filter(progress__lt=100).exists()
        
        if existing:
            logger.warning(f"[GOAL CREATE] Duplicate goal found for user {user.username}")
            raise ValidationError({
                'title': f'Já existe uma meta ativa com o título "{title}" e mesmo tipo.'
            })
        
        try:
            logger.info("[GOAL CREATE] Attempting to save goal...")
            goal = serializer.save()
            logger.info(f"[GOAL CREATE] Goal saved successfully with ID: {goal.id}")
            invalidate_user_dashboard_cache(self.request.user)
        except Exception as e:
            logger.error(f"[GOAL CREATE] Error saving goal: {type(e).__name__}: {str(e)}")
            raise
    
    def perform_update(self, serializer):
        """Atualizar meta com validações adicionais."""
        serializer.save()
    
    def perform_destroy(self, instance):
        """Deletar meta com validações de segurança."""
        if instance.target_amount > 0:
            progress_percent = (float(instance.current_amount) / float(instance.target_amount)) * 100
            if progress_percent >= 80:
                logger.warning(
                    f"Meta {instance.id} excluída com {progress_percent:.1f}% de progresso."
                )
        
        active_mission_links = MissionProgress.objects.filter(
            user=instance.user,
            mission__target_goal=instance,
            status=MissionProgress.Status.ACTIVE
        ).count()
        
        if active_mission_links > 0:
            raise ValidationError({
                'non_field_errors': f'Esta meta está vinculada a {active_mission_links} missão(ões) ativa(s).'
            })
        
        instance.delete()
    
    @action(detail=True, methods=['get'])
    def transactions(self, request, pk=None):
        """
        Retorna transações relacionadas à meta.
        
        Para metas do tipo SAVINGS/EMERGENCY_FUND: transações em categorias SAVINGS/INVESTMENT
        Para metas do tipo EXPENSE_REDUCTION: transações na categoria alvo
        Para outros tipos: retorna lista vazia
        """
        from ..models import Category, Transaction
        
        goal = self.get_object()
        
        if goal.goal_type in [Goal.GoalType.SAVINGS, Goal.GoalType.EMERGENCY_FUND]:
            transactions = Transaction.objects.filter(
                user=goal.user,
                category__group__in=[
                    Category.CategoryGroup.SAVINGS,
                    Category.CategoryGroup.INVESTMENT
                ]
            ).select_related('category').order_by('-date', '-created_at')
        elif goal.goal_type == Goal.GoalType.EXPENSE_REDUCTION and goal.target_category:
            transactions = Transaction.objects.filter(
                user=goal.user,
                type=Transaction.TransactionType.EXPENSE,
                category=goal.target_category
            ).select_related('category').order_by('-date', '-created_at')
        else:
            transactions = Transaction.objects.none()
        
        serializer = TransactionSerializer(transactions[:50], many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def refresh(self, request, pk=None):
        """
        Força atualização do progresso da meta.
        
        Metas do tipo CUSTOM não são atualizadas automaticamente.
        """
        from ..services import update_goal_progress
        
        goal = self.get_object()
        
        # Metas CUSTOM são atualizadas manualmente, outros tipos são automáticos
        if goal.goal_type != Goal.GoalType.CUSTOM:
            update_goal_progress(goal)
            goal.refresh_from_db()
        
        serializer = self.get_serializer(goal)
        return Response(serializer.data)
    
    @action(detail=True, methods=['get'])
    def insights(self, request, pk=None):
        """Retorna insights sobre o progresso da meta."""
        from ..services import get_goal_insights
        
        goal = self.get_object()
        insights = get_goal_insights(goal)
        
        return Response(insights)
