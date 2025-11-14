# Plano de Validação e Correção - Sistema de Missões Contextuais
**Data:** 14/11/2025  
**Objetivo:** Validar, limpar e corrigir todas as implementações dos Sprints 3, 4 e 5

---

## FASE 1: Validação de Sintaxe e Dependências ✅

### 1.1 Verificar Imports
- [x] `Api/finance/services.py` - Imports corretos
- [x] `Api/finance/views.py` - Imports atualizados
- [x] `Api/finance/mission_templates.py` - Imports OK
- [x] `Api/finance/management/commands/seed_missions.py` - Imports OK
- [x] `Api/finance/tests/test_mission_assignment.py` - Imports OK

**Status:** ✅ Sem erros de sintaxe detectados

### 1.2 Verificar Type Hints
- [ ] Corrigir `Dict[str, any]` → `Dict[str, Any]` (capitalize Any)
- [ ] Corrigir `List[tuple[Mission, float]]` → `List[Tuple[Mission, float]]`

---

## FASE 2: Limpeza de Comentários Excessivos

### 2.1 services.py
**Comentários a simplificar:**

1. `analyze_user_context()` - 11 linhas de docstring → 3 linhas
2. `identify_improvement_opportunities()` - 8 linhas → 3 linhas
3. `calculate_mission_priorities()` - 9 linhas → 3 linhas
4. `assign_missions_smartly()` - 12 linhas → 4 linhas

**Comentários inline a remover:**
- Comentários óbvios (ex: "# 1. Transações recentes" → já está claro no código)
- Comentários explicativos de lógica simples

### 2.2 views.py
**Endpoints:**
- `recommend()` - Reduzir docstring de 25 linhas → 8 linhas
- `by_category()` - Reduzir de 12 linhas → 5 linhas
- `by_goal()` - Reduzir de 13 linhas → 5 linhas
- `context_analysis()` - Reduzir de 20 linhas → 8 linhas

### 2.3 mission_templates.py
- Manter apenas comentário de cabeçalho por seção
- Remover comentários redundantes nos templates

---

## FASE 3: Testes Unitários

### 3.1 Executar Testes Existentes
```bash
cd Api
python manage.py test finance.tests.test_mission_assignment
```

**Casos a validar:**
- [x] `AnalyzeUserContextTestCase` (4 testes)
- [x] `IdentifyImprovementOpportunitiesTestCase` (2 testes)
- [x] `CalculateMissionPrioritiesTestCase` (2 testes)
- [x] `AssignMissionsSmartlyTestCase` (4 testes)

### 3.2 Criar Testes de Integração
- [ ] Teste end-to-end: criar usuário → transações → análise → atribuição
- [ ] Teste de performance: 1000 transações → análise em <2s
- [ ] Teste de edge cases: usuário sem transações, sem metas, etc.

---

## FASE 4: Validação de Endpoints REST

### 4.1 Endpoints Contextuais (Usuário Comum)
**Testes manuais:**

```bash
# 1. Recommend
GET /api/missions/recommend/?limit=3
Authorization: Bearer <token>
```
- [ ] Retorna missões baseadas em contexto
- [ ] Score de prioridade correto
- [ ] Razão de recomendação clara

```bash
# 2. By Category
GET /api/missions/by-category/?category_id=<uuid>
Authorization: Bearer <token>
```
- [ ] Valida propriedade da categoria
- [ ] Retorna 404 se categoria não existe
- [ ] Retorna 400 se category_id ausente

```bash
# 3. By Goal
GET /api/missions/by-goal/?goal_id=<uuid>
Authorization: Bearer <token>
```
- [ ] Valida propriedade da meta
- [ ] Fallback para missões genéricas de metas
- [ ] Retorna 404 se meta não existe

```bash
# 4. Context Analysis
GET /api/missions/context-analysis/
Authorization: Bearer <token>
```
- [ ] Retorna análise completa
- [ ] Oportunidades identificadas
- [ ] Ações sugeridas geradas

