# 🔧 PLANO DE IMPLEMENTAÇÃO: Sistema de Histórico e Validação de Missões

**Data:** 09/11/2025  
**Objetivo:** Implementar rastreamento temporal completo para validação correta de TODAS as missões

---

## 🎯 ESCOPO COMPLETO DO PROBLEMA

### **Casos de Missões que Precisam ser Suportados:**

1. ✅ **Missões de Melhoria Pontual** (já funcionam)
   - "Alcance TPS de 25%"
   - "Registre 10 transações"

2. 🔧 **Missões Temporais** (PRECISA CORRIGIR)
   - "Mantenha TPS > 20% por 30 dias"
   - "Não ultrapasse RDR de 15% por 90 dias"

3. 🔧 **Missões de Categoria** (PRECISA CORRIGIR)
   - "Reduza gastos com Alimentação em 15%"
   - "Gaste menos de R$ 500 em Lazer no mês"

4. 🔧 **Missões de Meta** (PRECISA CORRIGIR)
   - "Economize R$ 500 para meta de Emergência"
   - "Complete 80% da meta de Férias"

5. 🔧 **Missões de Poupança** (PRECISA CORRIGIR)
   - "Adicione R$ 300 em investimentos no mês"
   - "Aumente reserva de emergência em R$ 1000"

6. 🔧 **Missões de Consistência** (PRECISA CORRIGIR)
   - "Registre transações por 7 dias consecutivos"
   - "Não quebre orçamento mensal por 3 meses"

---

## 📊 ARQUITETURA DA SOLUÇÃO

### **Componente 1: Sistema de Snapshots Diários**

```
┌─────────────────────────────────────────────────────────────┐
│                  SNAPSHOT DIÁRIO (23:59)                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────┐                                    │
│  │  Indicadores Gerais │                                    │
│  ├─────────────────────┤                                    │
│  │  - TPS              │                                    │
│  │  - RDR              │                                    │
│  │  - ILI              │                                    │
│  │  - Saldo Total      │                                    │
│  └─────────────────────┘                                    │
│                                                               │
│  ┌─────────────────────┐                                    │
│  │  Por Categoria      │                                    │
│  ├─────────────────────┤                                    │
│  │  - Alimentação: 500 │                                    │
│  │  - Transporte: 300  │                                    │
│  │  - Lazer: 150       │                                    │
│  └─────────────────────┘                                    │
│                                                               │
│  ┌─────────────────────┐                                    │
│  │  Progresso de Metas │                                    │
│  ├─────────────────────┤                                    │
│  │  - Meta 1: 45%      │                                    │
│  │  - Meta 2: 78%      │                                    │
│  └─────────────────────┘                                    │
│                                                               │
│  ┌─────────────────────┐                                    │
│  │  Validações         │                                    │
│  ├─────────────────────┤                                    │
│  │  - Registrou hoje?  │                                    │
│  │  - Quebrou orç?     │                                    │
│  └─────────────────────┘                                    │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🗄️ MODELOS DE DADOS

### **Modelo 1: UserDailySnapshot (Histórico do Usuário)**

```python
class UserDailySnapshot(models.Model):
    """
    Snapshot diário dos indicadores financeiros do usuário.
    
    Criado automaticamente todo dia às 23:59 via Celery Beat.
    Serve como fonte de verdade para análise histórica e validação de missões.
    """
    
    # Identificação
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='daily_snapshots'
    )
    snapshot_date = models.DateField(
        help_text="Data do snapshot (YYYY-MM-DD)"
    )
    
    # Indicadores principais
    tps = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        help_text="Taxa de Poupança Pessoal do dia (%)"
    )
    rdr = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        help_text="Razão Dívida-Receita do dia (%)"
    )
    ili = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        help_text="Índice de Liquidez Imediata (meses)"
    )
    
    # Totais financeiros
    total_income = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        help_text="Total de receitas (acumulado do mês)"
    )
    total_expense = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        help_text="Total de despesas (acumulado do mês)"
    )
    total_debt = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        help_text="Total de dívidas"
    )
    available_balance = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        help_text="Saldo disponível (receitas - despesas - dívidas)"
    )
    
    # Gastos por categoria (JSON)
    category_spending = models.JSONField(
        default=dict,
        help_text="Gastos por categoria no mês atual até esta data"
    )
    # Exemplo: {
    #   "alimentacao": {"total": 500.00, "count": 15},
    #   "transporte": {"total": 300.00, "count": 8}
    # }
    
    # Poupança e investimentos
    savings_added_today = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        help_text="Valor adicionado a poupança/investimentos hoje"
    )
    savings_total = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        help_text="Total acumulado em poupança/investimentos"
    )
    
    # Progresso de metas
    goals_progress = models.JSONField(
        default=dict,
        help_text="Progresso de cada meta ativa"
    )
    # Exemplo: {
    #   "goal_uuid_1": {"name": "Emergência", "progress": 45.5, "current": 2275, "target": 5000},
    #   "goal_uuid_2": {"name": "Férias", "progress": 78.0, "current": 3900, "target": 5000}
    # }
    
    # Métricas de comportamento
    transactions_registered_today = models.BooleanField(
        default=False,
        help_text="Se registrou pelo menos 1 transação hoje"
    )
    transaction_count_today = models.PositiveIntegerField(
        default=0,
        help_text="Número de transações registradas hoje"
    )
    total_transactions_lifetime = models.PositiveIntegerField(
        default=0,
        help_text="Total de transações desde sempre"
    )
    
    # Violações de orçamento
    budget_exceeded = models.BooleanField(
        default=False,
        help_text="Se excedeu orçamento em alguma categoria hoje"
    )
    budget_violations = models.JSONField(
        default=list,
        help_text="Categorias que excederam orçamento"
    )
    # Exemplo: ["alimentacao", "lazer"]
    
    # Metadados
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        unique_together = ('user', 'snapshot_date')
        ordering = ['-snapshot_date']
        indexes = [
            models.Index(fields=['user', '-snapshot_date']),
            models.Index(fields=['snapshot_date']),
        ]
    
    def __str__(self):
        return f"{self.user.username} - {self.snapshot_date}"


