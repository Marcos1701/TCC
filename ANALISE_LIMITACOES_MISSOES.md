# ⚠️ ANÁLISE CRÍTICA: Limitações do Sistema de Missões Atual

**Data:** 09/11/2025  
**Foco:** Rastreamento de progresso e validação de metas

---

## 🔍 SUA PERGUNTA FOI PERFEITA!

Você identificou uma **LIMITAÇÃO CRÍTICA** do sistema atual. Vamos analisar:

### **Exemplos de Missões Problemáticas:**

1. ❌ **"Reduza gastos com alimentação em 15%"**
2. ❌ **"Mantenha TPS acima de 20% por 30 dias"**
3. ❌ **"Mantenha RDR abaixo de 15% por 90 dias"**

---

## ❌ PROBLEMA 1: Falta de Rastreamento Temporal

### **O que o sistema atual FAZ:**

```python
def update_mission_progress(user):
    # Calcula indicadores ATUAIS
    current_tps = calculate_summary(user)["tps"]  # TPS de HOJE
    current_rdr = calculate_summary(user)["rdr"]  # RDR de HOJE
    
    # Compara com valor INICIAL
    if current_tps >= mission.target_tps:
        progress = 100%  # ✅ COMPLETA
```

### **O que o sistema atual NÃO FAZ:**

❌ **Não rastreia evolução diária**
- Não salva TPS/RDR/ILI de cada dia
- Não consegue verificar "manteve por X dias"
- Não detecta regressões

❌ **Não valida consistência temporal**
- Missão: "Mantenha TPS > 20% por 30 dias"
- Sistema atual: Verifica apenas se TPS HOJE > 20%
- **FALHA:** Se TPS caiu para 15% no dia 15, não detecta!

❌ **Não rastreia gastos por categoria diariamente**
- Missão: "Reduza alimentação em 15%"
- Sistema atual: Não tem baseline de "alimentação" salvo
- **FALHA:** Não consegue medir redução real!

---

## 📊 DADOS DISPONÍVEIS vs DADOS NECESSÁRIOS

### **Campos no MissionProgress (Modelo Atual):**

```python
class MissionProgress(models.Model):
    # ✅ TEM: Valores iniciais (snapshot único)
    initial_tps = models.DecimalField(...)      # TPS quando missão começou
    initial_rdr = models.DecimalField(...)      # RDR quando missão começou
    initial_ili = models.DecimalField(...)      # ILI quando missão começou
    initial_transaction_count = models.IntegerField(...)
    
    # ✅ TEM: Progresso geral (0-100%)
    progress = models.DecimalField(...)
    
    # ✅ TEM: Timestamps básicos
    started_at = models.DateTimeField(...)
    completed_at = models.DateTimeField(...)
    updated_at = models.DateTimeField(...)
    
    # ❌ NÃO TEM: Histórico diário
    # ❌ NÃO TEM: Snapshots intermediários
    # ❌ NÃO TEM: Dias consecutivos
    # ❌ NÃO TEM: Baseline de categorias
```

### **O que FALTA para missões avançadas:**

```python
# ❌ NÃO EXISTE no sistema atual
class MissionProgressSnapshot(models.Model):
    """Snapshot diário para rastrear evolução temporal."""
    mission_progress = ForeignKey(MissionProgress)
    date = DateField()
    tps_value = DecimalField()
    rdr_value = DecimalField()
    ili_value = DecimalField()
    category_totals = JSONField()  # {"alimentacao": 500, "transporte": 300}
    met_criteria = BooleanField()  # Se atendeu critério neste dia
```

---

## 🔴 CASOS DE FALHA CRÍTICA

### **Caso 1: "Mantenha TPS > 20% por 30 dias"**

**Timeline Real do Usuário:**
```
Dia 1-10:  TPS = 25% ✅
Dia 11-20: TPS = 18% ❌ (VIOLOU!)
Dia 21-30: TPS = 22% ✅
```

**Comportamento do Sistema Atual:**
```python
# No dia 30
current_tps = 22%  # TPS atual
mission.target_tps = 20%
if current_tps >= 20%:
    progress = 100%  # ✅ MISSÃO COMPLETA (ERRADO!)
```

**Resultado:** ❌ **Missão marcada como completa INDEVIDAMENTE**
- Sistema NÃO detectou violação nos dias 11-20
- Usuário "trapaceou" sem querer
- Gamificação perde credibilidade

---

### **Caso 2: "Reduza gastos com alimentação em 15%"**

