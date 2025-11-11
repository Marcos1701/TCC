# Quick Start Guide - GenApp

Guia rápido para começar a usar a aplicação GenApp.

## Opção 1: Docker (Recomendado)

### Requisitos
- Docker 20.10+
- Docker Compose 2.0+

### Passos

```bash
# 1. Clone o repositório
git clone <url-do-repositorio>
cd TCC

# 2. Configure as variáveis de ambiente
cp .env.example .env
# Edite o .env e configure:
# - DJANGO_SECRET_KEY (gere um novo)
# - POSTGRES_PASSWORD (senha segura)
# - GEMINI_API_KEY (obtenha em https://aistudio.google.com/apikey)

# 3. Inicie os containers
docker-compose up -d

# 4. Aguarde os serviços iniciarem (30-60 segundos)
docker-compose ps

# 5. Execute as migrações
docker-compose exec api python manage.py migrate
docker-compose exec api python manage.py createcachetable

# 6. Crie um superusuário
docker-compose exec api python manage.py createsuperuser

# 7. Acesse a aplicação
# Backend API: http://localhost:8000
# Admin: http://localhost:8000/admin
# Frontend: http://localhost:3000
```

## Opção 2: Manual (Desenvolvimento)

### Requisitos Backend
- Python 3.11+
- PostgreSQL 14+ (ou Docker)
- Redis (ou Docker)

### Passos Backend

```bash
# 1. Configurar ambiente Python
cd Api
python -m venv venv
venv\Scripts\activate  # Windows
pip install -r requirements.txt

# 2. Configurar PostgreSQL (com Docker)
docker run -d --name genapp-postgres \
  -e POSTGRES_PASSWORD=postgres123 \
  -e POSTGRES_DB=finance_db \
  -p 5432:5432 postgres:16-alpine

# 3. Configurar Redis (com Docker)
docker run -d --name genapp-redis -p 6379:6379 redis:7-alpine

# 4. Configurar .env
cp .env.example .env
# Editar .env com as configurações corretas

# 5. Executar migrações
python manage.py migrate
python manage.py createcachetable
python manage.py createsuperuser

# 6. Iniciar servidor
python manage.py runserver

# 7. Em terminais separados, iniciar Celery
# Terminal 2:
celery -A config worker -l info --pool=solo  # Windows
# Terminal 3:
celery -A config beat -l info
```

### Requisitos Frontend
- Flutter 3.5+

### Passos Frontend

```bash
# 1. Instalar dependências
cd Front
flutter pub get

# 2. Executar aplicativo
flutter run -d chrome  # Web
# ou
flutter run  # Mobile (com emulador rodando)
```

## Próximos Passos

1. **Criar categorias**: Acesse a aplicação e crie suas primeiras categorias de receitas e despesas
2. **Registrar transações**: Adicione transações para começar a rastrear suas finanças
3. **Configurar metas**: Defina metas de TPS, RDR e ILI no seu perfil
4. **Completar missões**: Aceite e complete missões para ganhar XP

## Comandos Úteis

### Docker

```bash
# Ver logs
docker-compose logs -f api

# Parar serviços
docker-compose down

# Rebuild
docker-compose build

# Acessar shell do Django
docker-compose exec api python manage.py shell

# Executar testes
docker-compose exec api python manage.py test
```

### Manual

```bash
# Criar cache table (primeira vez)
python manage.py createcachetable

# Criar migrações
python manage.py makemigrations

# Aplicar migrações
python manage.py migrate

# Acessar shell
python manage.py shell

# Executar testes
python manage.py test
```

## Troubleshooting

### "connection refused" ao acessar API

```bash
# Verificar se API está rodando
docker-compose ps api
# ou
curl http://localhost:8000/admin/
```

### "relation does not exist"

```bash
# Executar migrações
docker-compose exec api python manage.py migrate
```

### "cache table not found"

```bash
# Criar cache table
docker-compose exec api python manage.py createcachetable
```

### Celery não processa tasks

```bash
# Verificar Redis
docker-compose exec redis redis-cli ping

# Ver logs do worker
docker-compose logs -f celery-worker
```

## Gerar DJANGO_SECRET_KEY

```bash
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

## Obter GEMINI_API_KEY

1. Acesse: https://aistudio.google.com/apikey
2. Faça login com conta Google
3. Crie uma API Key
4. Copie e cole no `.env`

## Suporte

Para problemas ou dúvidas, consulte:
- README.md principal
- VALIDATION_REPORT.md
- Documentação do código
