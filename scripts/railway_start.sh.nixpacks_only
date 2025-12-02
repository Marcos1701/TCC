#!/bin/bash
set -e

echo "🚀 Railway Startup Script - Starting Django Application"

# Activate virtual environment
. /opt/venv/bin/activate

# Change to API directory
cd Api

echo "⏳ Waiting for database to be ready..."
python manage.py wait_for_db 2>/dev/null || {
    echo "⚠️  wait_for_db command not found, attempting connection..."
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
" || exit 1
}

echo "🔄 Running database migrations..."
python manage.py migrate --noinput

echo "🗄️  Creating cache table..."
python manage.py createcachetable --noinput 2>/dev/null || {
    echo "⚠️  Cache table might already exist or command failed (non-critical)"
}

echo "📦 Collecting static files..."
python manage.py collectstatic --noinput --clear

echo "✅ Database initialization complete!"

echo "🌐 Starting Gunicorn server on port $PORT..."
exec gunicorn config.wsgi:application \
    --bind 0.0.0.0:$PORT \
    --workers 4 \
    --timeout 120 \
    --worker-class=sync \
    --access-logfile - \
    --error-logfile - \
    --log-level info
