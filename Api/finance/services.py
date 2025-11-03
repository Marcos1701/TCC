from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Dict, Iterable, List

from django.db.models import Case, DecimalField, F, Sum, When
from django.db.models.functions import Coalesce, TruncMonth
from django.utils import timezone

from .models import Category, Mission, MissionProgress, Transaction, UserProfile


def _decimal(value) -> Decimal:
    if isinstance(value, Decimal):
        return value
    return Decimal(value or 0)


def _debt_components(user) -> Dict[str, Decimal]:
    debt_qs = Transaction.objects.filter(user=user, category__type=Category.CategoryType.DEBT)
    increases = _decimal(
        debt_qs.filter(type=Transaction.TransactionType.EXPENSE).aggregate(
            total=Coalesce(Sum("amount"), Decimal("0"))
        )["total"]
    )
    payments = _decimal(
        debt_qs.filter(type=Transaction.TransactionType.DEBT_PAYMENT).aggregate(
            total=Coalesce(Sum("amount"), Decimal("0"))
        )["total"]
    )
    adjustments = _decimal(
        debt_qs.filter(type=Transaction.TransactionType.INCOME).aggregate(
            total=Coalesce(Sum("amount"), Decimal("0"))
        )["total"]
    )

    balance = increases - payments - adjustments
    return {
        "increases": increases,
        "payments": payments,
        "adjustments": adjustments,
        "balance": balance,
    }


def calculate_summary(user) -> Dict[str, Decimal]:
    """
    Calcula os indicadores financeiros principais do usuário.
    Utiliza cache quando disponível e não expirado.
    
    Indicadores calculados:
    - TPS (Taxa de Poupança Pessoal): (Receitas - Despesas - Pagamentos de Dívida) / Receitas × 100
    - RDR (Razão Dívida/Renda): Saldo de Dívidas / Receitas × 100
    - ILI (Índice de Liquidez Imediata): Reservas Líquidas / Média Despesas Essenciais (3 meses)
    
    Args:
        user: Usuário para cálculo dos indicadores
        
    Returns:
        Dicionário com indicadores e totais financeiros
    """
    # Verificar cache
    profile, _ = UserProfile.objects.get_or_create(user=user)
    if not profile.should_recalculate_indicators():
        # Usar valores em cache
        return {
            "tps": profile.cached_tps or Decimal("0.00"),
            "rdr": profile.cached_rdr or Decimal("0.00"),
            "ili": profile.cached_ili or Decimal("0.00"),
            "total_income": profile.cached_total_income or Decimal("0.00"),
            "total_expense": profile.cached_total_expense or Decimal("0.00"),
            "total_debt": profile.cached_total_debt or Decimal("0.00"),
        }
    
    # Calcular indicadores
    totals = defaultdict(Decimal)
    for entry in (
        Transaction.objects.filter(user=user)
        .values("type")
        .annotate(total=Sum("amount"))
    ):
        totals[entry["type"]] = _decimal(entry["total"])

    income = totals.get(Transaction.TransactionType.INCOME, Decimal("0"))
    expense = totals.get(Transaction.TransactionType.EXPENSE, Decimal("0"))
    debt_info = _debt_components(user)
    debt_balance = debt_info["balance"]
    debt_payments = debt_info["payments"]

    reserve_income = Decimal("0")
    reserve_expense = Decimal("0")
    for item in (
        Transaction.objects.filter(user=user, category__group=Category.CategoryGroup.SAVINGS)
        .values("type")
        .annotate(total=Sum("amount"))
    ):
        tx_type = item["type"]
        total = _decimal(item["total"])
        if tx_type == Transaction.TransactionType.EXPENSE:
            reserve_expense = total
        elif tx_type == Transaction.TransactionType.INCOME:
            reserve_income = total

    # Calcular média de despesas essenciais dos últimos 3 meses para ILI mais estável
    today = timezone.now().date()
    three_months_ago = today - timedelta(days=90)
    essential_expense_total = _decimal(
        Transaction.objects.filter(
            user=user,
            category__group=Category.CategoryGroup.ESSENTIAL_EXPENSE,
            type=Transaction.TransactionType.EXPENSE,
            date__gte=three_months_ago,
            date__lte=today,
        ).aggregate(total=Sum("amount"))["total"]
    )
    # Média mensal de despesas essenciais
    essential_expense = essential_expense_total / Decimal("3") if essential_expense_total > 0 else Decimal("0")

    # Cálculo do TPS: considera pagamentos de dívida como saída de receita
    tps = Decimal("0")
    rdr = Decimal("0")
    ili = Decimal("0")
    
    if income > 0:
        # TPS corrigido: desconta despesas E pagamentos de dívida da receita
        poupanca = income - expense - debt_payments
        tps = (poupanca / income) * Decimal("100")
        
        # RDR: usa saldo atual de dívidas se positivo
        if debt_balance > 0:
            rdr = (debt_balance / income) * Decimal("100")

    # ILI: quantos meses a reserva cobre de despesas essenciais
    reserve_balance = reserve_income - reserve_expense
    if essential_expense > 0:
        ili = reserve_balance / essential_expense

    debt_total = debt_balance if debt_balance > 0 else Decimal("0")

    # Atualizar cache
    profile.cached_tps = tps.quantize(Decimal("0.01")) if income > 0 else Decimal("0.00")
    profile.cached_rdr = rdr.quantize(Decimal("0.01")) if income > 0 else Decimal("0.00")
    profile.cached_ili = ili.quantize(Decimal("0.01")) if essential_expense > 0 else Decimal("0.00")
    profile.cached_total_income = income.quantize(Decimal("0.01"))
    profile.cached_total_expense = expense.quantize(Decimal("0.01"))
    profile.cached_total_debt = debt_total.quantize(Decimal("0.01"))
    profile.indicators_updated_at = timezone.now()
    profile.save(update_fields=[
        'cached_tps', 
        'cached_rdr', 
        'cached_ili', 
        'cached_total_income',
        'cached_total_expense',
        'cached_total_debt',
        'indicators_updated_at'
    ])

    return {
        "tps": profile.cached_tps,
        "rdr": profile.cached_rdr,
        "ili": profile.cached_ili,
        "total_income": profile.cached_total_income,
        "total_expense": profile.cached_total_expense,
        "total_debt": profile.cached_total_debt,
    }