class UserMonthlySnapshot(models.Model):
    """
    Snapshot mensal consolidado.
    
    Criado automaticamente no último dia do mês.
    Útil para análises de longo prazo sem precisar agregar diários.
    """
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='monthly_snapshots'
    )
    year = models.PositiveIntegerField()
    month = models.PositiveIntegerField()  # 1-12
    
    # Médias mensais
    avg_tps = models.DecimalField(max_digits=6, decimal_places=2)
    avg_rdr = models.DecimalField(max_digits=6, decimal_places=2)
    avg_ili = models.DecimalField(max_digits=6, decimal_places=2)
    
    # Totais do mês
    total_income = models.DecimalField(max_digits=12, decimal_places=2)
    total_expense = models.DecimalField(max_digits=12, decimal_places=2)
    total_savings = models.DecimalField(max_digits=12, decimal_places=2)
    
    # Categoria mais gasta
    top_category = models.CharField(max_length=100, blank=True)
    top_category_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0
    )
    
    # Gastos por categoria (consolidado)
    category_spending = models.JSONField(default=dict)
    
    # Consistência
    days_with_transactions = models.PositiveIntegerField(
        default=0,
        help_text="Quantos dias do mês registrou transações"
    )
    days_in_month = models.PositiveIntegerField(default=30)
    consistency_rate = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        help_text="% de dias com registro (days_with_transactions / days_in_month)"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ('user', 'year', 'month')
        ordering = ['-year', '-month']
    
    def __str__(self):
        return f"{self.user.username} - {self.year}/{self.month:02d}"
```

---

### **Modelo 2: MissionProgressSnapshot (Histórico por Missão)**

```python
class MissionProgressSnapshot(models.Model):
    """
    Snapshot diário do progresso de uma missão específica.
    
    Criado automaticamente para cada missão ativa.
    Permite validação temporal e detecção de violações.
    """
    
    mission_progress = models.ForeignKey(
        'MissionProgress',
        on_delete=models.CASCADE,
        related_name='snapshots'
    )
    snapshot_date = models.DateField()
    
    # Valores dos indicadores neste dia
    tps_value = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        null=True,
        blank=True
    )
    rdr_value = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        null=True,
        blank=True
    )
    ili_value = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        null=True,
        blank=True
    )
    
    # Para missões de categoria
    category_spending = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Gasto na categoria alvo neste dia/período"
    )
    
    # Para missões de meta
    goal_progress = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="% de progresso da meta neste dia"
    )
    goal_current_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True
    )
    
    # Para missões de poupança
    savings_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Total em poupança neste dia"
    )
    
    # Validação de critério
    met_criteria = models.BooleanField(
        default=False,
        help_text="Se atendeu os critérios da missão neste dia"
    )
    criteria_details = models.JSONField(
        default=dict,
        help_text="Detalhes de quais critérios foram atendidos"
    )
    # Exemplo: {
    #   "tps_target": {"required": 20, "actual": 22, "met": true},
    #   "consecutive_days": 5
    # }
    
    # Dias consecutivos até este ponto
    consecutive_days_met = models.PositiveIntegerField(
        default=0,
        help_text="Quantos dias consecutivos atendeu critério até hoje"
    )
    
    # Progresso calculado (0-100%)
    progress_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=0
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ('mission_progress', 'snapshot_date')
        ordering = ['snapshot_date']
        indexes = [
            models.Index(fields=['mission_progress', 'snapshot_date']),
            models.Index(fields=['snapshot_date']),
        ]
    
    def __str__(self):
        return f"{self.mission_progress} - {self.snapshot_date}"
```

---

### **Modelo 3: Extensões em Mission**

```python
class Mission(models.Model):
    # ... campos existentes ...
    
    # === NOVOS CAMPOS ===
    
    # Tipo refinado de validação
    validation_type = models.CharField(
        max_length=30,
        choices=[
            ('SNAPSHOT', 'Comparação pontual (inicial vs atual)'),
            ('TEMPORAL', 'Manter critério por período'),
            ('CATEGORY_REDUCTION', 'Reduzir gasto em categoria'),
            ('CATEGORY_LIMIT', 'Não exceder limite em categoria'),
            ('GOAL_PROGRESS', 'Progredir em meta específica'),
            ('SAVINGS_INCREASE', 'Aumentar poupança'),
            ('CONSISTENCY', 'Manter consistência/streak'),
        ],
        default='SNAPSHOT'
    )
    
    # Para validação temporal
    requires_consecutive_days = models.BooleanField(
        default=False,
        help_text="Se requer X dias CONSECUTIVOS atendendo critério"
    )
    min_consecutive_days = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Número mínimo de dias consecutivos"
    )
    
    # Para missões de categoria
    target_category = models.ForeignKey(
        'Category',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='missions',
        help_text="Categoria alvo para missões de redução/limite"
    )
    target_reduction_percent = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="% de redução alvo (ex: 15 = reduzir 15%)"
    )
    category_spending_limit = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Limite de gasto em reais para a categoria"
    )
    
    # Para missões de meta
    target_goal = models.ForeignKey(
        'Goal',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='missions',
        help_text="Meta alvo (se missão for sobre meta específica)"
    )
    goal_progress_target = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="% de progresso alvo na meta (ex: 80 = completar 80%)"
    )
    
    # Para missões de poupança
    savings_increase_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Valor em R$ para aumentar poupança"
    )
    
    # Para missões de consistência
    requires_daily_action = models.BooleanField(
        default=False,
        help_text="Se requer ação diária (registrar transação, etc)"
    )
    min_daily_actions = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Número mínimo de ações diárias necessárias"
    )