### 4.2 Endpoints Admin
```bash
# 5. Generate Template Missions (Admin)
POST /api/missions/generate_template_missions/
Authorization: Bearer <admin_token>
{
  "tier": "BEGINNER",
  "count": 20,
  "distribution": {"ONBOARDING": 5, "TPS_IMPROVEMENT": 15}
}
```
- [ ] Apenas admin consegue acessar
- [ ] Usuário comum recebe 403 Forbidden
- [ ] Missões criadas corretamente

---

## FASE 5: Validação de Permissões

### 5.1 Testes de Segurança
**Matriz de permissões:**

| Endpoint | Usuário Comum | Admin | Esperado |
|----------|--------------|-------|----------|
| GET /missions/recommend/ | ✅ | ✅ | IsAuthenticated |
| GET /missions/by-category/ | ✅ | ✅ | IsAuthenticated |
| GET /missions/by-goal/ | ✅ | ✅ | IsAuthenticated |
| GET /missions/context-analysis/ | ✅ | ✅ | IsAuthenticated |
| POST /missions/generate_template_missions/ | ❌ | ✅ | IsAdminUser |
| POST /missions/generate_ai_missions/ | ❌ | ✅ | IsAdminUser |

### 5.2 Testes a Executar
- [ ] Usuário comum tenta acessar endpoint admin → 403
- [ ] Usuário não autenticado tenta acessar → 401
- [ ] Admin acessa todos os endpoints → 200/201

---

## FASE 6: Validação do Comando seed_missions

### 6.1 Testes do Comando
```bash
# Teste 1: Gerar 10 missões ONBOARDING sem IA
python manage.py seed_missions --type ONBOARDING --count 10 --use-ai false

# Teste 2: Gerar 30 missões mistas
python manage.py seed_missions --count 30

# Teste 3: Limpar e recriar
python manage.py seed_missions --clear --count 50
```

**Validações:**
- [ ] Missões criadas com títulos únicos
- [ ] Placeholders expandidos corretamente
- [ ] Tipos de missão corretos
- [ ] Dificuldade e recompensas apropriadas
- [ ] Sem duplicatas

### 6.2 Verificar Templates
- [ ] Todos os 8 tipos têm templates válidos
- [ ] Placeholders funcionam: {count}, {target}, {percent}
- [ ] Ranges de valores fazem sentido

---

## FASE 7: Remover Código Não Utilizado

### 7.1 Funções Deprecadas/Duplicadas
**services.py:**
- [ ] `recommend_missions()` - DEPRECATED, mas mantido por compatibilidade
- [ ] `assign_missions_automatically()` - Verificar se ainda é usado
  - Se não usado → remover
  - Se usado → marcar como deprecated e migrar para `assign_missions_smartly()`

**views.py:**
- [ ] Verificar se há endpoints antigos não documentados
- [ ] Remover imports não utilizados

### 7.2 Arquivos Obsoletos
- [ ] Verificar `seed_default_missions.py` vs `seed_missions.py`
- [ ] Verificar `seed_specialized_missions.py` - ainda necessário?

### 7.3 Verificar Uso de Funções
```bash
# Buscar referências
grep -r "assign_missions_automatically" Api/
grep -r "recommend_missions" Api/
```

---

## FASE 8: Teste de Integração Completo

### 8.1 Cenário End-to-End (Usuário Novo)
1. Criar usuário
2. Criar 3 transações
3. Chamar `/missions/context-analysis/` → deve identificar "poucos dados"
4. Chamar `/missions/recommend/` → deve recomendar ONBOARDING
5. Chamar `assign_missions_smartly()` → deve atribuir missões de onboarding

### 8.2 Cenário End-to-End (Usuário Experiente)
1. Criar usuário com perfil completo (TPS=12%, RDR=55%, ILI=2.5)
2. Criar 50+ transações
3. Chamar `/missions/context-analysis/` → deve identificar:
   - TPS baixo
   - RDR alto
   - ILI baixo
