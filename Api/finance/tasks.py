
import logging
from datetime import timedelta
from decimal import Decimal

from celery import shared_task
from django.contrib.auth import get_user_model
from django.db.models import Avg, Count, Min, Max, Sum, Q
from django.utils import timezone

from .models import (
    Category,
    Mission,
    MissionProgress,
    Transaction,
)
from .services import calculate_summary, apply_mission_reward

User = get_user_model()
logger = logging.getLogger(__name__)



@shared_task(bind=True, name='finance.generate_missions_async')
def generate_missions_async(
    self,
    tier: str,
    scenario_key: str,
    count: int = 20,
    use_templates_first: bool = True
):
    from django.core.cache import cache
    from finance.ai_services import generate_hybrid_missions
    
    task_id = self.request.id
    logger.info(f"[Task {task_id}] Iniciando geração assíncrona: {count} missões ({tier}/{scenario_key})")
    
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
        
        result = generate_hybrid_missions(
            tier=tier,
            scenario_key=scenario_key,
            count=count,
            use_templates_first=use_templates_first
        )
        
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


@shared_task(name='finance.check_expired_missions')
def check_expired_missions():
    """
    Marca missões ativas que passaram do prazo como FAILED.
    Deve ser executada periodicamente (ex: diariamente).
    """
    from datetime import timedelta
    
    now = timezone.now()
    expired_count = 0
    
    # Busca missões ativas/pendentes que passaram do prazo
    active_missions = MissionProgress.objects.filter(
        status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE],
        started_at__isnull=False
    ).select_related('mission')
    
    for progress in active_missions:
        deadline = progress.started_at + timedelta(days=progress.mission.duration_days)
        if now > deadline:
            progress.status = MissionProgress.Status.FAILED
            progress.save(update_fields=['status'])
            expired_count += 1
            logger.info(f"Missão expirada: {progress.mission.title} (usuário: {progress.user_id})")
    
    logger.info(f"Verificação de expiração: {expired_count} missões marcadas como FAILED")
    
    return {
        'expired_count': expired_count,
        'checked_at': now.isoformat()
    }


@shared_task(name='finance.cleanup_old_missions')
def cleanup_old_missions(days: int = 90):
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