**Dados do Usuário:**
```
Mês anterior: R$ 800 em alimentação
Mês atual:    R$ 750 em alimentação
Redução real: 6.25% (não atingiu 15%)
```

**Comportamento do Sistema Atual:**
```python
# Sistema NÃO tem baseline de categoria salvo!
# Campos disponíveis:
initial_tps = 15.0     # ✅ TEM
initial_rdr = 45.0     # ✅ TEM
# ❌ NÃO TEM: initial_category_totals = {"alimentacao": 800}

# Resultado: Não consegue calcular progresso!
# Missão fica em 0% eternamente
```

**Resultado:** ❌ **Missão impossível de completar**
- Falta dados de baseline por categoria
- Sistema não rastreia gastos históricos por categoria
- Usuário fica frustrado

---

### **Caso 3: "Mantenha RDR abaixo de 15% por 90 dias"**

**Timeline Real:**
```
Dia 1-60:  RDR = 12% ✅
Dia 61:    RDR = 18% ❌ (pegou empréstimo emergencial)
Dia 62-90: RDR = 13% ✅
```

**Comportamento do Sistema Atual:**
```python
# No dia 90
current_rdr = 13%
mission.target_rdr = 15%
if current_rdr <= 15%:
    progress = 100%  # ✅ COMPLETA (ERRADO!)
```

**Resultado:** ❌ **Violação não detectada**
- Dia 61 invalidaria a missão
- Sistema só olha valor atual
- Não há conceito de "consecutividade"

---

## 💡 O QUE PRECISARIA SER IMPLEMENTADO

### **Solução 1: Snapshots Diários (IDEAL)**

```python
class MissionProgressSnapshot(models.Model):
    """Rastreamento diário de indicadores para missões temporais."""
    mission_progress = models.ForeignKey(MissionProgress, on_delete=models.CASCADE)
    snapshot_date = models.DateField()
    
    # Indicadores do dia
    tps_value = models.DecimalField(max_digits=6, decimal_places=2, null=True)
    rdr_value = models.DecimalField(max_digits=6, decimal_places=2, null=True)
    ili_value = models.DecimalField(max_digits=6, decimal_places=2, null=True)
    
    # Gastos por categoria (JSON)
    category_spending = models.JSONField(default=dict)
    # {"alimentacao": 50.00, "transporte": 30.00, ...}
    
    # Validação de critério
    met_target = models.BooleanField(default=False)
    # True se neste dia os critérios foram atendidos
    
    # Dias consecutivos até este ponto
    consecutive_days = models.PositiveIntegerField(default=0)
    
    class Meta:
        unique_together = ('mission_progress', 'snapshot_date')
        ordering = ['snapshot_date']


# Task diária (Celery)
@shared_task
def create_daily_mission_snapshots():
    """
    Executa TODO DIA às 23:59 para capturar estado atual.
    """
    from django.utils import timezone
    today = timezone.now().date()
    
    for progress in MissionProgress.objects.filter(
        status__in=['PENDING', 'ACTIVE']
    ):
        user = progress.user
        summary = calculate_summary(user)
        
        # Criar snapshot do dia
        snapshot = MissionProgressSnapshot.objects.create(
            mission_progress=progress,
            snapshot_date=today,
            tps_value=summary['tps'],
            rdr_value=summary['rdr'],
            ili_value=summary['ili'],
            category_spending=_calculate_category_totals(user, today),
            met_target=_check_mission_criteria(progress, summary),
        )
        
        # Calcular dias consecutivos
        snapshot.consecutive_days = _calculate_consecutive_days(progress)
        snapshot.save()
```

**Validação de Missão Temporal:**

```python
def update_temporal_mission_progress(progress):
    """
    Valida missões com critério de 'manter por X dias'.
    """
    mission = progress.mission
    
    # Exemplo: "Mantenha TPS > 20% por 30 dias"
    required_days = mission.duration_days  # 30
    target_tps = mission.target_tps  # 20
    
    # Buscar snapshots dos últimos 30 dias
    snapshots = MissionProgressSnapshot.objects.filter(
        mission_progress=progress,
        snapshot_date__gte=timezone.now().date() - timedelta(days=required_days)
    ).order_by('snapshot_date')
    
    # Contar dias que atenderam critério
    days_met = snapshots.filter(met_target=True).count()
    
    # Verificar consecutividade (se requerido)
    consecutive = _get_max_consecutive_days(snapshots)
    
    # Calcular progresso
    progress_pct = (consecutive / required_days) * 100
    
    # Validar se completou
    if consecutive >= required_days:
        progress.status = 'COMPLETED'
        progress.progress = 100
    else:
        progress.progress = progress_pct
    
    progress.save()
```

