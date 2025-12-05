"""
Rate Limiting (Throttling) para proteção contra abuso de API.

Este módulo define classes de throttling customizadas para endpoints sensíveis
que podem ser alvo de abuso ou causar sobrecarga no servidor.

Implementa controle de taxa baseado em:
- Identificação por usuário autenticado
- Limitação por hora
- Diferentes taxas para diferentes operações

Conformidade com boas práticas de segurança:
- Previne ataques de negação de serviço (DoS)
- Protege recursos computacionalmente caros
- Mantém performance e disponibilidade
"""

from rest_framework.throttling import UserRateThrottle


class BurstRateThrottle(UserRateThrottle):
    """
    Throttle para prevenir burst requests.
    Limita a 30 requests por minuto.
    """
    rate = '30/minute'
    scope = 'burst'


class TransactionCreateThrottle(UserRateThrottle):
    """
    Rate limiting para criação de transações.
    Limita um usuário a criar no máximo 100 transações por hora.
    """
    rate = '100/hour'
    scope = 'transaction_create'


class CategoryCreateThrottle(UserRateThrottle):
    """
    Rate limiting para criação de categorias.
    Limita a 20 categorias por hora.
    """
    rate = '20/hour'
    scope = 'category_create'


class LinkCreateThrottle(UserRateThrottle):
    """
    Rate limiting para criação de vinculações entre transações.
    Limita a 50 vinculações por hora.
    """
    rate = '50/hour'
    scope = 'link_create'


class DashboardRefreshThrottle(UserRateThrottle):
    """
    Rate limiting para refresh de dashboard/indicadores.
    Limita a 300 requests por hora.
    """
    rate = '300/hour'
    scope = 'dashboard_refresh'


class SensitiveOperationThrottle(UserRateThrottle):
    """
    Rate limiting mais restrito para operações sensíveis.
    """
    rate = '10/hour'
    scope = 'sensitive'


# Throttle classes por severidade (para uso combinado)
CRITICAL_THROTTLES = [BurstRateThrottle, TransactionCreateThrottle]
MODERATE_THROTTLES = [BurstRateThrottle, CategoryCreateThrottle]
LIGHT_THROTTLES = [BurstRateThrottle]

