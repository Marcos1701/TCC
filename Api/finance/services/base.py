
from __future__ import annotations

import logging
from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Any, Dict, Iterable, List, Tuple

from dateutil.relativedelta import relativedelta
from django.db.models import (
    Avg,
    Case,
    Count,
    DecimalField,
    F,
    Max,
    Min,
    Q,
    Sum,
    Value,
    When,
)
from django.db.models.functions import Coalesce, TruncMonth
from django.utils import timezone

from ..models import Category, Mission, MissionProgress, Transaction, UserProfile

logger = logging.getLogger(__name__)


def _decimal(value) -> Decimal:
    if isinstance(value, Decimal):
        return value
    return Decimal(value or 0)


def _xp_threshold(level: int) -> int:
    return 150 + (level - 1) * 50


__all__ = [
    'Any',
    'Dict',
    'Iterable',
    'List',
    'Tuple',
    'date',
    'datetime',
    'timedelta',
    'relativedelta',
    'timezone',
    'Decimal',
    '_decimal',
    '_xp_threshold',
    'defaultdict',
    'Avg',
    'Case',
    'Coalesce',
    'Count',
    'DecimalField',
    'F',
    'Max',
    'Min',
    'Q',
    'Sum',
    'TruncMonth',
    'Value',
    'When',
    'Category',
    'Mission',
    'MissionProgress',
    'Transaction',
    'UserProfile',
    'logger',
]
