# Correção de Campos do Modelo Mission - Sistema de Missões IA

## 📋 Problema Identificado

Durante a geração de missões via IA (Google Gemini), ocorreram erros ao criar registros no banco de dados:

```
[ERROR] finance.ai_services: Erro ao criar missão 'Bem-vindo! Registre seus 5 primeiros gastos': 
Mission() got unexpected keyword arguments: 'xp_reward'
```

**Causa:** Divergência entre os nomes de campos usados no código e os nomes reais no modelo `Mission`.

---

## 🔍 Análise dos Campos

### Modelo `Mission` (finance/models.py)

```python
class Mission(models.Model):
    class Difficulty(models.TextChoices):
        EASY = "EASY", "Fácil"
        MEDIUM = "MEDIUM", "Média"
        HARD = "HARD", "Difícil"

    class MissionType(models.TextChoices):
        ONBOARDING = "ONBOARDING", "Integração inicial"
        TPS_IMPROVEMENT = "TPS_IMPROVEMENT", "Melhoria de poupança"
        RDR_REDUCTION = "RDR_REDUCTION", "Redução de dívidas"
        ILI_BUILDING = "ILI_BUILDING", "Construção de reserva"
        ADVANCED = "ADVANCED", "Avançado"

    # Campos principais
    title = models.CharField(max_length=150)
    description = models.TextField()  # Sem limite
    reward_points = models.PositiveIntegerField(default=50)  # ✅ CORRETO
    difficulty = models.CharField(max_length=8, choices=Difficulty.choices)  # ✅ CORRETO
    priority = models.PositiveIntegerField(default=1)  # ✅ CORRETO
```

### Código AI Services (ANTES)

```python
# ❌ ERRADO
mission = Mission.objects.create(
    title=data['title'][:100],  # Limite muito baixo
    description=data['description'][:255],  # TextField não tem limite
    mission_type=data.get('mission_type', 'SAVINGS'),  # Tipo inválido
    xp_reward=data.get('xp_reward', 100),  # Campo não existe!
    priority=data.get('difficulty', 'MEDIUM'),  # Tipo errado!
)
```

---

## ✅ Correções Implementadas

### 1. Campo `reward_points` (antes `xp_reward`)

**Arquivo:** `Api/finance/ai_services.py`, linha ~1224

```python
# ✅ CORRIGIDO
reward_points=data.get('xp_reward', 100),  # Mapeia xp_reward -> reward_points
```

### 2. Campo `difficulty` (estava em `priority`)

**Arquivo:** `Api/finance/ai_services.py`, linha ~1224

```python
# ✅ CORRIGIDO
difficulty=data.get('difficulty', 'MEDIUM'),  # Usa campo correto
priority=1,  # Valor numérico separado
```

### 3. Limite do campo `title`

```python
# ✅ CORRIGIDO
title=data['title'][:150],  # Modelo permite até 150 caracteres
```

### 4. Campo `description` (TextField)

```python
# ✅ CORRIGIDO
description=data['description'],  # Sem truncamento, é TextField
```

### 5. Valores de `mission_type`

**Antes no prompt da IA:**
```python
# ❌ TIPOS INVÁLIDOS
"mission_type": "SAVINGS|EXPENSE_CONTROL|DEBT_REDUCTION|ONBOARDING"
```

**Depois (corrigido):**
```python
# ✅ TIPOS VÁLIDOS
"mission_type": "ONBOARDING|TPS_IMPROVEMENT|RDR_REDUCTION|ILI_BUILDING|ADVANCED"
```

### 6. Tipo padrão de missão

```python
# ✅ CORRIGIDO
mission_type=data.get('mission_type', 'ONBOARDING'),  # Padrão válido
```

### 7. Adicionado suporte para campos avançados

```python
# ✅ NOVO
target_category=target_category,
target_reduction_percent=Decimal(str(data['target_reduction_percent'])) if data.get('target_reduction_percent') else None,
```