def invalidate_indicators_cache(user) -> None:
    """
    Invalida o cache de indicadores, forçando recálculo na próxima consulta.
    Deve ser chamado após criar/editar/deletar transações.
    
    Args:
        user: Usuário cujo cache deve ser invalidado
    """
    try:
        profile = UserProfile.objects.get(user=user)
        profile.indicators_updated_at = None
        profile.save(update_fields=['indicators_updated_at'])
    except UserProfile.DoesNotExist:
        pass


def category_breakdown(user) -> Dict[str, List[Dict[str, str]]]:
    buckets: Dict[str, List[Dict[str, str]]] = defaultdict(list)
    queryset = (
        Transaction.objects.filter(user=user, category__isnull=False)
        .annotate(
            signed_amount=Case(
                When(
                    category__type=Category.CategoryType.DEBT,
                    type__in=[
                        Transaction.TransactionType.DEBT_PAYMENT,
                        Transaction.TransactionType.INCOME,
                    ],
                    then=-F("amount"),
                ),
                default=F("amount"),
                output_field=DecimalField(max_digits=12, decimal_places=2),
            )
        )
        .values("category__name", "category__type", "category__group")
        .annotate(total=Coalesce(Sum("signed_amount"), Decimal("0")))
        .order_by("category__name")
    )

    for item in queryset:
        total_value = _decimal(item["total"])
        if item["category__type"] == Category.CategoryType.DEBT:
            total_value = max(total_value, Decimal("0"))
        buckets[item["category__type"]].append(
            {
                "name": item["category__name"],
                "group": item.get("category__group") or Category.CategoryGroup.OTHER,
                "total": total_value.quantize(Decimal("0.01")),
            }
        )
    return buckets


