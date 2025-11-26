"""
Views para dashboard e analytics.
"""

import logging

from django.core.cache import cache
from rest_framework import mixins, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from .base import (
    DashboardRefreshThrottle,
    DashboardSerializer,
    MissionProgress,
    MissionProgressSerializer,
    UserProfile,
    assign_missions_automatically,
    calculate_summary,
    cashflow_series,
    category_breakdown,
    indicator_insights,
    update_mission_progress,
)

logger = logging.getLogger(__name__)


class DashboardViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    """ViewSet para dashboard principal."""
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [DashboardRefreshThrottle]

    def list(self, request, *args, **kwargs):
        """Dashboard principal com cache de 5 minutos."""
        user = request.user
        force_refresh = request.query_params.get('refresh', 'false').lower() == 'true'
        cache_key = f'dashboard_main_{user.id}'
        
        if not force_refresh:
            cached_data = cache.get(cache_key)
            if cached_data:
                cached_data['from_cache'] = True
                cached_data['cache_ttl_seconds'] = cache.ttl(cache_key) if hasattr(cache, 'ttl') else 300
                return Response(cached_data)
        
        update_mission_progress(user)
        assign_missions_automatically(user)
        
        summary = calculate_summary(user)
        breakdown = category_breakdown(user)
        cashflow = cashflow_series(user)
        profile, _ = UserProfile.objects.get_or_create(user=user)
        insights = indicator_insights(summary, profile)
        
        active_missions = (
            MissionProgress.objects.filter(
                user=user,
                status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
            )
            .select_related("mission")
            .order_by("mission__priority")
        )
        
        recommendations = []
        
        serializer = DashboardSerializer(
            {
                "summary": summary,
                "categories": breakdown,
                "cashflow": cashflow,
                "insights": insights,
                "active_missions": active_missions,
                "recommended_missions": recommendations,
                "profile": profile,
            },
            context={"request": request},
        )
        
        response_data = serializer.data
        response_data['from_cache'] = False
        cache.set(cache_key, response_data, timeout=300)
        
        return Response(response_data)

    @action(detail=False, methods=["get"], url_path="missions")
    def missions_summary(self, request):
        """Resumo de missões do usuário."""
        update_mission_progress(request.user)
        
        progress_qs = MissionProgress.objects.filter(user=request.user).select_related("mission")
        serializer = MissionProgressSerializer(progress_qs, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=["get"], url_path="analytics")
    def analytics(self, request):
        """Retorna análises avançadas sobre evolução e padrões."""
        from ..services import (
            analyze_category_patterns,
            analyze_tier_progression,
            get_comprehensive_mission_context,
            get_mission_distribution_analysis,
        )
        
        user = request.user
        
        try:
            comprehensive = get_comprehensive_mission_context(user)
            category_patterns = analyze_category_patterns(user)
            tier_progression = analyze_tier_progression(user)
            mission_distribution = get_mission_distribution_analysis(user)
            
            return Response({
                'success': True,
                'comprehensive_context': comprehensive,
                'category_patterns': category_patterns,
                'tier_progression': tier_progression,
                'mission_distribution': mission_distribution
            })
            
        except Exception as e:
            logger.error(f"Erro ao gerar analytics para usuário {user.id}: {e}")
            return Response({
                'success': False,
                'error': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