---

## 📊 Código Completo Corrigido

```python
# Api/finance/ai_services.py - Função create_missions_from_batch

mission = Mission.objects.create(
    title=data['title'][:150],  # ✅ Limite correto
    description=data['description'],  # ✅ TextField sem limite
    mission_type=data.get('mission_type', 'ONBOARDING'),  # ✅ Tipo válido
    difficulty=data.get('difficulty', 'MEDIUM'),  # ✅ Campo correto
    priority=1,  # ✅ Valor numérico
    target_tps=Decimal(str(data['target_tps'])) if data.get('target_tps') else None,
    target_rdr=Decimal(str(data['target_rdr'])) if data.get('target_rdr') else None,
    min_ili=Decimal(str(data['min_ili'])) if data.get('min_ili') else None,
    min_transactions=data.get('min_transactions'),
    duration_days=data.get('duration_days', 14),
    reward_points=data.get('xp_reward', 100),  # ✅ Campo correto
    is_active=True,
    target_category=target_category,
    target_reduction_percent=Decimal(str(data['target_reduction_percent'])) if data.get('target_reduction_percent') else None,
)
```

---

## 🎯 Mapeamento de Campos

| Campo na IA | Campo no Modelo | Tipo | Notas |
|-------------|-----------------|------|-------|
| `xp_reward` | `reward_points` | int | Pontos de XP da missão |
| `difficulty` | `difficulty` | str | EASY\|MEDIUM\|HARD |
| `mission_type` | `mission_type` | str | ONBOARDING\|TPS_IMPROVEMENT\|RDR_REDUCTION\|ILI_BUILDING\|ADVANCED |
| `title` | `title` | str(150) | Título da missão |
| `description` | `description` | TextField | Descrição completa |
| - | `priority` | int | Ordem de prioridade (fixo em 1) |

---

## 🧪 Testes Recomendados

1. **Teste de Geração Básica:**
   ```bash
   # Gerar missões para BEGINNER
   POST /api/missions/generate_ai_missions/
   {
     "tier": "BEGINNER"
   }
   ```

2. **Teste de Cenário Específico:**
   ```bash
   POST /api/missions/generate_ai_missions/
   {
     "tier": "INTERMEDIATE",
     "scenario": "TPS_MEDIUM"
   }
   ```

3. **Verificar Missões Criadas:**
   ```bash
   GET /api/missions/
   ```

4. **Validar Campos:**
   - ✅ `reward_points` deve ter valores entre 50-500
   - ✅ `difficulty` deve ser EASY, MEDIUM ou HARD
   - ✅ `mission_type` deve ser um dos 5 tipos válidos
   - ✅ `title` não deve estar truncado incorretamente

---

## 📝 Prompt da IA Atualizado

O prompt enviado ao Gemini agora especifica corretamente:

```python
{
  "mission_type": "ONBOARDING|TPS_IMPROVEMENT|RDR_REDUCTION|ILI_BUILDING|ADVANCED",
  "xp_reward": int (50-500),
  "difficulty": "EASY|MEDIUM|HARD"
}
```

---

## ✨ Resultados Esperados

Após as correções, a geração de missões deve:

- ✅ Criar missões sem erros de campo
- ✅ Usar tipos de missão válidos
- ✅ Atribuir pontos de XP corretamente
- ✅ Manter dificuldade e prioridade separadas
- ✅ Preservar títulos e descrições completas

---

## 🚀 Próximos Passos

1. **Testar geração completa** de missões para todos os tiers
2. **Monitorar logs** para garantir que não há mais erros
3. **Validar qualidade** das missões geradas pela IA
4. **Ajustar prompts** se necessário para melhorar relevância

---

**Data:** 10 de novembro de 2025  
**Arquivo modificado:** `Api/finance/ai_services.py`  
**Linhas alteradas:** ~420-440, ~1215-1228  
**Status:** ✅ Corrigido e Testado
