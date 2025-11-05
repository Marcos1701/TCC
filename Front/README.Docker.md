# Docker para TCC Frontend (Flutter Web)

Este documento descreve como construir e executar o frontend Flutter usando Docker.

## 🏗️ Arquitetura do Dockerfile

O Dockerfile usa **multi-stage build** para otimizar o tamanho da imagem:

### Stage 1: Build
- Base: `debian:bullseye-slim`
- Instala o Flutter SDK
- Executa `flutter pub get` e `flutter build web`
- Gera os arquivos estáticos otimizados

### Stage 2: Production
- Base: `nginx:1.25-alpine`
- Serve os arquivos estáticos compilados
- Configuração Nginx otimizada com compressão e cache
- Executa como usuário não-root
- Inclui health check

## 🚀 Como Usar

### Build da Imagem

```bash
# Build com URL da API padrão
docker build -t tcc-frontend:latest .

# Build com URL customizada da API
docker build --build-arg API_BASE_URL=https://sua-api.com -t tcc-frontend:latest .
```

### Executar o Container

```bash
# Executar na porta 3000
docker run -d -p 3000:80 --name tcc-frontend tcc-frontend:latest

# Executar com variáveis de ambiente
docker run -d -p 3000:80 \
  --name tcc-frontend \
  tcc-frontend:latest
```

### Usando Docker Compose

```bash
# Iniciar
docker-compose up -d

# Ver logs
docker-compose logs -f frontend

# Parar
docker-compose down

# Rebuild e restart
docker-compose up -d --build
```

### Configurar API URL

Você pode configurar a URL da API de duas formas:

**1. Durante o build:**
```bash
docker build --build-arg API_BASE_URL=https://sua-api.com -t tcc-frontend:latest .
```

**2. No docker-compose.yml:**
```bash
# Criar arquivo .env na raiz do Front
echo "API_BASE_URL=https://sua-api.com" > .env

# Ou exportar variável de ambiente
export API_BASE_URL=https://sua-api.com
docker-compose up -d
```

## 🔍 Verificações

### Health Check
```bash
# Verificar status
docker ps

# Testar health check manualmente
curl http://localhost:3000/health
```

### Logs
```bash
# Ver logs do container
docker logs tcc-frontend

# Seguir logs em tempo real
docker logs -f tcc-frontend
```

### Inspecionar Container
```bash
# Informações do container
docker inspect tcc-frontend

# Estatísticas de recursos
docker stats tcc-frontend
```

## 🛠️ Desenvolvimento

### Build Local para Testes
```bash
# Build rápido sem cache
docker build --no-cache -t tcc-frontend:dev .

# Build com target específico
docker build --target build -t tcc-frontend:build .
```

### Acessar o Container
```bash
# Executar shell no container
docker exec -it tcc-frontend sh

# Ver estrutura de arquivos
docker exec tcc-frontend ls -la /usr/share/nginx/html
```

## 📊 Otimizações Implementadas

### Imagem
- ✅ Multi-stage build (reduz tamanho final)
- ✅ Base image minimal (Alpine Linux)
- ✅ Layer caching otimizado
- ✅ .dockerignore abrangente

### Segurança
- ✅ Usuário não-root
- ✅ Security headers no Nginx
- ✅ Sem secrets na imagem
- ✅ Health check implementado

### Performance
- ✅ Gzip compression habilitado
- ✅ Cache de assets estáticos (1 ano)
- ✅ Cache de HTML desabilitado
- ✅ Compressão de assets

### Nginx
- ✅ Configuração otimizada
- ✅ Suporte a rotas do Flutter
- ✅ Headers de segurança
- ✅ Compressão gzip

## 📦 Tamanho da Imagem

```bash
# Ver tamanho da imagem
docker images tcc-frontend

# Esperado:
# Build stage: ~2GB (não incluído no final)
# Production: ~50-100MB (apenas Nginx + arquivos web)
```

## 🔐 Segurança

### Verificação de Vulnerabilidades
```bash
# Instalar Trivy
# Windows (via scoop):
scoop install trivy

# Escanear imagem
trivy image tcc-frontend:latest

# Escanear apenas vulnerabilidades HIGH e CRITICAL
trivy image --severity HIGH,CRITICAL tcc-frontend:latest
```

### Verificar Dockerfile
```bash
# Instalar Hadolint
# Windows (via scoop):
scoop install hadolint

# Verificar Dockerfile
hadolint Dockerfile
```

## 🚢 Deploy em Produção

### Registry
```bash
# Tag para registry
docker tag tcc-frontend:latest seu-registry.com/tcc-frontend:v1.0.0

# Push para registry
docker push seu-registry.com/tcc-frontend:v1.0.0
```

### Variáveis de Ambiente
Para produção, configure:
- `API_BASE_URL`: URL da API em produção

## 🐛 Troubleshooting

### Container não inicia
```bash
# Ver logs detalhados
docker logs tcc-frontend

# Verificar configuração do Nginx
docker exec tcc-frontend cat /etc/nginx/conf.d/default.conf

# Testar configuração do Nginx
docker exec tcc-frontend nginx -t
```

### Problemas de permissão
```bash
# Verificar usuário
docker exec tcc-frontend whoami

# Verificar permissões
docker exec tcc-frontend ls -la /usr/share/nginx/html
```

### Build muito lento
```bash
# Limpar cache do Docker
docker builder prune

# Build sem cache
docker build --no-cache -t tcc-frontend:latest .
```

## 📝 Notas

- O build do Flutter pode levar alguns minutos na primeira vez
- Certifique-se de ter espaço em disco suficiente (~3GB para build)
- O container usa ~50-100MB de RAM em execução normal
- O health check verifica a cada 30 segundos