```

---

### **Modelo 4: Extensões em MissionProgress**

```python
class MissionProgress(models.Model):
    # ... campos existentes ...
    
    # === NOVOS CAMPOS ===
    
    # Baseline de categoria (salvo ao iniciar)
    baseline_category_spending = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Gasto médio na categoria antes da missão começar"
    )
    baseline_period_days = models.PositiveIntegerField(
        default=30,
        help_text="Número de dias usados para calcular baseline"
    )
    
    # Para missões de meta
    initial_goal_progress = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="% de progresso da meta quando missão começou"
    )
    
    # Para missões de poupança
    initial_savings_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Total em poupança quando missão começou"
    )
    
    # Rastreamento de streak/consistência
    current_streak = models.PositiveIntegerField(
        default=0,
        help_text="Dias consecutivos atuais atendendo critério"
    )
    max_streak = models.PositiveIntegerField(
        default=0,
        help_text="Maior streak alcançado nesta missão"
    )
    days_met_criteria = models.PositiveIntegerField(
        default=0,
        help_text="Total de dias que atendeu critério (não necessariamente consecutivos)"
    )
    days_violated_criteria = models.PositiveIntegerField(
        default=0,
        help_text="Total de dias que violou critério"
    )
    last_violation_date = models.DateField(
        null=True,
        blank=True,
        help_text="Data da última violação de critério"
    )
    
    # Metadados de validação
    validation_details = models.JSONField(
        default=dict,
        help_text="Detalhes de como validação está sendo feita"
    )
    # Exemplo: {
    #   "type": "TEMPORAL",
    #   "required_days": 30,
    #   "days_completed": 15,
    #   "violations": []
    # }
```

---

## 🔄 TASKS CELERY

### **Task 1: Criar Snapshots Diários de Usuários**

```python
# Api/finance/tasks.py
from celery import shared_task
from django.utils import timezone
from django.contrib.auth import get_user_model
from .models import UserDailySnapshot, Transaction, Goal, Category
from .services import calculate_summary
from decimal import Decimal

User = get_user_model()


@shared_task
def create_daily_user_snapshots():
    """
    Task executada TODO DIA às 23:59 para criar snapshots de TODOS os usuários.
    
    Configurar no Celery Beat:
    CELERY_BEAT_SCHEDULE = {
        'create-daily-snapshots': {
            'task': 'finance.tasks.create_daily_user_snapshots',
            'schedule': crontab(hour=23, minute=59),
        },
    }
    """
    today = timezone.now().date()
    users = User.objects.filter(is_active=True)
    
    created_count = 0
    
    for user in users:
        try:
            # Verificar se já existe snapshot de hoje
            if UserDailySnapshot.objects.filter(user=user, snapshot_date=today).exists():
                continue
            
            # Calcular indicadores atuais
            summary = calculate_summary(user)
            
            # Calcular gastos por categoria (mês atual)
            month_start = today.replace(day=1)
            category_spending = _calculate_category_spending(user, month_start, today)
            
            # Calcular progresso de metas
            goals_progress = _calculate_goals_progress(user)
            
            # Verificar se registrou transação hoje
            registered_today = Transaction.objects.filter(
                user=user,
                date=today
            ).exists()
            
            transaction_count_today = Transaction.objects.filter(
                user=user,
                date=today
            ).count()
            
            # Total de transações lifetime
            total_transactions = Transaction.objects.filter(user=user).count()
            
            # Verificar violações de orçamento
            budget_exceeded, violations = _check_budget_violations(user, today)
            
            # Poupança (transações de INCOME em categorias de investimento)
            savings_today = _calculate_savings_added_today(user, today)
            savings_total = _calculate_total_savings(user)
            
            # Criar snapshot
            snapshot = UserDailySnapshot.objects.create(
                user=user,
                snapshot_date=today,
                tps=summary.get('tps', Decimal('0')),
                rdr=summary.get('rdr', Decimal('0')),
                ili=summary.get('ili', Decimal('0')),
                total_income=summary.get('total_income', Decimal('0')),
                total_expense=summary.get('total_expense', Decimal('0')),
                total_debt=summary.get('total_debt', Decimal('0')),
                available_balance=summary.get('available_balance', Decimal('0')),
                category_spending=category_spending,
                savings_added_today=savings_today,
                savings_total=savings_total,
                goals_progress=goals_progress,
                transactions_registered_today=registered_today,
                transaction_count_today=transaction_count_today,
                total_transactions_lifetime=total_transactions,
                budget_exceeded=budget_exceeded,
                budget_violations=violations,
            )
            
            created_count += 1
            
        except Exception as e:
            logger.error(f"Erro ao criar snapshot para {user.username}: {e}")
            continue
    
    logger.info(f"✓ {created_count} snapshots diários criados")
    return created_count


def _calculate_category_spending(user, start_date, end_date):
    """Calcula gastos por categoria no período."""
    from django.db.models import Sum
    
    spending = Transaction.objects.filter(
        user=user,
        type='EXPENSE',
        date__gte=start_date,
        date__lte=end_date
    ).values('category__name').annotate(
        total=Sum('amount'),
        count=models.Count('id')
    )
    
    return {
        item['category__name']: {
            'total': float(item['total']),
            'count': item['count']
        }
        for item in spending if item['category__name']
    }