def _calculate_monthly_indicators(income: Decimal, expense: Decimal, debt_payments: Decimal, debt_balance: Decimal) -> Dict[str, Decimal]:
    """
    Calcula TPS e RDR para um período específico.
    Extrai lógica comum usada em calculate_summary e cashflow_series.
    
    Args:
        income: Total de receitas do período
        expense: Total de despesas do período
        debt_payments: Total de pagamentos de dívida do período
        debt_balance: Saldo de dívidas do período
        
    Returns:
        Dicionário com 'tps' e 'rdr' calculados
    """
    tps = Decimal("0")
    rdr = Decimal("0")
    
    if income > 0:
        # TPS: poupança líquida após despesas e pagamentos de dívida
        poupanca = income - expense - debt_payments
        tps = (poupanca / income) * Decimal("100")
        
        # RDR: usa saldo de dívidas se positivo
        if debt_balance > 0:
            rdr = (debt_balance / income) * Decimal("100")
    
    return {
        "tps": tps.quantize(Decimal("0.01")),
        "rdr": rdr.quantize(Decimal("0.01")),
    }


def cashflow_series(user, months: int = 6) -> List[Dict[str, str]]:
    """
    Gera série temporal de fluxo de caixa e indicadores mensais.
    
    Args:
        user: Usuário para análise
        months: Número de meses retroativos a incluir (padrão: 6)
        
    Returns:
        Lista de dicionários com dados mensais (income, expense, debt, tps, rdr)
    """
    now = timezone.now().date()
    first_day = (now.replace(day=1) - timedelta(days=months * 31)).replace(day=1)
    data = (
        Transaction.objects.filter(user=user, date__gte=first_day)
        .annotate(month=TruncMonth("date"))
        .values("month", "type")
        .annotate(total=Sum("amount"))
    )

    buckets: Dict[date, Dict[str, Decimal]] = defaultdict(lambda: defaultdict(Decimal))
    for item in data:
        month_value = item["month"]
        if isinstance(month_value, datetime):
            month = month_value.date()
        else:
            month = month_value
        buckets[month][item["type"]] += _decimal(item["total"])

    debt_data = (
        Transaction.objects.filter(
            user=user,
            category__type=Category.CategoryType.DEBT,
            date__gte=first_day,
        )
        .annotate(month=TruncMonth("date"))
        .values("month", "type")
        .annotate(total=Sum("amount"))
    )

    debt_buckets: Dict[date, Dict[str, Decimal]] = defaultdict(lambda: defaultdict(Decimal))
    for item in debt_data:
        month_value = item["month"]
        if isinstance(month_value, datetime):
            month = month_value.date()
        else:
            month = month_value
        debt_buckets[month][item["type"]] += _decimal(item["total"])

    series: List[Dict[str, str]] = []
    current = now.replace(day=1)
    for _ in range(months):
        income = buckets[current].get(Transaction.TransactionType.INCOME, Decimal("0"))
        expense = buckets[current].get(Transaction.TransactionType.EXPENSE, Decimal("0"))
        debt_increase = debt_buckets[current].get(Transaction.TransactionType.EXPENSE, Decimal("0"))
        debt_payment = debt_buckets[current].get(Transaction.TransactionType.DEBT_PAYMENT, Decimal("0"))
        debt_adjustment = debt_buckets[current].get(Transaction.TransactionType.INCOME, Decimal("0"))
        
        # Saldo de dívidas do mês
        debt = debt_increase - debt_payment - debt_adjustment
        if debt < 0:
            debt = Decimal("0")
        
        # Usa função auxiliar para calcular indicadores de forma consistente
        indicators = _calculate_monthly_indicators(income, expense, debt_payment, debt)
        
        series.append(
            {
                "month": current.strftime("%Y-%m"),
                "income": income.quantize(Decimal("0.01")),
                "expense": expense.quantize(Decimal("0.01")),
                "debt": debt.quantize(Decimal("0.01")),
                "tps": indicators["tps"],
                "rdr": indicators["rdr"],
            }
        )
        if current.month == 1:
            current = current.replace(year=current.year - 1, month=12)
        else:
            current = current.replace(month=current.month - 1)
    series.reverse()
    return series


