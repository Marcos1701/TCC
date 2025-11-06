# 🚀 Quick Start - Fase 3 (IA)

Guia rápido para configurar e testar o sistema de IA.

## 📋 Pré-requisitos

- Python 3.8+
- PostgreSQL (ou SQLite para dev)
- Ambiente virtual ativado

## 🔧 Setup (5 minutos)

### 1. Instalar Dependências

```bash
cd Api
pip install -r requirements.txt
```

Isso instalará:
- `google-generativeai>=0.8.3` ✅
- Outras dependências do projeto

### 2. Configurar Gemini API Key

**Obter chave gratuita:**
1. Acesse: https://aistudio.google.com/apikey
2. Faça login com conta Google
3. Clique em "Create API Key"
4. Copie a chave

**Adicionar ao .env:**

```bash
# Criar .env se não existir
cp .env.example .env

# Editar e adicionar sua chave
nano .env  # ou vim, code, etc
```

```env
GEMINI_API_KEY=sua-chave-aqui
```

### 3. Criar Usuário Admin

```bash
python create_admin.py
```

**Entrada esperada:**
```
Email: admin@example.com
Username: admin
Senha: admin123
```

**Saída:**
```
✅ Superusuário criado com sucesso!
   Email: admin@example.com
   Username: admin
   is_staff: True
   is_superuser: True
```

**Ou via Django:**

```bash
python manage.py createsuperuser
```

### 4. Iniciar Servidor

```bash
python manage.py runserver
```

## 🧪 Testar Funcionalidades

### 1. Login como Admin

```bash
POST http://localhost:8000/api/auth/login/
Content-Type: application/json

{
    "email": "admin@example.com",
    "password": "admin123"
}
```

**Resposta:**
```json
{
    "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
    "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

Copie o `access` token.

### 2. Gerar Missões com IA

```bash
POST http://localhost:8000/api/missions/generate_ai_missions/
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc...
Content-Type: application/json

{
    "tier": "BEGINNER"
}
```

**Resposta esperada (20 missões):**
```json
{
    "success": true,
    "total_created": 20,
    "results": {
        "BEGINNER": {
            "generated": 20,
            "created": 20,
            "missions": [
                {
                    "id": "uuid-aqui",
                    "title": "Desafio do Primeiro Passo",
                    "type": "SAVINGS",
                    "difficulty": "EASY",
                    "xp": 75
                }
            ]
        }
    }
}
```

**Gerar para todas as faixas (60 missões):**

```bash
POST http://localhost:8000/api/missions/generate_ai_missions/
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc...
Content-Type: application/json

{}
```

### 3. Testar Sugestão de Categoria

**Como usuário comum:**

```bash
POST http://localhost:8000/api/transactions/suggest_category/
Authorization: Bearer <user-token>
Content-Type: application/json

{
    "description": "Uber para o trabalho"
}
```

**Resposta:**
```json
{
    "suggested_category": {
        "id": "uuid",
        "name": "Transporte",
        "type": "EXPENSE",
        "confidence": 0.90
    }
}
```

### 4. Acessar Django Admin

```
http://localhost:8000/admin/
```

**Login:** admin@example.com / admin123

**Você pode:**
- Ver todas as missões geradas
- Editar missões manualmente
- Gerenciar usuários
- Ver logs de geração

## 🐍 Testar no Django Shell

```bash
python manage.py shell
```

**Teste 1: Verificar configuração**
```python
from finance.ai_services import model

if model:
    print("✅ Gemini configurado corretamente")
else:
    print("❌ Gemini API key não configurada")
```

**Teste 2: Gerar batch de missões**
```python
from finance.ai_services import generate_batch_missions_for_tier

batch = generate_batch_missions_for_tier('BEGINNER')
print(f"Geradas {len(batch)} missões")

# Ver primeira missão
if batch:
    m = batch[0]
    print(f"\nTítulo: {m['title']}")
    print(f"Tipo: {m['mission_type']}")
    print(f"Dificuldade: {m['difficulty']}")
    print(f"XP: {m['xp_reward']}")
    print(f"Duração: {m['duration_days']} dias")
