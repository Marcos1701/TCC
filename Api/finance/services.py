from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Dict, Iterable, List

from django.db.models import Case, DecimalField, F, Q, Sum, When
from django.db.models.functions import Coalesce, TruncMonth
from django.utils import timezone

from .models import Category, Goal, Mission, MissionProgress, Transaction, UserProfile


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
    ATUALIZADO: Considera vinculações de transações para evitar dupla contagem.
    
    Indicadores calculados:
    - TPS (Taxa de Poupança Pessoal): ((Receitas - Despesas - Pagamentos via Links) / Receitas) × 100
      Mede quanto % da renda foi efetivamente poupado após pagar todas as despesas e dívidas.
      IMPORTANTE: Usa pagamentos REAIS via vinculação, não duplica com DEBT_PAYMENT.
      
    - RDR (Razão Dívida/Renda): (Pagamentos via Links / Receitas) × 100
      Mede quanto % da renda está comprometido com pagamento de dívidas.
      Valores saudáveis: ≤35%. Atenção: 35-42%. Crítico: ≥42%.
      IMPORTANTE: Usa apenas valores VINCULADOS, não conta DEBT_PAYMENT separado.
      
    - ILI (Índice de Liquidez Imediata): Reservas Líquidas / Média Despesas Essenciais (3 meses)
      Mede quantos meses a reserva de emergência consegue cobrir despesas essenciais.
      Recomendado: ≥6 meses.
    
    Args:
        user: Usuário para cálculo dos indicadores
        
    Returns:
        Dicionário com indicadores e totais financeiros
    """
    from .models import TransactionLink
    
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
    
    # ============================================================================
    # CÁLCULO ATUALIZADO: Considerar vinculações
    # ============================================================================
    
    # Total de receitas (bruto)
    total_income = _decimal(
        Transaction.objects.filter(
            user=user,
            type=Transaction.TransactionType.INCOME
        ).aggregate(total=Sum('amount'))['total']
    )
    
    # Total de despesas normais (não-dívida, bruto)
    # Excluir despesas em categorias de DEBT
    total_expense = _decimal(
        Transaction.objects.filter(
            user=user,
            type=Transaction.TransactionType.EXPENSE,
        ).exclude(
            category__type=Category.CategoryType.DEBT
        ).aggregate(total=Sum('amount'))['total']
    )
    
    # Total vinculado para pagamento de dívidas
    # Soma de todos os links onde target é uma dívida
    # NOVO: Usar vinculações em vez de DEBT_PAYMENT
    debt_payments_via_links = _decimal(
        TransactionLink.objects.filter(
            user=user,
            link_type=TransactionLink.LinkType.DEBT_PAYMENT
        ).aggregate(total=Sum('linked_amount'))['total']
    )

    # Calcular reserva de emergência usando o grupo SAVINGS
    # - INCOME em categoria SAVINGS = aporte na reserva (dinheiro guardado)
    # - EXPENSE em categoria SAVINGS = resgate da reserva (dinheiro retirado)
    # Saldo da reserva = Total de aportes (INCOME) - Total de resgates (EXPENSE)
    reserve_transactions = Transaction.objects.filter(
        user=user, 
        category__group=Category.CategoryGroup.SAVINGS
    ).values("type").annotate(total=Sum("amount"))
    
    reserve_deposits = Decimal("0")  # Aportes (INCOME)
    reserve_withdrawals = Decimal("0")  # Resgates (EXPENSE)
    
    for item in reserve_transactions:
        tx_type = item["type"]
        total = _decimal(item["total"])
        if tx_type == Transaction.TransactionType.INCOME:
            reserve_deposits += total
        elif tx_type == Transaction.TransactionType.EXPENSE:
            reserve_withdrawals += total

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

    # ============================================================================
    # CÁLCULO DOS INDICADORES - NOVA ABORDAGEM COM VINCULAÇÕES
    # ============================================================================
    
    tps = Decimal("0")
    rdr = Decimal("0")
    ili = Decimal("0")
    
    if total_income > 0:
        # TPS (Taxa de Poupança Pessoal) - CORRIGIDO
        # Fórmula: ((Receitas - Despesas - Pagamentos Dívida Vinculados) / Receitas) × 100
        # Agora usa pagamentos REAIS via vinculação, não duplica
        # 
        # Exemplo: Ganhou R$ 5.000, gastou R$ 2.000, pagou R$ 1.500 de dívida via link
        # TPS = (5.000 - 2.000 - 1.500) / 5.000 × 100 = 30%
        savings = total_income - total_expense - debt_payments_via_links
        tps = (savings / total_income) * Decimal("100")
        
        # RDR (Razão Dívida/Renda) - CORRIGIDO
        # Fórmula: (Pagamentos Dívida Vinculados / Receitas) × 100
        # Agora usa valor REAL pago via vinculação
        # 
        # Exemplo: Ganhou R$ 5.000, pagou R$ 1.500 de dívidas via link
        # RDR = 1.500 / 5.000 × 100 = 30%
        # 
        # Referências (CFPB, bancos brasileiros):
        # - ≤35%: Saudável
        # - 36-42%: Atenção
        # - ≥43%: Crítico (risco de inadimplência)
        rdr = (debt_payments_via_links / total_income) * Decimal("100")
    
    # ILI (Índice de Liquidez Imediata) - MANTÉM LÓGICA ATUAL
    # Fórmula: Reserva de Emergência / Despesas Essenciais Mensais
    # Representa quantos meses a reserva consegue cobrir despesas essenciais
    # 
    # Exemplo: Tem R$ 12.000 de reserva, gasta R$ 2.000/mês em essenciais
    # ILI = 12.000 / 2.000 = 6 meses
    # 
    # Recomendação padrão: 3-6 meses (mínimo), idealmente 6-12 meses
    reserve_balance = reserve_deposits - reserve_withdrawals
    if essential_expense > 0:
        ili = reserve_balance / essential_expense

    # Total de dívidas (saldo devedor atual)
    debt_info = _debt_components(user)
    debt_total = debt_info["balance"] if debt_info["balance"] > 0 else Decimal("0")

    # Atualizar cache
    profile.cached_tps = tps.quantize(Decimal("0.01")) if total_income > 0 else Decimal("0.00")
    profile.cached_rdr = rdr.quantize(Decimal("0.01")) if total_income > 0 else Decimal("0.00")
    profile.cached_ili = ili.quantize(Decimal("0.01")) if essential_expense > 0 else Decimal("0.00")
    profile.cached_total_income = total_income.quantize(Decimal("0.01"))
    profile.cached_total_expense = total_expense.quantize(Decimal("0.01"))
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
    Deve ser chamado após criar/editar/deletar transações e transaction links.
    
    Args:
        user: Usuário cujo cache deve ser invalidado
    """
    try:
        profile = UserProfile.objects.get(user=user)
        profile.indicators_updated_at = None
        profile.save(update_fields=['indicators_updated_at'])
    except UserProfile.DoesNotExist:
        pass


