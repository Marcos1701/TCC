#!/bin/bash
# Script para criar todos os 4 serviços no Railway automaticamente
# Requer: Railway CLI instalado (npm install -g @railway/cli)

set -e

echo "🚂 Railway Multi-Service Deployment Script"
echo "=========================================="
echo ""

# Verificar se Railway CLI está instalado
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI não encontrado!"
    echo "Instale com: npm install -g @railway/cli"
    exit 1
fi

echo "✅ Railway CLI encontrado"
echo ""

# Login (se necessário)
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

# Link ao projeto ou criar novo
echo ""
echo "🔗 Conectando ao projeto Railway..."
railway link || {
    echo "Criando novo projeto..."
    railway init
}

# Obter ID do projeto
PROJECT_ID=$(railway status --json | jq -r '.project.id')
echo "✅ Projeto ID: $PROJECT_ID"

# Função para criar serviço
create_service() {
    local SERVICE_NAME=$1
    local DOCKERFILE_PATH=$2
    local START_COMMAND=$3
    
    echo ""
    echo "📦 Criando serviço: $SERVICE_NAME"
    
    # Criar serviço via API (Railway CLI não tem comando direto)
    # Alternativa: usar railway up com diferentes configurações
    
    railway service create $SERVICE_NAME || echo "⚠️  Serviço $SERVICE_NAME já existe"
    
    # Configurar Dockerfile
    railway variables set DOCKERFILE_PATH="$DOCKERFILE_PATH" --service $SERVICE_NAME || true
    
    # Configurar start command (se fornecido)
    if [ -n "$START_COMMAND" ]; then
        railway variables set START_COMMAND="$START_COMMAND" --service $SERVICE_NAME || true
    fi
    
    echo "✅ Serviço $SERVICE_NAME configurado"
}

# Criar serviços
create_service "api" "Api/Dockerfile" ""
create_service "worker" "Api/Dockerfile" "/docker-entrypoint.sh worker"
create_service "beat" "Api/Dockerfile" "/docker-entrypoint.sh beat"
create_service "frontend" "Front/Dockerfile" ""

echo ""
echo "🎉 Serviços criados com sucesso!"
echo ""
echo "⚠️  PRÓXIMOS PASSOS MANUAIS:"
echo ""
echo "1. No Railway Dashboard (https://railway.app):"
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