```

**Teste 3: Criar missões no banco**
```python
from finance.ai_services import generate_batch_missions_for_tier, create_missions_from_batch

batch = generate_batch_missions_for_tier('INTERMEDIATE')
created = create_missions_from_batch('INTERMEDIATE', batch)

print(f"✅ {len(created)} missões criadas no banco de dados")
```

**Teste 4: Sugerir categoria**
```python
from finance.ai_services import suggest_category
from django.contrib.auth import get_user_model

User = get_user_model()
user = User.objects.first()  # Pegar primeiro usuário

category = suggest_category("Netflix mensal", user)
if category:
    print(f"✅ Categoria sugerida: {category.name}")
else:
    print("❌ Nenhuma categoria encontrada")
```

## 📊 Verificar Resultados

### Listar Missões Geradas

```bash
GET http://localhost:8000/api/missions/
Authorization: Bearer <token>
```

### Filtrar por Tipo

```bash
GET http://localhost:8000/api/missions/?mission_type=SAVINGS
```

### Ver Estatísticas

```python
# Django shell
from finance.models import Mission

total = Mission.objects.count()
por_tipo = Mission.objects.values('mission_type').annotate(
    count=Count('id')
)

print(f"Total de missões: {total}")
for item in por_tipo:
    print(f"  {item['mission_type']}: {item['count']}")
```

## ⚠️ Troubleshooting

### Erro: "Gemini API não configurada"

**Solução:**
```bash
# Verificar se existe
cat .env | grep GEMINI

# Se não existir, adicionar
echo "GEMINI_API_KEY=sua-chave-aqui" >> .env

# Reiniciar servidor
python manage.py runserver
```

### Erro: "Permission denied" ao gerar missões

**Causa:** Usuário não é admin/staff

**Solução:**
```python
# Django shell
from django.contrib.auth import get_user_model

User = get_user_model()
user = User.objects.get(email='seu@email.com')
user.is_staff = True
user.is_superuser = True
user.save()

print(f"✅ {user.email} agora é admin")
```

### Erro: JSON inválido da API Gemini

**Causa:** Resposta com markdown

**Solução:** Já tratado automaticamente no código, mas se persistir:

```python
# Verificar logs
tail -f logs/django.log | grep "ai_services"
```

### Rate limit excedido (429)

**Causa:** Tier gratuito tem limite de 15 req/min

**Solução:**
- Aguardar 1 minuto
- Usar cache (já implementado)
- Upgrade para tier pago (improvável com nosso uso)

## 💡 Dicas

### 1. Usar Postman/Insomnia

Facilita testar endpoints. Importar coleção:

```json
{
    "name": "Finance API - IA",
    "requests": [
        {
            "name": "Login Admin",
            "method": "POST",
            "url": "http://localhost:8000/api/auth/login/",
            "body": {
                "email": "admin@example.com",
                "password": "admin123"
            }
        },
        {
            "name": "Gerar Missões",
            "method": "POST",
            "url": "http://localhost:8000/api/missions/generate_ai_missions/",
            "headers": {
                "Authorization": "Bearer {{token}}"
            },
            "body": {
                "tier": "BEGINNER"
            }
        }
    ]
}
```

### 2. Limpar Missões Antigas

```python
# Django shell
from finance.models import Mission

# Deletar todas
Mission.objects.all().delete()

# Ou apenas de teste
Mission.objects.filter(title__contains='Teste').delete()
```

### 3. Monitorar Cache

```python
from django.core.cache import cache

# Ver todas as chaves
cache._cache.keys()  # SQLite cache

# Limpar cache
cache.clear()
```

## 📚 Próximos Passos

Depois de testar:

1. ✅ Gerar missões para produção
2. ✅ Configurar Celery para automação mensal
3. ✅ Ajustar prompts baseado em feedback
4. ✅ Adicionar campo `tier` no modelo Mission
5. ✅ Criar dashboard de métricas de IA

---

**Tempo estimado:** 5-10 minutos  
**Custo:** $0.00 (tier gratuito)  
**Dificuldade:** ⭐⭐☆☆☆