def auto_link_recurring_transactions(user) -> int:
    """
    Vincula automaticamente transações recorrentes baseado em configuração.
    
    Lógica:
    1. Buscar todos os TransactionLinks com is_recurring=True do usuário
    2. Para cada link recorrente:
       - Verificar se existem novas instâncias das transações recorrentes
       - Criar links automáticos entre as novas instâncias
    
    Args:
        user: Usuário para processar vinculações automáticas
    
    Returns:
        Número de links criados automaticamente
    """
    from .models import Transaction, TransactionLink
    
    links_created = 0
    
    # Buscar links recorrentes ativos
    recurring_links = TransactionLink.objects.filter(
        user=user,
        is_recurring=True
    ).select_related('source_transaction', 'target_transaction')
    
    for link in recurring_links:
        source = link.source_transaction
        target = link.target_transaction
        
        # Verificar se ambas são recorrentes
        if not (source.is_recurring and target.is_recurring):
            continue
        
        # Calcular delta de tempo baseado na recorrência
        if source.recurrence_unit == Transaction.RecurrenceUnit.DAYS:
            delta_days = source.recurrence_value
        elif source.recurrence_unit == Transaction.RecurrenceUnit.WEEKS:
            delta_days = source.recurrence_value * 7
        elif source.recurrence_unit == Transaction.RecurrenceUnit.MONTHS:
            delta_days = source.recurrence_value * 30  # Aproximado
        else:
            continue
        
        # Buscar transações similares criadas após a original
        # (mesma categoria, descrição, valor, tipo, recorrentes)
        next_sources = Transaction.objects.filter(
            user=user,
            type=source.type,
            category=source.category,
            description=source.description,
            amount=source.amount,
            date__gt=source.date,
            is_recurring=True,
        ).exclude(
            # Excluir transações já vinculadas como source
            id__in=TransactionLink.objects.filter(
                user=user,
                link_type=link.link_type
            ).values_list('source_transaction_id', flat=True)
        )
        
        next_targets = Transaction.objects.filter(
            user=user,
            category=target.category,
            description=target.description,
            amount=target.amount,
            date__gt=target.date,
            is_recurring=True,
        ).exclude(
            # Excluir transações já vinculadas como target
            id__in=TransactionLink.objects.filter(
                user=user,
                link_type=link.link_type
            ).values_list('target_transaction_id', flat=True)
        )
        
        # Criar links entre pares correspondentes (uma de cada vez para segurança)
        for next_source in next_sources[:1]:
            for next_target in next_targets[:1]:
                # Verificar se há saldo disponível
                if next_source.available_amount >= link.linked_amount:
                    if next_target.available_amount >= link.linked_amount:
                        try:
                            # Criar link automático
                            TransactionLink.objects.create(
                                user=user,
                                source_transaction=next_source,
                                target_transaction=next_target,
                                linked_amount=link.linked_amount,
                                link_type=link.link_type,
                                description=f"Auto: {link.description}" if link.description else "Vinculação automática recorrente",
                                is_recurring=True
                            )
                            links_created += 1
                        except Exception as e:
                            # Log erro mas continua processando outros links
                            print(f"Erro ao criar link automático: {e}")
                            continue
    
    # Invalidar cache se criou links
    if links_created > 0:
        invalidate_indicators_cache(user)
    
    return links_created


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
        debt_balance: Saldo de dívidas do período (não usado no cálculo, mantido para compatibilidade)
        
    Returns:
        Dicionário com 'tps' e 'rdr' calculados
    """
    tps = Decimal("0")
    rdr = Decimal("0")
    
    if income > 0:
        # TPS: poupança líquida após despesas e pagamentos de dívida
        # TPS = ((Receitas - Despesas - Pagamentos de Dívida) / Receitas) × 100
        savings = income - expense - debt_payments
        tps = (savings / income) * Decimal("100")
        
        # RDR: comprometimento da renda com pagamentos de dívidas
        # RDR = (Pagamentos Mensais de Dívidas / Receitas) × 100
        rdr = (debt_payments / income) * Decimal("100")
    
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
    """
    Aplica recompensa de XP ao completar uma missão.
    Usa transaction.atomic e select_for_update para evitar race conditions.
    Cria registro de auditoria para rastreamento.
    
    Args:
        progress: MissionProgress que foi completada
    """
    from django.db import transaction
    from .models import XPTransaction
    
    with transaction.atomic():
        # Lock no perfil para evitar condições de corrida
        profile = UserProfile.objects.select_for_update().get(user=progress.user)
        
        # Salvar estado anterior para auditoria
        level_before = profile.level
        xp_before = profile.experience_points
        
        # Adicionar XP da recompensa
        profile.experience_points += progress.mission.reward_points

        # Processar level ups
        while profile.experience_points >= _xp_threshold(profile.level):
            profile.experience_points -= _xp_threshold(profile.level)
            profile.level += 1
        
        profile.save(update_fields=["experience_points", "level"])
        
        # Criar registro de auditoria
        XPTransaction.objects.create(
            user=progress.user,
            mission_progress=progress,
            points_awarded=progress.mission.reward_points,
            level_before=level_before,
            level_after=profile.level,
            xp_before=xp_before,
            xp_after=profile.experience_points,
        )


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
    
    # Buscar missões já atribuídas (incluindo completadas para não repetir)
    existing_progress = MissionProgress.objects.filter(user=user)
    active_count = existing_progress.filter(
        status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
    ).count()
    
    # Se já tem 3 ou mais missões ativas, não atribui novas
    if active_count >= 3:
        return list(existing_progress.filter(
            status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
        ))
    
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
    
    # Buscar missões já linkadas ao usuário (incluindo completadas para não repetir)
    already_linked = set(
        existing_progress.values_list("mission_id", flat=True)
    )
    
    # Buscar missões disponíveis
    available_missions = Mission.objects.filter(
        is_active=True,
        mission_type__in=priority_types,
    ).exclude(id__in=already_linked).order_by('priority')
    
    # Filtrar por critérios de índices - apenas missões que fazem sentido
    suitable_missions = []
    for mission in available_missions:
        # Verificar número mínimo de transações
        if mission.min_transactions and transaction_count < mission.min_transactions:
            continue
        
        # Verificar TPS - só atribui se usuário está ABAIXO do target (precisa melhorar)
        if mission.target_tps is not None:
            if tps >= mission.target_tps:
                # Usuário já está acima do target, missão não faz sentido
                continue
        
        # Verificar RDR - só atribui se usuário está ACIMA do target (precisa reduzir)
        if mission.target_rdr is not None:
            if rdr <= mission.target_rdr:
                # Usuário já está abaixo do target, missão não faz sentido
                continue
        
        # Verificar ILI - só atribui se está na faixa adequada
        if mission.min_ili is not None:
            if ili >= float(mission.min_ili):
                # Usuário já atingiu o mínimo, missão não faz sentido
                continue
        
        if mission.max_ili is not None:
            if ili > float(mission.max_ili):
                # Usuário está acima do máximo, missão não faz sentido
                continue
        
        # Validação adicional: não atribuir missão que seria completada instantaneamente
        # Apenas para missões que não são de ONBOARDING
        if mission.mission_type != Mission.MissionType.ONBOARDING:
            would_complete_instantly = False
            
            # Verificar se TPS já atende o target
            if mission.target_tps is not None and tps >= mission.target_tps * 0.95:
                would_complete_instantly = True
            
            # Verificar se RDR já atende o target
            if mission.target_rdr is not None and rdr <= mission.target_rdr * 1.05:
                would_complete_instantly = True
            
            # Verificar se ILI já atende o target
            if mission.min_ili is not None and ili >= float(mission.min_ili) * 0.95:
                would_complete_instantly = True
            
            if would_complete_instantly:
                # Missão seria completada muito rapidamente, buscar outra
                continue
        
        suitable_missions.append(mission)
        
        # Limitar para preencher até 3 missões ativas
        if len(suitable_missions) >= (3 - active_count):
            break
    
    # Se não encontrou missões adequadas com filtros rigorosos, relaxa um pouco
    if not suitable_missions and active_count == 0:
        # Pega qualquer missão do tipo prioritário que o usuário não tenha
        suitable_missions = list(available_missions[:3])
    
    # Se ainda não tem e usuário tem 0 missões, pega qualquer missão ativa
    if not suitable_missions and active_count == 0:
        suitable_missions = list(
            Mission.objects.filter(is_active=True)
            .exclude(id__in=already_linked)
            .order_by('priority')[:3]
        )
    
    # Criar MissionProgress para as missões selecionadas
    created_progress = []
    for mission in suitable_missions:
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
    Usa select_for_update para evitar race conditions ao completar missões.
    
    Returns:
        Lista de missões que tiveram progresso atualizado.
    """
    from django.db import transaction
    from django.utils import timezone
    
    # Usar select_for_update para evitar condições de corrida
    with transaction.atomic():
        active_missions = MissionProgress.objects.select_for_update().filter(
            user=user,
            status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
        )
        
        if not active_missions:
            return []
        
        # Converter para lista para trabalhar fora do lock
        missions_to_update = list(active_missions)
    
    summary = calculate_summary(user)
    current_tps = float(summary.get("tps", Decimal("0")))
    current_rdr = float(summary.get("rdr", Decimal("0")))
    current_ili = float(summary.get("ili", Decimal("0")))
    current_transaction_count = Transaction.objects.filter(user=user).count()
    
    updated = []
    
    for progress in missions_to_update:
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
        
        # Garantir que valores não sejam None antes de calcular
        initial_tps = float(progress.initial_tps) if progress.initial_tps is not None else 0.0
        initial_rdr = float(progress.initial_rdr) if progress.initial_rdr is not None else 0.0
        initial_ili = float(progress.initial_ili) if progress.initial_ili is not None else 0.0
        
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
                initial = float(progress.initial_tps) if progress.initial_tps else 0.0
                target = float(mission.target_tps)
                
                if current_tps >= target:
                    # Atingiu ou superou a meta
                    new_progress = 100.0
                elif target > initial and (target - initial) > 0:
                    # Precisa melhorar
                    improvement = current_tps - initial
                    needed = target - initial
                    new_progress = min(100.0, max(0.0, (improvement / needed) * 100))
                elif initial >= target:
                    # Já estava acima da meta no início - missão inadequada mas considera completa
                    new_progress = 100.0
                else:
                    # Casos edge
                    new_progress = 100.0 if current_tps >= target else 0.0
        
        elif mission.mission_type == Mission.MissionType.RDR_REDUCTION:
            # Progresso baseado em redução do RDR
            if mission.target_rdr is not None:
                initial = float(progress.initial_rdr) if progress.initial_rdr else 0.0
                target = float(mission.target_rdr)
                
                if current_rdr <= target:
                    # Atingiu ou superou a meta (menor é melhor)
                    new_progress = 100.0
                elif initial > target and (initial - target) > 0:
                    # Precisa reduzir
                    reduction = initial - current_rdr
                    needed = initial - target
                    new_progress = min(100.0, max(0.0, (reduction / needed) * 100))
                elif initial <= target:
                    # Já estava abaixo da meta no início - missão inadequada mas considera completa
                    new_progress = 100.0
                else:
                    # Casos edge
                    new_progress = 100.0 if current_rdr <= target else 0.0
        
        elif mission.mission_type == Mission.MissionType.ILI_BUILDING:
            # Progresso baseado em construção do ILI
            if mission.min_ili is not None:
                initial = float(progress.initial_ili) if progress.initial_ili else 0.0
                target = float(mission.min_ili)
                
                if current_ili >= target:
                    # Atingiu ou superou a meta
                    new_progress = 100.0
                elif target > initial and (target - initial) > 0:
                    # Precisa melhorar
                    improvement = current_ili - initial
                    needed = target - initial
                    new_progress = min(100.0, max(0.0, (improvement / needed) * 100))
                elif initial >= target:
                    # Já estava acima da meta no início - missão inadequada mas considera completa
                    new_progress = 100.0
                else:
                    # Casos edge: se initial == target ou lógica não se aplica
                    new_progress = 100.0 if current_ili >= target else 0.0
        
        elif mission.mission_type == Mission.MissionType.ADVANCED:
            # Missões avançadas podem ter múltiplos critérios
            # Por enquanto, usa lógica similar às outras com pesos
            progress_components = []
            
            if mission.target_tps is not None and progress.initial_tps is not None:
                initial = float(progress.initial_tps)
                target = float(mission.target_tps)
                if current_tps >= target:
                    progress_components.append(100.0)
                elif target > initial and (target - initial) > 0:
                    progress_components.append(min(100.0, max(0.0, ((current_tps - initial) / (target - initial)) * 100)))
                elif initial >= target:
                    progress_components.append(100.0)
                else:
                    progress_components.append(100.0 if current_tps >= target else 0.0)
            
            if mission.target_rdr is not None and progress.initial_rdr is not None:
                initial = float(progress.initial_rdr)
                target = float(mission.target_rdr)
                if current_rdr <= target:
                    progress_components.append(100.0)
                elif initial > target and (initial - target) > 0:
                    progress_components.append(min(100.0, max(0.0, ((initial - current_rdr) / (initial - target)) * 100)))
                elif initial <= target:
                    progress_components.append(100.0)
                else:
                    progress_components.append(100.0 if current_rdr <= target else 0.0)
            
            if mission.min_ili is not None and progress.initial_ili is not None:
                initial = float(progress.initial_ili)
                target = float(mission.min_ili)
                if current_ili >= target:
                    progress_components.append(100.0)
                elif target > initial and (target - initial) > 0:
                    progress_components.append(min(100.0, max(0.0, ((current_ili - initial) / (target - initial)) * 100)))
                elif initial >= target:
                    progress_components.append(100.0)
                else:
                    progress_components.append(100.0 if current_ili >= target else 0.0)
            
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


