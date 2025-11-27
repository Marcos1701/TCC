"""
Views para gerenciamento de transações e vinculações.
"""

import logging
from collections import defaultdict
from decimal import Decimal

from django.db import transaction as db_transaction
from django.db.models import Count, OuterRef, Q, Subquery, Sum, Value
from django.db.models.functions import Coalesce
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response

from .base import (
    BurstRateThrottle,
    Category,
    IsOwnerPermission,
    Transaction,
    TransactionCreateThrottle,
    TransactionLink,
    TransactionLinkSerializer,
    TransactionSerializer,
    invalidate_user_dashboard_cache,
)

logger = logging.getLogger(__name__)


class TransactionViewSet(viewsets.ModelViewSet):
    serializer_class = TransactionSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerPermission]
    
    def get_throttles(self):
        if self.action in ['create', 'update', 'partial_update']:
            return [TransactionCreateThrottle(), BurstRateThrottle()]
        elif self.action == 'destroy':
            return [BurstRateThrottle()]
        return super().get_throttles()

    def get_queryset(self):
        outgoing_sum = TransactionLink.objects.filter(
            source_transaction_uuid=OuterRef('id')
        ).values('source_transaction_uuid').annotate(
            total=Coalesce(Sum('linked_amount'), Value(Decimal('0')))
        ).values('total')
        
        incoming_sum = TransactionLink.objects.filter(
            target_transaction_uuid=OuterRef('id')
        ).values('target_transaction_uuid').annotate(
            total=Coalesce(Sum('linked_amount'), Value(Decimal('0')))
        ).values('total')
        
        outgoing_count = TransactionLink.objects.filter(
            source_transaction_uuid=OuterRef('id')
        ).values('source_transaction_uuid').annotate(
            cnt=Count('id')
        ).values('cnt')
        
        incoming_count = TransactionLink.objects.filter(
            target_transaction_uuid=OuterRef('id')
        ).values('target_transaction_uuid').annotate(
            cnt=Count('id')
        ).values('cnt')
        
        qs = Transaction.objects.filter(
            user=self.request.user
        ).select_related(
            "category"
        ).annotate(
            linked_amount_annotated=Coalesce(Subquery(outgoing_sum), Value(Decimal('0'))),
            outgoing_links_count_annotated=Coalesce(Subquery(outgoing_count), Value(0)),
            incoming_links_count_annotated=Coalesce(Subquery(incoming_count), Value(0)),
        )
        
        tx_type = self.request.query_params.get("type")
        if tx_type:
            qs = qs.filter(type=tx_type)
        
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
        
        limit = self.request.query_params.get("limit")
        offset = self.request.query_params.get("offset")
        
        qs = qs.order_by("-date", "-created_at")
        
        if offset:
            qs = qs[int(offset):]
        if limit:
            qs = qs[:int(limit)]
        
        return qs
    
    def create(self, request, *args, **kwargs):
        """Criar transação com XP reward."""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        
        # Invalidar cache após criar transação
        invalidate_user_dashboard_cache(request.user)
        
        XP_PER_TRANSACTION = 50
        
        headers = self.get_success_headers(serializer.data)
        response_data = serializer.data
        response_data['xp_earned'] = XP_PER_TRANSACTION
        
        return Response(response_data, status=status.HTTP_201_CREATED, headers=headers)
    
    def perform_update(self, serializer):
        instance = self.get_object()
        data = serializer.validated_data
        
        category = data.get('category')
        if category and category.user is not None and category.user != self.request.user:
            raise ValidationError({
                'category': 'A categoria selecionada não pertence a você.'
            })
        
        if 'amount' in data or 'type' in data:
            TransactionLink.objects.filter(source_transaction_uuid=instance.id).count()
            TransactionLink.objects.filter(target_transaction_uuid=instance.id).count()
        
        if 'amount' in data:
            new_amount = data['amount']
            paid_amount = TransactionLink.objects.filter(
                target_transaction_uuid=instance.id
            ).aggregate(total=Sum('linked_amount'))['total'] or Decimal('0')
            
            if new_amount < paid_amount:
                raise ValidationError({
                    'amount': f'O novo valor ({new_amount}) não pode ser menor que o já pago ({paid_amount}).'
                })
        
        serializer.save()
        invalidate_user_dashboard_cache(self.request.user)
    
    def perform_destroy(self, instance):
        links_as_source = TransactionLink.objects.filter(source_transaction_uuid=instance.id).count()
        links_as_target = TransactionLink.objects.filter(target_transaction_uuid=instance.id).count()
        
        if links_as_source > 0:
            raise ValidationError({
                'non_field_errors': f'Esta transação possui {links_as_source} pagamento(s) vinculado(s). Remova os vínculos antes de excluir.'
            })
        
        if links_as_target > 0:
            raise ValidationError({
                'non_field_errors': f'Esta transação recebeu {links_as_target} pagamento(s). Remova os vínculos antes de excluir.'
            })
        
        instance.delete()
        invalidate_user_dashboard_cache(self.request.user)
    
    @action(detail=True, methods=['get'])
    def details(self, request, pk=None):
        transaction = self.get_object()
        serializer = self.get_serializer(transaction)
        
        data = serializer.data
        
        impact = self._calculate_transaction_impact(transaction)
        data['estimated_impact'] = impact
        
        stats = self._get_transaction_stats(transaction)
        data['related_stats'] = stats
        
        return Response(data)
    
    def _calculate_transaction_impact(self, transaction):
        from ..services import calculate_summary
        
        summary = calculate_summary(transaction.user)
        total_income = float(summary.get('total_income', 0))
        
        if total_income == 0:
            return {
                'tps_impact': 0,
                'rdr_impact': 0,
                'message': 'Sem receitas registradas para calcular impacto',
            }
        
        amount = float(transaction.amount)
        
        tps_impact = 0
        if transaction.type == Transaction.TransactionType.INCOME:
            tps_impact = (amount / (total_income + amount)) * 100
        elif transaction.type == Transaction.TransactionType.EXPENSE:
            tps_impact = -(amount / total_income) * 100
        
        rdr_impact = 0
        if transaction.type == Transaction.TransactionType.EXPENSE and transaction.is_recurring:
            rdr_impact = (amount / total_income) * 100
        
        return {
            'tps_impact': round(tps_impact, 2),
            'rdr_impact': round(rdr_impact, 2),
            'message': 'Impacto estimado nos indicadores',
        }
    
    def _get_transaction_stats(self, transaction):
        from django.db.models import Avg, Count, Sum
        
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
        """
        from ..ai_services import suggest_category
        
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
                    'confidence': 0.90
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
    """
    serializer_class = TransactionLinkSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerPermission]
    
    def get_queryset(self):
        qs = TransactionLink.objects.filter(
            user=self.request.user
        )
        
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
        """
        queryset = self.filter_queryset(self.get_queryset())
        
        links_list = list(queryset)
        source_uuids = {link.source_transaction_uuid for link in links_list}
        target_uuids = {link.target_transaction_uuid for link in links_list}
        
        all_uuids = source_uuids | target_uuids
        transactions_map = {
            tx.id: tx 
            for tx in Transaction.objects.filter(
                id__in=all_uuids
            ).select_related('category')
        }
        
        for link in links_list:
            if link.source_transaction_uuid in transactions_map:
                link._source_transaction_cache = transactions_map[link.source_transaction_uuid]
            if link.target_transaction_uuid in transactions_map:
                link._target_transaction_cache = transactions_map[link.target_transaction_uuid]
        
        page = self.paginate_queryset(links_list)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        
        serializer = self.get_serializer(links_list, many=True)
        return Response(serializer.data)
    
    def create(self, request, *args, **kwargs):
        source_uuid = request.data.get('source_uuid')
        target_uuid = request.data.get('target_uuid')
        
        try:
            source = Transaction.objects.get(id=source_uuid, user=request.user)
            target = Transaction.objects.get(id=target_uuid, user=request.user)
        except Transaction.DoesNotExist:
            return Response(
                {'error': 'Transação não encontrada'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        source_before = source.available_amount
        target_before = target.available_amount
        
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        
        source.refresh_from_db()
        target.refresh_from_db()
        
        source_after = source.available_amount
        target_after = target.available_amount
        
        is_complete = target.available_amount == 0
        
        suggestions = []
        if source_after > 0:
            fmt_source = f"{source_after:,.2f}".replace(',', 'X').replace('.', ',').replace('X', '.')
            suggestions.append(f"Você ainda tem R$ {fmt_source} disponíveis nesta receita")
        
        if not is_complete:
            fmt_target = f"{target_after:,.2f}".replace(',', 'X').replace('.', ',').replace('X', '.')
            suggestions.append(f"Faltam R$ {fmt_target} para quitar esta despesa")
        else:
            suggestions.append("Despesa quitada com sucesso!")
            
        headers = self.get_success_headers(serializer.data)
        return Response({
            'success': True,
            'payment': serializer.data,
            'impact': {
                'source': {
                    'id': str(source.id),
                    'description': source.description,
                    'before': float(source_before),
                    'after': float(source_after),
                    'difference': float(source_before - source_after),
                },
                'target': {
                    'id': str(target.id),
                    'description': target.description,
                    'before': float(target_before),
                    'after': float(target_after),
                    'difference': float(target_before - target_after),
                    'fully_paid': is_complete,
                },
            },
            'next_suggestions': suggestions,
        }, status=status.HTTP_201_CREATED, headers=headers)
    
    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
        invalidate_user_dashboard_cache(self.request.user)
    
    def perform_update(self, serializer):
        serializer.save()
        invalidate_user_dashboard_cache(self.request.user)
    
    def perform_destroy(self, instance):
        user = instance.user
        instance.delete()
        invalidate_user_dashboard_cache(user)
    
    @action(detail=False, methods=['get'])
    def available_sources(self, request):
        """Lista receitas que ainda têm saldo disponível."""
        min_amount = request.query_params.get('min_amount', 0)
        
        transactions = Transaction.objects.filter(
            user=request.user,
            type=Transaction.TransactionType.INCOME
        ).select_related('category')
        
        category_id = request.query_params.get('category')
        if category_id:
            transactions = transactions.filter(category_id=category_id)
        
        available = [tx for tx in transactions if tx.available_amount > Decimal(min_amount)]
        
        serializer = TransactionSerializer(available, many=True, context={'request': request})
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def available_targets(self, request):
        """Lista despesas que ainda têm saldo pendente de pagamento."""
        transactions = Transaction.objects.filter(
            user=request.user,
            type=Transaction.TransactionType.EXPENSE
        ).select_related('category')
        
        category_id = request.query_params.get('category')
        if category_id:
            transactions = transactions.filter(category_id=category_id)
        
        max_amount = request.query_params.get('max_amount')
        available = [
            tx for tx in transactions 
            if tx.available_amount > 0 and (not max_amount or tx.available_amount <= Decimal(max_amount))
        ]
        
        serializer = TransactionSerializer(available, many=True, context={'request': request})
        return Response(serializer.data)
    
    @action(detail=False, methods=['post'])
    def quick_link(self, request):
        """Criar vinculação rapidamente com validações."""
        serializer = self.get_serializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        link = serializer.save()
        
        return Response(
            TransactionLinkSerializer(link, context={'request': request}).data,
            status=status.HTTP_201_CREATED
        )
    
    @action(detail=False, methods=['get'])
    def payment_report(self, request):
        """Gera relatório de pagamentos de dívidas por período."""
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
        
        category_id = request.query_params.get('category')
        if category_id:
            links = links.filter(target_transaction__category_id=category_id)
        
        links_list = list(links)
        source_uuids = {link.source_transaction_uuid for link in links_list}
        target_uuids = {link.target_transaction_uuid for link in links_list}
        all_uuids = source_uuids | target_uuids
        
        transactions_map = {
            tx.id: tx 
            for tx in Transaction.objects.filter(id__in=all_uuids)
        }
        
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
        
        for link in links_list:
            debt = transactions_map.get(link.target_transaction_uuid)
            if not debt:
                continue
                
            debt_id = debt.id
            
            if by_debt[debt_id]['debt_id'] is None:
                by_debt[debt_id]['debt_id'] = debt_id
                by_debt[debt_id]['debt_description'] = debt.description
                by_debt[debt_id]['total_amount'] = debt.amount
            
            by_debt[debt_id]['paid_amount'] += link.linked_amount
            total_paid += link.linked_amount
            
            source = transactions_map.get(link.source_transaction_uuid)
            by_debt[debt_id]['payments'].append({
                'id': link.id,
                'amount': float(link.linked_amount),
                'date': link.created_at.isoformat(),
                'source': source.description if source else 'N/A'
            })
        
        total_remaining = Decimal('0')
        for debt_data in by_debt.values():
            debt_data['remaining_amount'] = debt_data['total_amount'] - debt_data['paid_amount']
            total_remaining += debt_data['remaining_amount']
            
            if debt_data['total_amount'] > 0:
                debt_data['payment_percentage'] = float(
                    (debt_data['paid_amount'] / debt_data['total_amount']) * Decimal('100')
                )
            
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
        """Retorna resumo de despesas pendentes com análise de urgência."""
        from django.utils import timezone
        
        min_remaining = Decimal(request.query_params.get('min_remaining', '0.01'))
        sort_by = request.query_params.get('sort_by', 'urgency')
        
        debts = Transaction.objects.filter(
            user=request.user
        ).filter(
            Q(type=Transaction.TransactionType.EXPENSE)
        ).select_related('category')
        
        pending_debts = []
        total_pending = Decimal('0')
        urgent_count = 0
        
        for debt in debts:
            remaining = debt.available_amount
            if remaining < min_remaining:
                continue
            
            payment_pct = float(debt.link_percentage)
            is_urgent = payment_pct >= 80
            from django.utils import timezone as tz
            days_since = (tz.now() - debt.created_at).days
            
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
        
        if sort_by == 'urgency':
            pending_debts.sort(
                key=lambda x: (-int(x['is_urgent']), -x['remaining_amount'])
            )
        elif sort_by == 'amount':
            pending_debts.sort(key=lambda x: -x['remaining_amount'])
        elif sort_by == 'date':
            pending_debts.sort(key=lambda x: x['created_at'], reverse=True)
        
        incomes = Transaction.objects.filter(
            user=request.user,
            type=Transaction.TransactionType.INCOME
        )
        
        available_income = sum(
            (income.available_amount for income in incomes),
            Decimal('0')
        )
        
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
        """Cria múltiplas vinculações de pagamento de uma vez."""
        from uuid import UUID
        
        from ..payment_validator import PaymentValidator
        
        payments_data = request.data.get('payments', [])
        description = request.data.get('description', 'Pagamento em lote')
        
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
                            f"Pagamento #{idx+1} inválido: faltam campos obrigatórios"
                        )
                    
                    try:
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
                            f"Pagamento #{idx+1}: valor deve ser positivo"
                        )
                    
                    if amount > Decimal('999999999.99'):
                        raise ValueError(
                            f"Pagamento #{idx+1}: valor muito alto"
                        )
                
                for idx, payment in enumerate(payments_data):
                    source_id = payment.get('source_id')
                    target_id = payment.get('target_id')
                    amount = Decimal(str(payment.get('amount')))
                    
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
                            f"Pagamento #{idx+1}: transação não encontrada"
                        )
                    
                    validator = PaymentValidator(request.user)
                    is_valid, errors = validator.validate_payment(source, target, amount)
                    
                    if not is_valid:
                        error_messages = [f"{k}: {v}" for k, v in errors.items()]
                        raise ValueError(
                            f"Pagamento #{idx+1}: {'; '.join(error_messages)}"
                        )
                    
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
                    
                    target.refresh_from_db()
                    if target.available_amount == 0:
                        fully_paid_expenses.append(str(target_id))
                
                invalidate_user_dashboard_cache(request.user)
            
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
