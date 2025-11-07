# Sistema de Geração de Missões com IA

## Visão Geral

Sistema avançado de geração de missões usando Google Gemini 2.5 Flash que adapta missões baseado em diferentes cenários e perfis de usuários.

## Características Principais

### 1. **Geração Contextual por Cenários**

O sistema identifica automaticamente ou aceita manualmente um de 13 cenários diferentes:

#### Cenários de Onboarding
- **BEGINNER_ONBOARDING**: Primeiros passos para usuários com poucas transações
  - Gera apenas se houver < 20 missões de onboarding
  - Foco: criar hábito de registro
  - 12 missões ONBOARDING + 5 SAVINGS + 3 EXPENSE_CONTROL

#### Cenários TPS (Taxa de Poupança Pessoal)
- **TPS_LOW**: Elevar TPS de 0-15% para 15-25%
  - 14 missões SAVINGS + 4 EXPENSE_CONTROL + 2 DEBT_REDUCTION
  
- **TPS_MEDIUM**: Elevar TPS de 15-25% para 25-35%
  - 12 missões SAVINGS + 5 EXPENSE_CONTROL + 3 DEBT_REDUCTION
  
- **TPS_HIGH**: Manter/elevar TPS de 25%+ para 30-40%
  - 10 missões SAVINGS + 6 EXPENSE_CONTROL + 4 DEBT_REDUCTION

#### Cenários RDR (Razão Dívida-Receita)
- **RDR_HIGH**: Reduzir RDR de 50%+ para 30-40%
  - 14 missões DEBT_REDUCTION + 3 SAVINGS + 3 EXPENSE_CONTROL
  
- **RDR_MEDIUM**: Reduzir RDR de 30-50% para 20-30%
  - 12 missões DEBT_REDUCTION + 5 SAVINGS + 3 EXPENSE_CONTROL
  
- **RDR_LOW**: Manter RDR abaixo de 30%
  - 8 missões DEBT_REDUCTION + 8 SAVINGS + 4 EXPENSE_CONTROL

#### Cenários ILI (Índice de Liquidez Imediata)
- **ILI_LOW**: Elevar ILI de 0-3 meses para 3-6 meses
  - 14 missões SAVINGS + 4 EXPENSE_CONTROL + 2 DEBT_REDUCTION
  
- **ILI_MEDIUM**: Elevar ILI de 3-6 meses para 6-12 meses
  - 12 missões SAVINGS + 5 EXPENSE_CONTROL + 3 DEBT_REDUCTION
  
- **ILI_HIGH**: Manter ILI acima de 6 meses (meta: 12-24)
  - 10 missões SAVINGS + 6 EXPENSE_CONTROL + 4 DEBT_REDUCTION

#### Cenários Mistos
- **MIXED_BALANCED**: Equilíbrio financeiro geral
  - 8 SAVINGS + 6 DEBT_REDUCTION + 6 EXPENSE_CONTROL
  
- **MIXED_RECOVERY**: Recuperação financeira (TPS < 15% + RDR > 40%)
  - 10 DEBT_REDUCTION + 6 SAVINGS + 4 EXPENSE_CONTROL
  
- **MIXED_OPTIMIZATION**: Otimização avançada (TPS > 20%, RDR < 30%, ILI > 6)
  - 7 SAVINGS + 7 EXPENSE_CONTROL + 6 DEBT_REDUCTION

### 2. **Adaptação por Faixa de Usuário**

Cada faixa tem características e focos diferentes:

- **BEGINNER** (Níveis 1-5): Hábitos básicos, conceitos fundamentais
- **INTERMEDIATE** (Níveis 6-15): Otimização, metas progressivas
- **ADVANCED** (Níveis 16+): Excelência, estratégias avançadas

### 3. **Contextualização Sazonal**

Missões adaptadas ao período do ano:
- Janeiro: Renovação, metas anuais
- Novembro: Black Friday, controle de impulsos
- Dezembro: Festas, planejamento do próximo ano
- Outros: Foco em consistência e progresso

### 4. **Prevenção de Duplicação**

- Verifica se missão similar já existe (por título)
- Conta missões existentes antes de gerar (para ONBOARDING)
- Pula missões duplicadas durante criação

### 5. **Cache Inteligente**

- Cache por 30 dias: `ai_missions_{tier}_{scenario}_{YYYY_MM}`
- Reduz custos e melhora performance
- Permite reutilização no mesmo mês

## Como Usar

