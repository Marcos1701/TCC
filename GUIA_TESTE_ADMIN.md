# Guia de Teste - Sistema de Administração

## 🎯 Objetivo

Este guia fornece instruções passo a passo para testar o sistema de administração implementado.

## 📋 Pré-requisitos

1. Backend Django rodando
2. Flutter app compilado e rodando
3. Usuário com permissões de admin:
   - `is_staff = True` ou `is_superuser = True`

## 🔧 Preparação

### 1. Criar Usuário Administrador

**Opção A: Via Django Admin**
```bash
cd Api
python manage.py createsuperuser
```

**Opção B: Via Script Python**
```python
# Api/create_admin.py já existe
python create_admin.py
```

**Opção C: Via Django Shell**
```bash
python manage.py shell
```
```python
from django.contrib.auth import get_user_model
User = get_user_model()
user = User.objects.create_user(
    username='admin',
    email='admin@example.com',
    password='admin123'
)
user.is_staff = True
user.is_superuser = True
user.save()
```

### 2. Verificar Backend está Rodando

```bash
cd Api
python manage.py runserver
```

Testar endpoint de stats:
```bash
# Terminal com curl ou Postman
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     http://localhost:8000/admin/stats/overview/
```

### 3. Compilar Flutter App

```bash
cd Front
flutter pub get
flutter run
```

## 🧪 Roteiro de Testes

### Teste 1: Login como Administrador

**Passos:**
1. Abrir app Flutter
2. Fazer login com credenciais de admin
3. Ir para Settings (Configurações)
4. Verificar se aparece o botão "Administração"

**Resultado Esperado:**
- ✅ Botão "Administração" visível
- ✅ Ícone de admin shield ao lado do botão

**Se falhar:**
- Verificar se `is_staff` ou `is_superuser` está `True` no banco
- Verificar se backend está retornando esses campos no `/profile/`

---

### Teste 2: Acessar Dashboard

**Passos:**
1. Clicar no botão "Administração"
2. Observar o carregamento
3. Verificar se as métricas aparecem

**Resultado Esperado:**
- ✅ 4 cards de métricas principais:
  - Total de Usuários
  - Missões Completadas
  - Missões Ativas
  - Nível Médio
- ✅ 3 botões de ação rápida
- ✅ Seção de estatísticas de missões
- ✅ Feed de atividade recente

**Se falhar:**
- Verificar logs do Flutter (procurar por erros HTTP)
- Testar endpoint `/admin/stats/overview/` diretamente
- Verificar se JWT token está sendo enviado

---

### Teste 3: Estatísticas de Missões

**Passos:**
1. No dashboard, observar seção "Estatísticas de Missões"
2. Verificar contadores por tier
3. Verificar contadores por tipo

**Resultado Esperado:**
- ✅ Missões por Nível:
  - Iniciante: X missões
  - Intermediário: Y missões
  - Avançado: Z missões
- ✅ Missões por Tipo:
  - Economia: X
  - Controle de Gastos: Y
  - Redução de Dívidas: Z
  - Onboarding: W
- ✅ Taxa de conclusão em %

**Dados de Teste:**
```python
# Django shell para criar dados de teste
from finance.models import Mission, MissionProgress

# Ver quantas missões existem
Mission.objects.count()

# Ver progresso
MissionProgress.objects.filter(status='COMPLETED').count()
```

---

### Teste 4: Atividade Recente

**Passos:**
1. Completar uma missão como usuário regular
2. Voltar ao dashboard admin
3. Puxar para atualizar (pull-to-refresh)
4. Verificar se aparece no feed

**Resultado Esperado:**
- ✅ Feed mostra últimas completadas
- ✅ Informações corretas:
  - Nome do usuário
  - Nome da missão
  - Data/hora
  - XP ganho

---

### Teste 5: Gerenciamento de Missões

**Passos:**
1. No dashboard, clicar em "Gerenciar Missões"
2. Observar listagem completa
3. Testar filtros

**Resultado Esperado:**
- ✅ Lista todas as missões
- ✅ Filtro por tipo funciona
- ✅ Filtro por dificuldade funciona
- ✅ Contador atualiza ao filtrar

**Filtros para testar:**
- [ ] TODAS + TODAS (deve mostrar todas)
- [ ] ECONOMIA + TODAS
- [ ] TODAS + FÁCIL
- [ ] CONTROLE DE GASTOS + MÉDIA

---

### Teste 6: Toggle de Missões

**Passos:**
1. Na lista de missões, escolher uma ativa
2. Clicar no switch para desativar
3. Observar animação e feedback
4. Atualizar página
5. Verificar se permanece desativada

**Resultado Esperado:**
- ✅ Switch muda de estado visualmente
- ✅ Toast ou snackbar de confirmação
- ✅ Estado persiste após reload
- ✅ Backend atualiza corretamente

**Teste Backend:**
```bash
# Verificar no banco
python manage.py shell
```
```python
from finance.models import Mission
mission = Mission.objects.get(id='MISSION_ID')
print(mission.is_active)  # Deve refletir a mudança
```

---

### Teste 7: Gerenciamento de Categorias

