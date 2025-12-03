#!/bin/bash
set -e

echo "🚀 Docker Entrypoint - Starting Django Service"

# Função para aguardar o banco de dados
wait_for_db() {
    echo "⏳ Waiting for database to be ready..."
    
    python -c "
import os
import time
import psycopg
from urllib.parse import urlparse

db_url = os.getenv('DATABASE_URL')
if db_url:
    result = urlparse(db_url)
    max_retries = 30
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            conn = psycopg.connect(
                dbname=result.path[1:],
                user=result.username,
                password=result.password,
                host=result.hostname,
                port=result.port
            )
            conn.close()
            print('✅ Database is ready!')
            break
        except Exception as e:
            retry_count += 1
            print(f'⏳ Database not ready yet (attempt {retry_count}/{max_retries})...')
            time.sleep(2)
    
    if retry_count >= max_retries:
        print('❌ Database connection timeout!')
        exit(1)
else:
    print('⚠️  No DATABASE_URL found, assuming SQLite')
"
}

# O primeiro argumento determina qual serviço executar
SERVICE_TYPE="${1:-gunicorn}"

case "$SERVICE_TYPE" in
    "gunicorn")
        echo "🌐 Starting API Service (Gunicorn)"
        
        wait_for_db
        
        echo "🔄 Running database migrations..."
        python manage.py migrate --noinput
        
        echo "🗄️  Creating cache table..."
        python manage.py createcachetable --noinput 2>/dev/null || {
            echo "⚠️  Cache table might already exist (non-critical)"
        }
        
        echo "📦 Collecting static files..."
        python manage.py collectstatic --noinput --clear
        
        echo "✅ Database initialization complete!"
        echo "🌐 Starting Gunicorn server on port ${PORT:-8000}..."
        
        exec gunicorn config.wsgi:application \
            --bind "0.0.0.0:${PORT:-8000}" \
            --workers 4 \
            --timeout 120 \
            --worker-class=sync \
            --access-logfile - \
            --error-logfile - \
            --log-level info
        ;;
        
    "worker")
        echo "👷 Starting Celery Worker Service"
        
        wait_for_db
        
        echo "⏳ Waiting for migrations (API service should handle this)..."
        sleep 10
        
        echo "🔄 Starting Celery Worker..."
        exec celery -A config worker \
            -l info \
            --concurrency=2 \
            --max-tasks-per-child=100
        ;;
        
    "beat")
        echo "⏰ Starting Celery Beat Service"
        
        wait_for_db
        
        echo "⏳ Waiting for migrations (API service should handle this)..."
        sleep 10
        
        echo "📅 Starting Celery Beat Scheduler..."
        exec celery -A config beat \
            -l info \
            --scheduler django_celery_beat.schedulers:DatabaseScheduler
        ;;
        
    *)
        echo "❌ Unknown service type: $SERVICE_TYPE"
        echo "Usage: $0 {gunicorn|worker|beat}"
        exit 1
        ;;
esac
