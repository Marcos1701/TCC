"""Configuração do Celery para o projeto TCC."""

import os
from celery import Celery
from celery.schedules import crontab

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
app = Celery('tcc_finance')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()

app.conf.beat_schedule = {
    'create-daily-user-snapshots': {
        'task': 'finance.create_daily_user_snapshots',
        'schedule': crontab(hour=23, minute=59),
        'options': {
            'expires': 3600,
        }
    },
    'create-daily-mission-snapshots': {
        'task': 'finance.create_daily_mission_snapshots',
        'schedule': crontab(hour=23, minute=59),
        'options': {
            'expires': 3600,
        }
    },
    'create-monthly-snapshots': {
        'task': 'finance.create_monthly_snapshots',
        'schedule': crontab(day_of_month='28-31', hour=23, minute=50),
        'options': {
            'expires': 3600,
        }
    },
}

app.conf.update(
    timezone='America/Sao_Paulo',
    enable_utc=True,
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    result_backend='django-db',
    result_extended=True,
    task_track_started=True,
    task_time_limit=30 * 60,
    task_soft_time_limit=25 * 60,
    worker_prefetch_multiplier=4,
    worker_max_tasks_per_child=1000,
    beat_scheduler='django_celery_beat.schedulers:DatabaseScheduler',
)


@app.task(bind=True, ignore_result=True)
def debug_task(self):
    """Task de debug para testar configuração do Celery."""
    print(f'Request: {self.request!r}')