---

### **Solução 2: Baseline de Categorias**

```python
class MissionProgress(models.Model):
    # ... campos existentes ...
    
    # ADICIONAR:
    initial_category_totals = models.JSONField(
        default=dict,
        help_text="Totais de categorias quando missão começou"
    )
    # Exemplo: {"alimentacao": 800, "transporte": 300}


def start_mission_with_category_baseline(progress):
    """
    Ao iniciar missão de redução de categoria, salvar baseline.
    """
    user = progress.user
    mission = progress.mission
    
    # Calcular totais dos últimos 30 dias
    last_month = timezone.now() - timedelta(days=30)
    
    category_totals = Transaction.objects.filter(
        user=user,
        type='EXPENSE',
        date__gte=last_month
    ).values('category__name').annotate(
        total=Sum('amount')
    )
    
    # Salvar baseline
    progress.initial_category_totals = {
        item['category__name']: float(item['total'])
        for item in category_totals
    }
    progress.save()


def update_category_reduction_progress(progress):
    """
    Calcula progresso de missão de redução de categoria.
    """
    mission = progress.mission
    target_category = mission.target_category  # "alimentacao"
    reduction_target = mission.target_reduction_percent  # 15
    
    # Baseline (salvo ao iniciar)
    initial_total = progress.initial_category_totals.get(target_category, 0)
    
    # Total atual (mesmos últimos 30 dias)
    last_month = timezone.now() - timedelta(days=30)
    current_total = Transaction.objects.filter(
        user=progress.user,
        type='EXPENSE',
        category__name=target_category,
        date__gte=last_month
    ).aggregate(total=Sum('amount'))['total'] or 0
    
    # Calcular redução real
    if initial_total > 0:
        reduction_achieved = ((initial_total - current_total) / initial_total) * 100
        
        # Progresso = % de redução alcançada / % de redução alvo
        progress_pct = min(100, (reduction_achieved / reduction_target) * 100)
    else:
        progress_pct = 0
    
    progress.progress = progress_pct
    progress.save()
```

---

### **Solução 3: Validação Específica por Tipo**

```python
# ADICIONAR novos tipos de missão
class Mission(models.Model):
    class MissionType(models.TextChoices):
        # ... existentes ...
        MAINTAIN_METRIC = "MAINTAIN_METRIC", "Manter métrica"
        REDUCE_CATEGORY = "REDUCE_CATEGORY", "Reduzir categoria"
        STREAK = "STREAK", "Sequência/streak"
    
    # ADICIONAR campos para validação temporal
    requires_consecutive_days = models.BooleanField(default=False)
    # Se True, missão exige X dias CONSECUTIVOS
    
    min_consecutive_days = models.PositiveIntegerField(null=True, blank=True)
    # Número de dias consecutivos necessários
    
    target_category = models.ForeignKey(
        Category, 
        null=True, 
        blank=True,
        on_delete=models.SET_NULL
    )
    # Categoria alvo para missões de redução
    
    target_reduction_percent = models.DecimalField(
        max_digits=5, 
        decimal_places=2,
        null=True, 
        blank=True
    )
    # % de redução alvo (ex: 15.00 = 15%)
```

---

## 📊 IMPACTO DAS LIMITAÇÕES

### **Tipos de Missões que FUNCIONAM Hoje:**

✅ **Missões Simples (Snapshot Único):**
- "Alcance TPS de 20%" → Verifica uma vez
- "Registre 10 transações" → Conta total
- "Complete cadastro" → Binário (sim/não)

### **Tipos de Missões que NÃO FUNCIONAM:**

❌ **Missões Temporais (Requerem Histórico):**
- "Mantenha TPS > 20% por 30 dias"
- "Não gaste mais que R$ 500 por 60 dias"
- "Mantenha sequência de 7 dias registrando"

❌ **Missões de Categoria (Requerem Baseline):**
- "Reduza alimentação em 15%"
- "Gaste 20% menos com lazer"
- "Aumente economia em transporte"

❌ **Missões de Consistência:**
- "Registre transações todo dia por 1 mês"
- "Não ultrapasse orçamento por 90 dias"
- "Mantenha dívida zerada por 6 meses"

---

