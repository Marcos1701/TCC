#!/bin/bash
set -e

echo "🚚 Railway Multi-Service Deployment Script"
echo "=========================================="
echo ""

if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI não encontrado!"
    echo "Instale com: npm install -g @railway/cli"
    exit 1
fi

echo "✅ Railway CLI encontrado"
echo ""

echo "🔐 Verificando autenticação..."
railway whoami || railway login

echo ""
echo "📋 Este script irá criar 4 serviços:"
echo "  1. api (Django + Gunicorn)"
echo "  2. worker (Celery Worker)"
echo "  3. beat (Celery Beat)"
echo "  4. frontend (Flutter Web)"
echo ""

read -p "Deseja continuar? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

echo ""
echo "🔗 Conectando ao projeto Railway..."
railway link || {
    echo "Criando novo projeto..."
    railway init
}

PROJECT_ID=$(railway status --json | jq -r '.project.id')
echo "✅ Projeto ID: $PROJECT_ID"

create_service() {
    local SERVICE_NAME=$1
    local DOCKERFILE_PATH=$2
    local START_COMMAND=$3
    
    echo ""
    echo "📦 Criando serviço: $SERVICE_NAME"
    
    railway service create $SERVICE_NAME || echo "⚠️  Serviço $SERVICE_NAME já existe"
    
    railway variables set DOCKERFILE_PATH="$DOCKERFILE_PATH" --service $SERVICE_NAME || true
    
    if [ -n "$START_COMMAND" ]; then
        railway variables set START_COMMAND="$START_COMMAND" --service $SERVICE_NAME || true
    fi
    
    echo "✅ Serviço $SERVICE_NAME configurado"
}

create_service "api" "Api/Dockerfile" ""
create_service "worker" "Api/Dockerfile" "/docker-entrypoint.sh worker"
create_service "beat" "Api/Dockerfile" "/docker-entrypoint.sh beat"
create_service "frontend" "Front/Dockerfile" ""

echo ""
echo "🎉 Serviços criados com sucesso!"
echo ""
echo "⚠️  PRÓXIMOS PASSOS MANUAIS:"
echo ""
echo "1. No Railway Dashboard:"
echo "   - Adicionar PostgreSQL add-on"
echo "   - Adicionar Redis add-on"
echo ""
echo "2. Para cada serviço, configurar:"
echo "   - Settings → Build → Builder: DOCKERFILE"
echo "   - Settings → Build → Dockerfile Path: (conforme acima)"
echo "   - Variables → Reference: DATABASE_URL, REDIS_URL"
echo ""
echo "3. Deploy:"
echo "   git push origin main"
echo ""
echo "Para mais detalhes, veja: RAILWAY_MULTI_SERVICE_SETUP.md"
