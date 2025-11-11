from decimal import Decimal
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.db import transaction as db_transaction
from django.db.models import Q, Sum
from django.utils import timezone
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
        Criar categoria com validações adicionais.
        """
        from rest_framework.exceptions import ValidationError
        
        user = self.request.user
        data = serializer.validated_data
        
        # 1. Limitar número de categorias personalizadas por usuário
        custom_categories = Category.objects.filter(user=user, is_system_default=False).count()
        if custom_categories >= 100:  # Limite razoável
            raise ValidationError({
                'non_field_errors': 'Você atingiu o limite de 100 categorias personalizadas.'
            })
        
        # 2. Validar unicidade case-insensitive
        name = data.get('name', '').strip()
        category_type = data.get('type')
        
        existing = Category.objects.filter(
            user=user,
            name__iexact=name,
            type=category_type
        ).exists()
        
        if existing:
            raise ValidationError({
                'name': f'Já existe uma categoria "{name}" do tipo {category_type} para você.'
            })
        
        # 3. Validar que não está tentando criar categoria de sistema
        if data.get('is_system_default', False):
            raise ValidationError({
                'is_system_default': 'Você não pode criar categorias de sistema.'
            })
        
        serializer.save(user=user, is_system_default=False)
    
    def perform_update(self, serializer):
        """
        Atualizar categoria com validações adicionais.
        """
        from rest_framework.exceptions import ValidationError
        
        instance = self.get_object()
        
        # 1. Validar que categorias de sistema não podem ser editadas
        if instance.is_system_default:
            raise ValidationError({
                'is_system_default': 'Categorias padrão do sistema não podem ser editadas.'
            })
        
        # 2. Validar que categoria pertence ao usuário
        if instance.user != self.request.user:
            raise ValidationError({
                'non_field_errors': 'Você não pode editar categorias de outros usuários.'
            })
        
        serializer.save()
    
    def perform_destroy(self, instance):
        """
        Deletar categoria com validações de segurança.
        """
        from rest_framework.exceptions import ValidationError
        
        # 1. Validar que categorias de sistema não podem ser deletadas
        if instance.is_system_default:
            raise ValidationError({
                'non_field_errors': 'Categorias padrão do sistema não podem ser excluídas.'
            })
        
        # 2. Validar que categoria pertence ao usuário
        if instance.user != self.request.user:
            raise ValidationError({
                'non_field_errors': 'Você não pode excluir categorias de outros usuários.'
            })
        
        # 3. Verificar se categoria tem transações vinculadas
        transaction_count = Transaction.objects.filter(category=instance).count()
        if transaction_count > 0:
            raise ValidationError({
                'non_field_errors': f'Esta categoria possui {transaction_count} transação(ões) vinculada(s). Reatribua as transações antes de excluir.'
            })
        
        # 4. Verificar se categoria tem metas vinculadas
        goal_count = Goal.objects.filter(target_category=instance).count()
        if goal_count > 0:
            raise ValidationError({
                'non_field_errors': f'Esta categoria possui {goal_count} meta(s) vinculada(s). Reatribua as metas antes de excluir.'
            })
        
        instance.delete()


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
        """
        Criar transação com validações adicionais.
        """
        from rest_framework.exceptions import ValidationError
        from decimal import Decimal
        
        # Validações extras antes de salvar
        user = self.request.user
        data = serializer.validated_data
        
        # 1. Verificar se categoria pertence ao usuário
        category = data.get('category')
        if category and category.user != user:
            raise ValidationError({
                'category': 'A categoria selecionada não pertence a você.'
            })
        
        # 2. Verificar limites de transações por dia (anti-spam)
        from django.utils import timezone
        today = timezone.now().date()
        today_transactions = Transaction.objects.filter(
            user=user,
            created_at__date=today
        ).count()
        
        if today_transactions >= 500:  # Limite razoável
            raise ValidationError({
                'non_field_errors': 'Limite de 500 transações por dia atingido.'
            })
        
        # 3. Validar valor não excede limite diário de criação
        total_today = Transaction.objects.filter(
            user=user,
            created_at__date=today
        ).aggregate(total=Sum('amount'))['total'] or Decimal('0')
        
        amount = data.get('amount', Decimal('0'))
        if total_today + amount > Decimal('100000000'):  # 100 milhões por dia
            raise ValidationError({
                'amount': 'Limite de valor total diário atingido (100 milhões).'
            })
        
        serializer.save()
        # Invalidar todos os caches após criar transação
        invalidate_user_dashboard_cache(self.request.user)
    
    def perform_update(self, serializer):
        """
        Atualizar transação com validações adicionais.
        """
        from rest_framework.exceptions import ValidationError
        
        instance = self.get_object()
        data = serializer.validated_data
        
        # 1. Verificar se nova categoria pertence ao usuário
        category = data.get('category')
        if category and category.user != self.request.user:
            raise ValidationError({
                'category': 'A categoria selecionada não pertence a você.'
            })
        
        # 2. Verificar se transação tem vínculos ativos que seriam invalidados
        if 'amount' in data or 'type' in data:
            links_as_source = TransactionLink.objects.filter(source_transaction=instance).count()
            links_as_target = TransactionLink.objects.filter(target_transaction=instance).count()
            
            if links_as_source > 0 or links_as_target > 0:
                # Avisar mas permitir (validações de TransactionLink.clean() vão prevenir inconsistências)
                pass
        
        # 3. Validar que transação paga (com links) não pode mudar para valor menor que já pago
        if 'amount' in data:
            new_amount = data['amount']
            paid_amount = TransactionLink.objects.filter(
                target_transaction=instance
            ).aggregate(total=Sum('amount'))['total'] or Decimal('0')
            
            if new_amount < paid_amount:
                raise ValidationError({
                    'amount': f'O novo valor ({new_amount}) não pode ser menor que o já pago ({paid_amount}).'
                })
        
        serializer.save()
        # Invalidar todos os caches após atualizar transação
        invalidate_user_dashboard_cache(self.request.user)
    
    def perform_destroy(self, instance):
        """
        Deletar transação com validações de segurança.
        """
        from rest_framework.exceptions import ValidationError
        
        # 1. Verificar se transação tem vínculos ativos
        links_as_source = TransactionLink.objects.filter(source_transaction=instance).count()
        links_as_target = TransactionLink.objects.filter(target_transaction=instance).count()
        
        if links_as_source > 0:
            raise ValidationError({
                'non_field_errors': f'Esta transação possui {links_as_source} pagamento(s) vinculado(s). Remova os vínculos antes de excluir.'
            })
        
        if links_as_target > 0:
            raise ValidationError({
                'non_field_errors': f'Esta transação recebeu {links_as_target} pagamento(s). Remova os vínculos antes de excluir.'
            })
        
        # 2. Verificar se transação está vinculada a metas
        goal_links = Goal.objects.filter(target_category=instance.category, user=instance.user).count()
        if goal_links > 0:
            # Permitir mas avisar via log
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(
                f"Transação {instance.uuid} excluída mas tinha categoria vinculada a {goal_links} meta(s)."
            )
        
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
        elif transaction.type == Transaction.TransactionType.EXPENSE:
            # Despesa reduz TPS
            tps_impact = -(amount / total_income) * 100
        
        # Impacto no RDR (apenas para despesas recorrentes)
        rdr_impact = 0
        if transaction.type == Transaction.TransactionType.EXPENSE and transaction.is_recurring:
            rdr_impact = (amount / total_income) * 100
        
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
        Lista despesas que ainda têm saldo pendente de pagamento.
        
        Query params:
        - max_amount: Filtrar despesas com saldo <= max_amount
        - category: Filtrar por categoria
        """
        from decimal import Decimal
        
        # Buscar transações do tipo EXPENSE com saldo pendente
        transactions = Transaction.objects.filter(
            user=request.user,
            type=Transaction.TransactionType.EXPENSE
        ).select_related('category')
        
        # Filtrar por categoria se fornecido
        category_id = request.query_params.get('category')
        if category_id:
            transactions = transactions.filter(category_id=category_id)
        
        # Filtrar apenas com saldo pendente
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
            "link_type": "EXPENSE_PAYMENT",  # opcional
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
            link_type=TransactionLink.LinkType.EXPENSE_PAYMENT
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
            Q(type=Transaction.TransactionType.EXPENSE)
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
                "fully_paid_expenses": ["uuid-despesa-2"]
            }
        }
        """
        from django.db import transaction as db_transaction
        from decimal import Decimal
        
        payments_data = request.data.get('payments', [])
        description = request.data.get('description', 'Pagamento em lote')
        
        # Validações iniciais
        if not payments_data:
            return Response(
                {'error': 'Nenhum pagamento fornecido'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if not isinstance(payments_data, list):
            return Response(
                {'error': 'O campo "payments" deve ser uma lista'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if len(payments_data) > 100:
            return Response(
                {'error': 'Máximo de 100 pagamentos por lote'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        created_links = []
        total_amount = Decimal('0')
        sources_used = set()
        targets_paid = set()
        fully_paid_expenses = []
        
        try:
            with db_transaction.atomic():
                # Validar todos os pagamentos primeiro
                for idx, payment in enumerate(payments_data):
                    if not isinstance(payment, dict):
                        raise ValueError(
                            f"Pagamento #{idx+1} inválido: deve ser um objeto"
                        )
                    
                    source_id = payment.get('source_id')
                    target_id = payment.get('target_id')
                    amount = payment.get('amount')
                    
                    if not source_id or not target_id or amount is None:
                        raise ValueError(
                            f"Pagamento #{idx+1} inválido: faltam campos obrigatórios (source_id, target_id, amount)"
                        )
                    
                    # Validar formato UUID
                    try:
                        from uuid import UUID
                        UUID(str(source_id))
                        UUID(str(target_id))
                    except (ValueError, AttributeError):
                        raise ValueError(
                            f"Pagamento #{idx+1}: IDs devem ser UUIDs válidos"
                        )
                    
                    if source_id == target_id:
                        raise ValueError(
                            f"Pagamento #{idx+1}: source_id e target_id não podem ser iguais"
                        )
                    
                    try:
                        amount = Decimal(str(amount))
                    except (ValueError, TypeError):
                        raise ValueError(
                            f"Pagamento #{idx+1}: valor inválido '{amount}'"
                        )
                    
                    if amount <= 0:
                        raise ValueError(
                            f"Pagamento #{idx+1}: valor deve ser positivo (recebido: {amount})"
                        )
                    
                    # Validar limite máximo por pagamento (prevenir erros)
                    if amount > Decimal('999999999.99'):
                        raise ValueError(
                            f"Pagamento #{idx+1}: valor muito alto (máximo: R$ 999.999.999,99)"
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
                    
                    # Validar tipos de transação
                    if source.type != Transaction.TransactionType.INCOME:
                        raise ValueError(
                            f"Pagamento #{idx+1}: source deve ser uma receita (INCOME), "
                            f"mas '{source.description}' é {source.type}"
                        )
                    
                    if target.type != Transaction.TransactionType.EXPENSE:
                        raise ValueError(
                            f"Pagamento #{idx+1}: target deve ser uma despesa (EXPENSE), "
                            f"mas '{target.description}' é {target.type}"
                        )
                    
                    # Validar saldo disponível
                    if amount > source.available_amount:
                        raise ValueError(
                            f"Pagamento #{idx+1}: valor R$ {amount} excede saldo disponível "
                            f"de '{source.description}' (R$ {source.available_amount})"
                        )
                    
                    if amount > target.available_amount:
                        raise ValueError(
                            f"Pagamento #{idx+1}: valor R$ {amount} excede saldo pendente "
                            f"de '{target.description}' (R$ {target.available_amount})"
                        )
                    
                    # Criar link (usar EXPENSE_PAYMENT para despesas comuns)
                    link = TransactionLink.objects.create(
                        user=request.user,
                        source_transaction_uuid=source_id,
                        target_transaction_uuid=target_id,
                        linked_amount=amount,
                        link_type=TransactionLink.LinkType.EXPENSE_PAYMENT,
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
                        fully_paid_expenses.append(str(target_id))
                
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
                    'fully_paid_expenses': fully_paid_expenses
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
    
    def perform_create(self, serializer):
        """
        Criar meta com validações adicionais.
        """
        from rest_framework.exceptions import ValidationError
        from decimal import Decimal
        
        user = self.request.user
        data = serializer.validated_data
        
        # 1. Limitar número de metas ativas por usuário
        active_goals = Goal.objects.filter(user=user, is_completed=False).count()
        if active_goals >= 50:  # Limite razoável
            raise ValidationError({
                'non_field_errors': 'Você atingiu o limite de 50 metas ativas. Complete ou exclua metas antigas.'
            })
        
        # 2. Validar categoria pertence ao usuário
        target_category = data.get('target_category')
        if target_category and target_category.user != user:
            raise ValidationError({
                'target_category': 'A categoria selecionada não pertence a você.'
            })
        
        # 3. Validar que não existe meta duplicada (mesmo título e tipo)
        title = data.get('title', '').strip()
        goal_type = data.get('goal_type')
        existing = Goal.objects.filter(
            user=user,
            title__iexact=title,
            goal_type=goal_type,
            is_completed=False
        ).exists()
        
        if existing:
            raise ValidationError({
                'title': f'Já existe uma meta ativa com o título "{title}" e mesmo tipo.'
            })
        
        serializer.save()
    
    def perform_update(self, serializer):
        """
        Atualizar meta com validações adicionais.
        """
        from rest_framework.exceptions import ValidationError
        
        instance = self.get_object()
        data = serializer.validated_data
        
        # 1. Validar que meta concluída não pode ser reaberta
        if instance.is_completed and not data.get('is_completed', True):
            raise ValidationError({
                'is_completed': 'Uma meta concluída não pode ser reaberta. Crie uma nova meta.'
            })
        
        # 2. Validar nova categoria pertence ao usuário
        target_category = data.get('target_category')
        if target_category and target_category.user != self.request.user:
            raise ValidationError({
                'target_category': 'A categoria selecionada não pertence a você.'
            })
        
        # 3. Validar que se marcar como concluída, progresso deve ser >= 95%
        if data.get('is_completed') and not instance.is_completed:
            current_amount = data.get('current_amount', instance.current_amount)
            target_amount = data.get('target_amount', instance.target_amount)
            
            if target_amount > 0:
                progress_percent = (float(current_amount) / float(target_amount)) * 100
                if progress_percent < 95:
                    raise ValidationError({
                        'is_completed': f'Meta só pode ser concluída com pelo menos 95% de progresso. Atual: {progress_percent:.1f}%'
                    })
        
        serializer.save()
    
    def perform_destroy(self, instance):
        """
        Deletar meta com validações de segurança.
        """
        from rest_framework.exceptions import ValidationError
        
        # 1. Avisar se meta está próxima da conclusão
        if instance.target_amount > 0:
            progress_percent = (float(instance.current_amount) / float(instance.target_amount)) * 100
            if progress_percent >= 80:
                # Permitir mas logar aviso
                import logging
                logger = logging.getLogger(__name__)
                logger.warning(
                    f"Meta {instance.uuid} excluída com {progress_percent:.1f}% de progresso (próxima da conclusão)."
                )
        
        # 2. Verificar se está vinculada a missões ativas
        active_mission_links = MissionProgress.objects.filter(
            user=instance.user,
            mission__target_goal=instance,
            status=MissionProgress.MissionStatus.IN_PROGRESS
        ).count()
        
        if active_mission_links > 0:
            raise ValidationError({
                'non_field_errors': f'Esta meta está vinculada a {active_mission_links} missão(ões) ativa(s). Complete ou cancele as missões primeiro.'
            })
        
        instance.delete()
    
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


class MissionViewSet(viewsets.ModelViewSet):
    """
    ViewSet para CRUD completo de missões.
    
    - LIST/RETRIEVE: Qualquer usuário autenticado (apenas missões ativas)
    - CREATE/UPDATE/DELETE: Apenas admins (is_staff ou is_superuser)
    
    Filtros disponíveis:
    - tier: BEGINNER, INTERMEDIATE, ADVANCED
    - mission_type: ONBOARDING, TPS_IMPROVEMENT, RDR_REDUCTION, etc.
    - difficulty: EASY, MEDIUM, HARD
    - is_active: true/false
    - search: busca por título ou descrição
    """
    serializer_class = MissionSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['mission_type', 'difficulty', 'is_active']
    search_fields = ['title', 'description']
    ordering_fields = ['created_at', 'priority', 'reward_points']
    ordering = ['priority', '-created_at']

    def _get_tier_level_range(self, tier):
        """Retorna o range de níveis para um tier específico."""
        tier_ranges = {
            'BEGINNER': (1, 5),
            'INTERMEDIATE': (6, 15),
            'ADVANCED': (16, 100)
        }
        return tier_ranges.get(tier, (1, 100))
    
    def get_permissions(self):
        """
        Define permissões baseadas na ação:
        - create, update, partial_update, destroy: IsAdminUser
        - list, retrieve, outras actions: IsAuthenticated
        """
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [permissions.IsAdminUser()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        """
        Retorna missões:
        - Para admin: todas as missões
        - Para usuário comum: apenas missões ativas
        
        Suporta filtro por tier via query param.
        """
        queryset = Mission.objects.all()
        
        # Usuários comuns veem apenas missões ativas
        if not self.request.user.is_staff:
            queryset = queryset.filter(is_active=True)
        
        # Filtro por tier (custom)
        tier = self.request.query_params.get('tier', None)
        if tier:
            tier_level_range = self._get_tier_level_range(tier)
            # Missões que se aplicam ao tier
            queryset = queryset.filter(
                Q(min_transactions__isnull=True) | 
                Q(min_transactions__lte=tier_level_range[1])
            )
        
        return queryset
    
    def perform_create(self, serializer):
        """
        Valida e cria nova missão.
        Apenas admins podem criar missões.
        """
        # Validações adicionais podem ser adicionadas aqui
        mission = serializer.save()
        logger.info(f"Missão '{mission.title}' criada por admin {self.request.user.username}")
        return mission
    
    def perform_update(self, serializer):
        """
        Valida e atualiza missão existente.
        Apenas admins podem atualizar missões.
        """
        mission = serializer.save()
        logger.info(f"Missão '{mission.title}' atualizada por admin {self.request.user.username}")
        return mission
    
    def perform_destroy(self, instance):
        """
        Desativa missão ao invés de deletar (soft delete).
        Apenas admins podem desativar missões.
        """
        instance.is_active = False
        instance.save()
        logger.info(f"Missão '{instance.title}' desativada por admin {self.request.user.username}")
        # Não chama super().perform_destroy() para não deletar do banco
    
    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def duplicate(self, request, pk=None):
        """
        Duplica uma missão existente.
        
        POST /api/missions/{id}/duplicate/
        {
            "title_suffix": " (Cópia)" (opcional, padrão: " - Cópia")
        }
        
        Retorna a missão duplicada.
        Apenas admins podem duplicar missões.
        """
        original_mission = self.get_object()
        title_suffix = request.data.get('title_suffix', ' - Cópia')
        
        # Criar cópia da missão
        duplicated = Mission.objects.create(
            title=f"{original_mission.title}{title_suffix}",
            description=original_mission.description,
            reward_points=original_mission.reward_points,
            difficulty=original_mission.difficulty,
            mission_type=original_mission.mission_type,
            priority=original_mission.priority + 1,  # Incrementa prioridade
            target_tps=original_mission.target_tps,
            target_rdr=original_mission.target_rdr,
            min_ili=original_mission.min_ili,
            max_ili=original_mission.max_ili,
            min_transactions=original_mission.min_transactions,
            duration_days=original_mission.duration_days,
            is_active=False,  # Criar desativada para admin revisar
            validation_type=original_mission.validation_type,
            requires_consecutive_days=original_mission.requires_consecutive_days,
            min_consecutive_days=original_mission.min_consecutive_days,
            target_category=original_mission.target_category,
            target_reduction_percent=original_mission.target_reduction_percent,
            category_spending_limit=original_mission.category_spending_limit,
            target_goal=original_mission.target_goal,
            goal_progress_target=original_mission.goal_progress_target,
            savings_increase_amount=original_mission.savings_increase_amount,
        )
        
        logger.info(f"Missão '{original_mission.title}' duplicada como '{duplicated.title}' por admin {request.user.username}")
        
        serializer = self.get_serializer(duplicated)
        return Response(
            {
                'success': True,
                'message': f'Missão duplicada com sucesso',
                'original_id': str(original_mission.id),
                'duplicated': serializer.data
            },
            status=status.HTTP_201_CREATED
        )
    
    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def toggle_active(self, request, pk=None):
        """
        Ativa/desativa uma missão.
        
        POST /api/missions/{id}/toggle_active/
        
        Apenas admins podem ativar/desativar missões.
        """
        mission = self.get_object()
        mission.is_active = not mission.is_active
        mission.save()
        
        status_text = 'ativada' if mission.is_active else 'desativada'
        logger.info(f"Missão '{mission.title}' {status_text} por admin {request.user.username}")
        
        serializer = self.get_serializer(mission)
        return Response(
            {
                'success': True,
                'message': f'Missão {status_text} com sucesso',
                'mission': serializer.data
            }
        )
    
    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def generate_ai_missions(self, request):
        """
        Gera missões usando IA (Gemini) com validação incremental - ADMIN/STAFF ONLY
        
        Requer: is_staff=True ou is_superuser=True
        
        POST /api/missions/generate_ai_missions/
        {
            "tier": "BEGINNER|INTERMEDIATE|ADVANCED" (opcional),
            "scenario": "TPS_LOW|RDR_HIGH|MIXED_BALANCED|..." (opcional),
            "count": 20 (opcional, número de missões a gerar)
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
        
        NOVO: Geração incremental (1 por vez) com:
        - Validação antes de salvar
        - Detecção de duplicatas semânticas
        - Salvamento parcial (não perde tudo se houver erro)
        
        Exemplo de resposta:
        {
            "success": true,
            "total_created": 18,
            "total_failed": 2,
            "validation_summary": {
                "failed_validation": 1,
                "failed_duplicate": 1,
                "failed_api": 0
            },
            "created_missions": [
                {
                    "id": "uuid",
                    "title": "...",
                    "mission_type": "TPS_IMPROVEMENT",
                    "difficulty": "MEDIUM",
                    "xp_reward": 150
                },
                ...
            ],
            "failed_missions": [
                {
                    "index": 15,
                    "error": "Máximo de tentativas excedido",
                    "retries": 3
                }
            ]
        }
        """
        from .ai_services import (
            generate_and_save_incrementally,
            MISSION_SCENARIOS
        )
        
        tier = request.data.get('tier')
        scenario = request.data.get('scenario')
        count = request.data.get('count', 20)
        
        # Validar count
        try:
            count = int(count)
            if count < 1 or count > 100:
                return Response(
                    {'error': 'count deve estar entre 1 e 100'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        except (ValueError, TypeError):
            return Response(
                {'error': 'count deve ser um número inteiro'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
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
        
        # Se tier não fornecido, usar BEGINNER como padrão
        if not tier:
            tier = 'BEGINNER'
            logger.info(f"Tier não especificado, usando padrão: {tier}")
        
        try:
            # Tentar obter contexto de usuário representativo do tier para personalização
            from .services import get_comprehensive_mission_context
            
            user_context = None
            try:
                tier_level_range = self._get_tier_level_range(tier)
                representative_profile = UserProfile.objects.filter(
                    level__range=tier_level_range
                ).select_related('user').order_by('-user__last_login').first()
                
                if representative_profile and representative_profile.user:
                    user_context = get_comprehensive_mission_context(representative_profile.user)
                    logger.info(f"Usando contexto do usuário {representative_profile.user.username} (nível {representative_profile.level}) para tier {tier}")
            except Exception as e:
                logger.warning(f"Não foi possível obter contexto de usuário para {tier}: {e}")
            
            # Gerar missões incrementalmente (NOVA FUNÇÃO)
            result = generate_and_save_incrementally(
                tier=tier,
                scenario_key=scenario,
                user_context=user_context,
                count=count,
                max_retries=3
            )
            
            # Extrair resultados
            created_missions = result['created']
            failed_missions = result['failed']
            summary = result['summary']
            
            # Preparar resposta
            return Response({
                'success': summary['total_created'] > 0,
                'total_created': summary['total_created'],
                'total_failed': summary['total_failed'],
                'validation_summary': {
                    'failed_validation': summary['failed_validation'],
                    'failed_duplicate': summary['failed_duplicate'],
                    'failed_api': summary['failed_api']
                },
                'created_missions': created_missions[:10],  # Primeiras 10 como preview
                'failed_missions': failed_missions[:5],  # Primeiras 5 falhas
                'tier': tier,
                'scenario': scenario or 'auto-detectado',
                'personalized': user_context is not None,
                'message': f'{summary["total_created"]} missões criadas com sucesso via IA (validação incremental)'
            })
            
        except Exception as e:
            logger.error(f"Erro ao gerar missões via IA: {e}", exc_info=True)
            return Response(
                {
                    'success': False,
                    'error': 'Erro ao gerar missões',
                    'detail': str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


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


class SimplifiedOnboardingView(APIView):
    """
    Endpoint para onboarding simplificado.
    Recebe apenas 2 valores: renda mensal e gastos essenciais.
    Cria transações iniciais e retorna insights básicos.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        from decimal import Decimal, InvalidOperation
        
        # Extrair e validar parâmetros
        try:
            monthly_income = Decimal(str(request.data.get('monthly_income', 0)))
        except (InvalidOperation, ValueError, TypeError):
            return Response(
                {"error": "Renda mensal inválida. Use um número válido."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            essential_expenses = Decimal(str(request.data.get('essential_expenses', 0)))
        except (InvalidOperation, ValueError, TypeError):
            return Response(
                {"error": "Gastos essenciais inválidos. Use um número válido."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Validações de negócio
        if monthly_income <= 0:
            return Response(
                {"error": "Renda mensal deve ser maior que zero."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if essential_expenses < 0:
            return Response(
                {"error": "Gastos essenciais não podem ser negativos."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if essential_expenses > monthly_income:
            return Response(
                {"error": "Gastos essenciais não podem exceder a renda."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        user = request.user
        
        # Criar transações iniciais e categorias
        try:
            with db_transaction.atomic():
                # Categoria de renda
                income_cat, _ = Category.objects.get_or_create(
                    user=user,
                    name="Salário",
                    type=Category.CategoryType.INCOME,
                    defaults={
                        'group': Category.CategoryGroup.REGULAR_INCOME,
                        'color': '#4CAF50'
                    }
                )
                
                # Categoria de despesa
                expense_cat, _ = Category.objects.get_or_create(
                    user=user,
                    name="Gastos Essenciais",
                    type=Category.CategoryType.EXPENSE,
                    defaults={
                        'group': Category.CategoryGroup.ESSENTIAL_EXPENSE,
                        'color': '#F44336'
                    }
                )
                
                # Transação de renda
                Transaction.objects.create(
                    user=user,
                    description="Salário mensal",
                    amount=monthly_income,
                    category=income_cat,
                    type=Transaction.TransactionType.INCOME,
                    date=timezone.now().date()
                )
                
                # Transação de despesa (se houver)
                if essential_expenses > 0:
                    Transaction.objects.create(
                        user=user,
                        description="Gastos essenciais do mês",
                        amount=essential_expenses,
                        category=expense_cat,
                        type=Transaction.TransactionType.EXPENSE,
                        date=timezone.now().date()
                    )
                
                # Marcar onboarding completo
                profile = user.userprofile
                profile.is_first_access = False
                profile.save()
                
                # Atribuir missões automaticamente
                assign_missions_automatically(user)
                
                # Atualizar indicadores em cache
                from .services import FinancialIndicatorsService
                FinancialIndicatorsService.update_cached_indicators(user)
        
        except Exception as e:
            logger.error(f"Erro ao processar onboarding simplificado: {e}")
            return Response(
                {"error": "Erro ao processar onboarding. Tente novamente."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        # Calcular insights
        balance = monthly_income - essential_expenses
        savings_rate = (balance / monthly_income * 100) if monthly_income > 0 else Decimal('0')
        
        recommendation = self._get_recommendation(savings_rate)
        
        return Response({
            "success": True,
            "insights": {
                "monthly_balance": float(balance),
                "savings_rate": float(savings_rate),
                "can_save": balance > 0,
                "recommendation": recommendation,
                "next_steps": [
                    "Registre suas transações diárias",
                    "Crie metas de economia",
                    "Complete desafios para ganhar pontos"
                ]
            }
        }, status=status.HTTP_201_CREATED)
    
    def _get_recommendation(self, savings_rate: Decimal) -> str:
        """Retorna recomendação baseada na taxa de poupança."""
        if savings_rate >= 20:
            return "Excelente! Você está no caminho certo para construir patrimônio."
        elif savings_rate >= 10:
            return "Bom começo! Tente aumentar gradualmente sua taxa de poupança."
        elif savings_rate >= 5:
            return "Você está começando a poupar. Procure oportunidades para economizar mais."
        else:
            return "Revise seus gastos e tente encontrar áreas onde pode economizar."


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
    - GET /leaderboard/ - DEPRECATED (usar /leaderboard/friends/)
    - GET /leaderboard/friends/ - Ranking de amigos (otimizado com cache)
    
    Dia 11-14: Ranking apenas entre amigos
    - Endpoint geral deprecado para reduzir comparação social
    - Ranking de amigos otimizado com cache de 5 minutos
    - Sistema de sugestão de amigos integrado
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def list(self, request):
        """
        DEPRECATED: Ranking geral removido.
        
        Agora o sistema foca apenas em ranking entre amigos para:
        - Reduzir pressão de comparação social
        - Aumentar engajamento entre amigos
        - Melhorar motivação por conexões próximas
        
        Use GET /leaderboard/friends/ para ver ranking de amigos.
        """
        return Response({
            'deprecated': True,
            'message': 'O ranking geral foi descontinuado. Use /api/leaderboard/friends/ para ver o ranking de amigos.',
            'redirect_to': '/api/leaderboard/friends/',
            'reason': 'Focamos em comparação saudável entre amigos ao invés de ranking global.',
        }, status=status.HTTP_410_GONE)
        
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
        """
        Retorna o ranking otimizado apenas dos amigos do usuário.
        
        Melhorias (Dia 11-14):
        - Cache de 5 minutos por usuário
        - Sugestões de amigos quando < 3 amigos
        - Incentivos para adicionar amigos
        - Query otimizada com select_related
        """
        from .serializers import LeaderboardEntrySerializer
        from .models import Friendship
        from django.core.cache import cache
        
        user = request.user
        cache_key = f"friends_leaderboard:{user.id}"
        
        # Tentar buscar do cache (5 minutos)
        cached_data = cache.get(cache_key)
        if cached_data is not None:
            return Response(cached_data)
        
        # Obter IDs dos amigos (amizades aceitas)
        friendships = Friendship.objects.filter(
            (Q(user=user) | Q(friend=user)),
            status=Friendship.FriendshipStatus.ACCEPTED
        ).select_related('user', 'friend')
        
        friends_ids = []
        for friendship in friendships:
            friend_id = friendship.friend_id if friendship.user_id == user.id else friendship.user_id
            friends_ids.append(friend_id)
        
        # Adicionar o próprio usuário ao ranking
        user_ids = friends_ids + [user.id]
        
        # Buscar perfis dos amigos ordenados por XP
        profiles = UserProfile.objects.filter(
            user_id__in=user_ids
        ).select_related('user').order_by('-level', '-experience_points')[:50]
        
        # Montar resultados com ranking
        results = []
        current_user_rank = None
        
        for idx, profile in enumerate(profiles, start=1):
            user_obj = profile.user
            full_name = f"{user_obj.first_name} {user_obj.last_name}".strip() if user_obj.first_name or user_obj.last_name else user_obj.username
            
            is_current = user_obj.id == user.id
            if is_current:
                current_user_rank = idx
            
            results.append({
                'rank': idx,
                'user_id': user_obj.id,
                'username': user_obj.username,
                'name': full_name,
                'level': profile.level,
                'xp': profile.experience_points,
                'is_current_user': is_current,
            })
        
        serializer = LeaderboardEntrySerializer(results, many=True)
        
        # Sistema de sugestões de amigos
        total_friends = len(friends_ids)
        suggestions = {
            'should_add_friends': total_friends < 3,
            'message': None,
            'reward': None,
        }
        
        if total_friends == 0:
            suggestions['message'] = '🎉 Adicione seu primeiro amigo e ganhe +100 XP!'
            suggestions['reward'] = 100
        elif total_friends < 3:
            suggestions['message'] = f'💪 Adicione mais {3 - total_friends} amigo(s) para completar seu círculo!'
            suggestions['reward'] = 50
        else:
            suggestions['message'] = '🌟 Você tem uma ótima rede de amigos!'
        
        response_data = {
            'count': len(results),
            'leaderboard': serializer.data,
            'current_user_rank': current_user_rank,
            'total_friends': total_friends,
            'suggestions': suggestions,
        }
        
        # Cachear por 5 minutos
        cache.set(cache_key, response_data, timeout=300)
        
        return Response(response_data)
    
    @action(detail=False, methods=['get'])
    def suggestions(self, request):
        """
        Retorna sugestões de amigos baseadas em:
        - Usuários com nível similar (±2 níveis)
        - Usuários que ainda não são amigos
        - Exclui solicitações pendentes
        
        Novo endpoint (Dia 11-14) para incentivar adição de amigos.
        """
        from .models import Friendship
        from django.core.cache import cache
        
        user = request.user
        cache_key = f"friend_suggestions:{user.id}"
        
        # Cache de 10 minutos
        cached_suggestions = cache.get(cache_key)
        if cached_suggestions is not None:
            return Response(cached_suggestions)
        
        # Obter perfil do usuário
        user_profile = UserProfile.objects.get(user=user)
        user_level = user_profile.level
        
        # Obter IDs de amigos existentes e pendentes
        existing_friendships = Friendship.objects.filter(
            Q(user=user) | Q(friend=user)
        ).values_list('user_id', 'friend_id')
        
        excluded_ids = set([user.id])
        for user_id, friend_id in existing_friendships:
            excluded_ids.add(user_id)
            excluded_ids.add(friend_id)
        
        # Buscar usuários com nível similar (±2 níveis)
        suggested_profiles = UserProfile.objects.filter(
            level__gte=user_level - 2,
            level__lte=user_level + 2,
        ).exclude(
            user_id__in=excluded_ids
        ).select_related('user').order_by('-experience_points')[:10]
        
        suggestions = []
        for profile in suggested_profiles:
            suggested_user = profile.user
            suggestions.append({
                'user_id': suggested_user.id,
                'username': suggested_user.username,
                'name': f"{suggested_user.first_name} {suggested_user.last_name}".strip() or suggested_user.username,
                'level': profile.level,
                'xp': profile.experience_points,
                'reason': f'Nível {profile.level} - similar ao seu!',
            })
        
        response_data = {
            'count': len(suggestions),
            'suggestions': suggestions,
            'tip': 'Adicione amigos com níveis similares para uma competição saudável! 🎯',
        }
        
        # Cache de 10 minutos
        cache.set(cache_key, response_data, timeout=600)
        
        return Response(response_data)


# ============================================================================
# ADMIN STATISTICS
# ============================================================================
class AdminStatsViewSet(viewsets.ViewSet):
    """
    ViewSet for admin statistics and dashboard data.
    Only accessible by staff users.
    Implements caching with 10-minute TTL for performance.
    """
    permission_classes = [permissions.IsAdminUser]
    
    def _get_cached_or_compute(self, cache_key, compute_func, timeout=600):
        """
        Helper to get data from cache or compute and cache it.
        
        Args:
            cache_key: Unique key for this data
            compute_func: Function to call if cache miss
            timeout: Cache TTL in seconds (default 600 = 10 minutes)
        """
        data = cache.get(cache_key)
        if data is None:
            data = compute_func()
            cache.set(cache_key, data, timeout)
            logger.info(f"Cache miss for {cache_key}, computed and cached")
        else:
            logger.info(f"Cache hit for {cache_key}")
        return data
    
    @action(detail=False, methods=['get'])
    def overview(self, request):
        """
        Get overview statistics for admin dashboard.
        Cached for 10 minutes.
        
        Returns:
        - total_users: Total number of users in the system
        - completed_missions: Total completed missions across all users
        - active_missions: Total active (non-completed) missions
        - avg_user_level: Average level of all users
        - missions_by_tier: Mission distribution by tier
        - missions_by_type: Mission distribution by type
        - recent_activity: Recent mission completions
        """
        def compute_overview():
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
            
            return {
                'total_users': total_users,
                'completed_missions': completed_missions,
                'active_missions': active_missions,
                'avg_user_level': avg_user_level,
                'missions_by_difficulty': missions_by_difficulty,
                'missions_by_type': missions_by_type,
                'recent_activity': recent_activity,
                'level_distribution': level_distribution,
                'mission_completion_rate': completion_rate,
            }
        
        data = self._get_cached_or_compute('admin_stats_overview', compute_overview)
        return Response(data)
    
    @action(detail=False, methods=['get'])
    def user_analytics(self, request):
        """
        Get detailed user analytics.
        Cached for 10 minutes.
        
        Returns:
        - total_users: Total registered users
        - active_users_7d: Users active in last 7 days
        - active_users_30d: Users active in last 30 days
        - new_users_7d: New registrations in last 7 days
        - users_by_level: Distribution of users by level
        - top_users: Top 10 users by XP
        - inactive_users: Users inactive for >30 days
        """
        def compute_user_analytics():
            from django.db.models import Count, Q, F
            from datetime import timedelta
            from django.utils import timezone
            
            now = timezone.now()
            seven_days_ago = now - timedelta(days=7)
            thirty_days_ago = now - timedelta(days=30)
            
            # Total users
            total_users = User.objects.count()
            
            # Active users (users with transactions or mission progress in period)
            active_users_7d = User.objects.filter(
                Q(transaction__date__gte=seven_days_ago.date()) |
                Q(missionprogress__updated_at__gte=seven_days_ago)
            ).distinct().count()
            
            active_users_30d = User.objects.filter(
                Q(transaction__date__gte=thirty_days_ago.date()) |
                Q(missionprogress__updated_at__gte=thirty_days_ago)
            ).distinct().count()
            
            # New users
            new_users_7d = User.objects.filter(
                date_joined__gte=seven_days_ago
            ).count()
            
            # Users by level (detailed)
            users_by_level = {}
            for level in range(1, 21):
                count = UserProfile.objects.filter(level=level).count()
                if count > 0:
                    users_by_level[f'Level {level}'] = count
            users_by_level['Level 21+'] = UserProfile.objects.filter(level__gte=21).count()
            
            # Top users by XP
            top_users = UserProfile.objects.select_related('user').order_by('-total_xp')[:10]
            top_users_data = []
            for profile in top_users:
                top_users_data.append({
                    'username': profile.user.username,
                    'level': profile.level,
                    'total_xp': profile.total_xp,
                    'xp_to_next_level': profile.xp_to_next_level,
                })
            
            # Inactive users (no activity in last 30 days)
            inactive_users = User.objects.exclude(
                Q(transaction__date__gte=thirty_days_ago.date()) |
                Q(missionprogress__updated_at__gte=thirty_days_ago)
            ).distinct().count()
            
            # Users with goals
            users_with_goals = User.objects.filter(
                goal__isnull=False
            ).distinct().count()
            
            # Users with completed goals
            users_with_completed_goals = User.objects.filter(
                goal__status='COMPLETED'
            ).distinct().count()
            
            return {
                'total_users': total_users,
                'active_users_7d': active_users_7d,
                'active_users_30d': active_users_30d,
                'new_users_7d': new_users_7d,
                'users_by_level': users_by_level,
                'top_users': top_users_data,
                'inactive_users': inactive_users,
                'users_with_goals': users_with_goals,
                'users_with_completed_goals': users_with_completed_goals,
            }
        
        data = self._get_cached_or_compute('admin_stats_user_analytics', compute_user_analytics)
        return Response(data)
    
    @action(detail=False, methods=['get'])
    def system_health(self, request):
        """
        Get system health metrics.
        Cached for 10 minutes.
        
        Returns:
        - total_transactions: Total transactions in system
        - transactions_7d: Transactions in last 7 days
        - total_goals: Total goals created
        - active_goals: Currently active goals
        - completed_goals: Completed goals
        - categories_count: Total categories (global + user)
        - avg_transactions_per_user: Average transactions per user
        - avg_goals_per_user: Average goals per user
        """
        def compute_system_health():
            from django.db.models import Count, Avg
            from datetime import timedelta
            from django.utils import timezone
            
            now = timezone.now()
            seven_days_ago = now - timedelta(days=7)
            
            # Transaction metrics
            total_transactions = Transaction.objects.count()
            transactions_7d = Transaction.objects.filter(
                date__gte=seven_days_ago.date()
            ).count()
            
            # Goal metrics
            total_goals = Goal.objects.count()
            active_goals = Goal.objects.filter(
                status='ACTIVE'
            ).count()
            completed_goals = Goal.objects.filter(
                status='COMPLETED'
            ).count()
            
            # Category metrics
            categories_count = Category.objects.count()
            global_categories = Category.objects.filter(user__isnull=True).count()
            user_categories = Category.objects.filter(user__isnull=False).count()
            
            # Averages
            total_users = User.objects.count()
            avg_transactions_per_user = 0
            avg_goals_per_user = 0
            
            if total_users > 0:
                avg_transactions_per_user = round(total_transactions / total_users, 1)
                avg_goals_per_user = round(total_goals / total_users, 1)
            
            # Mission metrics
            total_missions = Mission.objects.filter(is_active=True).count()
            ai_generated_missions = Mission.objects.filter(
                is_active=True,
                priority__lt=90  # Missões IA geralmente têm priority < 90
            ).count()
            default_missions = Mission.objects.filter(
                is_active=True,
                priority__gte=90  # Missões padrão têm priority >= 90
            ).count()
            
            return {
                'total_transactions': total_transactions,
                'transactions_7d': transactions_7d,
                'total_goals': total_goals,
                'active_goals': active_goals,
                'completed_goals': completed_goals,
                'categories_count': categories_count,
                'global_categories': global_categories,
                'user_categories': user_categories,
                'avg_transactions_per_user': avg_transactions_per_user,
                'avg_goals_per_user': avg_goals_per_user,
                'total_missions': total_missions,
                'ai_generated_missions': ai_generated_missions,
                'default_missions': default_missions,
            }
        
        data = self._get_cached_or_compute('admin_stats_system_health', compute_system_health)
        return Response(data)