def _calculate_goals_progress(user):
    """Calcula progresso de todas as metas ativas."""
    goals = Goal.objects.filter(user=user, is_active=True)
    
    return {
        str(goal.id): {
            'name': goal.name,
            'progress': float(goal.progress),
            'current': float(goal.current_amount),
            'target': float(goal.target_amount),
        }
        for goal in goals
    }


def _check_budget_violations(user, date):
    """Verifica se excedeu orçamento em alguma categoria."""
    # TODO: Implementar lógica de orçamento se existir
    # Por enquanto, retorna False
    return False, []


def _calculate_savings_added_today(user, date):
    """Calcula quanto foi adicionado em poupança hoje."""
    # Considera categorias de tipo INCOME com grupo de poupança/investimento
    savings = Transaction.objects.filter(
        user=user,
        date=date,
        type='INCOME',
        category__group__in=['SAVINGS', 'INVESTMENTS']
    ).aggregate(total=Sum('amount'))
    
    return savings.get('total') or Decimal('0')


def _calculate_total_savings(user):
    """Calcula total acumulado em poupança."""
    savings = Transaction.objects.filter(
        user=user,
        type='INCOME',
        category__group__in=['SAVINGS', 'INVESTMENTS']
    ).aggregate(total=Sum('amount'))
    
    return savings.get('total') or Decimal('0')
```

---

### **Task 2: Criar Snapshots de Missões Ativas**

```python
@shared_task
def create_daily_mission_snapshots():
    """
    Task executada TODO DIA às 23:59 para criar snapshots de MISSÕES ATIVAS.
    
    Executado DEPOIS de create_daily_user_snapshots para usar dados atualizados.
    """
    from .models import MissionProgress, MissionProgressSnapshot, UserDailySnapshot
    
    today = timezone.now().date()
    
    active_missions = MissionProgress.objects.filter(
        status__in=['PENDING', 'ACTIVE']
    ).select_related('mission', 'user')
    
    created_count = 0
    
    for progress in active_missions:
        try:
            # Verificar se já existe snapshot
            if MissionProgressSnapshot.objects.filter(
                mission_progress=progress,
                snapshot_date=today
            ).exists():
                continue
            
            # Buscar snapshot do usuário (já foi criado)
            user_snapshot = UserDailySnapshot.objects.filter(
                user=progress.user,
                snapshot_date=today
            ).first()
            
            if not user_snapshot:
                logger.warning(f"Snapshot do usuário não encontrado para {progress.user}")
                continue
            
            # Calcular se atendeu critérios
            met_criteria, criteria_details = _evaluate_mission_criteria(
                progress,
                user_snapshot
            )
            
            # Calcular streak
            consecutive_days = _calculate_consecutive_days(progress, met_criteria)
            
            # Calcular progresso %
            progress_pct = _calculate_mission_progress_percentage(
                progress,
                user_snapshot,
                consecutive_days
            )
            
            # Criar snapshot da missão
            snapshot = MissionProgressSnapshot.objects.create(
                mission_progress=progress,
                snapshot_date=today,
                tps_value=user_snapshot.tps,
                rdr_value=user_snapshot.rdr,
                ili_value=user_snapshot.ili,
                category_spending=_get_category_spending_for_mission(progress, user_snapshot),
                goal_progress=_get_goal_progress_for_mission(progress, user_snapshot),
                savings_amount=user_snapshot.savings_total,
                met_criteria=met_criteria,
                criteria_details=criteria_details,
                consecutive_days_met=consecutive_days,
                progress_percentage=progress_pct,
            )
            
            # Atualizar MissionProgress
            _update_mission_progress_from_snapshot(progress, snapshot)
            
            created_count += 1
            
        except Exception as e:
            logger.error(f"Erro ao criar snapshot de missão {progress.id}: {e}")
            continue
    
    logger.info(f"✓ {created_count} snapshots de missões criados")
    return created_count


def _evaluate_mission_criteria(progress, user_snapshot):
    """
    Avalia se missão atendeu critérios neste dia.
    
    Returns:
        tuple: (met_criteria: bool, criteria_details: dict)
    """
    mission = progress.mission
    details = {}
    met = True
    
    # Validar baseado no tipo
    if mission.validation_type == 'TEMPORAL':
        # Ex: Manter TPS > 20%
        if mission.target_tps is not None:
            actual_tps = float(user_snapshot.tps)
            required_tps = float(mission.target_tps)
            met_tps = actual_tps >= required_tps
            details['tps'] = {
                'required': required_tps,
                'actual': actual_tps,
                'met': met_tps
            }
            met = met and met_tps
        
        if mission.target_rdr is not None:
            actual_rdr = float(user_snapshot.rdr)
            required_rdr = float(mission.target_rdr)
            met_rdr = actual_rdr <= required_rdr  # Menor é melhor
            details['rdr'] = {
                'required': required_rdr,
                'actual': actual_rdr,
                'met': met_rdr
            }
            met = met and met_rdr
    
    elif mission.validation_type == 'CATEGORY_LIMIT':
        # Ex: Não gastar mais que R$ 500 em Lazer
        if mission.target_category and mission.category_spending_limit:
            category_name = mission.target_category.name
            actual_spending = user_snapshot.category_spending.get(
                category_name, {}
            ).get('total', 0)
            limit = float(mission.category_spending_limit)
            met_limit = actual_spending <= limit
            details['category_limit'] = {
                'category': category_name,
                'limit': limit,
                'actual': actual_spending,
                'met': met_limit
            }
            met = met_limit
    
    elif mission.validation_type == 'CONSISTENCY':
        # Ex: Registrar transação todo dia
        if mission.requires_daily_action:
            registered = user_snapshot.transactions_registered_today
            details['daily_action'] = {
                'required': True,
                'actual': registered,
                'met': registered
            }
            met = registered
    
    # Adicionar mais tipos conforme necessário
    
    return met, details


