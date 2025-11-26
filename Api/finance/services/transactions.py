from __future__ import annotations

from decimal import Decimal

from django.db.models import Sum

from ..models import Transaction, TransactionLink
from .base import logger
from .indicators import invalidate_indicators_cache


def auto_link_recurring_transactions(user) -> int:
    """
    Vincula automaticamente transações recorrentes baseado em configuração.
    
    Lógica:
    1. Buscar todos os TransactionLinks com is_recurring=True do usuário
    2. Para cada link recorrente, verificar se existem novas instâncias
    3. Criar links automáticos entre as novas instâncias
    
    Returns:
        Número de links criados automaticamente
    """
    links_created = 0
    
    recurring_links = TransactionLink.objects.filter(
        user=user,
        is_recurring=True
    )
    
    for link in recurring_links:
        source = link.source_transaction
        target = link.target_transaction
        
        if not (source.is_recurring and target.is_recurring):
            continue
        
        if source.recurrence_unit == Transaction.RecurrenceUnit.DAYS:
            delta_days = source.recurrence_value
        elif source.recurrence_unit == Transaction.RecurrenceUnit.WEEKS:
            delta_days = source.recurrence_value * 7
        elif source.recurrence_unit == Transaction.RecurrenceUnit.MONTHS:
            delta_days = source.recurrence_value * 30
        else:
            continue
        
        next_sources = Transaction.objects.filter(
            user=user,
            type=source.type,
            category=source.category,
            description=source.description,
            amount=source.amount,
            date__gt=source.date,
            is_recurring=True,
        ).exclude(
            id__in=TransactionLink.objects.filter(
                user=user,
                link_type=link.link_type
            ).values_list('source_transaction_uuid', flat=True)
        )
        
        next_targets = Transaction.objects.filter(
            user=user,
            category=target.category,
            description=target.description,
            amount=target.amount,
            date__gt=target.date,
            is_recurring=True,
        ).exclude(
            id__in=TransactionLink.objects.filter(
                user=user,
                link_type=link.link_type
            ).values_list('target_transaction_uuid', flat=True)
        )
        
        for next_source in next_sources[:1]:
            for next_target in next_targets[:1]:
                if next_source.available_amount >= link.linked_amount:
                    if next_target.available_amount >= link.linked_amount:
                        try:
                            TransactionLink.objects.create(
                                user=user,
                                source_transaction=next_source,
                                target_transaction=next_target,
                                linked_amount=link.linked_amount,
                                link_type=link.link_type,
                                description=f"Auto: {link.description}" if link.description else "Vinculação automática recorrente",
                                is_recurring=True
                            )
                            links_created += 1
                        except Exception as e:
                            logger.error(f"Erro ao criar link automático: {e}")
                            continue
    
    if links_created > 0:
        invalidate_indicators_cache(user)
    
    return links_created
