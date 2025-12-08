from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Any, Dict, List

from dateutil.relativedelta import relativedelta
from django.db.models import Sum
from django.db.models.functions import Coalesce, TruncMonth
from django.utils import timezone

from ..models import Category, Transaction, TransactionLink, UserProfile
from .base import _decimal, logger


def calculate_summary(user) -> Dict[str, Decimal]:
    profile, _ = UserProfile.objects.get_or_create(user=user)
    if not profile.should_recalculate_indicators():
        return {
            "tps": profile.cached_tps or Decimal("0.00"),
            "rdr": profile.cached_rdr or Decimal("0.00"),
            "ili": profile.cached_ili or Decimal("0.00"),
            "total_income": profile.cached_total_income or Decimal("0.00"),
            "total_expense": profile.cached_total_expense or Decimal("0.00"),
        }
    
    today = timezone.now().date()
    start_date = today - timedelta(days=30)
    
    total_income = _decimal(
        Transaction.objects.filter(
            user=user,
            type=Transaction.TransactionType.INCOME,
            date__gte=start_date,
            date__lte=today
        ).aggregate(total=Coalesce(Sum('amount'), Decimal("0")))['total']
    )

    total_expense = _decimal(
        Transaction.objects.filter(
            user=user,
            type=Transaction.TransactionType.EXPENSE,
            date__gte=start_date,
            date__lte=today
        ).aggregate(total=Coalesce(Sum('amount'), Decimal("0")))['total']
    )

    source_transaction_ids = Transaction.objects.filter(
        user=user,
        date__gte=start_date,
        date__lte=today
    ).values_list('id', flat=True)
    
    debt_payments = _decimal(
        TransactionLink.objects.filter(
            user=user,
            source_transaction_uuid__in=source_transaction_ids,
            link_type=TransactionLink.LinkType.EXPENSE_PAYMENT  # FIXED: Only count actual debt payments, exclude savings/transfers
        ).aggregate(total=Coalesce(Sum('linked_amount'), Decimal("0")))['total']
    )
    
    reserve_transactions = Transaction.objects.filter(
        user=user, 
        category__group=Category.CategoryGroup.SAVINGS
    ).values("type").annotate(total=Sum("amount"))
    
    reserve_deposits = Decimal("0")
    reserve_withdrawals = Decimal("0")
    
    for item in reserve_transactions:
        tx_type = item["type"]
        total = _decimal(item["total"])
        if tx_type == Transaction.TransactionType.INCOME:
            reserve_deposits += total
        elif tx_type == Transaction.TransactionType.EXPENSE:
            reserve_withdrawals += total

    reserve_balance = reserve_deposits - reserve_withdrawals

    essential_expense = _decimal(
        Transaction.objects.filter(
            user=user,
            category__group=Category.CategoryGroup.ESSENTIAL_EXPENSE,
            type=Transaction.TransactionType.EXPENSE,
            date__gte=start_date,
            date__lte=today,
        ).aggregate(total=Coalesce(Sum("amount"), Decimal("0")))["total"]
    )

    tps = Decimal("0")
    rdr = Decimal("0")
    ili = Decimal("0")
    
    if total_income > 0:
        savings = total_income - total_expense
        tps = (savings / total_income) * Decimal("100")
        rdr = (debt_payments / total_income) * Decimal("100")
    
    if essential_expense > 0:
        ili = reserve_balance / essential_expense

    profile.cached_tps = tps.quantize(Decimal("0.01")) if total_income > 0 else Decimal("0.00")
    profile.cached_rdr = rdr.quantize(Decimal("0.01")) if total_income > 0 else Decimal("0.00")
    profile.cached_ili = ili.quantize(Decimal("0.01")) if essential_expense > 0 else Decimal("0.00")
    profile.cached_total_income = total_income.quantize(Decimal("0.01"))
    profile.cached_total_expense = total_expense.quantize(Decimal("0.01"))
    profile.indicators_updated_at = timezone.now()
    profile.save(update_fields=[
        'cached_tps',
        'cached_rdr', 
        'cached_ili', 
        'cached_total_income',
        'cached_total_expense',
        'indicators_updated_at'
    ])

    return {
        "tps": profile.cached_tps,
        "rdr": profile.cached_rdr,
        "ili": profile.cached_ili,
        "total_income": profile.cached_total_income,
        "total_expense": profile.cached_total_expense,
    }


