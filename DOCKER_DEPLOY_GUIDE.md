# 🐳 Guia de Deploy com Docker

Este documento descreve as correções aplicadas aos Dockerfiles e como realizar o deploy corretamente.

## 📋 Resumo das Correções Aplicadas

### 1. **API - Dockerfile** (`Api/Dockerfile`)

#### Problemas Corrigidos:
- ✅ Adicionado `netcat-openbsd` para healthchecks de rede
- ✅ Adicionado HEALTHCHECK interno do Docker
- ✅ Corrigido line endings (CRLF → LF) no entrypoint
- ✅ Variáveis de ambiente configuráveis (`PORT`, `WORKERS`, `TIMEOUT`)
- ✅ Endpoint de health check adicionado (`/api/health/`)

#### Variáveis de Ambiente Importantes:
```env
# Obrigatórias em produção
SECRET_KEY=sua-chave-secreta-aqui
DATABASE_URL=postgresql://user:pass@host:5432/dbname

# Opcionais (com defaults)
PORT=8000
WORKERS=4
TIMEOUT=120
CELERY_CONCURRENCY=2
```

### 2. **API - docker-entrypoint.sh**

#### Problemas Corrigidos:
- ✅ Suporte a `psycopg` e `psycopg2` (fallback automático)
- ✅ Validação de variáveis de ambiente críticas
- ✅ Suporte a variáveis individuais (`DB_HOST`, `DB_NAME`, etc.) além de `DATABASE_URL`
- ✅ Melhor tratamento de erros com mensagens claras
- ✅ Configuração de workers baseada em variáveis de ambiente
- ✅ Flags adicionais no Celery para melhor performance

### 3. **Frontend - Dockerfile** (`Front/Dockerfile`)

#### Problemas Corrigidos:
- ✅ **Versão do Flutter corrigida**: `3.35.5` → `3.24.5` (versão compatível com SDK ^3.5.2)
- ✅ Base image atualizada: `debian:bullseye-slim` → `debian:bookworm-slim`
- ✅ URL padrão da API corrigida (adicionado protocolo `https://`)
- ✅ Build com fallback caso source-maps falhe
- ✅ Verificação do output do build
- ✅ Nginx configurado para arquivos `.wasm`
- ✅ Tratamento do `flutter_service_worker.js`
- ✅ Instalação do `wget` para healthcheck

### 4. **docker-compose.yml**

#### Problemas Corrigidos:
- ✅ Locale do PostgreSQL corrigido (`pt_BR.UTF-8` → `C`)
- ✅ Redis com limite de memória configurado
- ✅ Removido volume bind mount de desenvolvimento (`./Api:/app`)
- ✅ Celery worker e beat agora dependem da API estar saudável
- ✅ Healthcheck do frontend corrigido
- ✅ Variáveis de banco passadas explicitamente

---

## 🚀 Como Fazer Deploy

### Deploy Local (Desenvolvimento)

```bash
# Criar arquivo .env na pasta Api/
cp Api/.env.example Api/.env
# Editar com suas configurações

# Subir todos os serviços
docker-compose up -d

# Ver logs
docker-compose logs -f

# Ver logs de serviço específico
docker-compose logs -f api
docker-compose logs -f celery-worker
docker-compose logs -f frontend
```

### Deploy no Railway

#### Configuração de Variáveis de Ambiente (Railway)

**Para o serviço API:**
```env
SECRET_KEY=gere-uma-chave-segura
DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
CELERY_BROKER_URL=${{Redis.REDIS_URL}}
DJANGO_DEBUG=False
ALLOWED_HOSTS=*.railway.app,*.up.railway.app
PORT=8000
WORKERS=2
```

**Para o serviço Worker:**
```env
SECRET_KEY=${{API.SECRET_KEY}}
DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
CELERY_BROKER_URL=${{Redis.REDIS_URL}}
CELERY_CONCURRENCY=2
```