### Via API (Admin)

```bash
# Auto-detectar cenário para todas as faixas
POST /api/missions/generate_ai_missions/
{}

# Gerar para faixa específica (auto-detecta cenário)
POST /api/missions/generate_ai_missions/
{
  "tier": "BEGINNER"
}

# Gerar cenário específico para todas as faixas
POST /api/missions/generate_ai_missions/
{
  "scenario": "TPS_LOW"
}

# Gerar cenário específico para faixa específica
POST /api/missions/generate_ai_missions/
{
  "tier": "INTERMEDIATE",
  "scenario": "RDR_HIGH"
}
```

### Via Flutter (Admin Page)

1. Acesse Configurações → Administração
2. Selecione a faixa desejada (ou "Todas")
3. Opcionalmente selecione um cenário específico
4. Clique em "Gerar Missões"

### Programaticamente

```python
from finance.ai_services import (
    generate_all_monthly_missions,
    generate_missions_by_scenario,
    generate_batch_missions_for_tier
)

# Gerar tudo automaticamente
result = generate_all_monthly_missions()

# Gerar cenário específico
result = generate_missions_by_scenario('TPS_LOW', tiers=['BEGINNER'])

# Gerar para uma faixa (auto-detecta cenário)
missions = generate_batch_missions_for_tier('INTERMEDIATE')
created = create_missions_from_batch('INTERMEDIATE', missions)
```

## Algoritmo de Auto-Detecção de Cenário

```python
def determine_best_scenario(tier_stats):
    tps = tier_stats['avg_tps']
    rdr = tier_stats['avg_rdr']
    ili = tier_stats['avg_ili']
    tier = tier_stats['tier']
    
    # 1. Iniciantes com poucas missões → BEGINNER_ONBOARDING
    if tier == 'BEGINNER' and count_missions('ONBOARDING') < 20:
        return 'BEGINNER_ONBOARDING'
    
    # 2. Situação crítica → MIXED_RECOVERY
    if tps < 15 and rdr > 40:
        return 'MIXED_RECOVERY'
    
    # 3. Excelência → MIXED_OPTIMIZATION
    if tps >= 20 and rdr < 30 and ili >= 6:
        return 'MIXED_OPTIMIZATION'
    
    # 4. Foco por métrica mais problemática
    # Prioridade: TPS → RDR → ILI
```

## Estrutura de Missão Gerada

```json
{
  "title": "Economize 20% da sua Receita em Novembro",
  "description": "Alcance TPS de 20% mantendo controle de gastos essenciais",
  "mission_type": "SAVINGS",
  "target_tps": 20.0,
  "target_rdr": null,
  "min_ili": null,
  "target_category": null,
  "target_reduction_percent": null,
  "min_transactions": null,
  "duration_days": 30,
  "xp_reward": 200,
  "difficulty": "MEDIUM",
  "tags": ["economia", "novembro", "tps"]
}
```

## Métricas de Qualidade

- **Variedade**: 20 missões únicas por batch
- **Progressão**: 8 EASY + 8 MEDIUM + 4 HARD
- **Distribuição**: Balanceada por tipo conforme cenário
- **Contextualização**: Adaptada a período e faixa
- **Mensurabilidade**: Metas específicas e alcançáveis

## Custos Estimados

- **Tier Gratuito Gemini**: 1500 req/dia
- **Custo por batch**: ~$0.001 (20 missões)
- **Custo mensal estimado**: ~$0.01
  - 3 faixas × 3 cenários médios × $0.001 = $0.009

## Logs e Monitoramento

```python
logger.info(f"Gerando missões para {tier}/{scenario}")
logger.info(f"Cenário auto-detectado: {scenario_key}")
logger.info(f"✓ {len(missions)} missões geradas")
logger.info(f"✓ {len(created)}/{len(batch)} criadas ({skipped} puladas)")
```

## Próximas Melhorias

1. ✅ Adicionar campo `tier` ao modelo Mission
2. ✅ Adicionar campo `scenario` ao modelo Mission
3. ✅ Adicionar campo `tags` ao modelo Mission
4. ⬜ Criar dashboard de analytics de missões
5. ⬜ Sistema de A/B testing de missões
6. ⬜ Feedback de usuários sobre missões
7. ⬜ Machine learning para otimizar cenários

## Referências

- [Gemini API Documentation](https://ai.google.dev/docs)
- [Gamification Best Practices](https://example.com)
- [Financial Education Principles](https://example.com)
