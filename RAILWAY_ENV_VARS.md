# Variáveis de Ambiente - Railway

## 📋 Configuração Obrigatória

Copie e cole estas variáveis em **TODOS os 3 serviços** (web, worker, beat):

### 1. Django Core

```env
# Gerar com: python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
SECRET_KEY=django-insecure-SUBSTITUA_POR_UMA_CHAVE_SEGURA_DE_50_CHARS

DEBUG=False

# Railway injeta automaticamente o domínio, mas você pode adicionar mais
ALLOWED_HOSTS=*.railway.app,*.up.railway.app

DJANGO_SETTINGS_MODULE=config.settings

# Indica que está rodando no Railway (usado no settings.py)
RAILWAY_ENVIRONMENT=production
```

### 2. CORS (Frontend)

```env
# Adicione os domínios do seu frontend Flutter Web
CORS_ALLOWED_ORIGINS=https://seu-frontend.vercel.app,https://outro-dominio.com

# Ou permita todos (NÃO recomendado em produção)
# CORS_ALLOW_ALL_ORIGINS=True
```

### 3. Google Gemini AI

```env
# Obtenha em: https://aistudio.google.com/app/apikey
GOOGLE_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### 4. Database e Redis (Auto-configurados)

**Estas variáveis são INJETADAS AUTOMATICAMENTE pelo Railway quando você adiciona os add-ons:**

```env
# PostgreSQL (criado automaticamente pelo add-on)
DATABASE_URL=postgresql://postgres:xxxxx@containers-us-west-xx.railway.app:5432/railway

# Redis (criado automaticamente pelo add-on)
REDIS_URL=redis://default:xxxxx@containers-us-west-xx.railway.app:6379
```

**⚠️ IMPORTANTE:** Você NÃO precisa adicionar DATABASE_URL e REDIS_URL manualmente! Railway faz isso automaticamente.

---

## 🔐 Como Gerar SECRET_KEY

### Método 1: Python (Recomendado)

```bash
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

Exemplo de saída:
```
django-insecure-r8$k3#mf9@x^2w!p&7v+c%n*4q6h-s5j=u1a0z9y8t7e
```

### Método 2: Online

Acesse: https://djecrety.ir/

---

## 🌐 Como Obter GOOGLE_API_KEY

1. Acesse: https://aistudio.google.com/app/apikey
2. Clique em "Create API Key"
3. Escolha ou crie um projeto Google Cloud
4. Copie a chave gerada (começa com `AIzaSy...`)
5. Cole em `GOOGLE_API_KEY` no Railway

**⚠️ Importante:** Não compartilhe esta chave publicamente!

---

## 🚀 Template Completo para Copiar

### Para Serviço WEB:

```env
SECRET_KEY=GERAR_AQUI_COM_O_COMANDO_ACIMA
DEBUG=False
ALLOWED_HOSTS=*.railway.app,*.up.railway.app
DJANGO_SETTINGS_MODULE=config.settings
RAILWAY_ENVIRONMENT=production
CORS_ALLOWED_ORIGINS=https://seu-frontend.vercel.app
GOOGLE_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### Para Serviço WORKER:

```env
SECRET_KEY=MESMA_CHAVE_DO_WEB
DEBUG=False
DJANGO_SETTINGS_MODULE=config.settings
RAILWAY_ENVIRONMENT=production
GOOGLE_API_KEY=MESMA_CHAVE_DO_WEB
```

### Para Serviço BEAT:

```env
SECRET_KEY=MESMA_CHAVE_DO_WEB
DEBUG=False
DJANGO_SETTINGS_MODULE=config.settings
RAILWAY_ENVIRONMENT=production
GOOGLE_API_KEY=MESMA_CHAVE_DO_WEB
```

---

## 🎯 Passo a Passo no Railway

1. **No serviço WEB:**
   - Vá em **Settings → Variables**
   - Clique em **"+ New Variable"**
   - Adicione cada variável acima
   - Clique em **"Add"**

2. **No serviço WORKER:**
   - Repita o processo
   - Use as mesmas variáveis (exceto CORS e ALLOWED_HOSTS)

3. **No serviço BEAT:**
   - Repita o processo
   - Use as mesmas variáveis (exceto CORS e ALLOWED_HOSTS)

---

## ✅ Verificar Configuração

### Via Railway Dashboard:

1. Acesse cada serviço
2. Vá em **Settings → Variables**
3. Verifique se todas estão presentes
4. Clique em **"Deploy"** para aplicar

### Via Logs:

Após deploy, verifique os logs:

```
# Serviço Web - Deve mostrar:
Starting gunicorn 21.x.x
Booting worker with pid: xxxx
```

```
# Serviço Worker - Deve mostrar:
Connected to redis://containers-us-west-xxx.railway.app:6379/0
celery@worker-xxx ready.
```

```
# Serviço Beat - Deve mostrar:
DatabaseScheduler: Schedule changed.
Writing entries (3)...
```

Se aparecer algum erro relacionado a variáveis, verifique se todas foram configuradas corretamente.

---

## 🔒 Segurança

### ❌ NÃO FAZER:

- Commitar `.env` para Git
- Compartilhar `SECRET_KEY` publicamente
- Usar `DEBUG=True` em produção
- Usar `CORS_ALLOW_ALL_ORIGINS=True` em produção

### ✅ FAZER:

- Usar variáveis de ambiente no Railway
- Gerar `SECRET_KEY` única para produção
- Manter `DEBUG=False`
- Listar domínios específicos em `CORS_ALLOWED_ORIGINS`
- Rotacionar API keys regularmente

---

## 📊 Variáveis Opcionais (Avançadas)

### Email (para notificações, reset de senha, etc.):

```env
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=seu-email@gmail.com
EMAIL_HOST_PASSWORD=sua-senha-de-app
DEFAULT_FROM_EMAIL=noreply@seuapp.com
```

### Sentry (Monitoramento de erros):

```env
SENTRY_DSN=https://xxxxx@o123456.ingest.sentry.io/123456
SENTRY_ENVIRONMENT=production
```

### AWS S3 (Para arquivos estáticos/media):

```env
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_STORAGE_BUCKET_NAME=seu-bucket
AWS_S3_REGION_NAME=us-east-1
```

---

## 🆘 Troubleshooting

### Erro: "Invalid HTTP_HOST header"

**Causa:** `ALLOWED_HOSTS` não inclui domínio do Railway

**Solução:**
```env
ALLOWED_HOSTS=*.railway.app,*.up.railway.app,seu-dominio-custom.com
```

### Erro: "CORS policy blocked"

**Causa:** Frontend não está em `CORS_ALLOWED_ORIGINS`

**Solução:**
```env
CORS_ALLOWED_ORIGINS=https://seu-frontend-real.vercel.app
```

### Erro: "SECRET_KEY must be set"

**Causa:** Variável `SECRET_KEY` não configurada

**Solução:** Adicione a variável com uma chave gerada

### Erro: "google.generativeai.types.generation_types.BlockedPromptException"

**Causa:** `GOOGLE_API_KEY` inválida ou não configurada

**Solução:** 
1. Verifique se a chave está correta
2. Verifique se a API do Gemini está habilitada no Google Cloud

---

**Variáveis configuradas = Deploy pronto!** 🎉