def _xp_threshold(level: int) -> int:
    return 150 + (level - 1) * 50


def apply_mission_reward(progress: MissionProgress) -> None:
    profile: UserProfile = progress.user.userprofile
    profile.experience_points += progress.mission.reward_points

    while profile.experience_points >= _xp_threshold(profile.level):
        profile.experience_points -= _xp_threshold(profile.level)
        profile.level += 1
    profile.save(update_fields=["experience_points", "level"])


def profile_snapshot(user) -> Dict[str, int]:
    profile, _ = UserProfile.objects.get_or_create(user=user)
    return {
        "level": profile.level,
        "experience_points": profile.experience_points,
        "next_level_threshold": profile.next_level_threshold,
        "target_tps": profile.target_tps,
        "target_rdr": profile.target_rdr,
        "target_ili": profile.target_ili,
    }


def indicator_insights(summary: Dict[str, Decimal], profile: UserProfile) -> Dict[str, Dict[str, str]]:
    """Gera dicas alinhadas às faixas descritas no texto."""

    def _quantize(value: Decimal) -> Decimal:
        return value.quantize(Decimal("0.01"))

    def _tps_status(value: Decimal) -> Dict[str, str]:
        numero = float(value)
        if numero >= profile.target_tps:
            return {
                "severity": "good",
                "title": "Boa disciplina",
                "message": "A poupança tá batendo a meta, segue no ritmo.",
            }
        if numero >= 10:
            return {
                "severity": "attention",
                "title": "Quase lá",
                "message": f"Dá pra cortar uns gastos pra chegar nos {profile.target_tps}% esperados.",
            }
        return {
            "severity": "critical",
            "title": "Reserva apertada",
            "message": "Organiza prioridades e tenta separar algo todo mês pra não ficar no sufoco.",
        }

    def _rdr_status(value: Decimal) -> Dict[str, str]:
        numero = float(value)
        if numero <= profile.target_rdr:
            return {
                "severity": "good",
                "title": "Dívidas controladas",
                "message": "Comprometimento da renda tá saudável, mantém as parcelas em dia.",
            }
        if numero <= 42:
            return {
                "severity": "attention",
                "title": "Fica de olho",
                "message": f"Avalia renegociação ou amortização leve pra ficar abaixo dos {profile.target_rdr}%.",
            }
        if numero <= 49:
            return {
                "severity": "warning",
                "title": "Alerta ligado",
                "message": "Boa rever prioridades e conter novos créditos enquanto ajusta as dívidas.",
            }
        return {
            "severity": "critical",
            "title": "Risco alto",
            "message": "Busca renegociar e cortar gastos urgentes pra escapar de inadimplência.",
        }

    def _ili_status(value: Decimal) -> Dict[str, str]:
        numero = float(value)
        alvo = float(profile.target_ili)
        if numero >= alvo:
            return {
                "severity": "good",
                "title": "Reserva sólida",
                "message": "Liquidez cobre vários meses, dá pra pensar em diversificar investimentos.",
            }
        if numero >= 3:
            return {
                "severity": "attention",
                "title": "Cofre em construção",
                "message": "Reserva segura por poucos meses, planeja aportes automáticos pra chegar na meta.",
            }
        return {
            "severity": "critical",
            "title": "Almofada curta",
            "message": "Prioriza formar reserva de emergência pra aguentar imprevistos sem recorrer a crédito.",
        }

    tps_value = summary.get("tps", Decimal("0"))
    rdr_value = summary.get("rdr", Decimal("0"))
    ili_value = summary.get("ili", Decimal("0"))

    tps_info = _tps_status(tps_value)
    rdr_info = _rdr_status(rdr_value)
    ili_info = _ili_status(ili_value)

    return {
        "tps": {
            "value": _quantize(tps_value),
            "target": profile.target_tps,
            **tps_info,
        },
        "rdr": {
            "value": _quantize(rdr_value),
            "target": profile.target_rdr,
            **rdr_info,
        },
        "ili": {
            "value": _quantize(ili_value),
            "target": profile.target_ili.quantize(Decimal("0.01")),
            **ili_info,
        },
    }


