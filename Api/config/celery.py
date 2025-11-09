"""
Configuração do Celery para o projeto TCC.

Este módulo configura o Celery para executar tasks assíncronas e agendadas.
Principais funcionalidades:
- Snapshots diários de usuários (23:59)
- Snapshots diários de missões (23:59)
- Snapshots mensais consolidados (último dia do mês 23:59)
"""

import os
from celery import Celery
from celery.schedules import crontab

# Configurar o Django settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

# Criar instância do Celery
app = Celery('tcc_finance')

# Usar string de configuração para evitar serialização de objetos
app.config_from_object('django.conf:settings', namespace='CELERY')

# Descobrir tasks automaticamente nos apps
app.autodiscover_tasks()

# Configuração do Celery Beat Schedule
app.conf.beat_schedule = {
    # ========================================================================
    # SNAPSHOTS DIÁRIOS DE USUÁRIOS
    # ========================================================================
    'create-daily-user-snapshots': {
        'task': 'finance.create_daily_user_snapshots',
        'schedule': crontab(hour=23, minute=59),  # Todo dia às 23:59
        'options': {
            'expires': 3600,  # Expira em 1 hora se não executar
        }
    },
    
    # ========================================================================
    # SNAPSHOTS DIÁRIOS DE MISSÕES
    # ========================================================================
    'create-daily-mission-snapshots': {
        'task': 'finance.create_daily_mission_snapshots',
        'schedule': crontab(hour=23, minute=59),  # Todo dia às 23:59
        'options': {
            'expires': 3600,  # Expira em 1 hora se não executar
        }
    },
    
    # ========================================================================
    # SNAPSHOTS MENSAIS CONSOLIDADOS
    # ========================================================================
    'create-monthly-snapshots': {
        'task': 'finance.create_monthly_snapshots',
        'schedule': crontab(day_of_month='28-31', hour=23, minute=50),  # Últimos dias do mês
        'options': {
            'expires': 3600,  # Expira em 1 hora se não executar
        }
    },
}

# Configurações adicionais do Celery
app.conf.update(
    # Timezone
    timezone='America/Sao_Paulo',
    enable_utc=True,
    
    # Serialização
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    
    # Resultados
    result_backend='django-db',  # Usar Django DB como backend
    result_extended=True,
    
    # Task settings
    task_track_started=True,
    task_time_limit=30 * 60,  # 30 minutos
    task_soft_time_limit=25 * 60,  # 25 minutos (warning)
    
    # Worker settings
    worker_prefetch_multiplier=4,
    worker_max_tasks_per_child=1000,
    
    # Beat settings
    beat_scheduler='django_celery_beat.schedulers:DatabaseScheduler',
)


@app.task(bind=True, ignore_result=True)
def debug_task(self):
    """Task de debug para testar configuração do Celery."""
    print(f'Request: {self.request!r}')
