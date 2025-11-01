from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Dict, Iterable, List

from django.db.models import Case, DecimalField, F, Sum, When
from django.db.models.functions import Coalesce, TruncMonth
from django.utils import timezone

from .models import Category, Mission, MissionProgress, Transaction, UserProfile


def _decimal(value) -> Decimal:
    if isinstance(value, Decimal):
        return value
    return Decimal(value or 0)


def _debt_components(user) -> Dict[str, Decimal]:
    debt_qs = Transaction.objects.filter(user=user, category__type=Category.CategoryType.DEBT)
    increases = _decimal(
        debt_qs.filter(type=Transaction.TransactionType.EXPENSE).aggregate(
            total=Coalesce(Sum("amount"), Decimal("0"))
        )["total"]
    )
    payments = _decimal(
        debt_qs.filter(type=Transaction.TransactionType.DEBT_PAYMENT).aggregate(
            total=Coalesce(Sum("amount"), Decimal("0"))
        )["total"]
    )
    adjustments = _decimal(
        debt_qs.filter(type=Transaction.TransactionType.INCOME).aggregate(
            total=Coalesce(Sum("amount"), Decimal("0"))
        )["total"]
    )

    balance = increases - payments - adjustments
    return {
        "increases": increases,
        "payments": payments,
        "adjustments": adjustments,
        "balance": balance,
    }


def calculate_summary(user) -> Dict[str, Decimal]:
    totals = defaultdict(Decimal)
    for entry in (
        Transaction.objects.filter(user=user)
        .values("type")
        .annotate(total=Sum("amount"))
    ):
        totals[entry["type"]] = _decimal(entry["total"])

    income = totals.get(Transaction.TransactionType.INCOME, Decimal("0"))
    expense = totals.get(Transaction.TransactionType.EXPENSE, Decimal("0"))
    debt_info = _debt_components(user)
    debt_balance = debt_info["balance"]
    debt_payments = debt_info["payments"]

    reserve_income = Decimal("0")
    reserve_expense = Decimal("0")
    for item in (
        Transaction.objects.filter(user=user, category__group=Category.CategoryGroup.SAVINGS)
        .values("type")
        .annotate(total=Sum("amount"))
    ):
        tx_type = item["type"]
        total = _decimal(item["total"])
        if tx_type == Transaction.TransactionType.EXPENSE:
            reserve_expense = total
        elif tx_type == Transaction.TransactionType.INCOME:
            reserve_income = total

    today = timezone.now().date()
    month_start = today.replace(day=1)
    essential_expense = _decimal(
        Transaction.objects.filter(
            user=user,
            category__group=Category.CategoryGroup.ESSENTIAL_EXPENSE,
            type=Transaction.TransactionType.EXPENSE,
            date__gte=month_start,
            date__lte=today,
        ).aggregate(total=Sum("amount"))["total"]
    )

    tps = Decimal("0")
    rdr = Decimal("0")
    ili = Decimal("0")
    if income > 0:
        poupanca = income - expense
        tps = (poupanca / income) * Decimal("100")
        debt_reference = debt_balance if debt_balance > 0 else debt_payments
        if debt_reference > 0:
            rdr = (debt_reference / income) * Decimal("100")

    reserve_balance = reserve_income - reserve_expense
    if essential_expense > 0:
        ili = reserve_balance / essential_expense

    debt_total = debt_balance if debt_balance > 0 else Decimal("0")

    return {
        "tps": tps.quantize(Decimal("0.01")) if income > 0 else Decimal("0.00"),
        "rdr": rdr.quantize(Decimal("0.01")) if income > 0 else Decimal("0.00"),
        "ili": ili.quantize(Decimal("0.01")) if essential_expense > 0 else Decimal("0.00"),
        "total_income": income.quantize(Decimal("0.01")),
        "total_expense": expense.quantize(Decimal("0.01")),
        "total_debt": debt_total.quantize(Decimal("0.01")),
    }


