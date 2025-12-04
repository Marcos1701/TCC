#!/bin/bash
set -e

echo "🚀 Docker Entrypoint - Starting Django Service"
echo "📋 Environment: ${DJANGO_SETTINGS_MODULE:-config.settings}"
echo "📋 Service Type: ${1:-gunicorn}"

# Validar variáveis de ambiente críticas
validate_env() {
    echo "🔍 Validating environment variables..."
    
    local missing_vars=()
    
    # SECRET_KEY é obrigatório em produção (aceita SECRET_KEY ou DJANGO_SECRET_KEY)
    if [ -z "$SECRET_KEY" ] && [ -z "$DJANGO_SECRET_KEY" ] && [ "$DJANGO_DEBUG" != "True" ] && [ "$DJANGO_DEBUG" != "true" ]; then
        missing_vars+=("SECRET_KEY or DJANGO_SECRET_KEY")
    fi
    
    # Exportar DJANGO_SECRET_KEY como SECRET_KEY se necessário
    if [ -z "$SECRET_KEY" ] && [ -n "$DJANGO_SECRET_KEY" ]; then
        export SECRET_KEY="$DJANGO_SECRET_KEY"
        echo "✅ Using DJANGO_SECRET_KEY as SECRET_KEY"
    fi
    
    # DATABASE_URL ou variáveis individuais de DB
    if [ -z "$DATABASE_URL" ]; then
        if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ]; then
            echo "⚠️  No DATABASE_URL or DB_HOST/DB_NAME found, will use defaults or SQLite"
        fi
    fi
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "❌ Missing required environment variables: ${missing_vars[*]}"
        exit 1
    fi
    
    echo "✅ Environment validation passed!"
}

# Função para aguardar o banco de dados
wait_for_db() {
    echo "⏳ Waiting for database to be ready..."
    
    python -c "
import os
import sys
import time

# Tentar psycopg primeiro, depois psycopg2
try:
    import psycopg
    psycopg_version = 3
except ImportError:
    try:
        import psycopg2 as psycopg
        psycopg_version = 2
    except ImportError:
        print('❌ Neither psycopg nor psycopg2 is installed!')
        sys.exit(1)

from urllib.parse import urlparse

db_url = os.getenv('DATABASE_URL')

# Se não tem DATABASE_URL, tenta construir a partir das variáveis individuais
if not db_url:
    db_host = os.getenv('DB_HOST', 'localhost')
    db_port = os.getenv('DB_PORT', '5432')
    db_name = os.getenv('DB_NAME', os.getenv('POSTGRES_DB', 'finance_db'))
    db_user = os.getenv('DB_USER', os.getenv('POSTGRES_USER', 'postgres'))
    db_pass = os.getenv('DB_PASSWORD', os.getenv('POSTGRES_PASSWORD', 'postgres123'))
    db_url = f'postgresql://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}'

if db_url and db_url.startswith('postgres'):
    result = urlparse(db_url)
    max_retries = 30
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            if psycopg_version == 3:
                conn = psycopg.connect(
                    dbname=result.path[1:],
                    user=result.username,
                    password=result.password,
                    host=result.hostname,
                    port=result.port or 5432
                )
            else:
                conn = psycopg.connect(
                    dbname=result.path[1:],
                    user=result.username,
                    password=result.password,
                    host=result.hostname,
                    port=result.port or 5432
                )
            conn.close()
            print('✅ Database is ready!')
            sys.exit(0)
        except Exception as e:
            retry_count += 1
            print(f'⏳ Database not ready yet (attempt {retry_count}/{max_retries}): {str(e)[:100]}')
            time.sleep(2)
    
    if retry_count >= max_retries:
        print('❌ Database connection timeout!')
        sys.exit(1)
else:
    print('⚠️  No PostgreSQL DATABASE_URL found, assuming SQLite or other DB')
"
}

# O primeiro argumento determina qual serviço executar
SERVICE_TYPE="${1:-gunicorn}"

# Validar ambiente
validate_env

case "$SERVICE_TYPE" in
    "gunicorn")
        echo "🌐 Starting API Service (Gunicorn)"
        
        wait_for_db
        
        echo "🔄 Running database migrations..."
        python manage.py migrate --noinput || {
            echo "❌ Migration failed! Check database connection and permissions."
            exit 1
        }
        
        echo "🗄️  Creating cache table..."
        python manage.py createcachetable 2>/dev/null || {
            echo "⚠️  Cache table might already exist (non-critical)"
        }
        
        echo "📦 Collecting static files..."
        python manage.py collectstatic --noinput --clear || {
            echo "⚠️  Collectstatic had issues, continuing anyway..."
        }
        
        echo "✅ Database initialization complete!"
        
        # Configurar número de workers baseado em CPU disponível
        WORKERS=${WORKERS:-4}
        TIMEOUT=${TIMEOUT:-120}
        PORT=${PORT:-8000}
        
        echo "🌐 Starting Gunicorn server on port ${PORT} with ${WORKERS} workers..."
        
        exec gunicorn config.wsgi:application \
            --bind "0.0.0.0:${PORT}" \
            --workers "${WORKERS}" \
            --timeout "${TIMEOUT}" \
            --worker-class=sync \
            --access-logfile - \
            --error-logfile - \
            --log-level info \
            --capture-output \
            --enable-stdio-inheritance
        ;;
        
    "worker")
        echo "👷 Starting Celery Worker Service"
        
        wait_for_db
        
        echo "⏳ Waiting for migrations (API service should handle this)..."
        sleep 15
        
        # Configurar concorrência baseada em recursos disponíveis
        CELERY_CONCURRENCY=${CELERY_CONCURRENCY:-2}
        
        echo "🔄 Starting Celery Worker with concurrency=${CELERY_CONCURRENCY}..."
        exec celery -A config worker \
            -l info \
            --concurrency="${CELERY_CONCURRENCY}" \
            --max-tasks-per-child=100 \
            --without-heartbeat \
            --without-gossip \
            --without-mingle
        ;;
        
    "beat")
        echo "⏰ Starting Celery Beat Service"
        
        wait_for_db
        
        echo "⏳ Waiting for migrations (API service should handle this)..."
        sleep 20
        
        echo "📅 Starting Celery Beat Scheduler..."
        exec celery -A config beat \
            -l info \
            --scheduler django_celery_beat.schedulers:DatabaseScheduler \
            --pidfile=/tmp/celerybeat.pid
        ;;
        
    *)
        echo "❌ Unknown service type: $SERVICE_TYPE"
        echo "Usage: $0 {gunicorn|worker|beat}"
        echo ""
        echo "Available service types:"
        echo "  gunicorn - Django API server with Gunicorn"
        echo "  worker   - Celery worker for background tasks"
        echo "  beat     - Celery beat for scheduled tasks"
        exit 1
        ;;
esac