def _calculate_consecutive_days(progress, met_today):
    """Calcula quantos dias consecutivos atendeu critério."""
    if not met_today:
        # Quebrou a sequência
        return 0
    
    # Buscar último snapshot
    last_snapshot = MissionProgressSnapshot.objects.filter(
        mission_progress=progress
    ).order_by('-snapshot_date').first()
    
    if not last_snapshot:
        return 1 if met_today else 0
    
    # Se último também atendeu, incrementa
    if last_snapshot.met_criteria:
        return last_snapshot.consecutive_days_met + 1
    else:
        return 1 if met_today else 0


def _calculate_mission_progress_percentage(progress, user_snapshot, consecutive_days):
    """Calcula % de progresso da missão."""
    mission = progress.mission
    
    if mission.validation_type == 'TEMPORAL':
        # Progresso = (dias consecutivos / dias requeridos) * 100
        if mission.requires_consecutive_days and mission.min_consecutive_days:
            return min(100, (consecutive_days / mission.min_consecutive_days) * 100)
        else:
            # Usar duration_days como alvo
            return min(100, (consecutive_days / mission.duration_days) * 100)
    
    elif mission.validation_type == 'CATEGORY_REDUCTION':
        # Progresso = (redução alcançada / redução alvo) * 100
        if progress.baseline_category_spending:
            category_name = mission.target_category.name
            current_spending = user_snapshot.category_spending.get(
                category_name, {}
            ).get('total', 0)
            baseline = float(progress.baseline_category_spending)
            
            if baseline > 0:
                reduction_pct = ((baseline - current_spending) / baseline) * 100
                target_pct = float(mission.target_reduction_percent or 0)
                
                if target_pct > 0:
                    return min(100, (reduction_pct / target_pct) * 100)
        return 0
    
    elif mission.validation_type == 'GOAL_PROGRESS':
        # Progresso baseado em meta
        if mission.target_goal:
            goal_id = str(mission.target_goal.id)
            goal_data = user_snapshot.goals_progress.get(goal_id)
            
            if goal_data:
                current_progress = goal_data['progress']
                target_progress = float(mission.goal_progress_target or 100)
                initial_progress = float(progress.initial_goal_progress or 0)
                
                if target_progress > initial_progress:
                    needed = target_progress - initial_progress
                    achieved = current_progress - initial_progress
                    return min(100, (achieved / needed) * 100)
        return 0
    
    elif mission.validation_type == 'SAVINGS_INCREASE':
        # Progresso baseado em aumento de poupança
        if mission.savings_increase_amount:
            initial = float(progress.initial_savings_amount or 0)
            current = float(user_snapshot.savings_total)
            target_increase = float(mission.savings_increase_amount)
            
            actual_increase = current - initial
            return min(100, (actual_increase / target_increase) * 100)
        return 0
    
    # Default: usar lógica antiga
    return float(progress.progress)


def _update_mission_progress_from_snapshot(progress, snapshot):
    """Atualiza MissionProgress baseado no snapshot criado."""
    progress.progress = snapshot.progress_percentage
    progress.current_streak = snapshot.consecutive_days_met
    progress.max_streak = max(progress.max_streak, snapshot.consecutive_days_met)
    
    if snapshot.met_criteria:
        progress.days_met_criteria += 1
    else:
        progress.days_violated_criteria += 1
        progress.last_violation_date = snapshot.snapshot_date
        progress.current_streak = 0  # Resetar streak
    
    # Completar se atingiu 100%
    if snapshot.progress_percentage >= 100:
        progress.status = 'COMPLETED'
        progress.completed_at = timezone.now()
        apply_mission_reward(progress)
    
    # Ativar se estava pendente e tem progresso
    elif progress.status == 'PENDING' and snapshot.progress_percentage > 0:
        progress.status = 'ACTIVE'
        progress.started_at = timezone.now()
    
    # Verificar expiração
    if progress.started_at and progress.mission.duration_days:
        deadline = progress.started_at.date() + timedelta(days=progress.mission.duration_days)
        if timezone.now().date() > deadline and progress.status != 'COMPLETED':
            progress.status = 'FAILED'
    
    progress.save()
