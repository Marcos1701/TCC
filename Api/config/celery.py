
import os
from celery import Celery
from celery.schedules import crontab

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
app = Celery('tcc_finance')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()

app.conf.beat_schedule = {
    'check-expired-missions': {
        'task': 'finance.check_expired_missions',
        'schedule': crontab(hour=6, minute=0),
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
    print(f'Request: {self.request!r}')
