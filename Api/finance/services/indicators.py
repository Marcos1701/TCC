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
    
    today = timezone.now().date()
    start_date = today.replace(day=1)  # Calendar Month (1st of current month)
    
    # total_aportes is always calculated (not cached)
    total_aportes = _decimal(
        Transaction.objects.filter(
            user=user,
            type=Transaction.TransactionType.EXPENSE,
            date__gte=start_date,
            date__lte=today,
            category__group__in=[
                Category.CategoryGroup.SAVINGS,
                Category.CategoryGroup.INVESTMENT
            ]
        ).aggregate(total=Coalesce(Sum('amount'), Decimal("0")))['total']
    )
    
    if not profile.should_recalculate_indicators():
        # Check if there are essential expenses for the cached period
        has_essential = Transaction.objects.filter(
            user=user,
            category__group=Category.CategoryGroup.ESSENTIAL_EXPENSE,
            type=Transaction.TransactionType.EXPENSE,
            date__gte=start_date,
            date__lte=today,
        ).exists()
        
        return {
            "tps": profile.cached_tps or Decimal("0.00"),
            "rdr": profile.cached_rdr or Decimal("0.00"),
            "ili": profile.cached_ili or Decimal("0.00"),
            "total_income": profile.cached_total_income or Decimal("0.00"),
            "total_expense": profile.cached_total_expense or Decimal("0.00"),
            "total_aportes": total_aportes.quantize(Decimal("0.01")),
            "has_essential_expenses": has_essential,
        }
    
    today = timezone.now().date()
    start_date = today.replace(day=1)  # Calendar Month (1st of current month)
    
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
        ).exclude(
            category__group__in=[
                Category.CategoryGroup.SAVINGS,
                Category.CategoryGroup.INVESTMENT
            ]
        ).aggregate(total=Coalesce(Sum('amount'), Decimal("0")))['total']
    )

    total_aportes = _decimal(
        Transaction.objects.filter(
            user=user,
            type=Transaction.TransactionType.EXPENSE,
            date__gte=start_date,
            date__lte=today,
            category__group__in=[
                Category.CategoryGroup.SAVINGS,
                Category.CategoryGroup.INVESTMENT
            ]
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
            link_type=TransactionLink.LinkType.EXPENSE_PAYMENT
        ).aggregate(total=Coalesce(Sum('linked_amount'), Decimal("0")))['total']
    )
    
    reserve_transactions = Transaction.objects.filter(
        user=user, 
        category__group__in=[
            Category.CategoryGroup.SAVINGS,
            Category.CategoryGroup.INVESTMENT
        ]
    ).values("type").annotate(total=Sum("amount"))
    
    reserve_deposits = Decimal("0")
    reserve_withdrawals = Decimal("0")
    
    for item in reserve_transactions:
        tx_type = item["type"]
        total = _decimal(item["total"])
        if tx_type == Transaction.TransactionType.EXPENSE:
            reserve_deposits += total
        elif tx_type == Transaction.TransactionType.INCOME:
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
        "total_aportes": total_aportes.quantize(Decimal("0.01")),
        "has_essential_expenses": essential_expense > 0,
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

    def _ili_status(value: Decimal, has_essential: bool) -> Dict[str, str]:
        numero = float(value)
        alvo = float(profile.target_ili)
        
        # Informative message when no essential expenses are registered
        if not has_essential:
            return {
                "severity": "info",
                "title": "Sem despesas essenciais",
                "message": "Registre despesas em categorias essenciais (Alimentação, Moradia, Transporte, Saúde) para calcular sua reserva de emergência.",
            }
        
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
    has_essential_expenses = summary.get("has_essential_expenses", True)

    tps_info = _tps_status(tps_value)
    rdr_info = _rdr_status(rdr_value)
    ili_info = _ili_status(ili_value, has_essential_expenses)

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
        group = item.get("category__group")
        cat_type = item["category__type"]
        
        # Separate APORTES (SAVINGS/INVESTMENT expenses) from regular expenses
        if cat_type == Transaction.TransactionType.EXPENSE and group in [
            Category.CategoryGroup.SAVINGS,
            Category.CategoryGroup.INVESTMENT
        ]:
            bucket_key = "APORTES"
        else:
            bucket_key = cat_type
            
        buckets[bucket_key].append(
            {
                "name": item["category__name"],
                "group": group or Category.CategoryGroup.OTHER,
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
        .values("month", "type", "category__group")
        .annotate(total=Sum("amount"))
    )

    buckets: Dict[date, Dict[str, Decimal]] = defaultdict(lambda: defaultdict(Decimal))
    for item in data:
        month_value = item["month"]
        if isinstance(month_value, datetime):
            month = month_value.date()
        else:
            month = month_value
        
        # Track aportes separately from regular expenses
        if item["type"] == Transaction.TransactionType.EXPENSE and item.get("category__group") in [Category.CategoryGroup.SAVINGS, Category.CategoryGroup.INVESTMENT]:
            buckets[month]["APORTES"] += _decimal(item["total"])
        else:
            buckets[month][item["type"]] += _decimal(item["total"])

    recurrence_projections: Dict[date, Dict[str, Decimal]] = defaultdict(lambda: defaultdict(Decimal))
    
    from django.db.models import Q
    from django.db.models.functions import ExtractYear, ExtractMonth
    
    active_recurrences = Transaction.objects.filter(
        user=user,
        is_recurring=True,
    ).filter(
        Q(recurrence_end_date__isnull=True) | Q(recurrence_end_date__gte=now)
    ).select_related('category')
    
    for transaction in active_recurrences:
        projection_month = current_month
        for _ in range(3):
            projection_month = projection_month + timedelta(days=32)
            projection_month = projection_month.replace(day=1)
            
            # Track aportes separately in projections
            if transaction.type == Transaction.TransactionType.EXPENSE and transaction.category and transaction.category.group in [Category.CategoryGroup.SAVINGS, Category.CategoryGroup.INVESTMENT]:
                recurrence_projections[projection_month]["APORTES"] += transaction.amount
                continue

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

    # Get IDs of potential source transactions in the date range
    source_tx_qs = Transaction.objects.filter(
        user=user,
        date__gte=first_day,
        date__lte=now
    ).values('id', 'date')
    
    # Create a map of transaction ID to date for easy lookup
    tx_date_map = {tx['id']: tx['date'] for tx in source_tx_qs}
    
    # Query links that match these source transactions
    links_by_month = {}
    if tx_date_map:
        all_links = (
            TransactionLink.objects.filter(
                user=user,
                source_transaction_uuid__in=tx_date_map.keys()
            )
            .values('source_transaction_uuid', 'linked_amount')
        )
        
        for link in all_links:
            tx_id = link['source_transaction_uuid']
            amount = link['linked_amount']
            # We already know the date from our map
            if tx_id in tx_date_map:
                tx_date = tx_date_map[tx_id]
                key = (tx_date.year, tx_date.month)
                links_by_month[key] = links_by_month.get(key, Decimal("0")) + _decimal(amount)

    series: List[Dict[str, str]] = []
    current = first_day
    
    end_month = current_month + timedelta(days=100)
    while current <= end_month:
        is_future = current > current_month
        
        if is_future:
            income = recurrence_projections[current].get(Transaction.TransactionType.INCOME, Decimal("0"))
            expense = recurrence_projections[current].get(Transaction.TransactionType.EXPENSE, Decimal("0"))
            aportes = recurrence_projections[current].get("APORTES", Decimal("0"))
        else:
            income = buckets[current].get(Transaction.TransactionType.INCOME, Decimal("0"))
            expense = buckets[current].get(Transaction.TransactionType.EXPENSE, Decimal("0"))
            aportes = buckets[current].get("APORTES", Decimal("0"))
        
        tps = Decimal("0")
        if income > 0:
            savings = income - expense
            tps = (savings / income) * Decimal("100")
        
        rdr = Decimal("0")
        if income > 0:
            if is_future:
                recurring_debt = recurrence_projections[current].get(Transaction.TransactionType.EXPENSE, Decimal("0"))
            else:
                recurring_debt = links_by_month.get((current.year, current.month), Decimal("0"))
            
            rdr = (recurring_debt / income) * Decimal("100")
        
        if income > 0 or expense > 0 or aportes > 0:
            series.append(
                {
                    "month": current.strftime("%Y-%m"),
                    "income": income.quantize(Decimal("0.01")),
                    "expense": expense.quantize(Decimal("0.01")),
                    "aportes": aportes.quantize(Decimal("0.01")),
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
