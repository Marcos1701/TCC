"""
Módulo base com imports e helpers comuns para todas as views.
"""

import logging
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.db import transaction as db_transaction
from django.db.models import Q, Sum
from django.utils import timezone

from rest_framework import mixins, permissions, status, viewsets, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAdminUser
from rest_framework_simplejwt.tokens import RefreshToken
from django_filters.rest_framework import DjangoFilterBackend

from ..models import (
    Category,
    Mission,
    MissionProgress,
    Transaction,
    TransactionLink,
    UserProfile,
)
from ..permissions import IsOwnerPermission, IsOwnerOrReadOnly
from ..mixins import UUIDLookupMixin, UUIDResponseMixin
from ..throttling import (
    BurstRateThrottle,
    CategoryCreateThrottle,
    DashboardRefreshThrottle,
    LinkCreateThrottle,
    TransactionCreateThrottle,
)
from ..serializers import (
    CategorySerializer,
    DashboardSerializer,
    MissionProgressSerializer,
    MissionSerializer,
    TransactionSerializer,
    TransactionLinkSerializer,
    UserProfileSerializer,
)
from ..services import (
    analyze_user_context,
    apply_mission_reward,
    assign_missions_automatically,
    assign_missions_smartly,
    calculate_mission_priorities,
    calculate_summary,
    cashflow_series,
    category_breakdown,
    identify_improvement_opportunities,
    indicator_insights,
    invalidate_indicators_cache,
    profile_snapshot,
    update_mission_progress,
)

logger = logging.getLogger(__name__)
User = get_user_model()


def invalidate_user_dashboard_cache(user):
    """Invalida todos os caches relacionados ao usuário."""
    cache_keys = [
        f'dashboard_main_{user.id}',
        f'summary_{user.id}',
        f'dashboard_summary_{user.id}',
    ]
    
    for key in cache_keys:
        cache.delete(key)
    
    invalidate_indicators_cache(user)
