"""
Throttling customizado para operações sensíveis.
"""
from rest_framework.throttling import UserRateThrottle


class BurstRateThrottle(UserRateThrottle):
    """
    Rate limiting para operações sensíveis que precisam de proteção extra.
    
    Usa a taxa 'burst' definida em settings.REST_FRAMEWORK['DEFAULT_THROTTLE_RATES']
    """
    scope = 'burst'


class SensitiveOperationThrottle(UserRateThrottle):
    """
    Rate limiting mais restrito para operações muito sensíveis.
    Exemplo: mudança de senha, exclusão de conta, operações financeiras grandes.
    """
    rate = '10/hour'