def recommend_missions(user, summary: Dict[str, Decimal]) -> Iterable[Mission]:
    """
    DEPRECATED: Mantido apenas para compatibilidade.
    Use assign_missions_automatically() para atribuição automática.
    """
    user_tps = summary.get("tps", Decimal("0"))
    user_rdr = summary.get("rdr", Decimal("0"))
    user_ili = summary.get("ili", Decimal("0"))

    already_linked = set(
        MissionProgress.objects.filter(user=user).values_list("mission_id", flat=True)
    )

    base_queryset = Mission.objects.filter(is_active=True).exclude(id__in=already_linked)

    selected: List[Mission] = []
    for mission in base_queryset:
        match_tps = mission.target_tps is None or user_tps < Decimal(mission.target_tps)
        match_rdr = mission.target_rdr is None or user_rdr > Decimal(mission.target_rdr)
        match_ili = True
        if mission.min_ili is not None and user_ili < mission.min_ili:
            match_ili = False
        if mission.max_ili is not None and user_ili > mission.max_ili:
            match_ili = False
        if match_tps and match_rdr and match_ili:
            selected.append(mission)

    if not selected:
        selected = list(base_queryset[:3])

    return selected[:3]


def assign_missions_automatically(user) -> List[MissionProgress]:
    """
    Atribui missões automaticamente baseado nos índices do usuário.
    
    Lógica de atribuição:
    1. Usuários novos (< 5 transações): missões ONBOARDING
    2. ILI <= 3: prioriza ILI_BUILDING
    3. RDR >= 50: prioriza RDR_REDUCTION
    4. TPS < 10: prioriza TPS_IMPROVEMENT
    5. ILI entre 3-6: missões de controle
    6. ILI >= 6: missões ADVANCED
    
    Retorna lista de MissionProgress criadas ou atualizadas.
    """
    from django.utils import timezone
    
    summary = calculate_summary(user)
    tps = float(summary.get("tps", Decimal("0")))
    rdr = float(summary.get("rdr", Decimal("0")))
    ili = float(summary.get("ili", Decimal("0")))
    
    transaction_count = Transaction.objects.filter(user=user).count()
    
    # Buscar missões já atribuídas
    existing_progress = MissionProgress.objects.filter(
        user=user,
        status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
    )
    
    # Se já tem missões ativas, não atribui novas
    if existing_progress.filter(status=MissionProgress.Status.ACTIVE).count() >= 3:
        return list(existing_progress)
    
    # Determinar tipo de missão prioritária
    priority_types = []
    
    if transaction_count < 5:
        priority_types = [Mission.MissionType.ONBOARDING]
    elif ili <= 3:
        priority_types = [Mission.MissionType.ILI_BUILDING, Mission.MissionType.TPS_IMPROVEMENT]
    elif rdr >= 50:
        priority_types = [Mission.MissionType.RDR_REDUCTION]
    elif tps < 10:
        priority_types = [Mission.MissionType.TPS_IMPROVEMENT, Mission.MissionType.ILI_BUILDING]
    elif 3 < ili < 6:
        priority_types = [Mission.MissionType.TPS_IMPROVEMENT, Mission.MissionType.ILI_BUILDING]
    elif ili >= 6:
        priority_types = [Mission.MissionType.ADVANCED]
    else:
        priority_types = [Mission.MissionType.TPS_IMPROVEMENT]
    
    # Buscar missões já linkadas ao usuário
    already_linked = set(
        MissionProgress.objects.filter(user=user).values_list("mission_id", flat=True)
    )
    
    # Buscar missões disponíveis
    available_missions = Mission.objects.filter(
        is_active=True,
        mission_type__in=priority_types,
    ).exclude(id__in=already_linked)
    
    # Filtrar por critérios de índices
    suitable_missions = []
    for mission in available_missions:
        # Verificar número mínimo de transações
        if mission.min_transactions and transaction_count < mission.min_transactions:
            continue
        
        # Verificar TPS
        if mission.target_tps is not None and tps >= mission.target_tps:
            continue
        
        # Verificar RDR
        if mission.target_rdr is not None and rdr <= mission.target_rdr:
            continue
        
        # Verificar ILI
        if mission.min_ili is not None and ili < float(mission.min_ili):
            continue
        if mission.max_ili is not None and ili > float(mission.max_ili):
            continue
        
        suitable_missions.append(mission)
    
    # Se não encontrou missões adequadas, pega qualquer uma disponível do tipo prioritário
    if not suitable_missions:
        suitable_missions = list(available_missions[:3])
    
    # Se ainda não tem, pega qualquer missão ativa
    if not suitable_missions:
        suitable_missions = list(
            Mission.objects.filter(is_active=True)
            .exclude(id__in=already_linked)[:3]
        )
    
    # Criar MissionProgress para as missões selecionadas (máximo 3)
    created_progress = []
    for mission in suitable_missions[:3]:
        progress, created = MissionProgress.objects.get_or_create(
            user=user,
            mission=mission,
            defaults={
                'status': MissionProgress.Status.PENDING,
                'progress': Decimal("0.00"),
                'initial_tps': Decimal(str(tps)),
                'initial_rdr': Decimal(str(rdr)),
                'initial_ili': Decimal(str(ili)),
                'initial_transaction_count': transaction_count,
            }
        )
        if created:
            created_progress.append(progress)
    
    return created_progress