```

---

### **Task 3: Consolidar Snapshots Mensais**

```python
@shared_task
def create_monthly_snapshots():
    """
    Task executada no ÚLTIMO DIA DO MÊS para consolidar snapshots mensais.
    
    Configurar no Celery Beat:
    CELERY_BEAT_SCHEDULE = {
        'create-monthly-snapshots': {
            'task': 'finance.tasks.create_monthly_snapshots',
            'schedule': crontab(day_of_month='last', hour=23, minute=59),
        },
    }
    """
    from django.db.models import Avg, Sum
    from .models import UserMonthlySnapshot
    
    today = timezone.now().date()
    year = today.year
    month = today.month
    
    users = User.objects.filter(is_active=True)
    created_count = 0
    
    for user in users:
        try:
            # Buscar snapshots diários do mês
            daily_snapshots = UserDailySnapshot.objects.filter(
                user=user,
                snapshot_date__year=year,
                snapshot_date__month=month
            )
            
            if not daily_snapshots.exists():
                continue
            
            # Calcular médias
            averages = daily_snapshots.aggregate(
                avg_tps=Avg('tps'),
                avg_rdr=Avg('rdr'),
                avg_ili=Avg('ili')
            )
            
            # Último snapshot do mês
            last_snapshot = daily_snapshots.order_by('-snapshot_date').first()
            
            # Consolidar gastos por categoria
            category_spending = {}
            for snapshot in daily_snapshots:
                for cat, data in snapshot.category_spending.items():
                    if cat not in category_spending:
                        category_spending[cat] = {'total': 0, 'count': 0}
                    category_spending[cat]['total'] += data['total']
                    category_spending[cat]['count'] += data['count']
            
            # Categoria top
            top_cat = max(
                category_spending.items(),
                key=lambda x: x[1]['total']
            ) if category_spending else (None, {'total': 0})
            
            # Dias com transações
            days_with_trans = daily_snapshots.filter(
                transactions_registered_today=True
            ).count()
            
            total_days = daily_snapshots.count()
            consistency = (days_with_trans / total_days * 100) if total_days > 0 else 0
            
            # Criar snapshot mensal
            UserMonthlySnapshot.objects.create(
                user=user,
                year=year,
                month=month,
                avg_tps=averages['avg_tps'] or 0,
                avg_rdr=averages['avg_rdr'] or 0,
                avg_ili=averages['avg_ili'] or 0,
                total_income=last_snapshot.total_income,
                total_expense=last_snapshot.total_expense,
                total_savings=last_snapshot.savings_total,
                top_category=top_cat[0] or '',
                top_category_amount=top_cat[1]['total'],
                category_spending=category_spending,
                days_with_transactions=days_with_trans,
                days_in_month=total_days,
                consistency_rate=Decimal(str(consistency)),
            )
            
            created_count += 1
            
        except Exception as e:
            logger.error(f"Erro ao criar snapshot mensal para {user.username}: {e}")
            continue
    
    logger.info(f"✓ {created_count} snapshots mensais criados")
    return created_count
```

---

## 🔧 FUNÇÕES DE SERVIÇO ATUALIZADAS

### **Inicialização de Missão (com Baselines)**

```python
def initialize_mission_progress(progress):
    """
    Inicializa MissionProgress com todos os baselines necessários.
    
    Chamado quando missão é atribuída ao usuário pela primeira vez.
    """
    user = progress.user
    mission = progress.mission
    
    # Calcular summary atual
    summary = calculate_summary(user)
    
    # Valores iniciais padrão (já existentes)
    progress.initial_tps = summary.get('tps', Decimal('0'))
    progress.initial_rdr = summary.get('rdr', Decimal('0'))
    progress.initial_ili = summary.get('ili', Decimal('0'))
    progress.initial_transaction_count = Transaction.objects.filter(user=user).count()
    
    # === NOVOS BASELINES ===
    
    # Para missões de categoria
    if mission.validation_type in ['CATEGORY_REDUCTION', 'CATEGORY_LIMIT']:
        if mission.target_category:
            # Calcular baseline dos últimos 30 dias
            baseline_days = 30
            start_date = timezone.now().date() - timedelta(days=baseline_days)
            
            baseline = Transaction.objects.filter(
                user=user,
                type='EXPENSE',
                category=mission.target_category,
                date__gte=start_date
            ).aggregate(total=Sum('amount'))
            
            progress.baseline_category_spending = baseline.get('total') or Decimal('0')
            progress.baseline_period_days = baseline_days
    
    # Para missões de meta
    if mission.validation_type == 'GOAL_PROGRESS':
        if mission.target_goal:
            goal = mission.target_goal
            progress.initial_goal_progress = goal.progress
    
    # Para missões de poupança
    if mission.validation_type == 'SAVINGS_INCREASE':
        # Total atual em poupança
        savings = Transaction.objects.filter(
            user=user,
            type='INCOME',
            category__group__in=['SAVINGS', 'INVESTMENTS']
        ).aggregate(total=Sum('amount'))
        
        progress.initial_savings_amount = savings.get('total') or Decimal('0')
    
    # Iniciar como PENDING
    progress.status = 'PENDING'
    progress.current_streak = 0
    progress.max_streak = 0
    progress.days_met_criteria = 0
    progress.days_violated_criteria = 0
    
    progress.save()
    
    logger.info(f"Missão {mission.title} inicializada para {user.username}")
```

---

### **Validação Manual (quando necessário)**

```python
def validate_mission_progress_manual(progress):
    """
    Valida progresso de uma missão MANUALMENTE (fora do ciclo diário).
    
    Útil para:
    - Validação imediata após transação
    - Verificação on-demand pelo usuário
    - Testes
    """
    from .models import UserDailySnapshot
    
    # Buscar último snapshot do usuário (ou criar temporário)
    today = timezone.now().date()
    snapshot = UserDailySnapshot.objects.filter(
        user=progress.user,
        snapshot_date=today
    ).first()
    
    if not snapshot:
        # Criar snapshot temporário (não salvo)
        summary = calculate_summary(progress.user)
        snapshot = UserDailySnapshot(
            user=progress.user,
            snapshot_date=today,
            tps=summary.get('tps', Decimal('0')),
            rdr=summary.get('rdr', Decimal('0')),
            ili=summary.get('ili', Decimal('0')),
            # ... outros campos ...
        )
    
    # Avaliar critérios
    met_criteria, details = _evaluate_mission_criteria(progress, snapshot)
    
    # Calcular progresso
    consecutive = _calculate_consecutive_days(progress, met_criteria)
    progress_pct = _calculate_mission_progress_percentage(progress, snapshot, consecutive)
    
    # Atualizar
    progress.progress = Decimal(str(progress_pct))
    
    if progress_pct >= 100:
        progress.status = 'COMPLETED'
        progress.completed_at = timezone.now()
        apply_mission_reward(progress)
    elif progress.status == 'PENDING' and progress_pct > 0:
        progress.status = 'ACTIVE'
        progress.started_at = timezone.now()
    
    progress.save()
    
    return progress