def invalidate_indicators_cache(user) -> None:
    try:
        profile = UserProfile.objects.get(user=user)
        profile.indicators_updated_at = None
        profile.save(update_fields=['indicators_updated_at'])
    except UserProfile.DoesNotExist:
        pass


def indicator_insights(summary: Dict[str, Decimal], profile: UserProfile) -> Dict[str, Dict[str, str]]:

    def _quantize(value: Decimal) -> Decimal:
        return value.quantize(Decimal("0.01"))

    def _tps_status(value: Decimal) -> Dict[str, str]:
        numero = float(value)
        if numero >= profile.target_tps:
            return {
                "severity": "good",
                "title": "Boa disciplina",
                "message": "A poupança tá batendo a meta, segue no ritmo.",
            }
        if numero >= 10:
            return {
                "severity": "attention",
                "title": "Quase lá",
                "message": f"Dá pra cortar uns gastos pra chegar nos {profile.target_tps}% esperados.",
            }
        return {
            "severity": "critical",
            "title": "Reserva apertada",
            "message": "Organiza prioridades e tenta separar algo todo mês pra não ficar no sufoco.",
        }

    def _rdr_status(value: Decimal) -> Dict[str, str]:
        numero = float(value)
        if numero <= profile.target_rdr:
            return {
                "severity": "good",
                "title": "Dívidas controladas",
                "message": "Comprometimento da renda tá saudável, mantém as parcelas em dia.",
            }
        if numero <= 42:
            return {
                "severity": "attention",
                "title": "Fica de olho",
                "message": f"Avalia renegociação ou amortização leve pra ficar abaixo dos {profile.target_rdr}%.",
            }
        if numero <= 49:
            return {
                "severity": "warning",
                "title": "Alerta ligado",
                "message": "Boa rever prioridades e conter novos créditos enquanto ajusta as dívidas.",
            }
        return {
            "severity": "critical",
            "title": "Risco alto",
            "message": "Busca renegociar e cortar gastos urgentes pra escapar de inadimplência.",
        }

    def _ili_status(value: Decimal) -> Dict[str, str]:
        numero = float(value)
        alvo = float(profile.target_ili)
        if numero >= alvo:
            return {
                "severity": "good",
                "title": "Reserva sólida",
                "message": "Liquidez cobre vários meses, dá pra pensar em diversificar investimentos.",
            }
        if numero >= 3:
            return {
                "severity": "attention",
                "title": "Cofre em construção",
                "message": "Reserva segura por poucos meses, planeja aportes automáticos pra chegar na meta.",
            }
        return {
            "severity": "critical",
            "title": "Almofada curta",
            "message": "Prioriza formar reserva de emergência pra aguentar imprevistos sem recorrer a crédito.",
        }

    tps_value = summary.get("tps", Decimal("0"))
    rdr_value = summary.get("rdr", Decimal("0"))
    ili_value = summary.get("ili", Decimal("0"))

    tps_info = _tps_status(tps_value)
    rdr_info = _rdr_status(rdr_value)
    ili_info = _ili_status(ili_value)

    return {
        "tps": {
            "value": _quantize(tps_value),
            "target": profile.target_tps,
            **tps_info,
        },
        "rdr": {
            "value": _quantize(rdr_value),
            "target": profile.target_rdr,
            **rdr_info,
        },
        "ili": {
            "value": _quantize(ili_value),
            "target": profile.target_ili.quantize(Decimal("0.01")),
            **ili_info,
        },
    }


def category_breakdown(user) -> Dict[str, List[Dict[str, str]]]:
    buckets: Dict[str, List[Dict[str, str]]] = defaultdict(list)
    queryset = (
        Transaction.objects.filter(user=user, category__isnull=False)
        .values("category__name", "category__type", "category__group")
        .annotate(total=Coalesce(Sum("amount"), Decimal("0")))
        .order_by("category__name")
    )

    for item in queryset:
        total_value = _decimal(item["total"])
        buckets[item["category__type"]].append(
            {
                "name": item["category__name"],
                "group": item.get("category__group") or Category.CategoryGroup.OTHER,
                "total": total_value.quantize(Decimal("0.01")),
            }
        )
    return buckets


