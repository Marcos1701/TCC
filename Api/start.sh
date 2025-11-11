#!/bin/sh

# Script de inicialização para Railway
# Usa a variável PORT do Railway ou 8000 como padrão

set -e

echo "Starting application..."
echo "PORT: ${PORT:-8000}"

# Coletar arquivos estáticos
echo "Collecting static files..."
python manage.py collectstatic --noinput --clear || echo "Static files collection failed, continuing..."

# Executar migrações
echo "Running migrations..."
python manage.py migrate --noinput || echo "Migrations failed, continuing..."

# Iniciar Gunicorn
echo "Starting Gunicorn on port ${PORT:-8000}..."
exec gunicorn config.wsgi:application \
    --bind "0.0.0.0:${PORT:-8000}" \
    --workers 4 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile - \
    --log-level info