**Passos:**
1. No dashboard, clicar em "Gerenciar Categorias"
2. Observar listagem agrupada
3. Testar filtros por tipo

**Resultado Esperado:**
- ✅ Categorias agrupadas por tipo
- ✅ Ícones apropriados para cada categoria
- ✅ Cores personalizadas visíveis
- ✅ Labels de grupo traduzidos

**Filtros para testar:**
- [ ] TODAS (mostra todas agrupadas)
- [ ] RECEITA (mostra apenas receitas)
- [ ] DESPESA (mostra apenas despesas)
- [ ] DÍVIDA (mostra apenas dívidas)

---

### Teste 8: Pull-to-Refresh

**Passos:**
1. Em cada página (Dashboard, Missões, Categorias)
2. Puxar para baixo no topo da lista
3. Observar loading indicator
4. Verificar se dados atualizam

**Resultado Esperado:**
- ✅ Indicador de loading aparece
- ✅ Dados são recarregados
- ✅ UI atualiza com novos dados

---

### Teste 9: Navegação Entre Páginas

**Passos:**
1. Dashboard → Gerar Missões IA
2. Voltar
3. Dashboard → Gerenciar Missões
4. Voltar
5. Dashboard → Gerenciar Categorias
6. Voltar

**Resultado Esperado:**
- ✅ Navegação fluida sem crashes
- ✅ Botão de voltar funciona
- ✅ Estado preservado ao voltar

---

### Teste 10: Permissões (Teste Negativo)

**Passos:**
1. Fazer logout
2. Login como usuário não-admin
3. Ir para Settings
4. Verificar se botão admin NÃO aparece
5. Tentar acessar `/admin/stats/overview/` via Postman

**Resultado Esperado:**
- ✅ Botão "Administração" não visível
- ✅ Backend retorna 403 Forbidden
- ✅ Sem crash no app

---

## 🐛 Troubleshooting

### Problema: "Erro ao carregar estatísticas"

**Diagnóstico:**
```bash
# Verificar logs Django
python manage.py runserver

# Testar endpoint diretamente
curl -H "Authorization: Bearer TOKEN" \
     http://localhost:8000/admin/stats/overview/
```

**Soluções:**
- Verificar se rota está registrada em `urls.py`
- Verificar se `AdminStatsViewSet` foi importado
- Verificar permissões do usuário

### Problema: Toggle de missão não funciona

**Diagnóstico:**
```python
# Django shell
from finance.models import Mission
Mission.objects.filter(is_active=True).count()
```

**Soluções:**
- Verificar se endpoint `PATCH /missions/{id}/` aceita `is_active`
- Verificar serializer permite atualização desse campo
- Verificar logs de erro no Flutter

### Problema: Categorias não aparecem

**Diagnóstico:**
```python
from finance.models import Category
Category.objects.filter(is_user_created=False).count()
```

**Soluções:**
- Criar categorias globais se não existirem
- Verificar filtro `is_user_created=False`
- Verificar permissões do endpoint

---

## ✅ Checklist Completo

### Backend
- [ ] Endpoint `/admin/stats/overview/` responde 200
- [ ] Retorna todas as estatísticas esperadas
- [ ] Permissão `IsAdminUser` funciona
- [ ] Usuário não-admin recebe 403

### Frontend - Dashboard
- [ ] Carrega estatísticas corretamente
- [ ] 4 cards de métricas visíveis
- [ ] 3 botões de ação funcionam
- [ ] Pull-to-refresh atualiza dados
- [ ] Navegação para outras páginas funciona

### Frontend - Missões
- [ ] Lista todas as missões
- [ ] Filtros por tipo funcionam
- [ ] Filtros por dificuldade funcionam
- [ ] Toggle ativo/inativo funciona
- [ ] Dados persistem após refresh

### Frontend - Categorias
- [ ] Lista categorias globais
- [ ] Agrupamento por tipo funciona
- [ ] Filtros funcionam
- [ ] Ícones e cores corretos

### Segurança
- [ ] Apenas admins veem botão de admin
- [ ] Backend rejeita usuários não-admin
- [ ] JWT token obrigatório

---

## 📊 Relatório de Teste

**Data:** ___/___/______
**Testador:** _________________
**Versão:** _________________

| Teste | Status | Observações |
|-------|--------|-------------|
| 1. Login Admin | ⬜ Pass ⬜ Fail | |
| 2. Dashboard | ⬜ Pass ⬜ Fail | |
| 3. Estatísticas | ⬜ Pass ⬜ Fail | |
| 4. Atividade Recente | ⬜ Pass ⬜ Fail | |
| 5. Gerenciar Missões | ⬜ Pass ⬜ Fail | |
| 6. Toggle Missões | ⬜ Pass ⬜ Fail | |
| 7. Gerenciar Categorias | ⬜ Pass ⬜ Fail | |
| 8. Pull-to-Refresh | ⬜ Pass ⬜ Fail | |
| 9. Navegação | ⬜ Pass ⬜ Fail | |
| 10. Permissões | ⬜ Pass ⬜ Fail | |

**Bugs Encontrados:**
1. ________________________________________________
2. ________________________________________________
3. ________________________________________________

**Observações Gerais:**
_____________________________________________________
_____________________________________________________