# ======= Funções de Metas =======

def update_goal_progress(goal) -> None:
    """
    Atualiza o progresso de uma meta baseado nas transações relacionadas.
    
    Args:
        goal: Instância do modelo Goal
    
    Chamado automaticamente após criar/atualizar/deletar transação
    quando goal.auto_update=True.
    """
    from .models import Goal
    
    # Só atualiza se auto_update estiver ativado
    if not goal.auto_update:
        return
    
    # Para metas personalizadas, não fazer nada (atualização manual)
    if goal.goal_type == Goal.GoalType.CUSTOM:
        return
    
    # Obter transações relacionadas
    transactions = goal.get_related_transactions()
    
    # Calcular total
    total = _decimal(
        transactions.aggregate(total=Coalesce(Sum('amount'), Decimal('0')))['total']
    )
    
    # Adicionar o valor inicial (se houver)
    total_with_initial = total + goal.initial_amount
    
    # Para metas de redução, calcular quanto foi reduzido
    # (quanto deixou de gastar em relação ao alvo)
    if goal.is_reduction_goal:
        # Se o alvo é gastar no máximo R$ 500
        # E gastou R$ 300, progresso = R$ 200 economizados
        if total < goal.target_amount:
            goal.current_amount = goal.target_amount - total
        else:
            goal.current_amount = Decimal('0.00')
    else:
        # Para metas normais (juntar dinheiro, pagar dívidas, etc)
        goal.current_amount = total_with_initial
    
    goal.save(update_fields=['current_amount', 'updated_at'])


