from __future__ import annotations

from collections import defaultdict
from datetime import date, timedelta
from decimal import Decimal
from typing import Dict, Iterable, List

from django.db.models import Sum
from django.db.models.functions import TruncMonth
from django.utils import timezone

from .models import Mission, MissionProgress, Transaction, UserProfile


def _decimal(value) -> Decimal:
    if isinstance(value, Decimal):
        return value
    return Decimal(value or 0)


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
    debt = totals.get(Transaction.TransactionType.DEBT_PAYMENT, Decimal("0"))

    tps = Decimal("0")
    rdr = Decimal("0")
    if income > 0:
        poupanca = income - expense
        tps = (poupanca / income) * Decimal("100")
        base_debt = debt if debt > 0 else expense
        rdr = (base_debt / income) * Decimal("100")

    return {
        "tps": tps.quantize(Decimal("0.01")) if income > 0 else Decimal("0.00"),
        "rdr": rdr.quantize(Decimal("0.01")) if income > 0 else Decimal("0.00"),
        "total_income": income.quantize(Decimal("0.01")),
        "total_expense": expense.quantize(Decimal("0.01")),
        "total_debt": debt.quantize(Decimal("0.01")),
    }


def category_breakdown(user) -> Dict[str, List[Dict[str, str]]]:
    buckets: Dict[str, List[Dict[str, str]]] = defaultdict(list)
    queryset = (
        Transaction.objects.filter(user=user, category__isnull=False)
        .values("category__name", "category__type")
        .annotate(total=Sum("amount"))
        .order_by("category__name")
    )

    for item in queryset:
        buckets[item["category__type"]].append(
            {
                "name": item["category__name"],
                "total": _decimal(item["total"]).quantize(Decimal("0.01")),
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
        month = item["month"].date()
        buckets[month][item["type"]] += _decimal(item["total"])

    series: List[Dict[str, str]] = []
    current = now.replace(day=1)
    for _ in range(months):
        income = buckets[current].get(Transaction.TransactionType.INCOME, Decimal("0"))
        expense = buckets[current].get(Transaction.TransactionType.EXPENSE, Decimal("0"))
        series.append(
            {
                "month": current.strftime("%Y-%m"),
                "income": income.quantize(Decimal("0.01")),
                "expense": expense.quantize(Decimal("0.01")),
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
    profile = user.userprofile
    return {
        "level": profile.level,
        "experience_points": profile.experience_points,
        "next_level_threshold": profile.next_level_threshold,
        "target_tps": profile.target_tps,
        "target_rdr": profile.target_rdr,
    }


def recommend_missions(user, summary: Dict[str, Decimal]) -> Iterable[Mission]:
    user_tps = summary.get("tps", Decimal("0"))
    user_rdr = summary.get("rdr", Decimal("0"))

    already_linked = set(
        MissionProgress.objects.filter(user=user).values_list("mission_id", flat=True)
    )

    base_queryset = Mission.objects.filter(is_active=True).exclude(id__in=already_linked)

    selected: List[Mission] = []
    for mission in base_queryset:
        match_tps = mission.target_tps is None or user_tps < Decimal(mission.target_tps)
        match_rdr = mission.target_rdr is None or user_rdr > Decimal(mission.target_rdr)
        if match_tps and match_rdr:
            selected.append(mission)

    if not selected:
        selected = list(base_queryset[:3])

    return selected[:3]
