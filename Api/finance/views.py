from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.db.models import Q
from rest_framework import mixins, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
import logging

logger = logging.getLogger(__name__)

from .models import Category, Goal, Mission, MissionProgress, Transaction, TransactionLink, UserProfile, Friendship
from .permissions import IsOwnerPermission, IsOwnerOrReadOnly
from .mixins import UUIDLookupMixin, UUIDResponseMixin
from .throttling import (
    BurstRateThrottle,
    CategoryCreateThrottle,
    DashboardRefreshThrottle,
    GoalCreateThrottle,
    LinkCreateThrottle,
    TransactionCreateThrottle,
)
from .serializers import (
    CategorySerializer,
    DashboardSerializer,
    GoalSerializer,
    MissionProgressSerializer,
    MissionSerializer,
    TransactionSerializer,
    TransactionLinkSerializer,
    UserProfileSerializer,
    FriendshipSerializer,
)
from .services import (
    apply_mission_reward,
    assign_missions_automatically,
    calculate_summary,
    cashflow_series,
    category_breakdown,
    indicator_insights,
    invalidate_indicators_cache,
    profile_snapshot,
    recommend_missions,
    update_mission_progress,
)

User = get_user_model()


# ============================================================================
# CACHE INVALIDATION HELPER
# ============================================================================
def invalidate_user_dashboard_cache(user):
    """
    Invalida todos os caches relacionados ao usuário.
    
    Deve ser chamado ao:
    - Criar/editar/deletar Transaction
    - Criar/editar/deletar TransactionLink
    - Criar/editar/deletar Goal
    - Completar missão
    
    Args:
        user: Usuário cujo cache deve ser invalidado
    """
    cache_keys = [
        f'dashboard_main_{user.id}',
        f'summary_{user.id}',
        f'dashboard_summary_{user.id}',
    ]
    
    for key in cache_keys:
        cache.delete(key)
    
    # Invalidar cache de indicadores também (UserProfile)
    invalidate_indicators_cache(user)


class CategoryViewSet(viewsets.ModelViewSet):
    serializer_class = CategorySerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_throttles(self):
        """
        Aplica rate limiting apenas em operações de criação.
        Leitura não é limitada para não impactar UX.
        """
        if self.action == 'create':
            return [CategoryCreateThrottle(), BurstRateThrottle()]
        return super().get_throttles()

    def get_queryset(self):
        """
        Retorna categorias do usuário autenticado e, se for admin, 
        também retorna categorias globais (user=None).
        SEGURANÇA: Isolamento total de dados entre usuários.
        """
        user = self.request.user
        
        # Todos os usuários veem suas categorias + categorias globais (user=None)
        # Categorias globais são as criadas pelo sistema, disponíveis para todos
        qs = Category.objects.filter(
            Q(user=user) | Q(user=None)
        )
        
        # Filtros opcionais
        category_type = self.request.query_params.get("type")
        if category_type:
            qs = qs.filter(type=category_type)
        
        group = self.request.query_params.get("group")
        if group:
            qs = qs.filter(group=group)
        
        return qs.order_by("name")

    def perform_create(self, serializer):
        """
        Sempre associa categoria ao usuário atual.
        Categorias personalizadas não são marcadas como system_default.
        """
        serializer.save(user=self.request.user, is_system_default=False)


