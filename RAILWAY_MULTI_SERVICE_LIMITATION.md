# ⚠️ LIMITAÇÃO DO RAILWAY

O Railway **NÃO suporta**:
- Múltiplos serviços definidos em um único `railway.toml` ou `railway.json`
- Docker Compose nativo
- Auto-criação de serviços de um repositório

## Soluções Disponíveis

### ✅ Solução 1: Manual via Dashboard (Criar 1 vez, deploy automático depois)

**Criar serviços uma única vez:**

1. **No Railway Dashboard**, criar 4 serviços separados do mesmo repositório
2. Cada serviço aponta para o mesmo repo mas com configurações diferentes
3. **Depois disso**, cada `git push` deploya TODOS automaticamente

**Passos (fazer apenas UMA vez):**

```
1. Railway Dashboard → Seu Projeto
2. Clicar "+ New" 4 vezes
3. Cada vez selecionar "GitHub Repo" → Mesmo repositório

Serviço 1 - api:
  - Name: api
  - Settings → Build → Dockerfile Path: Api/Dockerfile
  - Settings → Deploy → Start Command: (vazio)
  
Serviço 2 - worker:
  - Name: worker  
  - Settings → Build → Dockerfile Path: Api/Dockerfile
  - Settings → Deploy → Start Command: /docker-entrypoint.sh worker
  
Serviço 3 - beat:
  - Name: beat
  - Settings → Build → Dockerfile Path: Api/Dockerfile
  - Settings → Deploy → Start Command: /docker-entrypoint.sh beat
  
Serviço 4 - frontend:
  - Name: frontend
  - Settings → Build → Dockerfile Path: Front/Dockerfile
  - Settings → Deploy → Start Command: (vazio)
```

**Depois desses passos iniciais:**
- ✅ `git push` → todos os 4 serviços deployam automaticamente
- ✅ Não precisa fazer nada manual novamente

### ✅ Solução 2: Railway CLI (Automação parcial)

```bash
# Instalar Railway CLI
npm install -g @railway/cli

# Login
railway login

# Link ao projeto
railway link

# Criar cada serviço (fazer 1 vez)
railway service create api
railway service create worker
railway service create beat  
railway service create frontend

# Depois disso, configurar cada um no Dashboard conforme Solução 1
```

### ❌ Solução 3: Monolito com Supervisord (NÃO recomendado)

Rodar todos os processos em um único container. **Não é boa prática**.

## 🎯 Recomendação

**Use a Solução 1** - É trivial criar os 4 serviços uma única vez no Dashboard.

**Benefícios:**
- ✅ Cada serviço escala independentemente
- ✅ Logs separados por serviço
- ✅ Restart policies individuais
- ✅ Depois de configurar, `git push` deploya tudo automaticamente

**Tempo estimado:** 10 minutos (fazer uma única vez)

## 📋 Guia Rápido (Setup Inicial)

```bash
# 1. Fazer push do código atual
git add .
git commit -m "feat: Railway multi-service configuration"
git push origin main

# 2. Abrir Railway Dashboard
open https://railway.app

# 3. No seu projeto:
#    - Add PostgreSQL
#    - Add Redis
#    - Criar 4 serviços (api, worker, beat, frontend)
#      conforme tabela acima
#    - Configurar variáveis de ambiente
#    - Wait for deploy

# Pronto! Daqui pra frente é só:
git push origin main  # ← Deploya tudo automaticamente
```

## 🔄 Fluxo Após Setup Inicial

```
Você faz alterações localmente
         ↓
    git push origin main
         ↓
Railway detecta push
         ↓
┌────────────────────────────┐
│ Build todos os 4 serviços: │
│  ✓ api                     │
│  ✓ worker                  │
│  ✓ beat                    │
│  ✓ frontend                │
└────────────────────────────┘
         ↓
Deploy automático de todos
```

## 💡 Alternativa: Monorepo com Railway Apps

Se você realmente quer 100% automatizado sem configuração manual:

1. Separar cada serviço em repositório próprio
2. Ou usar Railway Template (criar template customizado)

Mas **não vale a pena** - configurar uma vez no Dashboard é mais rápido.
