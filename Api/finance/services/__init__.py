"""
Package de serviços do módulo finance.

Este pacote contém toda a lógica de negócio do módulo finance,
organizada em módulos por domínio:

- base.py: Helpers e constantes comuns
- indicators.py: Cálculo de indicadores financeiros (TPS, RDR, ILI)
- context.py: Análise de contexto do usuário
- missions.py: Gerenciamento de missões
- analytics.py: Análises avançadas e métricas
- transactions.py: Operações com transações
- transactions.py: Operações com transações
"""

from .base import _decimal, _xp_threshold

from .indicators import (
    calculate_summary,
    invalidate_indicators_cache,
    indicator_insights,
    category_breakdown,
    cashflow_series,
    profile_snapshot,
)

from .context import (
    analyze_user_context,
    identify_improvement_opportunities,
)

from .missions import (
    assign_missions_smartly,
    calculate_mission_priorities,
    assign_missions_automatically,
    update_mission_progress,
    initialize_mission_progress,
    validate_mission_progress_manual,
    apply_mission_reward,
)

from .analytics import (
    analyze_user_evolution,
    analyze_category_patterns,
    analyze_tier_progression,
    get_mission_distribution_analysis,
    get_comprehensive_mission_context,
)

from .transactions import (
    auto_link_recurring_transactions,
)

__all__ = [
    # Base
    '_decimal',
    '_xp_threshold',
    
    # Indicadores
    'calculate_summary',
    'invalidate_indicators_cache',
    'indicator_insights',
    'category_breakdown',
    'cashflow_series',
    'profile_snapshot',
    
    # Contexto
    'analyze_user_context',
    'identify_improvement_opportunities',
    
    # Missões
    'assign_missions_smartly',
    'calculate_mission_priorities',
    'assign_missions_automatically',
    'update_mission_progress',
    'initialize_mission_progress',
    'validate_mission_progress_manual',
    'apply_mission_reward',
    

    
    # Analytics
    'analyze_user_evolution',
    'analyze_category_patterns',
    'analyze_tier_progression',
    'get_mission_distribution_analysis',
    'get_comprehensive_mission_context',
    
    # Transações
    'auto_link_recurring_transactions',
]