```

---

## 📈 USO DO HISTÓRICO PARA GERAÇÃO DE MISSÕES

### **Análise de Evolução do Usuário**

```python
def analyze_user_evolution(user, days=90):
    """
    Analisa evolução do usuário nos últimos X dias.
    
    Usado pela IA para gerar missões personalizadas.
    
    Returns:
        dict: Análise completa de evolução
    """
    from .models import UserDailySnapshot
    from django.db.models import Avg, Min, Max
    
    start_date = timezone.now().date() - timedelta(days=days)
    
    snapshots = UserDailySnapshot.objects.filter(
        user=user,
        snapshot_date__gte=start_date
    ).order_by('snapshot_date')
    
    if not snapshots.exists():
        return {
            'has_data': False,
            'message': 'Dados insuficientes para análise'
        }
    
    # Análise de TPS
    tps_data = snapshots.aggregate(
        avg=Avg('tps'),
        min=Min('tps'),
        max=Max('tps')
    )
    first_tps = float(snapshots.first().tps)
    last_tps = float(snapshots.last().tps)
    tps_trend = 'crescente' if last_tps > first_tps else 'decrescente' if last_tps < first_tps else 'estável'
    
    # Análise de RDR
    rdr_data = snapshots.aggregate(
        avg=Avg('rdr'),
        min=Min('rdr'),
        max=Max('rdr')
    )
    first_rdr = float(snapshots.first().rdr)
    last_rdr = float(snapshots.last().rdr)
    rdr_trend = 'crescente' if last_rdr > first_rdr else 'decrescente' if last_rdr < first_rdr else 'estável'
    
    # Categoria mais problemática
    all_category_spending = {}
    for snapshot in snapshots:
        for cat, data in snapshot.category_spending.items():
            if cat not in all_category_spending:
                all_category_spending[cat] = 0
            all_category_spending[cat] += data['total']
    
    problem_category = max(
        all_category_spending.items(),
        key=lambda x: x[1]
    )[0] if all_category_spending else None
    
    # Consistência de registro
    days_with_registro = snapshots.filter(
        transactions_registered_today=True
    ).count()
    consistency_rate = (days_with_registro / snapshots.count()) * 100
    
    # Identificar problemas
    problems = []
    if tps_data['avg'] < 15:
        problems.append('TPS_BAIXO')
    if rdr_data['avg'] > 40:
        problems.append('RDR_ALTO')
    if consistency_rate < 50:
        problems.append('BAIXA_CONSISTENCIA')
    
    # Identificar pontos fortes
    strengths = []
    if tps_trend == 'crescente':
        strengths.append('TPS_MELHORANDO')
    if rdr_trend == 'decrescente':
        strengths.append('RDR_MELHORANDO')
    if consistency_rate > 80:
        strengths.append('ALTA_CONSISTENCIA')
    
    return {
        'has_data': True,
        'period_days': days,
        'tps': {
            'average': float(tps_data['avg']),
            'min': float(tps_data['min']),
            'max': float(tps_data['max']),
            'first': first_tps,
            'last': last_tps,
            'trend': tps_trend,
        },
        'rdr': {
            'average': float(rdr_data['avg']),
            'min': float(rdr_data['min']),
            'max': float(rdr_data['max']),
            'first': first_rdr,
            'last': last_rdr,
            'trend': rdr_trend,
        },
        'categories': {
            'most_spending': problem_category,
            'all_spending': all_category_spending,
        },
        'consistency': {
            'rate': consistency_rate,
            'days_registered': days_with_registro,
            'total_days': snapshots.count(),
        },
        'problems': problems,
        'strengths': strengths,
    }


def get_mission_generation_context_enhanced(user):
    """
    Contexto aprimorado para geração de missões usando histórico.
    
    Usado pelo prompt da IA.
    """
    # Análise de evolução
    evolution = analyze_user_evolution(user, days=90)
    
    # Tier atual
    tier = 'BEGINNER' if user.userprofile.level <= 5 else \
           'INTERMEDIATE' if user.userprofile.level <= 15 else \
           'ADVANCED'
    
    # Missões recentes completadas
    recent_completed = MissionProgress.objects.filter(
        user=user,
        status='COMPLETED'
    ).order_by('-completed_at')[:5]
    
    completed_types = [m.mission.mission_type for m in recent_completed]
    
    # Determinar foco recomendado
    if 'TPS_BAIXO' in evolution.get('problems', []):
        recommended_focus = 'SAVINGS'
    elif 'RDR_ALTO' in evolution.get('problems', []):
        recommended_focus = 'DEBT'
    elif 'BAIXA_CONSISTENCIA' in evolution.get('problems', []):
        recommended_focus = 'CONSISTENCY'
    else:
        recommended_focus = 'AUTO'
    
    return {
        'user_id': user.id,
        'tier': tier,
        'level': user.userprofile.level,
        'evolution': evolution,
        'recommended_focus': recommended_focus,
        'recent_completed_types': completed_types,
        'problem_category': evolution.get('categories', {}).get('most_spending'),
    }
