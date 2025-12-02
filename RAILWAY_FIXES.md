# 🔧 Correções Aplicadas no Deploy Railway

## Problema Identificado

O Railway estava tentando usar o **Procfile** ou **nixpacks.toml** ao invés do **Dockerfile**, causando o erro:
```
The executable `cd` could not be found.
```

Isso acontecia porque o Procfile tinha comandos como `cd Api && ...`, mas no container Docker o código já está em `/app`.

## Soluções Aplicadas

### 1. ✅ Dockerfile Corrigido

**Arquivo**: `Api/Dockerfile`

**Mudanças**:
- ✅ `COPY Api/requirements.txt .` - Caminho correto para build context no root
- ✅ `COPY Api/ .` - Copia apenas conteúdo do diretório Api para /app
- ✅ Script entrypoint copiado antes de mudar para non-root user
- ✅ `chmod +x` executado como root antes de USER directive

### 2. ✅ Procfile e Nixpacks Desabilitados

Para garantir que o Railway use **APENAS o Dockerfile**:

- `Procfile` → renomeado para `Procfile.disabled`
- `nixpacks.toml` → renomeado para `nixpacks.toml.disabled`

Estes arquivos podem causar conflito quando o Railway detecta múltiplas estratégias de build.

### 3. ✅ Railway Configuration

Certifique-se de que no **Railway Dashboard**:

1. **Settings → Build**
   - **Builder**: `DOCKERFILE` (não Nixpacks)
   - **Dockerfile Path**: `Api/Dockerfile`
   - **Build Context**: `.` (root do repositório)

2. **Settings → Deploy**
   - **Start Command**: deixar VAZIO (usar do Dockerfile)
   - Ou explicitamente: `/docker-entrypoint.sh gunicorn`

## Estrutura de Arquivos

```
TCC/
├── Api/
│   ├── Dockerfile          ← Usado para build
│   ├── requirements.txt
│   └── ...
├── scripts/
│   └── docker-entrypoint.sh  ← Entrypoint inteligente
├── railway.toml             ← Config do serviço API
├── railway-worker.toml      ← Config do Worker
├── railway-beat.toml        ← Config do Beat
├── railway-frontend.toml    ← Config do Frontend
├── Procfile.disabled        ← DESABILITADO (não usar)
└── nixpacks.toml.disabled   ← DESABILITADO (não usar)
```

## Próximos Passos

### 1. Commit e Push

```bash
git add .
git commit -m "fix: disable Procfile/nixpacks, use Docker exclusively"
git push origin main
```

### 2. Verificar Railway Dashboard

Após o push, no Railway Dashboard do serviço **api**:

1. Ir em **Settings → Build**
2. Verificar que mostra: **Builder: DOCKERFILE**
3. Se mostrar "NIXPACKS", mudar manualmente para "DOCKERFILE"

### 3. Redeploy

O deploy deve agora:
1. ✅ Build com sucesso
2. ✅ Container iniciar sem erro de `cd`
3. ✅ Migrations rodarem
4. ✅ Gunicorn iniciar
5. ✅ Healthcheck passar

### 4. Logs Esperados

```
🚀 Docker Entrypoint - Starting Django Service
🌐 Starting API Service (Gunicorn)
⏳ Waiting for database to be ready...
✅ Database is ready!
🔄 Running database migrations...
  Applying contenttypes.0001_initial... OK
  ...
🗄️  Creating cache table...
📦 Collecting static files...
✅ Database initialization complete!
🌐 Starting Gunicorn server on port 8080...
[INFO] Starting gunicorn 21.2.0
[INFO] Listening at: http://0.0.0.0:8080
[INFO] Booting worker with pid: 124
```

## Se Ainda Houver Problemas

### Erro: "Builder not found"

**Solução**: No Railway Dashboard, manualmente selecionar **DOCKERFILE** em Settings → Build

### Erro: "Dockerfile not found"

**Solução**: Verificar que **Dockerfile Path** está `Api/Dockerfile` e **Build Context** está `.`

### Erro: Ainda tentando usar Procfile

**Solução**: Deletar completamente Procfile e nixpacks.toml:
```bash
git rm Procfile.disabled nixpacks.toml.disabled
git commit -m "remove old build configs"
git push
```

## Reabilitar Procfile/Nixpacks (se necessário)

Se por algum motivo precisar voltar ao Procfile:

```bash
# Renomear de volta
mv Procfile.disabled Procfile
mv nixpacks.toml.disabled nixpacks.toml

# No Railway Dashboard:
# Settings → Build → Builder: NIXPACKS
```

Mas isso **não é recomendado** para deploy multi-serviço.

---

**Status**: ✅ Configuração corrigida e pronta para deploy!