def category_breakdown(user) -> Dict[str, List[Dict[str, str]]]:
    buckets: Dict[str, List[Dict[str, str]]] = defaultdict(list)
    queryset = (
        Transaction.objects.filter(user=user, category__isnull=False)
        .annotate(
            signed_amount=Case(
                When(
                    category__type=Category.CategoryType.DEBT,
                    type__in=[
                        Transaction.TransactionType.DEBT_PAYMENT,
                        Transaction.TransactionType.INCOME,
                    ],
                    then=-F("amount"),
                ),
                default=F("amount"),
                output_field=DecimalField(max_digits=12, decimal_places=2),
            )
        )
        .values("category__name", "category__type", "category__group")
        .annotate(total=Coalesce(Sum("signed_amount"), Decimal("0")))
        .order_by("category__name")
    )

    for item in queryset:
        total_value = _decimal(item["total"])
        if item["category__type"] == Category.CategoryType.DEBT:
            total_value = max(total_value, Decimal("0"))
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

    debt_data = (
        Transaction.objects.filter(
            user=user,
            category__type=Category.CategoryType.DEBT,
            date__gte=first_day,
        )
        .annotate(month=TruncMonth("date"))
        .values("month", "type")
        .annotate(total=Sum("amount"))
    )

    debt_buckets: Dict[date, Dict[str, Decimal]] = defaultdict(lambda: defaultdict(Decimal))
    for item in debt_data:
        month_value = item["month"]
        if isinstance(month_value, datetime):
            month = month_value.date()
        else:
            month = month_value
        debt_buckets[month][item["type"]] += _decimal(item["total"])

    series: List[Dict[str, str]] = []
    current = now.replace(day=1)
    for _ in range(months):
        income = buckets[current].get(Transaction.TransactionType.INCOME, Decimal("0"))
        expense = buckets[current].get(Transaction.TransactionType.EXPENSE, Decimal("0"))
        debt_increase = debt_buckets[current].get(Transaction.TransactionType.EXPENSE, Decimal("0"))
        debt_payment = debt_buckets[current].get(Transaction.TransactionType.DEBT_PAYMENT, Decimal("0"))
        debt_adjustment = debt_buckets[current].get(Transaction.TransactionType.INCOME, Decimal("0"))
        debt = debt_increase - debt_payment - debt_adjustment
        if debt < 0:
            debt = Decimal("0")
        tps = Decimal("0")
        rdr = Decimal("0")
        if income > 0:
            poupanca = income - expense
            tps = (poupanca / income) * Decimal("100")
            debt_reference = debt if debt > 0 else debt_payment
            if debt_reference > 0:
                rdr = (debt_reference / income) * Decimal("100")
        series.append(
            {
                "month": current.strftime("%Y-%m"),
                "income": income.quantize(Decimal("0.01")),
                "expense": expense.quantize(Decimal("0.01")),
                "debt": debt.quantize(Decimal("0.01")),
                "tps": tps.quantize(Decimal("0.01")) if income > 0 else Decimal("0.00"),
                "rdr": rdr.quantize(Decimal("0.01")) if income > 0 else Decimal("0.00"),
            }
        )
        if current.month == 1:
            current = current.replace(year=current.year - 1, month=12)
        else:
            current = current.replace(month=current.month - 1)
    series.reverse()
    return series


def _xp_threshold(level: int) -> int:
    return 150 + (level - 1) * 50


def apply_mission_reward(progress: MissionProgress) -> None:
    profile: UserProfile = progress.user.userprofile
    profile.experience_points += progress.mission.reward_points

    while profile.experience_points >= _xp_threshold(profile.level):
        profile.experience_points -= _xp_threshold(profile.level)
        profile.level += 1
    profile.save(update_fields=["experience_points", "level"])


def profile_snapshot(user) -> Dict[str, int]:
    profile, _ = UserProfile.objects.get_or_create(user=user)
    return {
        "level": profile.level,
        "experience_points": profile.experience_points,
        "next_level_threshold": profile.next_level_threshold,
        "target_tps": profile.target_tps,
        "target_rdr": profile.target_rdr,
        "target_ili": profile.target_ili,
    }


def indicator_insights(summary: Dict[str, Decimal], profile: UserProfile) -> Dict[str, Dict[str, str]]:
    """Gera dicas alinhadas às faixas descritas no texto."""

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


def recommend_missions(user, summary: Dict[str, Decimal]) -> Iterable[Mission]:
    user_tps = summary.get("tps", Decimal("0"))
    user_rdr = summary.get("rdr", Decimal("0"))
    user_ili = summary.get("ili", Decimal("0"))

    already_linked = set(
        MissionProgress.objects.filter(user=user).values_list("mission_id", flat=True)
    )

    base_queryset = Mission.objects.filter(is_active=True).exclude(id__in=already_linked)

    selected: List[Mission] = []
    for mission in base_queryset:
        match_tps = mission.target_tps is None or user_tps < Decimal(mission.target_tps)
        match_rdr = mission.target_rdr is None or user_rdr > Decimal(mission.target_rdr)
        match_ili = True
        if mission.min_ili is not None and user_ili < mission.min_ili:
            match_ili = False
        if mission.max_ili is not None and user_ili > mission.max_ili:
            match_ili = False
        if match_tps and match_rdr and match_ili:
            selected.append(mission)

    if not selected:
        selected = list(base_queryset[:3])

    return selected[:3]