```

---

## 🎯 TIPOS DE MISSÕES SUPORTADAS (COMPLETO)

### **1. Missões de Melhoria Pontual** ✅
```python
Mission(
    validation_type='SNAPSHOT',
    target_tps=25,
    # Valida: TPS atual >= 25%
)
```

### **2. Missões Temporais** ✅
```python
Mission(
    validation_type='TEMPORAL',
    target_tps=20,
    requires_consecutive_days=True,
    min_consecutive_days=30,
    # Valida: TPS >= 20% por 30 dias CONSECUTIVOS
)
```

### **3. Missões de Categoria - Redução** ✅
```python
Mission(
    validation_type='CATEGORY_REDUCTION',
    target_category=alimentacao,
    target_reduction_percent=15,
    duration_days=30,
    # Valida: Reduzir gastos com alimentação em 15% comparado ao baseline
)
```

### **4. Missões de Categoria - Limite** ✅
```python
Mission(
    validation_type='CATEGORY_LIMIT',
    target_category=lazer,
    category_spending_limit=500,
    duration_days=30,
    # Valida: Não gastar mais que R$ 500 em lazer no mês
)
```

### **5. Missões de Meta** ✅
```python
Mission(
    validation_type='GOAL_PROGRESS',
    target_goal=emergencia_goal,
    goal_progress_target=80,
    # Valida: Completar 80% da meta de emergência
)
```

### **6. Missões de Poupança** ✅
```python
Mission(
    validation_type='SAVINGS_INCREASE',
    savings_increase_amount=500,
    duration_days=30,
    # Valida: Adicionar R$ 500 em poupança no mês
)
```

### **7. Missões de Consistência** ✅
```python
Mission(
    validation_type='CONSISTENCY',
    requires_daily_action=True,
    duration_days=7,
    # Valida: Registrar transações por 7 dias consecutivos
)
```

---

## 📅 CRONOGRAMA DE IMPLEMENTAÇÃO

### **Sprint 1 (2-3 dias) - Modelos e Migrations** ⭐ CRÍTICO
- [ ] Criar modelo `UserDailySnapshot`
- [ ] Criar modelo `UserMonthlySnapshot`
- [ ] Criar modelo `MissionProgressSnapshot`
- [ ] Estender modelo `Mission` com novos campos
- [ ] Estender modelo `MissionProgress` com novos campos
- [ ] Criar e rodar migrations
- [ ] Testes unitários dos modelos

### **Sprint 2 (2-3 dias) - Tasks Celery** ⭐ CRÍTICO
- [ ] Implementar `create_daily_user_snapshots()`
- [ ] Implementar `create_daily_mission_snapshots()`
- [ ] Implementar `create_monthly_snapshots()`
- [ ] Configurar Celery Beat schedule
- [ ] Testes das tasks

### **Sprint 3 (2 dias) - Funções de Validação** ⭐ CRÍTICO
- [ ] Implementar `_evaluate_mission_criteria()`
- [ ] Implementar `_calculate_consecutive_days()`
- [ ] Implementar `_calculate_mission_progress_percentage()`
- [ ] Implementar `initialize_mission_progress()`
- [ ] Implementar `validate_mission_progress_manual()`
- [ ] Testes de validação

### **Sprint 4 (1-2 dias) - Análise e IA**
- [ ] Implementar `analyze_user_evolution()`
- [ ] Implementar `get_mission_generation_context_enhanced()`
- [ ] Atualizar prompt da IA para usar análise
- [ ] Testes de geração

### **Sprint 5 (1 dia) - Migração de Dados**
- [ ] Script para popular snapshots históricos (se possível)
- [ ] Script para atualizar missões existentes
- [ ] Validação de dados migrados

### **Sprint 6 (1 dia) - Testes de Integração**
- [ ] Teste completo do fluxo diário
- [ ] Teste de missões de cada tipo
- [ ] Teste de edge cases
- [ ] Performance testing

---

## 🎓 BENEFÍCIOS PARA O TCC

### **1. Sistema Robusto e Profissional**
- ✅ Suporta TODOS os tipos de missões mencionados
- ✅ Rastreamento temporal completo
- ✅ Validação precisa e confiável
- ✅ Análise de evolução do usuário

### **2. Diferencial Técnico**
- ✅ Uso de snapshots diários (padrão de mercado)
- ✅ Celery Beat para automação
- ✅ Sistema escalável e performático
- ✅ Arquitetura bem planejada

### **3. Base para IA Avançada**
- ✅ Histórico rico para análise
- ✅ Identificação de padrões
- ✅ Personalização real
- ✅ Missões verdadeiramente adaptativas

### **4. Apresentação**
Slides sugeridos:
- "Sistema de Rastreamento Temporal"
- "7 Tipos de Missões Suportadas"
- "Análise de Evolução com 90 dias de histórico"
- "Validação Diária Automatizada com Celery"

---

## ⚠️ CONSIDERAÇÕES E TRADE-OFFS

### **Custo de Implementação:**
- **Tempo:** 8-12 dias de desenvolvimento
- **Complexidade:** Alta (mas bem estruturada)
- **Testes:** Essencial (mais 2-3 dias)

### **Custo de Operação:**
- **Storage:** ~1-2 KB por usuário por dia (~730 KB/ano)
- **Processing:** Task diária leve (< 1s por usuário)
- **Queries:** Otimizadas com indexes

### **Benefícios vs Complexidade:**
- ✅ Vale a pena para TCC de qualidade
- ✅ Demonstra engenharia profissional
- ✅ Sistema realmente funcional
- ✅ Diferencial competitivo

---

## 📝 PRÓXIMOS PASSOS RECOMENDADOS

1. **Revisar e Aprovar** este plano
2. **Priorizar** sprints críticos (1-3)
3. **Começar** pela Sprint 1 (modelos)
4. **Testar** incrementalmente
5. **Documentar** para o TCC

**Quer que eu comece a implementar alguma sprint específica?**

---

**Data:** 09/11/2025  
**Documento:** Plano de Implementação Completo - Sistema de Histórico e Validação
