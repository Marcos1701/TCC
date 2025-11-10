# Deploy no Railway - Guia Completo

## 📋 Visão Geral

O Railway é uma plataforma PaaS (Platform as a Service) que facilita o deploy de aplicações. Para rodar o sistema completo com Celery, você precisará de **3 serviços**:

1. **Web (Django)** - API REST
2. **Worker (Celery Worker)** - Processa tasks em background
3. **Beat (Celery Beat)** - Agenda tasks periódicas

**Plus 2 add-ons:**
- **PostgreSQL** - Banco de dados
- **Redis** - Message broker para Celery

---

## 🚀 Passo a Passo - Deploy Completo

### Parte 1: Preparar o Repositório

#### 1.1 Adicionar `runtime.txt` (Opcional)

Especifica a versão do Python:

```txt
python-3.11.9
```

#### 1.2 Verificar `Procfile`

Já criado! Contém 3 comandos:
- `web` - Django com Gunicorn
- `worker` - Celery Worker
- `beat` - Celery Beat

#### 1.3 Configurar variáveis de ambiente no código

Já configurado em `settings.py`:
- `REDIS_URL` - Railway injeta automaticamente (formato: `redis://default:**@redis.railway.internal:6379/`)
- `RAILWAY_ENVIRONMENT` - Detecta ambiente de produção
- `DATABASE_URL` - Railway injeta automaticamente

---

### Parte 2: Criar Projeto no Railway

#### 2.1 Login no Railway

1. Acesse: https://railway.app
2. Faça login com GitHub
3. Clique em **"New Project"**

#### 2.2 Criar Projeto

1. Selecione **"Deploy from GitHub repo"**
2. Escolha o repositório `Marcos1701/TCC`
3. Railway detectará automaticamente o `Procfile`

---

### Parte 3: Adicionar Add-ons

#### 3.1 Adicionar PostgreSQL

1. No dashboard do projeto, clique **"+ New"**
2. Selecione **"Database" → "Add PostgreSQL"**
3. Railway criará automaticamente:
   - Variável `DATABASE_URL`
   - Injetada em todos os serviços

#### 3.2 Adicionar Redis

1. No dashboard, clique **"+ New"**
2. Selecione **"Database" → "Add Redis"**
3. Railway criará automaticamente:
   - Variável `REDIS_URL`
   - Injetada em todos os serviços

---

### Parte 4: Configurar Serviços

Railway cria apenas o serviço **web** por padrão. Você precisa criar **worker** e **beat** manualmente.

#### 4.1 Configurar Serviço WEB (Django)

1. Clique no serviço **web** (já criado)
2. Vá em **Settings**
3. Configure:

**Build Command:** (Opcional)
```bash
cd Api && pip install -r requirements.txt
```

**Start Command:** (Railway usa automaticamente do Procfile)
```bash
cd Api && gunicorn config.wsgi:application --bind 0.0.0.0:$PORT --workers 4 --timeout 120
```

**Health Check Path:**
```
/api/
```

**Variáveis de Ambiente:**
```env
SECRET_KEY=<gerar-uma-chave-secreta-forte>
DEBUG=False
ALLOWED_HOSTS=*.railway.app,*.up.railway.app
DJANGO_SETTINGS_MODULE=config.settings
RAILWAY_ENVIRONMENT=production
```

4. Clique em **"Generate Domain"** para criar URL pública

#### 4.2 Criar Serviço WORKER (Celery Worker)

1. No dashboard, clique **"+ New"**
2. Selecione **"Empty Service"**
3. Nomeie como **"worker"**
4. Clique no serviço **worker**
5. Vá em **Settings → Service**

**Source:** Conecte ao mesmo repositório GitHub

**Root Directory:** `/` (raiz do projeto)

**Start Command:**
```bash
cd Api && celery -A config worker -l info --concurrency=2 --max-tasks-per-child=100
```

**Variáveis de Ambiente:** (Mesmo que web)
```env
SECRET_KEY=<mesma-chave-do-web>
DEBUG=False
DJANGO_SETTINGS_MODULE=config.settings
RAILWAY_ENVIRONMENT=production
```

**IMPORTANTE:** Desmarque **"Public Networking"** - Worker não precisa de URL pública

#### 4.3 Criar Serviço BEAT (Celery Beat)

1. No dashboard, clique **"+ New"**
2. Selecione **"Empty Service"**
3. Nomeie como **"beat"**
4. Clique no serviço **beat**
5. Vá em **Settings → Service**

**Source:** Conecte ao mesmo repositório GitHub

**Root Directory:** `/` (raiz do projeto)

**Start Command:**
```bash
cd Api && celery -A config beat -l info --scheduler django_celery_beat.schedulers:DatabaseScheduler
```

**Variáveis de Ambiente:** (Mesmo que web)
```env
SECRET_KEY=<mesma-chave-do-web>
DEBUG=False
DJANGO_SETTINGS_MODULE=config.settings
RAILWAY_ENVIRONMENT=production
```

**IMPORTANTE:** Desmarque **"Public Networking"** - Beat não precisa de URL pública

---