class TransactionViewSet(viewsets.ModelViewSet):
    """
    ViewSet para gerenciar transações.
    Usa UUID como identificador primário.
    """
    serializer_class = TransactionSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerPermission]
    
    def get_throttles(self):
        """
        Aplica rate limiting em criações e atualizações.
        DELETE tem burst protection.
        """
        if self.action in ['create', 'update', 'partial_update']:
            return [TransactionCreateThrottle(), BurstRateThrottle()]
        elif self.action == 'destroy':
            return [BurstRateThrottle()]
        return super().get_throttles()

    def get_queryset(self):
        # Otimizado: select_related para evitar N+1 queries
        qs = Transaction.objects.filter(
            user=self.request.user
        ).select_related(
            "category"
        )
        
        tx_type = self.request.query_params.get("type")
        if tx_type:
            qs = qs.filter(type=tx_type)
        
        # Filtros avançados
        category_id = self.request.query_params.get("category")
        if category_id:
            qs = qs.filter(category_id=category_id)
        
        date_from = self.request.query_params.get("date_from")
        if date_from:
            qs = qs.filter(date__gte=date_from)
        
        date_to = self.request.query_params.get("date_to")
        if date_to:
            qs = qs.filter(date__lte=date_to)
        
        min_amount = self.request.query_params.get("min_amount")
        if min_amount:
            qs = qs.filter(amount__gte=min_amount)
        
        max_amount = self.request.query_params.get("max_amount")
        if max_amount:
            qs = qs.filter(amount__lte=max_amount)
        
        is_recurring = self.request.query_params.get("is_recurring")
        if is_recurring is not None:
            qs = qs.filter(is_recurring=is_recurring.lower() == 'true')
        
        return qs.order_by("-date", "-created_at")
    
    def perform_create(self, serializer):
        serializer.save()
        # Invalidar todos os caches após criar transação
        invalidate_user_dashboard_cache(self.request.user)
    
    def perform_update(self, serializer):
        serializer.save()
        # Invalidar todos os caches após atualizar transação
        invalidate_user_dashboard_cache(self.request.user)
    
    def perform_destroy(self, instance):
        instance.delete()
        # Invalidar todos os caches após deletar transação
        invalidate_user_dashboard_cache(self.request.user)
    
    @action(detail=True, methods=['get'])
    def details(self, request, pk=None):
        """Retorna detalhes completos da transação com metadados."""
        transaction = self.get_object()
        serializer = self.get_serializer(transaction)
        
        # Adicionar informações extras
        data = serializer.data
        
        # Calcular impacto nos indicadores (estimativa)
        impact = self._calculate_transaction_impact(transaction)
        data['estimated_impact'] = impact
        
        # Estatísticas relacionadas
        stats = self._get_transaction_stats(transaction)
        data['related_stats'] = stats
        
        return Response(data)
    
    def _calculate_transaction_impact(self, transaction):
        """Calcula impacto estimado da transação nos indicadores."""
        from .services import calculate_summary
        
        summary = calculate_summary(transaction.user)
        total_income = float(summary.get('total_income', 0))
        
        if total_income == 0:
            return {
                'tps_impact': 0,
                'rdr_impact': 0,
                'message': 'Sem receitas registradas para calcular impacto',
            }
        
        amount = float(transaction.amount)
        
        # Impacto no TPS
        tps_impact = 0
        if transaction.type == Transaction.TransactionType.INCOME:
            # Receita aumenta TPS potencial
            tps_impact = (amount / (total_income + amount)) * 100
        elif transaction.type in [Transaction.TransactionType.EXPENSE, Transaction.TransactionType.DEBT_PAYMENT]:
            # Despesa/pagamento reduz TPS
            tps_impact = -(amount / total_income) * 100
        
        # Impacto no RDR (apenas para dívidas)
        rdr_impact = 0
        if transaction.category and transaction.category.type == Category.CategoryType.DEBT:
            if transaction.type == Transaction.TransactionType.EXPENSE:
                rdr_impact = (amount / total_income) * 100
            elif transaction.type == Transaction.TransactionType.DEBT_PAYMENT:
                rdr_impact = -(amount / total_income) * 100
        
        return {
            'tps_impact': round(tps_impact, 2),
            'rdr_impact': round(rdr_impact, 2),
            'message': 'Impacto estimado nos indicadores',
        }
    
    def _get_transaction_stats(self, transaction):
        """Retorna estatísticas relacionadas à transação."""
        from django.db.models import Sum, Count, Avg
        
        # Estatísticas da mesma categoria
        category_stats = None
        if transaction.category:
            category_qs = Transaction.objects.filter(
                user=transaction.user,
                category=transaction.category,
            )
            category_stats = category_qs.aggregate(
                total=Sum('amount'),
                count=Count('id'),
                avg=Avg('amount'),
            )
            if category_stats['total']:
                category_stats['total'] = float(category_stats['total'])
            if category_stats['avg']:
                category_stats['avg'] = float(category_stats['avg'])
        
        # Estatísticas do mesmo tipo
        type_stats = Transaction.objects.filter(
            user=transaction.user,
            type=transaction.type,
        ).aggregate(
            total=Sum('amount'),
            count=Count('id'),
            avg=Avg('amount'),
        )
        if type_stats['total']:
            type_stats['total'] = float(type_stats['total'])
        if type_stats['avg']:
            type_stats['avg'] = float(type_stats['avg'])
        
        return {
            'category_stats': category_stats,
            'type_stats': type_stats,
        }
    
    @action(detail=False, methods=['post'])
    def suggest_category(self, request):
        """
        Sugere categoria baseado na descrição usando IA.
        
        POST /api/transactions/suggest_category/
        {
            "description": "Uber para o trabalho"
        }
        
        Response:
        {
            "suggested_category": {
                "id": "uuid",
                "name": "Transporte",
                "type": "EXPENSE",
                "confidence": 0.90
            }
        }
        """
        from .ai_services import suggest_category
        
        description = request.data.get('description', '')
        
        if not description or len(description) < 3:
            return Response(
                {'error': 'Descrição deve ter pelo menos 3 caracteres'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        category = suggest_category(description, request.user)
        
        if category:
            return Response({
                'suggested_category': {
                    'id': str(category.id),
                    'name': category.name,
                    'type': category.type,
                    'confidence': 0.90  # Placeholder - pode ser melhorado
                }
            })
        
        return Response({
            'suggested_category': None,
            'message': 'Nenhuma categoria encontrada. Tente uma descrição mais específica.'
        })


class TransactionLinkViewSet(viewsets.ModelViewSet):
    """
    ViewSet para gerenciar vinculações entre transações.
    Usa UUID como identificador primário.
    
    Endpoints:
    - GET /transaction-links/ - Listar vinculações
    - POST /transaction-links/ - Criar vinculação
    - GET /transaction-links/{id}/ - Detalhe de vinculação
    - DELETE /transaction-links/{id}/ - Remover vinculação
    - GET /transaction-links/available_sources/ - Listar receitas disponíveis
    - GET /transaction-links/available_targets/ - Listar despesas e dívidas pendentes
    - POST /transaction-links/quick_link/ - Vincular rapidamente
    - GET /transaction-links/payment_report/ - Relatório de pagamentos
    """
    serializer_class = TransactionLinkSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerPermission]
    
    def get_queryset(self):
        """
        Otimizado para evitar N+1 queries ao carregar transactions relacionadas.
        Carrega todas as transactions de source e target de uma vez.
        """
        qs = TransactionLink.objects.filter(
            user=self.request.user
        )
        
        # Filtros
        link_type = self.request.query_params.get('link_type')
        if link_type:
            qs = qs.filter(link_type=link_type)
        
        date_from = self.request.query_params.get('date_from')
        if date_from:
            qs = qs.filter(created_at__gte=date_from)
        
        date_to = self.request.query_params.get('date_to')
        if date_to:
            qs = qs.filter(created_at__lte=date_to)
        
        return qs.order_by('-created_at')
    
    def list(self, request, *args, **kwargs):
        """
        Override list para fazer prefetch manual de transactions relacionadas.
        Como usamos UUIDs em vez de FKs, precisamos fazer isso manualmente.
        
        Performance: 100 links - 201 queries → 3 queries (-98.5%)
        """
        queryset = self.filter_queryset(self.get_queryset())
        
        # Coletar todos os UUIDs únicos de source e target
        links_list = list(queryset)
        source_uuids = {link.source_transaction_uuid for link in links_list}
        target_uuids = {link.target_transaction_uuid for link in links_list}
        
        # Fazer 2 queries para buscar todas as transactions de uma vez
        all_uuids = source_uuids | target_uuids
        transactions_map = {
            tx.id: tx 
            for tx in Transaction.objects.filter(
                id__in=all_uuids
            ).select_related('category')
        }
        
        # Popular o cache de cada link
        for link in links_list:
            if link.source_transaction_uuid in transactions_map:
                link._source_transaction_cache = transactions_map[link.source_transaction_uuid]
            if link.target_transaction_uuid in transactions_map:
                link._target_transaction_cache = transactions_map[link.target_transaction_uuid]
        
        # Paginar e serializar normalmente
        page = self.paginate_queryset(links_list)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        
        serializer = self.get_serializer(links_list, many=True)
        return Response(serializer.data)
    
    def perform_create(self, serializer):
        """Ao criar link, invalidar cache."""
        serializer.save(user=self.request.user)
        invalidate_user_dashboard_cache(self.request.user)
    
    def perform_update(self, serializer):
        """Ao atualizar link, invalidar cache."""
        serializer.save()
        invalidate_user_dashboard_cache(self.request.user)
    
    def perform_destroy(self, instance):
        """Ao deletar, invalidar cache."""
        user = instance.user
        instance.delete()
        invalidate_user_dashboard_cache(user)
    
    @action(detail=False, methods=['get'])
    def available_sources(self, request):
        """
        Lista receitas que ainda têm saldo disponível.
        
        Query params:
        - min_amount: Filtrar receitas com saldo >= min_amount
        - category: Filtrar por categoria
        """
        from decimal import Decimal
        
        min_amount = request.query_params.get('min_amount', 0)
        
        transactions = Transaction.objects.filter(
            user=request.user,
            type=Transaction.TransactionType.INCOME
        ).select_related('category')
        
        # Filtrar por categoria se fornecido
        category_id = request.query_params.get('category')
        if category_id:
            transactions = transactions.filter(category_id=category_id)
        
        # Filtrar apenas com saldo disponível
        available = [tx for tx in transactions if tx.available_amount > Decimal(min_amount)]
        
        serializer = TransactionSerializer(available, many=True, context={'request': request})
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def available_targets(self, request):
        """
        Lista despesas e dívidas que ainda têm saldo devedor.
        
        Query params:
        - max_amount: Filtrar despesas com saldo <= max_amount
        - category: Filtrar por categoria
        """
        from decimal import Decimal
        
        # Buscar tanto transações do tipo EXPENSE quanto categorias do tipo DEBT
        transactions = Transaction.objects.filter(
            user=request.user
        ).filter(
            Q(type=Transaction.TransactionType.EXPENSE) | 
            Q(category__type=Category.CategoryType.DEBT)
        ).select_related('category')
        
        # Filtrar por categoria se fornecido
        category_id = request.query_params.get('category')
        if category_id:
            transactions = transactions.filter(category_id=category_id)
        
        # Filtrar apenas com saldo devedor
        max_amount = request.query_params.get('max_amount')
        available = [
            tx for tx in transactions 
            if tx.available_amount > 0 and (not max_amount or tx.available_amount <= Decimal(max_amount))
        ]
        
        serializer = TransactionSerializer(available, many=True, context={'request': request})
        return Response(serializer.data)
    
    @action(detail=False, methods=['post'])
    def quick_link(self, request):
        """
        Criar vinculação rapidamente com validações.
        
        Payload:
        {
            "source_id": 123,
            "target_id": 456,
            "amount": "150.00",
            "link_type": "DEBT_PAYMENT",  # opcional
            "description": "...",  # opcional
            "is_recurring": false  # opcional
        }
        """
        serializer = self.get_serializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        link = serializer.save()
        
        return Response(
            TransactionLinkSerializer(link, context={'request': request}).data,
            status=status.HTTP_201_CREATED
        )
    
    @action(detail=False, methods=['get'])
    def payment_report(self, request):
        """
        Gera relatório de pagamentos de dívidas por período.
        
        Query params:
        - start_date: Data inicial (YYYY-MM-DD)
        - end_date: Data final (YYYY-MM-DD)
        - category: Filtrar por categoria de dívida
        
        Response:
        {
            "summary": {
                "total_paid": "5000.00",
                "total_remaining": "15000.00",
                "payment_count": 10
            },
            "by_debt": [
                {
                    "debt_id": 123,
                    "debt_description": "Cartão de Crédito",
                    "total_amount": "2000.00",
                    "paid_amount": "800.00",
                    "remaining_amount": "1200.00",
                    "payment_percentage": 40.0,
                    "payments": [...]
                }
            ]
        }
        """
        from django.db.models import Sum
        from collections import defaultdict
        from decimal import Decimal
        
        # Filtros de data
        start_date = request.query_params.get('start_date')
        end_date = request.query_params.get('end_date')
        
        links = TransactionLink.objects.filter(
            user=request.user,
            link_type=TransactionLink.LinkType.DEBT_PAYMENT
        ).select_related('target_transaction', 'target_transaction__category')
        
        if start_date:
            links = links.filter(created_at__gte=start_date)
        if end_date:
            links = links.filter(created_at__lte=end_date)
        
        # Filtrar por categoria se fornecido
        category_id = request.query_params.get('category')
        if category_id:
            links = links.filter(target_transaction__category_id=category_id)
        
        # Agrupar por dívida
        by_debt = defaultdict(lambda: {
            'debt_id': None,
            'debt_description': '',
            'total_amount': Decimal('0'),
            'paid_amount': Decimal('0'),
            'remaining_amount': Decimal('0'),
            'payment_percentage': Decimal('0'),
            'payments': []
        })
        
        total_paid = Decimal('0')
        
        for link in links:
            debt = link.target_transaction
            debt_id = debt.id
            
            if by_debt[debt_id]['debt_id'] is None:
                by_debt[debt_id]['debt_id'] = debt_id
                by_debt[debt_id]['debt_description'] = debt.description
                by_debt[debt_id]['total_amount'] = debt.amount
            
            by_debt[debt_id]['paid_amount'] += link.linked_amount
            total_paid += link.linked_amount
            
            by_debt[debt_id]['payments'].append({
                'id': link.id,
                'amount': float(link.linked_amount),
                'date': link.created_at.isoformat(),
                'source': link.source_transaction.description
            })
        
        # Calcular remaining e percentage
        total_remaining = Decimal('0')
        for debt_data in by_debt.values():
            debt_data['remaining_amount'] = debt_data['total_amount'] - debt_data['paid_amount']
            total_remaining += debt_data['remaining_amount']
            
            if debt_data['total_amount'] > 0:
                debt_data['payment_percentage'] = float(
                    (debt_data['paid_amount'] / debt_data['total_amount']) * Decimal('100')
                )
            
            # Converter Decimal para float para JSON
            debt_data['total_amount'] = float(debt_data['total_amount'])
            debt_data['paid_amount'] = float(debt_data['paid_amount'])
            debt_data['remaining_amount'] = float(debt_data['remaining_amount'])
        
        return Response({
            'summary': {
                'total_paid': float(total_paid),
                'total_remaining': float(total_remaining),
                'payment_count': links.count()
            },
            'by_debt': list(by_debt.values())
        })
    
    @action(detail=False, methods=['get'])
    def pending_summary(self, request):
        """
        Retorna resumo de despesas pendentes com análise de urgência.
        Útil para notificações e telas de pagamento.
        
        Query params:
        - min_remaining: Valor mínimo de saldo devedor (padrão: 0.01)
        - sort_by: urgency|amount|date (padrão: urgency)
        
        Response:
        {
            "total_pending": 5000.00,
            "urgent_count": 3,
            "debts": [
                {
                    "id": "uuid",
                    "description": "Cartão",
                    "category": {...},
                    "total_amount": 2000.00,
                    "paid_amount": 500.00,
                    "remaining_amount": 1500.00,
                    "payment_percentage": 25.0,
                    "is_urgent": false,
                    "days_since_created": 15
                }
            ],
            "available_income": 3500.00,
            "coverage_percentage": 70.0
        }
        """
        from decimal import Decimal
        from django.utils import timezone
        
        min_remaining = Decimal(request.query_params.get('min_remaining', '0.01'))
        sort_by = request.query_params.get('sort_by', 'urgency')
        
        # Buscar despesas com saldo devedor
        debts = Transaction.objects.filter(
            user=request.user
        ).filter(
            Q(type=Transaction.TransactionType.EXPENSE) | 
            Q(category__type=Category.CategoryType.DEBT)
        ).select_related('category')
        
        # Filtrar apenas com saldo devedor
        pending_debts = []
        total_pending = Decimal('0')
        urgent_count = 0
        
        for debt in debts:
            remaining = debt.available_amount
            if remaining < min_remaining:
                continue
            
            payment_pct = float(debt.link_percentage)
            is_urgent = payment_pct >= 80  # >80% vinculado = urgente
            days_since = (timezone.now() - debt.created_at).days
            
            pending_debts.append({
                'id': str(debt.id),
                'description': debt.description,
                'category': {
                    'id': debt.category.id if debt.category else None,
                    'name': debt.category.name if debt.category else 'Sem categoria',
                    'type': debt.category.type if debt.category else None,
                },
                'total_amount': float(debt.amount),
                'paid_amount': float(debt.linked_amount),
                'remaining_amount': float(remaining),
                'payment_percentage': payment_pct,
                'is_urgent': is_urgent,
                'days_since_created': days_since,
                'created_at': debt.created_at.isoformat(),
            })
            
            total_pending += remaining
            if is_urgent:
                urgent_count += 1
        
        # Ordenar
        if sort_by == 'urgency':
            # Urgentes primeiro, depois por valor decrescente
            pending_debts.sort(
                key=lambda x: (-int(x['is_urgent']), -x['remaining_amount'])
            )
        elif sort_by == 'amount':
            pending_debts.sort(key=lambda x: -x['remaining_amount'])
        elif sort_by == 'date':
            pending_debts.sort(key=lambda x: x['created_at'], reverse=True)
        
        # Calcular receita disponível total
        incomes = Transaction.objects.filter(
            user=request.user,
            type=Transaction.TransactionType.INCOME
        )
        
        available_income = sum(
            (income.available_amount for income in incomes),
            Decimal('0')
        )
        
        # Calcular % de cobertura
        coverage_pct = 0.0
        if total_pending > 0:
            coverage_pct = float(
                min(available_income / total_pending, Decimal('1')) * Decimal('100')
            )
        
        return Response({
            'total_pending': float(total_pending),
            'urgent_count': urgent_count,
            'debts': pending_debts,
            'available_income': float(available_income),
            'coverage_percentage': coverage_pct,
        })
    
    @action(detail=False, methods=['post'])
    def bulk_payment(self, request):
        """
        Cria múltiplas vinculações de pagamento de uma vez.
        Permite pagar várias despesas usando várias fontes de receita.
        
        Body:
        {
            "payments": [
                {
                    "source_id": "uuid-receita-1",
                    "target_id": "uuid-despesa-1",
                    "amount": 500.00
                },
                {
                    "source_id": "uuid-receita-1",
                    "target_id": "uuid-despesa-2",
                    "amount": 300.00
                }
            ],
            "description": "Pagamento mensal - Janeiro/2025"  // Opcional
        }
        
        Response:
        {
            "success": true,
            "created_count": 2,
            "total_amount": 800.00,
            "links": [...],
            "summary": {
                "sources_used": 1,
                "targets_paid": 2,
                "fully_paid_debts": ["uuid-despesa-2"]
            }
        }
        """
        from django.db import transaction as db_transaction
        from decimal import Decimal
        
        payments_data = request.data.get('payments', [])
        description = request.data.get('description', 'Pagamento em lote')
        
        if not payments_data:
            return Response(
                {'error': 'Nenhum pagamento fornecido'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        created_links = []
        total_amount = Decimal('0')
        sources_used = set()
        targets_paid = set()
        fully_paid_debts = []
        
        try:
            with db_transaction.atomic():
                # Validar todos os pagamentos primeiro
                for idx, payment in enumerate(payments_data):
                    source_id = payment.get('source_id')
                    target_id = payment.get('target_id')
                    amount = payment.get('amount')
                    
                    if not source_id or not target_id or not amount:
                        raise ValueError(
                            f"Pagamento #{idx+1} inválido: faltam campos obrigatórios"
                        )
                    
                    try:
                        amount = Decimal(str(amount))
                    except (ValueError, TypeError):
                        raise ValueError(
                            f"Pagamento #{idx+1}: valor inválido '{amount}'"
                        )
                    
                    if amount <= 0:
                        raise ValueError(
                            f"Pagamento #{idx+1}: valor deve ser positivo"
                        )
                
                # Criar todos os links
                for idx, payment in enumerate(payments_data):
                    source_id = payment.get('source_id')
                    target_id = payment.get('target_id')
                    amount = Decimal(str(payment.get('amount')))
                    
                    # Verificar se as transações existem e pertencem ao usuário
                    try:
                        source = Transaction.objects.select_for_update().get(
                            id=source_id,
                            user=request.user
                        )
                        target = Transaction.objects.select_for_update().get(
                            id=target_id,
                            user=request.user
                        )
                    except Transaction.DoesNotExist:
                        raise ValueError(
                            f"Pagamento #{idx+1}: transação não encontrada ou não autorizada"
                        )
                    
                    # Validar saldo disponível
                    if amount > source.available_amount:
                        raise ValueError(
                            f"Pagamento #{idx+1}: valor R$ {amount} excede saldo disponível "
                            f"de '{source.description}' (R$ {source.available_amount})"
                        )
                    
                    if amount > target.available_amount:
                        raise ValueError(
                            f"Pagamento #{idx+1}: valor R$ {amount} excede saldo devedor "
                            f"de '{target.description}' (R$ {target.available_amount})"
                        )
                    
                    # Criar link
                    link = TransactionLink.objects.create(
                        user=request.user,
                        source_transaction_uuid=source_id,
                        target_transaction_uuid=target_id,
                        linked_amount=amount,
                        link_type=TransactionLink.LinkType.DEBT_PAYMENT,
                        description=description
                    )
                    
                    created_links.append(link)
                    total_amount += amount
                    sources_used.add(str(source_id))
                    targets_paid.add(str(target_id))
                    
                    # Verificar se a despesa foi quitada totalmente
                    # Recarregar target para pegar linked_amount atualizado
                    target.refresh_from_db()
                    if target.available_amount == 0:
                        fully_paid_debts.append(str(target_id))
                
                # Invalidar cache
                invalidate_user_dashboard_cache(request.user)
            
            # Serializar resposta
            serializer = TransactionLinkSerializer(
                created_links,
                many=True,
                context={'request': request}
            )
            
            return Response({
                'success': True,
                'created_count': len(created_links),
                'total_amount': float(total_amount),
                'links': serializer.data,
                'summary': {
                    'sources_used': len(sources_used),
                    'targets_paid': len(targets_paid),
                    'fully_paid_debts': fully_paid_debts
                }
            }, status=status.HTTP_201_CREATED)
            
        except ValueError as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            logger.error(f"Erro ao criar pagamento em lote: {e}")
            return Response(
                {'error': f'Erro interno: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class GoalViewSet(viewsets.ModelViewSet):
    """
    ViewSet para gerenciamento de objetivos financeiros.
    Usa UUID como identificador primário.
    """
    serializer_class = GoalSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerPermission]

    def get_queryset(self):
        """
        Otimizado: Adiciona select_related para category e prefetch_related
        para tracked_categories para evitar N+1 queries.
        """
        return Goal.objects.filter(
            user=self.request.user
        ).select_related(
            'target_category'
        ).prefetch_related(
            'tracked_categories'
        ).order_by("-created_at")
    
    @action(detail=True, methods=['get'])
    def transactions(self, request, pk=None):
        """
        Retorna transações relacionadas à meta.
        
        Otimizado: Adiciona select_related('category') para evitar N+1 queries.
        Performance: 51 queries → 1 query (-98%)
        """
        goal = self.get_object()
        transactions = goal.get_related_transactions().select_related('category')
        
        serializer = TransactionSerializer(transactions, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def refresh(self, request, pk=None):
        """Força atualização do progresso da meta."""
        from .services import update_goal_progress
        
        goal = self.get_object()
        
        if goal.auto_update:
            update_goal_progress(goal)
            goal.refresh_from_db()
        
        serializer = self.get_serializer(goal)
        return Response(serializer.data)
    
    @action(detail=True, methods=['get'])
    def insights(self, request, pk=None):
        """Retorna insights sobre o progresso da meta."""
        from .services import get_goal_insights
        
        goal = self.get_object()
        insights = get_goal_insights(goal)
        
        return Response(insights)


class MissionViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = MissionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def _get_tier_level_range(self, tier):
        """Retorna o range de níveis para um tier específico."""
        tier_ranges = {
            'BEGINNER': (1, 5),
            'INTERMEDIATE': (6, 15),
            'ADVANCED': (16, 100)
        }
        return tier_ranges.get(tier, (1, 100))

    def get_queryset(self):
        return Mission.objects.filter(is_active=True)
    
    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def generate_ai_missions(self, request):
        """
        Gera missões usando IA (Gemini) - ADMIN/STAFF ONLY
        
        Requer: is_staff=True ou is_superuser=True
        
        POST /api/missions/generate_ai_missions/
        {
            "tier": "BEGINNER|INTERMEDIATE|ADVANCED" (opcional),
            "scenario": "TPS_LOW|RDR_HIGH|MIXED_BALANCED|..." (opcional)
        }
        
        Cenários disponíveis:
        - BEGINNER_ONBOARDING: Primeiros passos (< 20 transações)
        - TPS_LOW, TPS_MEDIUM, TPS_HIGH: Melhorar taxa de poupança
        - RDR_HIGH, RDR_MEDIUM, RDR_LOW: Reduzir/controlar dívidas
        - ILI_LOW, ILI_MEDIUM, ILI_HIGH: Construir/manter reserva
        - MIXED_BALANCED: Equilíbrio financeiro geral
        - MIXED_RECOVERY: Recuperação (baixo TPS + alto RDR)
        - MIXED_OPTIMIZATION: Otimização avançada
        
        Se tier e scenario não forem fornecidos: gera automaticamente
        baseado nas estatísticas dos usuários.
        
        Exemplo de resposta:
        {
            "success": true,
            "total_created": 60,
            "results": {
                "BEGINNER": {
                    "scenario": "BEGINNER_ONBOARDING",
                    "scenario_name": "Primeiros Passos",
                    "generated": 20,
                    "created": 20,
                    "missions": [...]
                },
                ...
            }
        }
        """
        from .ai_services import (
            generate_batch_missions_for_tier,
            create_missions_from_batch,
            generate_all_monthly_missions,
            generate_missions_by_scenario,
            MISSION_SCENARIOS
        )
        
        tier = request.data.get('tier')
        scenario = request.data.get('scenario')
        
        # Validar tier se fornecido
        if tier and tier not in ['BEGINNER', 'INTERMEDIATE', 'ADVANCED']:
            return Response(
                {'error': 'tier deve ser BEGINNER, INTERMEDIATE ou ADVANCED'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Validar scenario se fornecido
        if scenario and scenario not in MISSION_SCENARIOS:
            return Response(
                {
                    'error': f'scenario inválido: {scenario}',
                    'available_scenarios': list(MISSION_SCENARIOS.keys()),
                    'scenario_descriptions': {
                        key: val['name'] for key, val in MISSION_SCENARIOS.items()
                    }
                },
                status=status.HTTP_400_BAD_REQUEST
            )
        
        results = {}
        
        # Caso 1: Cenário específico
        if scenario:
            tiers = [tier] if tier else ['BEGINNER', 'INTERMEDIATE', 'ADVANCED']
            result = generate_missions_by_scenario(scenario, tiers)
            results = result.get('results', {})
            total_created = result.get('total_created', 0)
        
        # Caso 2: Tier específica, auto-detectar cenário
        elif tier:
            # Tentar usar contexto de usuário representativo do tier
            from .services import get_comprehensive_mission_context
            from .models import User, UserProfile
            
            user_context = None
            try:
                # Buscar usuário representativo do tier para personalização
                tier_level_range = self._get_tier_level_range(tier)
                representative_profile = UserProfile.objects.filter(
                    level__range=tier_level_range
                ).select_related('user').order_by('-user__last_login').first()
                
                if representative_profile and representative_profile.user:
                    user_context = get_comprehensive_mission_context(representative_profile.user)
                    logger.info(f"Usando contexto do usuário {representative_profile.user.username} (nível {representative_profile.level}) para tier {tier}")
            except Exception as e:
                logger.warning(f"Não foi possível obter contexto de usuário para {tier}: {e}")
            
            batch = generate_batch_missions_for_tier(tier, user_context=user_context)
            if batch:
                created = create_missions_from_batch(tier, batch)
                results[tier] = {
                    'generated': len(batch),
                    'created': len(created),
                    'personalized': user_context is not None,
                    'missions': [
                        {
                            'id': str(m.id),
                            'title': m.title,
                            'type': m.mission_type,
                            'difficulty': m.priority,
                            'xp': m.xp_reward
                        }
                        for m in created[:5]  # Primeiras 5 como exemplo
                    ]
                }
                total_created = len(created)
            else:
                results[tier] = {
                    'generated': 0,
                    'created': 0,
                    'error': 'Falha ao gerar batch'
                }
                total_created = 0
        
        # Caso 3: Auto-detectar tudo
        else:
            result = generate_all_monthly_missions()
            results = result.get('results', {})
            total_created = result.get('total_created', 0)
        
        return Response({
            'success': True,
            'total_created': total_created,
            'results': results
        })


class MissionProgressViewSet(viewsets.ModelViewSet):
    serializer_class = MissionProgressSerializer
    permission_classes = [permissions.IsAuthenticated]
    # Remove create/delete - missões são atribuídas automaticamente
    http_method_names = ['get', 'put', 'patch', 'head', 'options']

    def get_queryset(self):
        qs = MissionProgress.objects.filter(user=self.request.user).select_related("mission")
        
        # Filtro por status
        status_filter = self.request.query_params.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter)
        
        # Filtro por tipo de missão
        mission_type = self.request.query_params.get("mission_type")
        if mission_type:
            qs = qs.filter(mission__mission_type=mission_type)
        
        return qs

    def perform_update(self, serializer):
        previous = serializer.instance.status
        progress = serializer.save()
        
        # Completar missão manualmente se usuário marcar como completa
        if (
            previous != MissionProgress.Status.COMPLETED
            and progress.status == MissionProgress.Status.COMPLETED
        ):
            from django.utils import timezone
            progress.progress = 100
            progress.completed_at = timezone.now()
            progress.save(update_fields=['progress', 'completed_at'])
            apply_mission_reward(progress)
            
            # Atribuir novas missões após completar uma
            assign_missions_automatically(self.request.user)
    
    @action(detail=True, methods=['get'])
    def details(self, request, pk=None):
        """Retorna detalhes completos da missão incluindo breakdown de progresso."""
        mission_progress = self.get_object()
        serializer = self.get_serializer(mission_progress)
        
        # Adicionar breakdown detalhado do progresso
        data = serializer.data
        breakdown = self._calculate_progress_breakdown(mission_progress)
        data['progress_breakdown'] = breakdown
        
        # Adicionar timeline de progresso (últimos registros)
        timeline = self._get_progress_timeline(mission_progress)
        data['progress_timeline'] = timeline
        
        return Response(data)
    
    def _calculate_progress_breakdown(self, mission_progress):
        """Calcula breakdown detalhado do progresso por critério."""
        from .services import calculate_summary
        from decimal import Decimal
        
        mission = mission_progress.mission
        summary = calculate_summary(mission_progress.user)
        
        breakdown = {
            'components': [],
            'overall_status': mission_progress.status,
        }
        
        # Componente TPS
        if mission.target_tps is not None and mission_progress.initial_tps is not None:
            current_tps = float(summary.get('tps', 0))
            initial_tps = float(mission_progress.initial_tps)
            target_tps = float(mission.target_tps)
            
            if current_tps >= target_tps:
                progress_pct = 100.0
            elif target_tps > initial_tps and (target_tps - initial_tps) > 0:
                progress_pct = min(100, max(0, ((current_tps - initial_tps) / (target_tps - initial_tps)) * 100))
            elif initial_tps >= target_tps:
                progress_pct = 100.0
            else:
                progress_pct = 100.0 if current_tps >= target_tps else 0.0
            
            breakdown['components'].append({
                'indicator': 'TPS',
                'name': 'Taxa de Poupança Pessoal',
                'initial': round(initial_tps, 2),
                'current': round(current_tps, 2),
                'target': target_tps,
                'progress': round(progress_pct, 1),
                'met': current_tps >= target_tps,
            })
        
        # Componente RDR
        if mission.target_rdr is not None and mission_progress.initial_rdr is not None:
            current_rdr = float(summary.get('rdr', 0))
            initial_rdr = float(mission_progress.initial_rdr)
            target_rdr = float(mission.target_rdr)
            
            if current_rdr <= target_rdr:
                progress_pct = 100.0
            elif initial_rdr > target_rdr and (initial_rdr - target_rdr) > 0:
                progress_pct = min(100, max(0, ((initial_rdr - current_rdr) / (initial_rdr - target_rdr)) * 100))
            elif initial_rdr <= target_rdr:
                progress_pct = 100.0
            else:
                progress_pct = 100.0 if current_rdr <= target_rdr else 0.0
            
            breakdown['components'].append({
                'indicator': 'RDR',
                'name': 'Razão Dívida/Renda',
                'initial': round(initial_rdr, 2),
                'current': round(current_rdr, 2),
                'target': target_rdr,
                'progress': round(progress_pct, 1),
                'met': current_rdr <= target_rdr,
            })
        
        # Componente ILI
        if mission.min_ili is not None and mission_progress.initial_ili is not None:
            current_ili = float(summary.get('ili', 0))
            initial_ili = float(mission_progress.initial_ili)
            target_ili = float(mission.min_ili)
            
            if current_ili >= target_ili:
                progress_pct = 100.0
            elif target_ili > initial_ili and (target_ili - initial_ili) > 0:
                progress_pct = min(100, max(0, ((current_ili - initial_ili) / (target_ili - initial_ili)) * 100))
            elif initial_ili >= target_ili:
                progress_pct = 100.0
            else:
                progress_pct = 100.0 if current_ili >= target_ili else 0.0
            
            breakdown['components'].append({
                'indicator': 'ILI',
                'name': 'Índice de Liquidez Imediata',
                'initial': round(initial_ili, 2),
                'current': round(current_ili, 2),
                'target': target_ili,
                'progress': round(progress_pct, 1),
                'met': current_ili >= target_ili,
            })
        
        # Componente de transações (para onboarding)
        if mission.min_transactions:
            from .models import Transaction
            current_count = Transaction.objects.filter(user=mission_progress.user).count()
            initial_count = mission_progress.initial_transaction_count or 0
            target_count = mission.min_transactions
            
            if target_count > initial_count:
                progress_pct = min(100, ((current_count - initial_count) / (target_count - initial_count)) * 100)
            else:
                progress_pct = 100 if current_count >= target_count else 0
            
            breakdown['components'].append({
                'indicator': 'Transações',
                'name': 'Transações Registradas',
                'initial': int(initial_count),
                'current': int(current_count),
                'target': int(target_count),
                'progress': round(progress_pct, 1),
                'met': current_count >= target_count,
            })
        
        return breakdown
    
    def _get_progress_timeline(self, mission_progress):
        """Retorna timeline simplificado do progresso (criação, início, conclusão)."""
        timeline = []
        
        # Criação
        timeline.append({
            'event': 'created',
            'label': 'Missão atribuída',
            'timestamp': mission_progress.updated_at.isoformat() if not mission_progress.started_at else None,
        })
        
        # Início
        if mission_progress.started_at:
            timeline.append({
                'event': 'started',
                'label': 'Missão iniciada',
                'timestamp': mission_progress.started_at.isoformat(),
            })
        
        # Conclusão
        if mission_progress.completed_at:
            timeline.append({
                'event': 'completed',
                'label': 'Missão concluída',
                'timestamp': mission_progress.completed_at.isoformat(),
                'reward': mission_progress.mission.reward_points,
            })
        
        # Prazo
        if mission_progress.started_at and mission_progress.mission.duration_days:
            from django.utils import timezone
            deadline = mission_progress.started_at + timezone.timedelta(days=mission_progress.mission.duration_days)
            timeline.append({
                'event': 'deadline',
                'label': 'Prazo final',
                'timestamp': deadline.isoformat(),
                'is_future': deadline > timezone.now(),
            })
        
        return timeline


class DashboardViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [DashboardRefreshThrottle]

    def list(self, request, *args, **kwargs):
        """
        Dashboard principal com cache de 5 minutos.
        
        Performance: ~280ms → ~10ms com cache ativo (-96%)
        Cache pode ser forçado a refresh com ?refresh=true
        """
        from django.core.cache import cache
        
        user = request.user
        force_refresh = request.query_params.get('refresh', 'false').lower() == 'true'
        cache_key = f'dashboard_main_{user.id}'
        
        # Verificar cache (a menos que force_refresh)
        if not force_refresh:
            cached_data = cache.get(cache_key)
            if cached_data:
                # Adicionar flag indicando que veio do cache
                cached_data['from_cache'] = True
                cached_data['cache_ttl_seconds'] = cache.ttl(cache_key) if hasattr(cache, 'ttl') else 300
                return Response(cached_data)
        
        # Atualizar progresso das missões antes de mostrar o dashboard
        update_mission_progress(user)
        
        # Garantir que o usuário tem missões atribuídas
        assign_missions_automatically(user)
        
        summary = calculate_summary(user)
        breakdown = category_breakdown(user)
        cashflow = cashflow_series(user)
        profile, _ = UserProfile.objects.get_or_create(user=user)
        insights = indicator_insights(summary, profile)
        
        # Buscar missões ativas (PENDING ou ACTIVE)
        active_missions = (
            MissionProgress.objects.filter(
                user=user,
                status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
            )
            .select_related("mission")
            .order_by("mission__priority")
        )
        
        # Não mostrar mais "recomendações" - todas são atribuídas automaticamente
        # Mas mantém compatibilidade com serializer
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
        
        # Cachear por 5 minutos (300 segundos)
        response_data = serializer.data
        response_data['from_cache'] = False
        cache.set(cache_key, response_data, timeout=300)
        
        return Response(response_data)

    @action(detail=False, methods=["get"], url_path="missions")
    def missions_summary(self, request):
        # Atualizar progresso antes de mostrar
        update_mission_progress(request.user)
        
        progress_qs = MissionProgress.objects.filter(user=request.user).select_related("mission")
        serializer = MissionProgressSerializer(progress_qs, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=["get"], url_path="analytics")
    def analytics(self, request):
        """
        Retorna análises avançadas sobre evolução, padrões de categoria e distribuição de missões.
        
        GET /api/dashboard/analytics/
        
        Retorna:
        {
            "comprehensive_context": {...},  // Contexto completo do usuário
            "category_patterns": {...},      // Análise de padrões por categoria
            "tier_progression": {...},       // Análise de progressão entre tiers
            "mission_distribution": {...}    // Análise de distribuição de missões
        }
        """
        from .services import (
            get_comprehensive_mission_context,
            analyze_category_patterns,
            analyze_tier_progression,
            get_mission_distribution_analysis
        )
        
        user = request.user
        
        try:
            # Obter contexto abrangente
            comprehensive = get_comprehensive_mission_context(user)
            
            # Análises adicionais
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
            return Response(
                {
                    'success': False,
                    'error': str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class ProfileView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        data = {
            "user": {
                "id": request.user.id,
                "email": request.user.email,
                "name": request.user.get_full_name() or request.user.username,
                "is_staff": request.user.is_staff,
                "is_superuser": request.user.is_superuser,
            },
            "profile": UserProfileSerializer(profile).data,
            "snapshot": profile_snapshot(request.user),
        }
        return Response(data)

    def put(self, request):
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        serializer = UserProfileSerializer(
            profile, data=request.data, partial=True
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        data = {
            "profile": serializer.data,
            "snapshot": profile_snapshot(request.user),
        }
        return Response(data)
    
    def patch(self, request):
        """Atualiza parcialmente o perfil, incluindo marcar primeiro acesso como concluído."""
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        
        # Preparar dados para atualização
        update_data = request.data.copy()
        
        # Se veio a flag de completar onboarding, atualiza is_first_access
        if update_data.get('complete_first_access'):
            update_data['is_first_access'] = False
            # Remove a flag customizada antes de passar ao serializer
            update_data.pop('complete_first_access')
            
            # Log para auditoria
            import logging
            logger = logging.getLogger(__name__)
            logger.info(
                f"User {request.user.id} ({request.user.username}) completed first access/onboarding"
            )
        
        serializer = UserProfileSerializer(
            profile, data=update_data, partial=True
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        
        # Refresh do profile após save para garantir dados atualizados
        profile.refresh_from_db()
        
        # Cria um novo serializer com os dados atualizados
        response_serializer = UserProfileSerializer(profile)
        
        data = {
            "profile": response_serializer.data,
            "snapshot": profile_snapshot(request.user),
        }
        return Response(data)


class XPHistoryView(APIView):
    """
    Endpoint para visualizar histórico de XP do usuário.
    Útil para debugging e análise de progressão.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from .models import XPTransaction
        
        # Buscar últimas 50 transações de XP
        transactions = XPTransaction.objects.filter(
            user=request.user
        ).select_related('mission_progress__mission')[:50]
        
        data = []
        for tx in transactions:
            data.append({
                'id': tx.id,
                'mission_title': tx.mission_progress.mission.title,
                'mission_type': tx.mission_progress.mission.mission_type,
                'points_awarded': tx.points_awarded,
                'level_before': tx.level_before,
                'level_after': tx.level_after,
                'xp_before': tx.xp_before,
                'xp_after': tx.xp_after,
                'created_at': tx.created_at.isoformat(),
                'leveled_up': tx.level_after > tx.level_before,
            })
        
        return Response({
            'count': len(data),
            'transactions': data,
        })


class RegisterView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        email = request.data.get("email", "").strip().lower()
        password = request.data.get("password")
        name = request.data.get("name", "").strip()

        if not email or not password:
            return Response(
                {"detail": "Email e senha são obrigatórios."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if User.objects.filter(email__iexact=email).exists():
            return Response(
                {"detail": "Já existe uma conta com esse email."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        username = email.split("@", 1)[0]
        user = User.objects.create_user(username=username, email=email, password=password)
        if name:
            parts = name.split(" ")
            user.first_name = parts[0]
            if len(parts) > 1:
                user.last_name = " ".join(parts[1:])
            user.save(update_fields=["first_name", "last_name"])

        refresh = RefreshToken.for_user(user)
        tokens = {"access": str(refresh.access_token), "refresh": str(refresh)}

        user_payload = {
            "id": user.id,
            "email": user.email,
            "name": user.get_full_name() or user.username,
            "is_staff": user.is_staff,
            "is_superuser": user.is_superuser,
        }

        return Response(
            {
                "access": tokens["access"],
                "refresh": tokens["refresh"],
                "tokens": tokens,
                "user": user_payload,
            },
            status=status.HTTP_201_CREATED,
        )


class UserProfileViewSet(
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    """
    ViewSet para gerenciar perfil do usuário.
    - GET /me/ - Obter dados do usuário autenticado
    - PATCH /me/ - Atualizar nome/email
    - POST /change_password/ - Alterar senha
    - DELETE /me/ - Excluir conta
    """
    serializer_class = UserProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user

    @action(detail=False, methods=['get'])
    def me(self, request):
        """Retorna dados do usuário autenticado."""
        user = request.user
        return Response({
            'id': user.id,
            'email': user.email,
            'name': user.get_full_name() or user.username,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'username': user.username,
            'is_staff': user.is_staff,
            'is_superuser': user.is_superuser,
        })

    @action(detail=False, methods=['patch'])
    def update_profile(self, request):
        """Atualiza nome e/ou email do usuário."""
        user = request.user
        name = request.data.get('name', '').strip()
        email = request.data.get('email', '').strip().lower()

        # Validar e atualizar nome
        if name:
            parts = name.split(' ', 1)
            user.first_name = parts[0]
            user.last_name = parts[1] if len(parts) > 1 else ''

        # Validar e atualizar email
        if email and email != user.email:
            if User.objects.filter(email__iexact=email).exclude(id=user.id).exists():
                return Response(
                    {'detail': 'Este email já está em uso.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            user.email = email
            user.username = email.split('@')[0]

        user.save()

        return Response({
            'id': user.id,
            'email': user.email,
            'name': user.get_full_name() or user.username,
            'is_staff': user.is_staff,
            'is_superuser': user.is_superuser,
            'message': 'Perfil atualizado com sucesso.',
        })

    @action(detail=False, methods=['post'])
    def change_password(self, request):
        """Altera senha do usuário após validar senha atual."""
        user = request.user
        current_password = request.data.get('current_password', '')
        new_password = request.data.get('new_password', '')

        if not current_password or not new_password:
            return Response(
                {'detail': 'Senha atual e nova senha são obrigatórias.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validar senha atual
        if not user.check_password(current_password):
            return Response(
                {'detail': 'Senha atual incorreta.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validar nova senha
        if len(new_password) < 6:
            return Response(
                {'detail': 'A nova senha deve ter pelo menos 6 caracteres.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Atualizar senha
        user.set_password(new_password)
        user.save()

        return Response({
            'message': 'Senha alterada com sucesso.',
        })

    @action(detail=False, methods=['delete'])
    def delete_account(self, request):
        """Exclui conta do usuário após validar senha."""
        user = request.user
        password = request.data.get('password', '')

        if not password:
            return Response(
                {'detail': 'Senha é obrigatória para excluir a conta.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validar senha
        if not user.check_password(password):
            return Response(
                {'detail': 'Senha incorreta.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Excluir usuário (cascade irá excluir perfil e transações)
        user_id = user.id
        user.delete()

        return Response({
            'message': f'Conta {user_id} excluída permanentemente.',
        }, status=status.HTTP_200_OK)


class FriendshipViewSet(viewsets.ModelViewSet):
    """
    ViewSet para gerenciar amizades entre usuários.
    Usa UUID como identificador primário.
    
    Endpoints:
    - GET /friendships/ - Listar amigos aceitos
    - POST /friendships/send_request/ - Enviar solicitação
    - POST /friendships/{id}/accept/ - Aceitar solicitação
    - POST /friendships/{id}/reject/ - Rejeitar solicitação
    - DELETE /friendships/{id}/ - Remover amizade
    - GET /friendships/requests/ - Listar solicitações pendentes
    - GET /friendships/search_users/ - Buscar usuários
    """
    from .serializers import FriendshipSerializer
    serializer_class = FriendshipSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerPermission]
    
    def get_queryset(self):
        """Retorna amizades aceitas do usuário."""
        user = self.request.user
        from .models import Friendship
        
        return Friendship.objects.filter(
            Q(user=user) | Q(friend=user),
            status=Friendship.FriendshipStatus.ACCEPTED
        ).select_related('user', 'friend').order_by('-accepted_at')
    
    @action(detail=False, methods=['post'])
    def send_request(self, request):
        """Envia uma solicitação de amizade."""
        from .serializers import FriendRequestSerializer
        from .models import Friendship
        
        serializer = FriendRequestSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        
        friend_id = serializer.validated_data['friend_id']
        friend = User.objects.get(id=friend_id)
        
        # Verificar se já existe solicitação
        existing = Friendship.objects.filter(
            Q(user=request.user, friend=friend) | Q(user=friend, friend=request.user)
        ).first()
        
        if existing:
            if existing.status == Friendship.FriendshipStatus.ACCEPTED:
                return Response(
                    {'detail': 'Vocês já são amigos.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            elif existing.status == Friendship.FriendshipStatus.PENDING:
                return Response(
                    {'detail': 'Já existe uma solicitação pendente.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        
        # Criar nova solicitação
        friendship = Friendship.objects.create(
            user=request.user,
            friend=friend,
            status=Friendship.FriendshipStatus.PENDING
        )
        
        return Response(
            self.serializer_class(friendship).data,
            status=status.HTTP_201_CREATED
        )
    
    @action(detail=True, methods=['post'])
    def accept(self, request, pk=None):
        """Aceita uma solicitação de amizade."""
        from .models import Friendship
        
        friendship = self.get_object()
        
        # Verificar se o usuário atual é o destinatário
        if friendship.friend != request.user:
            return Response(
                {'detail': 'Você não pode aceitar esta solicitação.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        if friendship.status != Friendship.FriendshipStatus.PENDING:
            return Response(
                {'detail': 'Esta solicitação não está pendente.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        friendship.accept()
        
        return Response(
            self.serializer_class(friendship).data,
            status=status.HTTP_200_OK
        )
    
    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        """Rejeita uma solicitação de amizade."""
        from .models import Friendship
        
        friendship = self.get_object()
        
        # Verificar se o usuário atual é o destinatário
        if friendship.friend != request.user:
            return Response(
                {'detail': 'Você não pode rejeitar esta solicitação.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        if friendship.status != Friendship.FriendshipStatus.PENDING:
            return Response(
                {'detail': 'Esta solicitação não está pendente.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        friendship.reject()
        friendship.delete()  # Remover solicitações rejeitadas
        
        return Response(
            {'message': 'Solicitação rejeitada.'},
            status=status.HTTP_200_OK
        )
    
    @action(detail=False, methods=['get'])
    def requests(self, request):
        """Lista solicitações pendentes recebidas pelo usuário."""
        from .models import Friendship
        
        requests_received = Friendship.objects.filter(
            friend=request.user,
            status=Friendship.FriendshipStatus.PENDING
        ).select_related('user', 'friend').order_by('-created_at')
        
        serializer = self.serializer_class(requests_received, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def search_users(self, request):
        """Busca usuários por nome ou email."""
        from .serializers import UserSearchSerializer
        from .models import Friendship
        
        query = request.query_params.get('q', '').strip()
        if not query or len(query) < 2:
            return Response(
                {'detail': 'Query de busca deve ter pelo menos 2 caracteres.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Buscar usuários (exceto o próprio)
        users = User.objects.filter(
            Q(username__icontains=query) | Q(email__icontains=query)
        ).exclude(id=request.user.id)[:20]  # Limitar a 20 resultados
        
        # Obter IDs de amigos e solicitações pendentes
        friendships = Friendship.objects.filter(
            Q(user=request.user) | Q(friend=request.user)
        ).select_related('user', 'friend')
        
        friends_ids = set()
        pending_ids = set()
        
        for friendship in friendships:
            other_user = friendship.friend if friendship.user == request.user else friendship.user
            if friendship.status == Friendship.FriendshipStatus.ACCEPTED:
                friends_ids.add(other_user.id)
            elif friendship.status == Friendship.FriendshipStatus.PENDING:
                pending_ids.add(other_user.id)
        
        # Montar resultados
        results = []
        for user in users:
            try:
                profile = UserProfile.objects.get(user=user)
            except UserProfile.DoesNotExist:
                profile = UserProfile.objects.create(user=user)
            
            # Construir nome completo ou usar first_name, fallback para username
            full_name = f"{user.first_name} {user.last_name}".strip() if user.first_name or user.last_name else user.username
            
            results.append({
                'id': user.id,
                'username': user.username,
                'name': full_name,
                'email': user.email,
                'level': profile.level,
                'xp': profile.experience_points,
                'is_friend': user.id in friends_ids,
                'has_pending_request': user.id in pending_ids,
            })
        
        serializer = UserSearchSerializer(results, many=True)
        return Response(serializer.data)
    
    def destroy(self, request, *args, **kwargs):
        """Remove uma amizade."""
        friendship = self.get_object()
        
        # Verificar se o usuário é parte da amizade
        if friendship.user != request.user and friendship.friend != request.user:
            return Response(
                {'detail': 'Você não pode remover esta amizade.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        friendship.delete()
        return Response(
            {'message': 'Amizade removida com sucesso.'},
            status=status.HTTP_200_OK
        )


class LeaderboardViewSet(viewsets.ViewSet):
    """
    ViewSet para rankings de usuários.
    
    Endpoints:
    - GET /leaderboard/ - Ranking geral (top usuários por XP)
    - GET /leaderboard/friends/ - Ranking de amigos
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def list(self, request):
        """Retorna o ranking geral de usuários por XP."""
        from .serializers import LeaderboardEntrySerializer
        
        # Parâmetros de paginação
        page_size = int(request.query_params.get('page_size', 50))
        page = int(request.query_params.get('page', 1))
        offset = (page - 1) * page_size
        
        # Buscar top usuários
        profiles = UserProfile.objects.select_related('user').order_by(
            '-level', '-experience_points'
        )[offset:offset + page_size]
        
        # Montar resultados com ranking
        results = []
        for idx, profile in enumerate(profiles, start=offset + 1):
            user = profile.user
            # Construir nome completo ou usar first_name, fallback para username
            full_name = f"{user.first_name} {user.last_name}".strip() if user.first_name or user.last_name else user.username
            
            results.append({
                'rank': idx,
                'user_id': user.id,
                'username': user.username,
                'name': full_name,
                'level': profile.level,
                'xp': profile.experience_points,
                'is_current_user': user.id == request.user.id,
            })
        
        # Buscar posição do usuário atual se não estiver na lista
        current_user_in_results = any(r['is_current_user'] for r in results)
        current_user_rank = None
        
        if not current_user_in_results:
            # Calcular posição do usuário
            current_profile = UserProfile.objects.get(user=request.user)
            users_above = UserProfile.objects.filter(
                Q(level__gt=current_profile.level) |
                Q(level=current_profile.level, experience_points__gt=current_profile.experience_points)
            ).count()
            current_user_rank = users_above + 1
        
        serializer = LeaderboardEntrySerializer(results, many=True)
        
        return Response({
            'count': len(results),
            'page': page,
            'page_size': page_size,
            'leaderboard': serializer.data,
            'current_user_rank': current_user_rank,
        })
    
    @action(detail=False, methods=['get'])
    def friends(self, request):
        """Retorna o ranking apenas dos amigos do usuário."""
        from .serializers import LeaderboardEntrySerializer
        from .models import Friendship
        
        # Obter IDs dos amigos
        friends_ids = Friendship.get_friends_ids(request.user)
        
        if not friends_ids:
            return Response({
                'count': 0,
                'leaderboard': [],
                'message': 'Você ainda não tem amigos.',
            })
        
        # Adicionar o próprio usuário ao ranking
        friends_ids.append(request.user.id)
        
        # Buscar perfis dos amigos ordenados por XP
        profiles = UserProfile.objects.filter(
            user_id__in=friends_ids
        ).select_related('user').order_by('-level', '-experience_points')
        
        # Montar resultados com ranking
        results = []
        for idx, profile in enumerate(profiles, start=1):
            user = profile.user
            # Construir nome completo ou usar first_name, fallback para username
            full_name = f"{user.first_name} {user.last_name}".strip() if user.first_name or user.last_name else user.username
            
            results.append({
                'rank': idx,
                'user_id': user.id,
                'username': user.username,
                'name': full_name,
                'level': profile.level,
                'xp': profile.experience_points,
                'is_current_user': user.id == request.user.id,
            })
        
        serializer = LeaderboardEntrySerializer(results, many=True)
        
        return Response({
            'count': len(results),
            'leaderboard': serializer.data,
        })


# ============================================================================
# ADMIN STATISTICS
# ============================================================================
class AdminStatsViewSet(viewsets.ViewSet):
    """
    ViewSet for admin statistics and dashboard data.
    Only accessible by staff users.
    """
    permission_classes = [permissions.IsAdminUser]
    
    @action(detail=False, methods=['get'])
    def overview(self, request):
        """
        Get overview statistics for admin dashboard.
        
        Returns:
        - total_users: Total number of users in the system
        - completed_missions: Total completed missions across all users
        - active_missions: Total active (non-completed) missions
        - avg_user_level: Average level of all users
        - missions_by_tier: Mission distribution by tier
        - missions_by_type: Mission distribution by type
        - recent_activity: Recent mission completions
        """
        from django.db.models import Avg, Count, Q
        from datetime import timedelta
        from django.utils import timezone
        
        # Total users
        total_users = User.objects.count()
        
        # Mission statistics
        completed_missions = MissionProgress.objects.filter(
            status='COMPLETED'
        ).count()
        
        active_missions = Mission.objects.filter(
            is_active=True
        ).count()
        
        # Average user level
        avg_level_data = UserProfile.objects.aggregate(
            avg_level=Avg('level')
        )
        avg_user_level = round(avg_level_data['avg_level'] or 0, 1)
        
        # Missions by difficulty (ao invés de tier)
        missions_by_difficulty = {}
        for difficulty in ['EASY', 'MEDIUM', 'HARD']:
            missions_by_difficulty[difficulty] = Mission.objects.filter(
                difficulty=difficulty,
                is_active=True
            ).count()
        
        # Missions by type
        missions_by_type = {}
        mission_types = ['ONBOARDING', 'TPS_IMPROVEMENT', 'RDR_REDUCTION', 'ILI_BUILDING', 'ADVANCED']
        for mission_type in mission_types:
            missions_by_type[mission_type] = Mission.objects.filter(
                mission_type=mission_type,
                is_active=True
            ).count()
        
        # Recent activity (last 10 completed missions)
        recent_completions = MissionProgress.objects.filter(
            status='COMPLETED'
        ).select_related(
            'mission', 'user__userprofile'
        ).order_by('-updated_at')[:10]
        
        recent_activity = []
        for progress in recent_completions:
            recent_activity.append({
                'user': progress.user.username,
                'mission': progress.mission.title,
                'completed_at': progress.updated_at.isoformat(),
                'xp_earned': progress.mission.reward_points,
            })
        
        # User level distribution
        level_distribution = {
            '1-5': UserProfile.objects.filter(level__gte=1, level__lte=5).count(),
            '6-10': UserProfile.objects.filter(level__gte=6, level__lte=10).count(),
            '11-20': UserProfile.objects.filter(level__gte=11, level__lte=20).count(),
            '21+': UserProfile.objects.filter(level__gte=21).count(),
        }
        
        # Mission completion rate
        total_mission_assignments = MissionProgress.objects.count()
        completion_rate = 0
        if total_mission_assignments > 0:
            completion_rate = round(
                (completed_missions / total_mission_assignments) * 100,
                1
            )
        
        return Response({
            'total_users': total_users,
            'completed_missions': completed_missions,
            'active_missions': active_missions,
            'avg_user_level': avg_user_level,
            'missions_by_difficulty': missions_by_difficulty,
            'missions_by_type': missions_by_type,
            'recent_activity': recent_activity,
            'level_distribution': level_distribution,
            'mission_completion_rate': completion_rate,
        })