## 🎯 RECOMENDAÇÕES PARA O TCC

### **Opção 1: Documentar a Limitação (HONESTO)**

No TCC, seja transparente:

> "O sistema atual suporta missões baseadas em **comparação pontual** (valor inicial vs valor atual), adequadas para metas de **melhoria incremental**. Missões que exigem **rastreamento temporal** (ex: 'manter por X dias') ou **baseline de categorias** (ex: 'reduzir gastos em Y%') requerem extensões futuras com snapshots diários, o que está fora do escopo deste trabalho."

**Benefícios:**
- ✅ Honestidade acadêmica
- ✅ Demonstra compreensão das limitações
- ✅ Abre oportunidade para trabalhos futuros
- ✅ Não compromete a qualidade do TCC

---

### **Opção 2: Implementar Snapshots Básicos (VIÁVEL)**

Implementar rastreamento básico em 2-3 dias:

**Sprint Rápida:**
1. Criar modelo `MissionProgressSnapshot` (1h)
2. Task Celery diária para snapshots (2h)
3. Atualizar `update_mission_progress()` para usar snapshots (3h)
4. Testes básicos (2h)

**Total:** ~8 horas de trabalho

**Vantagens:**
- ✅ Funcionalidade completa
- ✅ Demonstra engenharia sólida
- ✅ Diferencial competitivo no TCC

**Desvantagens:**
- ⚠️ Aumenta complexidade
- ⚠️ Requer testes adicionais
- ⚠️ Mais código para apresentar

---

### **Opção 3: Simplificar Descrições (PRAGMÁTICO)**

Ajustar IA para gerar apenas missões suportadas:

```python
# No prompt da IA, adicionar restrição
SIMPLIFIED_MISSION_RULES = """
IMPORTANTE: Gerar apenas missões de MELHORIA PONTUAL:
- ✅ "Alcance TPS de 25%" (compara inicial vs final)
- ✅ "Registre 15 transações" (conta total)
- ✅ "Reduza RDR para 30%" (compara inicial vs final)

NÃO gerar missões TEMPORAIS:
- ❌ "Mantenha TPS por 30 dias"
- ❌ "Reduza categoria em X%"
- ❌ "Não ultrapasse por Y dias"
"""
```

**Vantagens:**
- ✅ Rápido de implementar (30 min)
- ✅ Evita frustrações do usuário
- ✅ Mantém sistema consistente

**Desvantagens:**
- ⚠️ Reduz variedade de missões
- ⚠️ Menos desafiador

---

## 📝 RESUMO EXECUTIVO

### **Sua pergunta revelou que:**

1. ❌ Sistema atual **NÃO rastreia evolução diária** de indicadores
2. ❌ Sistema atual **NÃO valida consistência temporal** ("por X dias")
3. ❌ Sistema atual **NÃO tem baseline de categorias** para medir reduções
4. ✅ Sistema atual **FUNCIONA** para missões de melhoria pontual

### **Tipos de validação disponíveis:**

| Tipo de Missão | Funciona? | Por quê? |
|---------------|-----------|----------|
| "Alcance TPS 25%" | ✅ SIM | Compara inicial vs atual |
| "Registre 10 transações" | ✅ SIM | Conta simples |
| "Mantenha TPS > 20% por 30 dias" | ❌ NÃO | Falta rastreamento diário |
| "Reduza alimentação 15%" | ❌ NÃO | Falta baseline de categoria |
| "Não gaste > R$500 por 60 dias" | ❌ NÃO | Falta validação temporal |

### **Soluções:**

1. **Documentar limitação** → Honesto, rápido (30 min)
2. **Implementar snapshots** → Completo, trabalhoso (8h)
3. **Restringir IA** → Pragmático, rápido (30 min)

---

## 🎓 Para Apresentação do TCC

**Slide Sugerido:**

**"Limitações e Trabalhos Futuros"**

- Sistema suporta missões de **melhoria incremental**
- Missões temporais ("manter por X dias") requerem:
  - Snapshots diários de indicadores
  - Validação de consecutividade
  - Estimativa: 8-12h de implementação
- Trade-off consciente: **simplicidade** vs **complexidade**
- Oportunidade para extensão futura

---

**Conclusão:** Sua observação foi **EXCELENTE** e fundamental para entender os limites do sistema. Qual abordagem você prefere para o TCC?

1. Documentar como limitação conhecida?
2. Implementar snapshots básicos?
3. Restringir IA para missões suportadas?