### Parte 5: Configurar Migrações Iniciais

Railway roda migrações automaticamente **apenas no serviço web**. Você precisa rodar migrações do Celery manualmente uma vez.

#### 5.1 Rodar Migrações via Railway CLI (Recomendado)

**Instalar Railway CLI:**
```bash
npm i -g @railway/cli
# Ou
brew install railway
```

**Login e selecionar projeto:**
```bash
railway login
railway link
```

**Rodar migrações:**
```bash
railway run python Api/manage.py migrate
railway run python Api/manage.py migrate django_celery_beat
railway run python Api/manage.py migrate django_celery_results
```

**Criar superuser:**
```bash
railway run python Api/manage.py createsuperuser
```

#### 5.2 Alternativa: Rodar via SSH no serviço web

1. No serviço **web**, vá em **Deployments**
2. Clique em **"..."** → **"View Logs"**
3. Use o terminal interativo (se disponível) ou:

**Adicione temporariamente ao start command:**
```bash
cd Api && python manage.py migrate && python manage.py migrate django_celery_beat && python manage.py migrate django_celery_results && gunicorn config.wsgi:application --bind 0.0.0.0:$PORT
```

Após rodar uma vez, remova os comandos de migração.

---

### Parte 6: Configurar Variáveis de Ambiente (Todas)

Em **CADA SERVIÇO** (web, worker, beat), adicione as mesmas variáveis:

```env
# Django
SECRET_KEY=django-insecure-GERE_UMA_CHAVE_AQUI_COM_50_CHARS_ALEATORIOS
DEBUG=False
ALLOWED_HOSTS=*.railway.app,*.up.railway.app
DJANGO_SETTINGS_MODULE=config.settings
RAILWAY_ENVIRONMENT=production

# CORS (Frontend - ajuste conforme necessário)
CORS_ALLOWED_ORIGINS=https://seu-frontend.vercel.app,https://seu-app.netlify.app

# PostgreSQL (Railway injeta automaticamente)
# DATABASE_URL=postgresql://user:pass@host:port/db

# Redis (Railway injeta automaticamente)
# REDIS_URL=redis://default:pass@host:port

# Google Gemini AI (obrigatório para geração de missões)
GOOGLE_API_KEY=SUA_API_KEY_DO_GEMINI_AQUI
```

**Gerar SECRET_KEY:**
```python
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

---

### Parte 7: Verificar Deploy

#### 7.1 Verificar Logs

**Serviço Web:**
- Vá em **Deployments → View Logs**
- Deve mostrar: `Booting worker with pid: XXX`
- Sem erros de migração

**Serviço Worker:**
- Deve mostrar:
  ```
  [tasks]
    . config.celery.debug_task
    . finance.create_daily_mission_snapshots
    . finance.create_daily_user_snapshots
    . finance.create_monthly_snapshots
  
  Connected to redis://default:**@redis.railway.internal:6379//
  celery@xxxxxxxx ready.
  ```

**Serviço Beat:**
- Deve mostrar:
  ```
  DatabaseScheduler: Schedule changed.
  Writing entries (3)...
  ```

#### 7.2 Testar API

```bash
# Usando a URL gerada pelo Railway
curl https://seu-projeto.up.railway.app/api/

# Deve retornar JSON com endpoints disponíveis
```

#### 7.3 Verificar Tasks Agendadas

1. Acesse o admin: `https://seu-projeto.up.railway.app/admin/`
2. Login com superuser criado
3. Vá em **Django Celery Beat → Periodic Tasks**
4. Deve ter 3 tasks:
   - `create-daily-user-snapshots`
   - `create-daily-mission-snapshots`
   - `create-monthly-snapshots`

---

## 📊 Arquitetura Final no Railway

```
┌─────────────────────────────────────────────────────────┐
│                    Railway Project                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────┐    ┌──────────────┐   ┌────────────┐  │
│  │   Web       │◄───┤  PostgreSQL  │   │   Redis    │  │
│  │  (Django)   │    │  (Database)  │   │ (Broker)   │  │
│  │  Port: 8000 │    └──────────────┘   └────────────┘  │
│  │  Public URL │            ▲               ▲           │
│  └─────────────┘            │               │           │
│                             │               │           │
│  ┌─────────────┐            │               │           │
│  │   Worker    │────────────┴───────────────┤           │
│  │  (Celery)   │                            │           │
│  │  No Public  │                            │           │
│  └─────────────┘                            │           │
│                                             │           │
│  ┌─────────────┐                            │           │
│  │    Beat     │────────────────────────────┘           │
│  │ (Scheduler) │                                        │
│  │  No Public  │                                        │
│  └─────────────┘                                        │
│                                                          │
└─────────────────────────────────────────────────────────┘

Fluxo de dados:
1. Beat agenda tasks → Redis
2. Worker consome tasks do Redis
3. Worker executa tasks (cria snapshots no PostgreSQL)
4. Web serve API e lê dados do PostgreSQL
```

---

## 💰 Custos Estimados (Railway)

**Plano Hobby (Gratuito):**
- $5/mês em créditos grátis
- Suficiente para desenvolvimento/testes
- Limites:
  - 500h de execução/mês
  - Shared CPU
  - 512MB RAM por serviço

