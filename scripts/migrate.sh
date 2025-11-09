#!/bin/bash
# Script para rodar migrações no Railway
# Uso: railway run bash scripts/migrate.sh

echo "🚀 Rodando migrações no Railway..."

cd Api

echo "📦 Migrações principais..."
python manage.py migrate

echo "📅 Migrações do Celery Beat..."
python manage.py migrate django_celery_beat

echo "📊 Migrações do Celery Results..."
python manage.py migrate django_celery_results

echo "✅ Todas as migrações concluídas!"
echo ""
echo "🔐 Criar superuser agora? (s/n)"
read -r response
if [[ "$response" =~ ^([sS][iI][mM]|[sS])$ ]]
then
    python manage.py createsuperuser
fi

echo ""
echo "✨ Deploy completo!"
