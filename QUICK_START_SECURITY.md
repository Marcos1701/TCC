# 🚀 Guia de Aplicação das Melhorias de Segurança

## ⚡ Aplicação Rápida (5 minutos)

### 1. Aplicar Migrações do Banco de Dados

```powershell
# No diretório Api/
cd c:\Users\marco\Arq\TCC\Api

# Ativar ambiente virtual (se usar)
# .\venv\Scripts\Activate.ps1

# Aplicar migrações
python manage.py migrate

# Verificar se aplicou corretamente
python manage.py showmigrations finance
```

**Resultado esperado**: 
```
[X] 0024_add_security_constraints
```

---

### 2. Verificar Configurações (Opcional)

Adicionar ao arquivo `.env` (se quiser customizar):

```bash
# Rate Limiting (valores padrão já configurados)
THROTTLE_ANON_RATE=100
THROTTLE_USER_RATE=2000
THROTTLE_BURST_RATE=60

# Logging
DJANGO_LOG_LEVEL=INFO
```

---

### 3. Reiniciar Servidor da API

```powershell
# Parar servidor atual (Ctrl+C)
# Iniciar novamente
python manage.py runserver
```

---

### 4. Testar Frontend (Flutter)

```powershell
# No diretório Front/
cd c:\Users\marco\Arq\TCC\Front

# Limpar cache (recomendado)
flutter clean
flutter pub get

# Executar
flutter run
```

---

## ✅ Testes de Validação

### Teste 1: Primeiro Acesso
1. Registrar novo usuário
2. Verificar se onboarding aparece
3. Completar onboarding
4. Fazer logout e login novamente
5. ✅ Onboarding NÃO deve aparecer novamente

### Teste 2: Validações de Transação
1. Tentar criar transação com valor negativo
2. ✅ Deve mostrar erro: "O valor deve ser maior que zero"
3. Tentar criar transação com valor absurdo (> 1 bilhão)
4. ✅ Deve mostrar erro: "Valor muito alto"

### Teste 3: Permissões
1. Criar transação
2. Tentar acessar endpoint direto com ID de outro usuário (Postman/curl)
3. ✅ Deve retornar 404 ou 403 (não 200)

### Teste 4: Rate Limiting
1. Fazer muitas requisições rápidas (>60/minuto)
2. ✅ Deve receber erro 429 (Too Many Requests)

---

## 🔍 Monitoramento

### Ver Logs de Segurança

```powershell
# Durante execução do servidor, procurar por:
# - "Unauthorized access attempt"
# - "User X completed first access"
# - "New user profile created"
```

### Verificar Constraints no Banco

```bash
# PostgreSQL
python manage.py dbshell

# Ver constraints da tabela Transaction
\d finance_transaction

# Ver constraints da tabela Goal
\d finance_goal
```

---

## 🐛 Resolução de Problemas

### Erro: "Migration already applied"
```powershell
# Criar nova migration com outro nome
python manage.py makemigrations --name add_security_v2
python manage.py migrate
```

### Erro: "Constraint violation"
```powershell
# Se houver dados inválidos existentes, limpar antes:
python manage.py shell

# No shell Python:
from finance.models import Transaction
# Deletar transações com valor <= 0 (se houver)
Transaction.objects.filter(amount__lte=0).delete()

# Aplicar migration novamente
exit()
python manage.py migrate
```

### Erro: "is_first_access not working"
```powershell
# Verificar se campo existe
python manage.py shell

from finance.models import UserProfile
profile = UserProfile.objects.first()
print(profile.is_first_access)  # Deve imprimir True ou False

# Se não existir, rodar migração específica
python manage.py migrate finance 0022_add_is_first_access_field
python manage.py migrate finance 0023_set_existing_users_not_first_access
```

---

## 📊 Status Atual

### ✅ Implementado e Funcionando
- [x] Permissões de ownership em ViewSets críticos
- [x] Rate limiting configurado
- [x] Validações de dados (constraints + serializers)
- [x] Logging de segurança
- [x] Correção do fluxo de primeiro acesso
- [x] Índices otimizados

### ⚠️ Pendente (Próxima Sprint)
- [ ] Migração para UUIDs (planejamento necessário)
- [ ] Soft delete
- [ ] Testes automatizados de segurança

---

## 🎯 Próximos Passos

1. **Aplicar migrations** ✅ (5 min)
2. **Testar primeiro acesso** ✅ (5 min)
3. **Testar validações** ✅ (5 min)
4. **Monitorar logs** (contínuo)
5. **Planejar migração UUID** (próxima sprint)

---

## 📞 Suporte

Se encontrar problemas:
1. Verificar logs do servidor Django
2. Verificar logs do Flutter (console)
3. Verificar se migrations foram aplicadas: `python manage.py showmigrations`
4. Verificar se todas as dependências estão instaladas: `pip list`

---

## 🔐 Checklist de Segurança

Antes de ir para produção:
- [ ] Todas as migrations aplicadas
- [ ] Rate limiting configurado e testado
- [ ] Logging de segurança ativado (DJANGO_LOG_LEVEL=INFO)
- [ ] Primeiro acesso testado com novo usuário
- [ ] Validações de dados testadas
- [ ] SECRET_KEY forte configurado
- [ ] DEBUG=False em produção
- [ ] ALLOWED_HOSTS configurado
- [ ] CORS_ALLOWED_ORIGINS configurado corretamente
