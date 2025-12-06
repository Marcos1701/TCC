
from rest_framework.throttling import UserRateThrottle


class BurstRateThrottle(UserRateThrottle):
    rate = '30/minute'
    scope = 'burst'


class TransactionCreateThrottle(UserRateThrottle):
    rate = '100/hour'
    scope = 'transaction_create'


class CategoryCreateThrottle(UserRateThrottle):
    rate = '20/hour'
    scope = 'category_create'


class LinkCreateThrottle(UserRateThrottle):
    rate = '50/hour'
    scope = 'link_create'


class DashboardRefreshThrottle(UserRateThrottle):
    rate = '300/hour'
    scope = 'dashboard_refresh'


class SensitiveOperationThrottle(UserRateThrottle):
    rate = '10/hour'
    scope = 'sensitive'


CRITICAL_THROTTLES = [BurstRateThrottle, TransactionCreateThrottle]
MODERATE_THROTTLES = [BurstRateThrottle, CategoryCreateThrottle]
LIGHT_THROTTLES = [BurstRateThrottle]