4. Chamar `/missions/recommend/` → deve recomendar:
   - Missões de TPS_IMPROVEMENT (alta prioridade)
   - Missões de RDR_REDUCTION (alta prioridade)
   - Missões de ILI_BUILDING (alta prioridade)
5. Verificar scores de prioridade (devem ser >60 para indicadores em risco)

### 8.3 Cenário de Categoria Crescente
1. Criar transações: "Entretenimento" R$ 200/mês (60 dias atrás)
2. Criar transações: "Entretenimento" R$ 500/mês (últimos 30 dias)
3. Chamar `/missions/context-analysis/` → deve identificar:
   - Oportunidade: CATEGORY_GROWTH em "Entretenimento" (+150%)
4. Verificar ação sugerida: "REDUCE_CATEGORY_SPENDING"

---

## FASE 9: Documentação Final

### 9.1 Atualizar README
- [ ] Adicionar seção "API Endpoints Contextuais"
- [ ] Documentar query params
- [ ] Exemplos de requests/responses

### 9.2 Criar Documentação de API
**Criar:** `Api/docs/CONTEXTUAL_MISSIONS_API.md`

Conteúdo:
- Endpoints disponíveis
- Exemplos de uso
- Estrutura de resposta
- Códigos de erro

### 9.3 Atualizar MISSION_SYSTEM_REFACTOR.md
- [ ] Adicionar seção "Como Usar"
- [ ] Adicionar seção "Troubleshooting"
- [ ] Exemplos práticos

---

## FASE 10: Correções Específicas Identificadas

### 10.1 Type Hints
**services.py:**
```python
# ANTES
def analyze_user_context(user) -> Dict[str, any]:

# DEPOIS
def analyze_user_context(user) -> Dict[str, Any]:
```

```python
# ANTES
def calculate_mission_priorities(user, context: Dict[str, any] = None) -> List[tuple[Mission, float]]:

# DEPOIS
def calculate_mission_priorities(user, context: Dict[str, Any] = None) -> List[Tuple[Mission, float]]:
```

### 10.2 Imports Faltantes
**services.py:** Adicionar ao topo:
```python
from typing import Any, Dict, Iterable, List, Tuple
```

### 10.3 Validações de Segurança
**views.py - by_category():**
- [x] Já valida propriedade do usuário
- [x] Retorna 404 se não encontrado

**views.py - by_goal():**
- [x] Já valida propriedade do usuário
- [x] Retorna 404 se não encontrado

### 10.4 Edge Cases
**services.py - analyze_user_context():**
- [ ] Tratar caso de usuário sem transações
- [ ] Tratar caso de first_transaction = None

**services.py - identify_improvement_opportunities():**
- [ ] Retornar lista vazia se não houver dados suficientes

---

## Checklist Final de Validação

### Código
- [ ] Sem erros de sintaxe
- [ ] Sem warnings de type hints
- [ ] Imports organizados
- [ ] Comentários concisos
- [ ] Sem código morto

### Testes
- [ ] Testes unitários passam (12/12)
- [ ] Testes de integração passam
- [ ] Edge cases cobertos

### API
- [ ] Endpoints respondem corretamente
- [ ] Permissões validadas
- [ ] Erros retornam códigos HTTP corretos

### Performance
- [ ] Análise contextual <2s para 1000 transações
- [ ] Cálculo de prioridades <1s para 100 missões
- [ ] Sem N+1 queries

### Documentação
- [ ] Docstrings concisos
- [ ] README atualizado
- [ ] API documentada

---

## Prioridades de Execução

**P0 (Crítico - Bloqueia uso):**
1. Corrigir type hints (Any, Tuple)
2. Adicionar tratamento de edge cases
3. Validar permissões dos endpoints

**P1 (Alto - Impacta qualidade):**
4. Limpar comentários excessivos
5. Executar testes unitários
6. Validar comando seed_missions

**P2 (Médio - Melhoria):**
7. Testes de integração
8. Remover código não utilizado
9. Documentação

**P3 (Baixo - Opcional):**
10. Otimizações de performance
11. Testes de carga