def cashflow_series(user, months: int = 6) -> List[Dict[str, str]]:
    now = timezone.now().date()
    current_month = now.replace(day=1)
    first_day = (now.replace(day=1) - timedelta(days=months * 31)).replace(day=1)
    
    data = (
        Transaction.objects.filter(user=user, date__gte=first_day)
        .annotate(month=TruncMonth("date"))
        .values("month", "type")
        .annotate(total=Sum("amount"))
    )

    buckets: Dict[date, Dict[str, Decimal]] = defaultdict(lambda: defaultdict(Decimal))
    for item in data:
        month_value = item["month"]
        if isinstance(month_value, datetime):
            month = month_value.date()
        else:
            month = month_value
        buckets[month][item["type"]] += _decimal(item["total"])

    recurrence_projections: Dict[date, Dict[str, Decimal]] = defaultdict(lambda: defaultdict(Decimal))
    
    from django.db.models import Q
    active_recurrences = Transaction.objects.filter(
        user=user,
        is_recurring=True,
    ).filter(
        Q(recurrence_end_date__isnull=True) | Q(recurrence_end_date__gte=now)
    )
    
    for transaction in active_recurrences:
        projection_month = current_month
        for _ in range(3):
            projection_month = projection_month + timedelta(days=32)
            projection_month = projection_month.replace(day=1)
            
            if transaction.recurrence_unit == Transaction.RecurrenceUnit.MONTHS:
                recurrence_projections[projection_month][transaction.type] += transaction.amount
            elif transaction.recurrence_unit == Transaction.RecurrenceUnit.WEEKS:
                recurrence_projections[projection_month][transaction.type] += transaction.amount * 4
            elif transaction.recurrence_unit == Transaction.RecurrenceUnit.DAYS:
                if transaction.recurrence_value:
                    occurrences_per_month = 30 // transaction.recurrence_value
                    recurrence_projections[projection_month][transaction.type] += transaction.amount * occurrences_per_month
                else:
                    recurrence_projections[projection_month][transaction.type] += transaction.amount * 30

    series: List[Dict[str, str]] = []
    current = first_day
    
    end_month = current_month + timedelta(days=100)
    while current <= end_month:
        is_future = current > current_month
        
        if is_future:
            income = recurrence_projections[current].get(Transaction.TransactionType.INCOME, Decimal("0"))
            expense = recurrence_projections[current].get(Transaction.TransactionType.EXPENSE, Decimal("0"))
        else:
            income = buckets[current].get(Transaction.TransactionType.INCOME, Decimal("0"))
            expense = buckets[current].get(Transaction.TransactionType.EXPENSE, Decimal("0"))
        
        tps = Decimal("0")
        if income > 0:
            savings = income - expense
            tps = (savings / income) * Decimal("100")
        
        rdr = Decimal("0")
        if income > 0:
            if is_future:
                recurring_debt = recurrence_projections[current].get(Transaction.TransactionType.EXPENSE, Decimal("0"))
            else:
                month_transaction_ids = Transaction.objects.filter(
                    user=user,
                    date__year=current.year,
                    date__month=current.month
                ).values_list('id', flat=True)
                
                recurring_debt = TransactionLink.objects.filter(
                    user=user,
                    source_transaction_uuid__in=month_transaction_ids
                ).aggregate(total=Coalesce(Sum('linked_amount'), Decimal("0")))['total'] or Decimal("0")
            
            rdr = (recurring_debt / income) * Decimal("100")
        
        if income > 0 or expense > 0:
            series.append(
                {
                    "month": current.strftime("%Y-%m"),
                    "income": income.quantize(Decimal("0.01")),
                    "expense": expense.quantize(Decimal("0.01")),
                    "tps": tps.quantize(Decimal("0.01")),
                    "rdr": rdr.quantize(Decimal("0.01")),
                    "is_projection": is_future,
                }
            )
        
        if current.month == 12:
            current = current.replace(year=current.year + 1, month=1)
        else:
            current = current.replace(month=current.month + 1)
    
    return series


def profile_snapshot(user) -> Dict[str, int]:
    profile, _ = UserProfile.objects.get_or_create(user=user)
    return {
        "level": profile.level,
        "experience_points": profile.experience_points,
        "next_level_threshold": profile.next_level_threshold,
        "target_tps": profile.target_tps,
        "target_rdr": profile.target_rdr,
        "target_ili": profile.target_ili,
        "is_first_access": profile.is_first_access,
    }