def update_mission_progress(user) -> List[MissionProgress]:
    """
    Atualiza o progresso das missões ativas do usuário baseado em seus dados atuais.
    Trata corretamente casos onde valores iniciais são None.
    
    Returns:
        Lista de missões que tiveram progresso atualizado.
    """
    from django.utils import timezone
    
    active_missions = MissionProgress.objects.filter(
        user=user,
        status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
    )
    
    if not active_missions:
        return []
    
    summary = calculate_summary(user)
    current_tps = float(summary.get("tps", Decimal("0")))
    current_rdr = float(summary.get("rdr", Decimal("0")))
    current_ili = float(summary.get("ili", Decimal("0")))
    current_transaction_count = Transaction.objects.filter(user=user).count()
    
    updated = []
    
    for progress in active_missions:
        mission = progress.mission
        old_progress = float(progress.progress)
        new_progress = 0.0
        
        # Inicializar valores iniciais se None (para missões antigas)
        if progress.initial_tps is None:
            progress.initial_tps = Decimal(str(current_tps))
        if progress.initial_rdr is None:
            progress.initial_rdr = Decimal(str(current_rdr))
        if progress.initial_ili is None:
            progress.initial_ili = Decimal(str(current_ili))
        if progress.initial_transaction_count == 0:
            progress.initial_transaction_count = max(1, current_transaction_count)
        
        # Calcular progresso baseado no tipo de missão
        if mission.mission_type == Mission.MissionType.ONBOARDING:
            # Para onboarding, progresso é baseado em número de transações
            if mission.min_transactions:
                new_progress = min(100.0, (current_transaction_count / mission.min_transactions) * 100)
            else:
                # Se não especificou mínimo, considera 10 transações como meta
                new_progress = min(100.0, (current_transaction_count / 10) * 100)
        
        elif mission.mission_type == Mission.MissionType.TPS_IMPROVEMENT:
            # Progresso baseado em melhoria do TPS
            if mission.target_tps is not None:
                initial = float(progress.initial_tps)
                target = float(mission.target_tps)
                
                if current_tps >= target:
                    # Atingiu ou superou a meta
                    new_progress = 100.0
                elif target > initial:
                    # Precisa melhorar
                    improvement = current_tps - initial
                    needed = target - initial
                    new_progress = min(100.0, max(0.0, (improvement / needed) * 100))
                else:
                    # Já estava acima da meta no início
                    new_progress = 100.0
        
        elif mission.mission_type == Mission.MissionType.RDR_REDUCTION:
            # Progresso baseado em redução do RDR
            if mission.target_rdr is not None:
                initial = float(progress.initial_rdr)
                target = float(mission.target_rdr)
                
                if current_rdr <= target:
                    # Atingiu ou superou a meta (menor é melhor)
                    new_progress = 100.0
                elif initial > target:
                    # Precisa reduzir
                    reduction = initial - current_rdr
                    needed = initial - target
                    new_progress = min(100.0, max(0.0, (reduction / needed) * 100))
                else:
                    # Já estava abaixo da meta no início
                    new_progress = 100.0
        
        elif mission.mission_type == Mission.MissionType.ILI_BUILDING:
            # Progresso baseado em construção do ILI
            if mission.min_ili is not None:
                initial = float(progress.initial_ili)
                target = float(mission.min_ili)
                
                if current_ili >= target:
                    # Atingiu ou superou a meta
                    new_progress = 100.0
                elif target > initial:
                    # Precisa melhorar
                    improvement = current_ili - initial
                    needed = target - initial
                    new_progress = min(100.0, max(0.0, (improvement / needed) * 100))
                else:
                    # Já estava acima da meta no início
                    new_progress = 100.0
        
        elif mission.mission_type == Mission.MissionType.ADVANCED:
            # Missões avançadas podem ter múltiplos critérios
            # Por enquanto, usa lógica similar às outras com pesos
            progress_components = []
            
            if mission.target_tps is not None:
                initial = float(progress.initial_tps)
                target = float(mission.target_tps)
                if current_tps >= target:
                    progress_components.append(100.0)
                elif target > initial and (target - initial) > 0:
                    progress_components.append(min(100.0, ((current_tps - initial) / (target - initial)) * 100))
                else:
                    progress_components.append(100.0)
            
            if mission.target_rdr is not None:
                initial = float(progress.initial_rdr)
                target = float(mission.target_rdr)
                if current_rdr <= target:
                    progress_components.append(100.0)
                elif initial > target and (initial - target) > 0:
                    progress_components.append(min(100.0, ((initial - current_rdr) / (initial - target)) * 100))
                else:
                    progress_components.append(100.0)
            
            if mission.min_ili is not None:
                initial = float(progress.initial_ili)
                target = float(mission.min_ili)
                if current_ili >= target:
                    progress_components.append(100.0)
                elif target > initial and (target - initial) > 0:
                    progress_components.append(min(100.0, ((current_ili - initial) / (target - initial)) * 100))
                else:
                    progress_components.append(100.0)
            
            # Média dos componentes
            if progress_components:
                new_progress = sum(progress_components) / len(progress_components)
            else:
                new_progress = 0.0
        
        # Atualizar progresso
        progress.progress = Decimal(str(new_progress))
        
        # Ativar missão se estava pendente e tem algum progresso
        if progress.status == MissionProgress.Status.PENDING and new_progress > 0:
            progress.status = MissionProgress.Status.ACTIVE
            progress.started_at = timezone.now()
        
        # Completar missão se chegou a 100%
        if new_progress >= 100.0 and progress.status != MissionProgress.Status.COMPLETED:
            progress.status = MissionProgress.Status.COMPLETED
            progress.completed_at = timezone.now()
            progress.progress = Decimal("100.00")
            apply_mission_reward(progress)
        
        # Verificar se missão expirou
        if progress.started_at and mission.duration_days:
            deadline = progress.started_at + timedelta(days=mission.duration_days)
            if timezone.now() > deadline and progress.status != MissionProgress.Status.COMPLETED:
                progress.status = MissionProgress.Status.FAILED
        
        progress.save()
        updated.append(progress)
    
    return updated