**Para o serviço Beat:**
```env
SECRET_KEY=${{API.SECRET_KEY}}
DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
CELERY_BROKER_URL=${{Redis.REDIS_URL}}
```

**Para o Frontend:**
```env
API_BASE_URL=https://seu-servico-api.up.railway.app
```

#### Comandos de Start (Railway)

- **API**: `gunicorn` (usa o entrypoint padrão)
- **Worker**: `worker` (argumento para o entrypoint)
- **Beat**: `beat` (argumento para o entrypoint)
- **Frontend**: Não precisa (usa CMD do Dockerfile)

---

## 🔍 Troubleshooting

### Problema: Build do Flutter falha

**Sintoma:** Erro de versão incompatível do Dart/Flutter

**Solução:** Verifique se a versão do Flutter no Dockerfile é compatível com o `pubspec.yaml`:
```yaml
# pubspec.yaml
environment:
  sdk: ^3.5.2  # Requer Flutter 3.24.x
```

### Problema: Conexão com banco de dados falha

**Sintoma:** `Database connection timeout!`

**Soluções:**
1. Verifique se `DATABASE_URL` está correto
2. Verifique se o banco está acessível na rede
3. Aumente o tempo de retry no entrypoint

### Problema: Worker/Beat não inicia

**Sintoma:** Celery não consegue conectar ao Redis

**Soluções:**
1. Verifique `REDIS_URL` e `CELERY_BROKER_URL`
2. Garanta que Redis está rodando antes do worker
3. No Railway, use a referência `${{Redis.REDIS_URL}}`

### Problema: Frontend retorna 404

**Sintoma:** Rotas não funcionam após refresh

**Solução:** Verifique a configuração do nginx em `try_files`:
```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

### Problema: CORS errors no frontend

**Sintoma:** Requisições à API bloqueadas

**Solução:** Configure `CORS_ALLOWED_ORIGINS` na API:
```python
CORS_ALLOWED_ORIGINS = [
    "https://seu-frontend.up.railway.app",
]
```

---

## 📊 Health Checks

### Endpoints de Health Check

| Serviço | Endpoint | Resposta Esperada |
|---------|----------|-------------------|
| API | `/api/health/` | `{"status":"healthy","service":"genapp-api"}` |
| Frontend | `/health` | `{"status":"healthy","service":"genapp-frontend"}` |

### Verificar Status dos Containers

```bash
# Ver status de todos os containers
docker-compose ps

# Ver healthcheck de um container
docker inspect --format='{{json .State.Health}}' genapp-api | jq

# Testar endpoint manualmente
curl http://localhost:8000/api/health/
curl http://localhost:3000/health
```

---

## 🔒 Segurança

### Headers de Segurança (Nginx)
O frontend inclui headers de segurança:
- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: no-referrer-when-downgrade`
- `Permissions-Policy` (restringe APIs sensíveis)

### Usuário Non-Root
Todos os containers rodam com usuários não-root:
- API: `appuser` (UID 1000)
- Frontend: `appuser` (Alpine nginx)

---

## 📁 Estrutura de Arquivos Docker

```
TCC/
├── docker-compose.yml          # Orquestração de containers
├── Api/
│   ├── Dockerfile              # Build multi-stage para produção
│   ├── Dockerfile.dev          # Build para desenvolvimento
│   ├── docker-entrypoint.sh    # Script de inicialização
│   └── requirements.txt        # Dependências Python
├── Front/
│   ├── Dockerfile              # Build multi-stage para produção
│   ├── Dockerfile.simple       # Build simplificado (usa imagem Flutter pronta)
│   └── pubspec.yaml            # Dependências Flutter
└── scripts/
    └── init-db.sql             # Script de inicialização do banco
```

---

## 📝 Notas de Versão

### v1.1.0 (Dezembro 2024)
- Corrigida versão do Flutter (3.35.5 → 3.24.5)
- Adicionado suporte a psycopg e psycopg2
- Melhorado healthcheck com endpoints dedicados
- Configurações de ambiente mais flexíveis
- Melhor tratamento de erros no entrypoint