**Custos mensais estimados (uso real):**
- Web: ~$3-5/mês (sempre ativo)
- Worker: ~$2-3/mês (processa tasks)
- Beat: ~$1-2/mês (leve, apenas agenda)
- PostgreSQL: $5/mês (plano Hobby)
- Redis: $5/mês (plano Hobby)

**Total: ~$16-20/mês**

**Otimização de custos:**
- Beat e Worker podem compartilhar o mesmo serviço em baixo tráfego
- Use sleep mode para serviços não críticos

---

## 🔧 Troubleshooting Railway

### Problema: "No module named 'config'"

**Causa:** Start command não está mudando para diretório `Api`

**Solução:** Sempre use `cd Api &&` antes dos comandos:
```bash
cd Api && celery -A config worker -l info
```

### Problema: Worker não encontra tasks

**Causa:** `DJANGO_SETTINGS_MODULE` não configurado

**Solução:** Adicione variável de ambiente:
```env
DJANGO_SETTINGS_MODULE=config.settings
```

### Problema: "redis.exceptions.ConnectionError"

**Causa:** Redis add-on não foi criado

**Solução:**
1. Adicione Redis no dashboard
2. Verifique se `REDIS_URL` está nas variáveis

### Problema: Beat não agenda tasks

**Causa:** Migrações do `django_celery_beat` não foram rodadas

**Solução:**
```bash
railway run python Api/manage.py migrate django_celery_beat
```

### Problema: Tasks não executam no horário

**Causa:** Timezone incorreto

**Solução:** Verificar em `settings.py`:
```python
CELERY_TIMEZONE = 'America/Sao_Paulo'
TIME_ZONE = 'America/Sao_Paulo'
```

---

## 🔐 Segurança - Checklist

- [ ] `DEBUG=False` em produção
- [ ] `SECRET_KEY` forte e única (50+ caracteres)
- [ ] `ALLOWED_HOSTS` configurado corretamente
- [ ] `CORS_ALLOWED_ORIGINS` apenas domínios confiáveis
- [ ] Variáveis sensíveis (API keys) em Environment Variables
- [ ] PostgreSQL com credenciais fortes (Railway gera automaticamente)
- [ ] Redis com senha (Railway configura automaticamente)
- [ ] HTTPS habilitado (Railway faz automaticamente)

---

## 📈 Monitoramento

### Logs em Tempo Real

**Railway CLI:**
```bash
railway logs --service web
railway logs --service worker
railway logs --service beat
```

**Railway Dashboard:**
- Cada serviço tem aba **"Deployments" → "View Logs"**

### Métricas

**Railway Dashboard:**
- CPU usage
- Memory usage
- Network traffic
- Deployment status

### Alertas (Recomendado - Sentry)

Adicionar Sentry para tracking de erros:

```bash
pip install sentry-sdk
```

```python
# settings.py
import sentry_sdk

if not DEBUG:
    sentry_sdk.init(
        dsn=os.getenv('SENTRY_DSN'),
        environment='production',
        traces_sample_rate=0.1,
    )
```

---

## 🚀 Deploy Contínuo (CD)

Railway automaticamente faz deploy quando você:
1. Faz push para `main` branch
2. Merge pull request

**Desabilitar auto-deploy:**
- Vá em **Settings → Deploys**
- Desmarque **"Automatic Deploys"**

**Deploy manual:**
```bash
railway up
```

---

## 📋 Checklist Pré-Deploy

- [ ] Código commitado no GitHub
- [ ] `requirements.txt` atualizado com gunicorn
- [ ] `Procfile` criado
- [ ] `runtime.txt` criado (opcional)
- [ ] `GOOGLE_API_KEY` do Gemini obtida
- [ ] Conta Railway criada
- [ ] PostgreSQL add-on adicionado
- [ ] Redis add-on adicionado
- [ ] Variáveis de ambiente configuradas em TODOS os serviços
- [ ] Migrações rodadas (incluindo celery beat/results)
- [ ] Superuser criado
- [ ] Logs verificados (sem erros)
- [ ] Tasks visíveis no admin

---

## 🎯 Alternativas ao Railway

Se precisar de outras opções:

**1. Render.com** (Similar ao Railway)
- Também usa Procfile
- PostgreSQL/Redis grátis no tier free
- Interface mais simples

**2. Heroku**
- Pioneiro em PaaS
- Procfile nativo
- Mais caro que Railway

**3. DigitalOcean App Platform**
- Boa para escala
- Precisa de Dockerfile
- Mais controle

**4. AWS (EC2 + RDS + ElastiCache)**
- Máximo controle
- Mais complexo
- Requer DevOps

---

**Sistema pronto para deploy no Railway!** 🚀

Siga os passos acima e você terá:
- ✅ Django rodando com Gunicorn
- ✅ Celery Worker processando tasks
- ✅ Celery Beat agendando snapshots diários
- ✅ PostgreSQL com dados persistentes
- ✅ Redis como message broker
- ✅ Deploy automático via GitHub