def update_all_active_goals(user) -> None:
    """
    Atualiza todas as metas ativas do usuário que têm auto_update=True.
    
    Args:
        user: Usuário cujas metas devem ser atualizadas
    
    Chamado após criar/atualizar/deletar qualquer transação.
    """
    from .models import Goal
    
    goals = Goal.objects.filter(user=user, auto_update=True)
    for goal in goals:
        update_goal_progress(goal)


def get_goal_insights(goal) -> Dict[str, str]:
    """
    Gera insights e sugestões para uma meta específica.
    
    Args:
        goal: Instância do modelo Goal
    
    Returns:
        Dict com insights sobre o progresso da meta
    """
    from .models import Goal
    
    insights = {
        'status': '',
        'message': '',
        'suggestion': ''
    }
    
    progress = goal.progress_percentage
    
    # Insights baseados no progresso
    if progress >= 100:
        insights['status'] = 'completed'
        insights['message'] = '🎉 Parabéns! Você atingiu sua meta!'
        insights['suggestion'] = 'Considere criar uma nova meta para continuar evoluindo.'
    elif progress >= 75:
        insights['status'] = 'almost_there'
        insights['message'] = '💪 Falta pouco! Você está quase lá!'
        remaining = goal.target_amount - goal.current_amount
        insights['suggestion'] = f'Faltam apenas R$ {remaining:.2f} para completar.'
    elif progress >= 50:
        insights['status'] = 'on_track'
        insights['message'] = '📈 Você está no caminho certo!'
        insights['suggestion'] = 'Continue assim e você alcançará sua meta.'
    elif progress >= 25:
        insights['status'] = 'needs_attention'
        insights['message'] = '⚠️ Atenção! Progresso está lento.'
        insights['suggestion'] = 'Considere aumentar seu esforço para atingir a meta.'
    else:
        insights['status'] = 'just_started'
        insights['message'] = '🚀 Você está começando!'
        insights['suggestion'] = 'Mantenha o foco e a disciplina.'
    
    # Insights baseados no prazo
    if goal.deadline:
        today = date.today()
        days_remaining = (goal.deadline - today).days
        
        if days_remaining < 0:
            insights['message'] += f' (Prazo expirou há {abs(days_remaining)} dias)'
        elif days_remaining <= 7:
            insights['message'] += f' (Faltam {days_remaining} dias!)'
        elif days_remaining <= 30:
            insights['message'] += f' (Faltam {days_remaining} dias)'
    
    # Insights específicos por tipo de meta
    if goal.goal_type == Goal.GoalType.CATEGORY_EXPENSE and goal.is_reduction_goal:
        if progress < 50 and goal.tracking_period == Goal.TrackingPeriod.MONTHLY:
            # Se está gastando muito no mês
            insights['suggestion'] = f'Tente reduzir gastos em {goal.target_category.name}. ' + insights['suggestion']
    
    return insights


