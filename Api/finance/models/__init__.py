"""
Pacote de modelos do app finance.

Este arquivo exporta todos os modelos para manter compatibilidade com imports existentes.
"""

from .base import (
    MAX_AMOUNT,
    MAX_LEVEL,
    MIN_LEVEL,
    CACHE_EXPIRATION_SECONDS,
    MAX_RECURRENCE_VALUE,
    MAX_DESCRIPTION_LENGTH,
    MAX_TITLE_LENGTH,
    MAX_CATEGORY_NAME_LENGTH,
    MAX_DURATION_DAYS,
    MAX_REWARD_POINTS,
    MAX_DEADLINE_YEARS,
    MAX_FUTURE_DATE_YEARS,
)

from .user import UserProfile

from .category import Category

from .transaction import Transaction, TransactionLink

from .goal import Goal

from .mission import Mission, MissionProgress

from .admin import XPTransaction, AdminActionLog


__all__ = [
    # Constantes
    'MAX_AMOUNT',
    'MAX_LEVEL',
    'MIN_LEVEL',
    'CACHE_EXPIRATION_SECONDS',
    'MAX_RECURRENCE_VALUE',
    'MAX_DESCRIPTION_LENGTH',
    'MAX_TITLE_LENGTH',
    'MAX_CATEGORY_NAME_LENGTH',
    'MAX_DURATION_DAYS',
    'MAX_REWARD_POINTS',
    'MAX_DEADLINE_YEARS',
    'MAX_FUTURE_DATE_YEARS',
    # Modelos
    'UserProfile',
    'Category',
    'Transaction',
    'TransactionLink',
    'Goal',
    'Mission',
    'MissionProgress',
    'XPTransaction',
    'AdminActionLog',
]
