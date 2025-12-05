"""
Tasks Celery para sistema de snapshots e validação de missões.
"""

import logging
from datetime import timedelta
from decimal import Decimal

from celery import shared_task
from django.contrib.auth import get_user_model
from django.db.models import Avg, Count, Min, Max, Sum, Q
from django.utils import timezone

from .models import (\r\n    Category,\r\n    Mission,\r\n    MissionProgress,\r\n    Transaction,\r\n)
from .services import calculate_summary, apply_mission_reward

User = get_user_model()
logger = logging.getLogger(__name__)


# ============================================================================
# TASK 4: GERAÇÃO ASSÍNCRONA DE MISSÕES COM IA
# ============================================================================

@shared_task(bind=True, name='finance.generate_missions_async')
def generate_missions_async(
    self,
    tier: str,
    scenario_key: str,
    count: int = 20,
    use_templates_first: bool = True
):
    """
    Task assíncrona para geração de missões com IA.
    
    Esta task roda em background worker Celery, permitindo processamento
    de até 10+ minutos sem timeout do servidor HTTP.
    
    Args:
        self: Task instance (bind=True)
        tier: Faixa do usuário (BEGINNER, INTERMEDIATE, ADVANCED, EXPERT)
        scenario_key: Cenário do usuário (low_activity, etc)
        count: Número de missões a gerar
        use_templates_first: Se deve priorizar templates
        
    Returns:
        dict: Resultado da geração com missões criadas/falhas
        
    Progress Tracking:
        A task atualiza o cache com progresso:
        - task_id: ID da task (self.request.id)
        - status: PENDING, STARTED, SUCCESS, FAILURE
        - current: Missão atual sendo gerada (1-20)
        - total: Total de missões (20)
        - percent: Porcentagem (0-100)
        - created: Lista de missões criadas
        - message: Mensagem de status
    """
    from django.core.cache import cache
    from finance.ai_services import generate_hybrid_missions
    
    task_id = self.request.id
    logger.info(f"[Task {task_id}] Iniciando geração assíncrona: {count} missões ({tier}/{scenario_key})")
    
    # Inicializar progresso no cache (TTL: 1 hora)
    cache_key = f'mission_generation_{task_id}'
    cache.set(cache_key, {
        'task_id': task_id,
        'status': 'STARTED',
        'current': 0,
        'total': count,
        'percent': 0,
        'created': [],
        'failed': [],
        'message': 'Inicializando geração...',
        'tier': tier,
        'scenario': scenario_key
    }, timeout=3600)
    
    try:
        # FASE 1: Templates
        cache.set(cache_key, {
            'task_id': task_id,
            'status': 'STARTED',
            'current': 0,
            'total': count,
            'percent': 5,
            'created': [],
            'failed': [],
            'message': '🎯 Gerando missões de templates...',
            'tier': tier,
            'scenario': scenario_key
        }, timeout=3600)
        
        # Callback de progresso
        def update_progress(current: int, total: int, message: str):
            percent = int((current / total) * 100) if total > 0 else 0
            cached_data = cache.get(cache_key) or {}
            cached_data.update({
                'current': current,
                'total': total,
                'percent': percent,
                'message': message
            })
            cache.set(cache_key, cached_data, timeout=3600)
            logger.debug(f"[Task {task_id}] Progresso: {current}/{total} ({percent}%) - {message}")
        
        # Chamar função principal
        result = generate_hybrid_missions(
            tier=tier,
            scenario_key=scenario_key,
            count=count,
            use_templates_first=use_templates_first
        )
        
        # Sucesso
        created_missions = result.get('created', [])
        failed_missions = result.get('failed', [])
        summary = result.get('summary', {})
        
        logger.info(f"[Task {task_id}] Geração concluída: {len(created_missions)} criadas, {len(failed_missions)} falhas")
        
        cache.set(cache_key, {
            'task_id': task_id,
            'status': 'SUCCESS',
            'current': count,
            'total': count,
            'percent': 100,
            'created': created_missions,
            'failed': failed_missions,
            'summary': summary,
            'message': f'✅ Concluído: {len(created_missions)} missões criadas',
            'tier': tier,
            'scenario': scenario_key
        }, timeout=3600)
        
        return result
        
    except Exception as e:
        logger.error(f"[Task {task_id}] Erro na geração: {str(e)}", exc_info=True)
        
        cache.set(cache_key, {
            'task_id': task_id,
            'status': 'FAILURE',
            'current': 0,
            'total': count,
            'percent': 0,
            'created': [],
            'failed': [],
            'error': str(e),
            'message': f'❌ Erro: {str(e)}',
            'tier': tier,
            'scenario': scenario_key
        }, timeout=3600)
        
        raise


@shared_task(name='finance.cleanup_old_missions')
def cleanup_old_missions(days: int = 90):
    """
    Remove missões inativas antigas (execução periódica via Celery Beat).
    
    Args:
        days: Remover missões inativas há mais de X dias
        
    Returns:
        dict: Número de missões removidas
    """
    from datetime import timedelta
    
    cutoff_date = timezone.now() - timedelta(days=days)
    
    old_missions = Mission.objects.filter(
        is_active=False,
        created_at__lt=cutoff_date
    )
    
    count = old_missions.count()
    old_missions.delete()
    
    logger.info(f"Limpeza: {count} missões inativas (>{days} dias) removidas")
    
    return {
        'removed': count,
        'cutoff_date': cutoff_date.isoformat(),
        'days': days
    }
