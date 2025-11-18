# Procfile para Railway
# Este arquivo define os processos que rodam no Railway

# Processo Web - Django (obrigatório)
web: cd Api && gunicorn config.wsgi:application --bind 0.0.0.0:$PORT --workers 4 --timeout 300 --worker-class=sync

# Processo Worker - Celery Worker (opcional, criar serviço separado)
worker: cd Api && celery -A config worker -l info --concurrency=2 --max-tasks-per-child=100

# Processo Beat - Celery Beat Scheduler (opcional, criar serviço separado)
beat: cd Api && celery -A config beat -l info --scheduler django_celery_beat.schedulers:DatabaseScheduler
