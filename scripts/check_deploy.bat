@echo off
REM Script para verificar configuração local antes de deploy
REM Uso: scripts\check_deploy.bat

echo ========================================
echo   CHECKLIST PRE-DEPLOY - RAILWAY
echo ========================================
echo.

REM Verificar se está na raiz do projeto
if not exist "Api\manage.py" (
    echo [ERRO] Execute este script da raiz do projeto TCC
    exit /b 1
)

echo [1/10] Verificando arquivos necessarios...
set FILES_OK=1

if not exist "Procfile" (
    echo   [FALTA] Procfile nao encontrado
    set FILES_OK=0
) else (
    echo   [OK] Procfile
)

if not exist "Api\requirements.txt" (
    echo   [FALTA] requirements.txt nao encontrado
    set FILES_OK=0
) else (
    echo   [OK] requirements.txt
)

if not exist "railway.json" (
    echo   [AVISO] railway.json nao encontrado (opcional)
) else (
    echo   [OK] railway.json
)

if not exist "runtime.txt" (
    echo   [AVISO] runtime.txt nao encontrado (opcional)
) else (
    echo   [OK] runtime.txt
)

echo.
echo [2/10] Verificando dependencias no requirements.txt...
findstr /c:"gunicorn" Api\requirements.txt >nul
if errorlevel 1 (
    echo   [FALTA] gunicorn nao esta no requirements.txt
    set FILES_OK=0
) else (
    echo   [OK] gunicorn
)

findstr /c:"celery" Api\requirements.txt >nul
if errorlevel 1 (
    echo   [FALTA] celery nao esta no requirements.txt
    set FILES_OK=0
) else (
    echo   [OK] celery
)

findstr /c:"redis" Api\requirements.txt >nul
if errorlevel 1 (
    echo   [FALTA] redis nao esta no requirements.txt
    set FILES_OK=0
) else (
    echo   [OK] redis
)

findstr /c:"django-celery-beat" Api\requirements.txt >nul
if errorlevel 1 (
    echo   [FALTA] django-celery-beat nao esta no requirements.txt
    set FILES_OK=0
) else (
    echo   [OK] django-celery-beat
)

echo.
echo [3/10] Verificando settings.py...
findstr /c:"CELERY_BROKER_URL" Api\config\settings.py >nul
if errorlevel 1 (
    echo   [FALTA] CELERY_BROKER_URL nao configurado
    set FILES_OK=0
) else (
    echo   [OK] CELERY_BROKER_URL configurado
)

findstr /c:"django_celery_beat" Api\config\settings.py >nul
if errorlevel 1 (
    echo   [FALTA] django_celery_beat nao esta em INSTALLED_APPS
    set FILES_OK=0
) else (
    echo   [OK] django_celery_beat em INSTALLED_APPS
)

echo.
echo [4/10] Verificando celery.py...
if not exist "Api\config\celery.py" (
    echo   [FALTA] Api\config\celery.py nao encontrado
    set FILES_OK=0
) else (
    echo   [OK] celery.py existe
)

echo.
echo [5/10] Verificando tasks.py...
if not exist "Api\finance\tasks.py" (
    echo   [FALTA] Api\finance\tasks.py nao encontrado
    set FILES_OK=0
) else (
    echo   [OK] tasks.py existe
)

echo.
echo [6/10] Verificando modelos de snapshot...
findstr /c:"class UserDailySnapshot" Api\finance\models.py >nul
if errorlevel 1 (
    echo   [FALTA] UserDailySnapshot nao encontrado em models.py
    set FILES_OK=0
) else (
    echo   [OK] UserDailySnapshot
)

findstr /c:"class MissionProgressSnapshot" Api\finance\models.py >nul
if errorlevel 1 (
    echo   [FALTA] MissionProgressSnapshot nao encontrado em models.py
    set FILES_OK=0
) else (
    echo   [OK] MissionProgressSnapshot
)

echo.
echo [7/10] Verificando Git...
git status >nul 2>&1
if errorlevel 1 (
    echo   [AVISO] Nao e um repositorio Git
) else (
    echo   [OK] Repositorio Git inicializado
    
    REM Verificar se há mudanças não commitadas
    git diff --quiet
    if errorlevel 1 (
        echo   [AVISO] Ha mudancas nao commitadas
    ) else (
        echo   [OK] Nenhuma mudanca pendente
    )
)

echo.
echo [8/10] Verificando .env (local)...
if not exist "Api\.env" (
    echo   [AVISO] .env nao encontrado (normal em producao)
) else (
    echo   [OK] .env existe (apenas para dev local)
)

echo.
echo [9/10] Verificando .gitignore...
if not exist ".gitignore" (
    echo   [AVISO] .gitignore nao encontrado
) else (
    findstr /c:".env" .gitignore >nul
    if errorlevel 1 (
        echo   [AVISO] .env nao esta no .gitignore
    ) else (
        echo   [OK] .env no .gitignore
    )
)

echo.
echo [10/10] Resumo final...
echo.

if %FILES_OK%==1 (
    echo ========================================
    echo   ✅ TUDO PRONTO PARA DEPLOY!
    echo ========================================
    echo.
    echo Proximos passos:
    echo 1. Fazer commit das mudancas (se houver)
    echo 2. Fazer push para GitHub
    echo 3. Conectar repositorio no Railway
    echo 4. Adicionar PostgreSQL e Redis
    echo 5. Configurar variaveis de ambiente
    echo 6. Criar servicos Worker e Beat
    echo.
    echo Leia DEPLOY_RAILWAY.md para instrucoes detalhadas
    exit /b 0
) else (
    echo ========================================
    echo   ❌ CORRIGIR PROBLEMAS ANTES DO DEPLOY
    echo ========================================
    echo.
    echo Verifique os itens marcados como [FALTA] acima
    echo Leia DEPLOY_RAILWAY.md para instrucoes
    exit /b 1
)
