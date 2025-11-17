"""
Sistema de tipos de missões especializadas com validação e tracking personalizados.

Este módulo define classes abstratas e concretas para diferentes tipos de missões,
cada uma com sua própria lógica de validação e cálculo de progresso.

Arquitetura:
- BaseMissionValidator: Classe abstrata base
- Validators especializados para cada tipo de missão
- Factory pattern para instanciar o validator correto
"""

from abc import ABC, abstractmethod
from decimal import Decimal
from typing import Dict, Any, Optional, List, Tuple
from datetime import datetime, timedelta
from django.utils import timezone
from django.db.models import Sum, Count, Avg, Q
import logging

logger = logging.getLogger(__name__)


class BaseMissionValidator(ABC):
    """
    Classe base abstrata para validadores de missões.
    
    Cada tipo de missão deve implementar sua própria lógica de:
    - Cálculo de progresso
    - Validação de conclusão
    - Tracking de métricas específicas
    """
    
    def __init__(self, mission, user, mission_progress):
        """
        Inicializa o validador.
        
        Args:
            mission: Instância do modelo Mission
            user: Usuário que está realizando a missão
            mission_progress: Instância do modelo MissionProgress
        """
        self.mission = mission
        self.user = user
        self.mission_progress = mission_progress
        
    @abstractmethod
    def calculate_progress(self) -> Dict[str, Any]:
        """
        Calcula o progresso atual da missão.
        
        Returns:
            Dict contendo:
            - progress_percentage (float): 0-100
            - is_completed (bool): Se está completa
            - metrics (dict): Métricas específicas do tipo de missão
            - message (str): Mensagem de status
        """
        pass
    
    @abstractmethod
    def validate_completion(self) -> Tuple[bool, str]:
        """
        Valida se a missão está realmente completa.
        
        Returns:
            Tuple (is_valid, message)
        """
        pass
    
    def get_current_metrics(self) -> Dict[str, Any]:
        """
        Retorna métricas atuais do usuário relevantes para esta missão.
        Pode ser sobrescrito por subclasses.
        """
        from .services import calculate_summary
        return calculate_summary(self.user)


class OnboardingMissionValidator(BaseMissionValidator):
    """
    Validador para missões de integração inicial.
    
    Foco: Criar hábito de registro e explorar funcionalidades básicas.
    Tracking: Número de transações registradas, categorias criadas, etc.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        from .models import Transaction
        
        # Contar transações desde o início da missão
        transactions_count = Transaction.objects.filter(
            user=self.user,
            created_at__gte=self.mission_progress.started_at
        ).count()
        
        target = self.mission.min_transactions or 10
        progress = min(100, (transactions_count / target) * 100)
        
        return {
            'progress_percentage': progress,
            'is_completed': transactions_count >= target,
            'metrics': {
                'transactions_registered': transactions_count,
                'target_transactions': target,
                'remaining': max(0, target - transactions_count)
            },
            'message': f"Você registrou {transactions_count} de {target} transações"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        from .models import Transaction
        
        transactions_count = Transaction.objects.filter(
            user=self.user,
            created_at__gte=self.mission_progress.started_at
        ).count()
        
        target = self.mission.min_transactions or 10
        
        if transactions_count >= target:
            return True, f"Parabéns! Você registrou {transactions_count} transações!"
        
        return False, f"Continue registrando transações ({transactions_count}/{target})"


class TPSImprovementMissionValidator(BaseMissionValidator):
    """
    Validador para missões de melhoria de Taxa de Poupança Pessoal.
    
    Foco: Aumentar % de economia sobre receita total.
    Tracking: TPS inicial vs TPS atual, tendência ao longo do período.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        metrics = self.get_current_metrics()
        current_tps = float(metrics.get('tps', 0))
        target_tps = float(self.mission.target_tps or 20)
        
        # TPS inicial (capturado no snapshot)
        initial_tps = float(self.mission_progress.initial_tps or 0)
        
        # Calcular progresso baseado na melhoria
        if target_tps <= initial_tps:
            # Meta já estava atingida no início
            progress = 100 if current_tps >= target_tps else 0
        else:
            # Calcular progresso linear entre inicial e meta
            improvement_needed = target_tps - initial_tps
            current_improvement = current_tps - initial_tps
            progress = min(100, max(0, (current_improvement / improvement_needed) * 100))
        
        return {
            'progress_percentage': progress,
            'is_completed': current_tps >= target_tps,
            'metrics': {
                'initial_tps': round(initial_tps, 2),
                'current_tps': round(current_tps, 2),
                'target_tps': round(target_tps, 2),
                'improvement': round(current_tps - initial_tps, 2),
                'needed_improvement': round(max(0, target_tps - current_tps), 2)
            },
            'message': f"Seu TPS está em {current_tps:.1f}% (meta: {target_tps:.1f}%)"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        metrics = self.get_current_metrics()
        current_tps = float(metrics.get('tps', 0))
        target_tps = float(self.mission.target_tps or 20)
        
        if current_tps >= target_tps:
            return True, f"Excelente! Seu TPS de {current_tps:.1f}% atingiu a meta de {target_tps:.1f}%!"
        
        return False, f"Continue melhorando seu TPS (atual: {current_tps:.1f}%, meta: {target_tps:.1f}%)"


class RDRReductionMissionValidator(BaseMissionValidator):
    """
    Validador para missões de redução de Razão Dívida-Receita.
    
    Foco: Reduzir comprometimento de renda com despesas recorrentes.
    Tracking: RDR inicial vs RDR atual, despesas recorrentes identificadas.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        metrics = self.get_current_metrics()
        current_rdr = float(metrics.get('rdr', 100))
        target_rdr = float(self.mission.target_rdr or 30)
        
        # RDR inicial
        initial_rdr = float(self.mission_progress.initial_rdr or 100)
        
        # Para RDR, quanto MENOR, melhor
        if initial_rdr <= target_rdr:
            # Meta já estava atingida
            progress = 100 if current_rdr <= target_rdr else 0
        else:
            # Calcular progresso baseado na redução
            reduction_needed = initial_rdr - target_rdr
            current_reduction = initial_rdr - current_rdr
            progress = min(100, max(0, (current_reduction / reduction_needed) * 100))
        
        return {
            'progress_percentage': progress,
            'is_completed': current_rdr <= target_rdr,
            'metrics': {
                'initial_rdr': round(initial_rdr, 2),
                'current_rdr': round(current_rdr, 2),
                'target_rdr': round(target_rdr, 2),
                'reduction': round(initial_rdr - current_rdr, 2),
                'needed_reduction': round(max(0, current_rdr - target_rdr), 2)
            },
            'message': f"Seu RDR está em {current_rdr:.1f}% (meta: {target_rdr:.1f}%)"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        metrics = self.get_current_metrics()
        current_rdr = float(metrics.get('rdr', 100))
        target_rdr = float(self.mission.target_rdr or 30)
        
        if current_rdr <= target_rdr:
            return True, f"Parabéns! Seu RDR de {current_rdr:.1f}% está abaixo da meta de {target_rdr:.1f}%!"
        
        return False, f"Continue reduzindo seu RDR (atual: {current_rdr:.1f}%, meta: {target_rdr:.1f}%)"


class ILIBuildingMissionValidator(BaseMissionValidator):
    """
    Validador para missões de construção de Índice de Liquidez Imediata.
    
    Foco: Aumentar reserva de emergência em meses de despesas cobertas.
    Tracking: ILI inicial vs ILI atual, saldo disponível.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        metrics = self.get_current_metrics()
        current_ili = float(metrics.get('ili', 0))
        target_ili = float(self.mission.min_ili or 6)
        
        # ILI inicial
        initial_ili = float(self.mission_progress.initial_ili or 0)
        
        # Calcular progresso
        if target_ili <= initial_ili:
            # Meta já estava atingida
            progress = 100 if current_ili >= target_ili else 0
        else:
            # Progresso linear
            improvement_needed = target_ili - initial_ili
            current_improvement = current_ili - initial_ili
            progress = min(100, max(0, (current_improvement / improvement_needed) * 100))
        
        return {
            'progress_percentage': progress,
            'is_completed': current_ili >= target_ili,
            'metrics': {
                'initial_ili': round(initial_ili, 2),
                'current_ili': round(current_ili, 2),
                'target_ili': round(target_ili, 2),
                'improvement': round(current_ili - initial_ili, 2),
                'needed_improvement': round(max(0, target_ili - current_ili), 2)
            },
            'message': f"Sua reserva cobre {current_ili:.1f} meses (meta: {target_ili:.1f})"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        metrics = self.get_current_metrics()
        current_ili = float(metrics.get('ili', 0))
        target_ili = float(self.mission.min_ili or 6)
        
        if current_ili >= target_ili:
            return True, f"Fantástico! Sua reserva de {current_ili:.1f} meses atingiu a meta!"
        
        return False, f"Continue construindo sua reserva (atual: {current_ili:.1f}, meta: {target_ili:.1f})"


class AdvancedMissionValidator(BaseMissionValidator):
    """
    Validador para missões avançadas com múltiplos critérios.
    
    Foco: Desafios complexos que combinam TPS, RDR, ILI e outras métricas.
    Tracking: Múltiplas métricas simultaneamente.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        metrics = self.get_current_metrics()
        
        # Verificar quais critérios a missão possui
        criteria = []
        completed_criteria = 0
        
        if self.mission.target_tps is not None:
            current_tps = float(metrics.get('tps', 0))
            target_tps = float(self.mission.target_tps)
            met = current_tps >= target_tps
            criteria.append({
                'name': 'TPS',
                'current': current_tps,
                'target': target_tps,
                'met': met
            })
            if met:
                completed_criteria += 1
        
        if self.mission.target_rdr is not None:
            current_rdr = float(metrics.get('rdr', 100))
            target_rdr = float(self.mission.target_rdr)
            met = current_rdr <= target_rdr
            criteria.append({
                'name': 'RDR',
                'current': current_rdr,
                'target': target_rdr,
                'met': met
            })
            if met:
                completed_criteria += 1
        
        if self.mission.min_ili is not None:
            current_ili = float(metrics.get('ili', 0))
            target_ili = float(self.mission.min_ili)
            met = current_ili >= target_ili
            criteria.append({
                'name': 'ILI',
                'current': current_ili,
                'target': target_ili,
                'met': met
            })
            if met:
                completed_criteria += 1
        
        # Progresso é % de critérios atendidos
        total_criteria = len(criteria) or 1
        progress = (completed_criteria / total_criteria) * 100
        
        return {
            'progress_percentage': progress,
            'is_completed': completed_criteria == total_criteria,
            'metrics': {
                'criteria': criteria,
                'completed': completed_criteria,
                'total': total_criteria
            },
            'message': f"Você atendeu {completed_criteria} de {total_criteria} critérios"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        
        if result['is_completed']:
            return True, "Parabéns! Você completou todos os critérios desta missão avançada!"
        
        criteria = result['metrics']['criteria']
        pending = [c['name'] for c in criteria if not c['met']]
        
        return False, f"Continue trabalhando em: {', '.join(pending)}"


# === NOVOS VALIDADORES (Sprint 2) ===


class CategoryReductionValidator(BaseMissionValidator):
    """
    Validador para missões de redução de gastos em categorias específicas.
    
    Foco: Reduzir X% os gastos em uma categoria comparando período atual vs anterior.
    Tracking: Gastos por categoria, comparação temporal.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        from .models import Transaction
        
        if not self.mission.target_category:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão sem categoria alvo configurada'
            }
        
        # Período da missão
        mission_duration = self.mission.duration_days
        start_date = self.mission_progress.started_at
        
        # Período anterior (referência)
        reference_start = start_date - timedelta(days=mission_duration)
        reference_end = start_date
        
        # Período atual
        current_start = start_date
        current_end = timezone.now()
        
        # Gastos na categoria no período de referência
        reference_query = Transaction.objects.filter(
            user=self.user,
            type='EXPENSE',
            date__gte=reference_start.date(),
            date__lt=reference_end.date()
        )
        if self.mission.target_category:
            reference_query = reference_query.filter(category=self.mission.target_category)
        reference_spending = reference_query.aggregate(total=Sum('amount'))['total'] or Decimal('0')
        
        # Gastos na categoria no período atual
        current_query = Transaction.objects.filter(
            user=self.user,
            type='EXPENSE',
            date__gte=current_start.date(),
            date__lt=current_end.date()
        )
        if self.mission.target_category:
            current_query = current_query.filter(category=self.mission.target_category)
        current_spending = current_query.aggregate(total=Sum('amount'))['total'] or Decimal('0')
        
        # Calcular redução percentual
        if reference_spending > 0:
            reduction_percent = ((reference_spending - current_spending) / reference_spending) * 100
        else:
            reduction_percent = Decimal('0')
        
        target_reduction = self.mission.target_reduction_percent or Decimal('10')
        progress = min(100, (reduction_percent / target_reduction) * 100)
        
        return {
            'progress_percentage': float(progress),
            'is_completed': reduction_percent >= target_reduction,
            'metrics': {
                'reference_spending': float(reference_spending),
                'current_spending': float(current_spending),
                'reduction_percent': float(reduction_percent),
                'target_reduction': float(target_reduction),
                'category_name': self.mission.target_category.name
            },
            'message': f"Redução de {reduction_percent:.1f}% em {self.mission.target_category.name}"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        if result['is_completed']:
            return True, f"Parabéns! Você reduziu os gastos em {result['metrics']['category_name']}!"
        return False, f"Continue reduzindo gastos em {result['metrics']['category_name']}"


class CategoryLimitValidator(BaseMissionValidator):
    """
    Validador para missões de limite de gastos em categoria.
    
    Foco: Não exceder R$ X em uma categoria durante o período.
    Tracking: Total gasto na categoria.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        from .models import Transaction
        
        if not self.mission.target_category or not self.mission.category_spending_limit:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão sem categoria ou limite configurado'
            }
        
        # Gastos na categoria desde o início da missão
        spending_query = Transaction.objects.filter(
            user=self.user,
            type='EXPENSE',
            date__gte=self.mission_progress.started_at.date()
        )
        if self.mission.target_category:
            spending_query = spending_query.filter(category=self.mission.target_category)
        current_spending = spending_query.aggregate(total=Sum('amount'))['total'] or Decimal('0')
        
        limit = self.mission.category_spending_limit
        remaining = limit - current_spending
        
        # Se excedeu, progresso = 0, senão progresso baseado em quanto falta do período
        if current_spending > limit:
            progress = 0
            is_completed = False
        else:
            # Progresso baseado no tempo decorrido vs duração da missão
            elapsed_days = (timezone.now() - self.mission_progress.started_at).days
            mission_days = self.mission.duration_days
            time_progress = min(100, (elapsed_days / mission_days) * 100)
            progress = time_progress
            is_completed = elapsed_days >= mission_days
        
        return {
            'progress_percentage': float(progress),
            'is_completed': is_completed,
            'metrics': {
                'current_spending': float(current_spending),
                'limit': float(limit),
                'remaining': float(remaining),
                'exceeded': current_spending > limit,
                'category_name': self.mission.target_category.name
            },
            'message': f"R$ {remaining:.2f} restantes do limite em {self.mission.target_category.name}"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        if result['metrics']['exceeded']:
            return False, f"Você excedeu o limite de {self.mission.target_category.name}"
        if result['is_completed']:
            return True, f"Parabéns! Você respeitou o limite em {self.mission.target_category.name}!"
        return False, "Continue respeitando o limite"


class GoalProgressValidator(BaseMissionValidator):
    """
    Validador para missões de progresso em metas.
    
    Foco: Atingir X% de progresso em uma meta específica.
    Tracking: Progresso da meta.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        if not self.mission.target_goal_id:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão sem meta alvo configurada'
            }
        
        goal = self.mission.target_goal
        current_amount = goal.current_amount or Decimal('0')
        target_amount = goal.target_amount
        
        goal_progress = (current_amount / target_amount * 100) if target_amount > 0 else Decimal('0')
        target_progress = self.mission.goal_progress_target or Decimal('100')
        
        mission_progress = min(Decimal('100'), (goal_progress / target_progress) * 100)
        
        return {
            'progress_percentage': float(mission_progress),
            'is_completed': goal_progress >= target_progress,
            'metrics': {
                'goal_name': goal.title,
                'current_amount': float(current_amount),
                'target_amount': float(target_amount),
                'goal_progress': float(goal_progress),
                'target_progress': float(target_progress)
            },
            'message': f"Meta '{goal.title}' em {goal_progress:.1f}%"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        if result['is_completed']:
            return True, f"Parabéns! Você atingiu o progresso necessário em {result['metrics']['goal_name']}!"
        return False, f"Continue contribuindo para {result['metrics']['goal_name']}"


class GoalContributionValidator(BaseMissionValidator):
    """
    Validador para missões de contribuição para metas.
    
    Foco: Contribuir R$ X para uma meta durante o período.
    Tracking: Soma de transações vinculadas à meta.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        from .models import Transaction
        
        if not self.mission.target_goal_id:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão sem meta alvo configurada'
            }
        
        # Contribuições desde o início da missão
        contributions = Transaction.objects.filter(
            user=self.user,
            goal=self.mission.target_goal,
            date__gte=self.mission_progress.started_at.date()
        ).aggregate(total=Sum('amount'))['total'] or Decimal('0')
        
        target_contribution = self.mission.savings_increase_amount or Decimal('100')
        progress = min(100, (contributions / target_contribution) * 100)
        
        return {
            'progress_percentage': float(progress),
            'is_completed': contributions >= target_contribution,
            'metrics': {
                'goal_name': self.mission.target_goal.title,
                'contributions': float(contributions),
                'target_contribution': float(target_contribution),
                'remaining': float(target_contribution - contributions)
            },
            'message': f"R$ {contributions:.2f} / R$ {target_contribution:.2f} contribuídos"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        if result['is_completed']:
            return True, f"Parabéns! Você contribuiu o valor necessário para {result['metrics']['goal_name']}!"
        return False, f"Continue contribuindo para {result['metrics']['goal_name']}"


class TransactionConsistencyValidator(BaseMissionValidator):
    """
    Validador para missões de consistência no registro de transações.
    
    Foco: Registrar X transações por semana durante Y semanas.
    Tracking: Frequência semanal de transações.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        from .models import Transaction
        
        min_frequency = self.mission.min_transaction_frequency or 3  # Padrão: 3 transações/semana
        duration_weeks = (self.mission.duration_days + 6) // 7  # Arredondar para cima
        
        # Filtro por tipo de transação
        transaction_filter = Q(user=self.user, date__gte=self.mission_progress.started_at.date())
        if self.mission.transaction_type_filter != 'ALL':
            transaction_filter &= Q(type=self.mission.transaction_type_filter)
        
        # Contar transações por semana
        weeks_meeting_criteria = 0
        current_date = self.mission_progress.started_at.date()
        end_date = min(timezone.now().date(), current_date + timedelta(days=self.mission.duration_days))
        
        while current_date < end_date:
            week_end = min(current_date + timedelta(days=7), end_date)
            week_transactions = Transaction.objects.filter(
                transaction_filter,
                date__gte=current_date,
                date__lt=week_end
            ).count()
            
            if week_transactions >= min_frequency:
                weeks_meeting_criteria += 1
            
            current_date = week_end
        
        progress = min(100, (weeks_meeting_criteria / duration_weeks) * 100)
        
        return {
            'progress_percentage': float(progress),
            'is_completed': weeks_meeting_criteria >= duration_weeks,
            'metrics': {
                'weeks_meeting_criteria': weeks_meeting_criteria,
                'target_weeks': duration_weeks,
                'min_frequency': min_frequency,
                'transaction_type': self.mission.transaction_type_filter
            },
            'message': f"{weeks_meeting_criteria}/{duration_weeks} semanas com consistência"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        if result['is_completed']:
            return True, "Parabéns! Você manteve consistência no registro de transações!"
        return False, "Continue registrando transações regularmente"


class PaymentDisciplineValidator(BaseMissionValidator):
    """
    Validador para missões de disciplina em pagamentos.
    
    Foco: Registrar X pagamentos (transações com is_paid=True) no período.
    Tracking: Número de pagamentos registrados.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        from .models import Transaction
        
        if not self.mission.requires_payment_tracking:
            return {
                'progress_percentage': 0,
                'is_completed': False,
                'metrics': {},
                'message': 'Missão não requer rastreamento de pagamentos'
            }
        
        # Contar pagamentos desde o início da missão
        payments_count = Transaction.objects.filter(
            user=self.user,
            is_paid=True,
            date__gte=self.mission_progress.started_at.date()
        ).count()
        
        target_payments = self.mission.min_payments_count or 5
        progress = min(100, (payments_count / target_payments) * 100)
        
        return {
            'progress_percentage': float(progress),
            'is_completed': payments_count >= target_payments,
            'metrics': {
                'payments_count': payments_count,
                'target_payments': target_payments,
                'remaining': max(0, target_payments - payments_count)
            },
            'message': f"{payments_count}/{target_payments} pagamentos registrados"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        if result['is_completed']:
            return True, "Parabéns! Você manteve a disciplina nos pagamentos!"
        return False, "Continue registrando seus pagamentos"


class IndicatorMaintenanceValidator(BaseMissionValidator):
    """
    Validador para missões de manutenção de indicadores.
    
    Foco: Manter TPS/RDR/ILI em nível específico por X dias consecutivos.
    Tracking: Histórico diário de indicadores.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        from .services import calculate_summary
        
        # Obter métricas atuais
        metrics = calculate_summary(self.user)
        
        # Verificar quais indicadores estão sendo rastreados
        indicators_status = []
        all_met = True
        
        if self.mission.target_tps is not None:
            current_tps = float(metrics.get('tps', 0))
            met = current_tps >= self.mission.target_tps
            indicators_status.append({
                'name': 'TPS',
                'current': current_tps,
                'target': self.mission.target_tps,
                'met': met
            })
            all_met = all_met and met
        
        if self.mission.target_rdr is not None:
            current_rdr = float(metrics.get('rdr', 100))
            met = current_rdr <= self.mission.target_rdr
            indicators_status.append({
                'name': 'RDR',
                'current': current_rdr,
                'target': self.mission.target_rdr,
                'met': met
            })
            all_met = all_met and met
        
        if self.mission.min_ili is not None or self.mission.max_ili is not None:
            current_ili = float(metrics.get('ili', 0))
            if self.mission.min_ili is not None:
                met_min = current_ili >= float(self.mission.min_ili)
            else:
                met_min = True
            if self.mission.max_ili is not None:
                met_max = current_ili <= float(self.mission.max_ili)
            else:
                met_max = True
            met = met_min and met_max
            indicators_status.append({
                'name': 'ILI',
                'current': current_ili,
                'target_min': float(self.mission.min_ili) if self.mission.min_ili else None,
                'target_max': float(self.mission.max_ili) if self.mission.max_ili else None,
                'met': met
            })
            all_met = all_met and met
        
        # Calcular dias de manutenção (simplificado - em produção, usar histórico)
        min_days = self.mission.min_consecutive_days or self.mission.duration_days
        elapsed_days = (timezone.now() - self.mission_progress.started_at).days
        
        if all_met:
            days_maintained = elapsed_days
        else:
            days_maintained = 0
        
        progress = min(100, (days_maintained / min_days) * 100)
        
        return {
            'progress_percentage': float(progress),
            'is_completed': days_maintained >= min_days,
            'metrics': {
                'indicators': indicators_status,
                'days_maintained': days_maintained,
                'target_days': min_days,
                'all_met': all_met
            },
            'message': f"Indicadores mantidos por {days_maintained}/{min_days} dias"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        if result['is_completed']:
            return True, "Parabéns! Você manteve seus indicadores no nível adequado!"
        if not result['metrics']['all_met']:
            pending = [ind['name'] for ind in result['metrics']['indicators'] if not ind['met']]
            return False, f"Ajuste os indicadores: {', '.join(pending)}"
        return False, "Continue mantendo seus indicadores"


class MultiCriteriaValidator(BaseMissionValidator):
    """
    Validador para missões com múltiplos critérios simultâneos.
    
    Foco: Combinar validações de diferentes tipos (categorias + metas + indicadores).
    Tracking: Agregação de múltiplos validadores.
    """
    
    def calculate_progress(self) -> Dict[str, Any]:
        criteria_results = []
        total_progress = 0
        criteria_count = 0
        
        # Validar categorias alvo (se houver)
        if self.mission.target_categories.exists():
            from .models import Transaction
            for category in self.mission.target_categories.all():
                spending = Transaction.objects.filter(
                    user=self.user,
                    category=category,
                    type='EXPENSE',
                    date__gte=self.mission_progress.started_at.date()
                ).aggregate(total=Sum('amount'))['total'] or Decimal('0')
                
                # Critério: manter gasto baixo
                limit = self.mission.category_spending_limit or Decimal('500')
                met = spending <= limit
                criteria_results.append({
                    'type': 'category',
                    'name': category.name,
                    'met': met,
                    'value': float(spending),
                    'target': float(limit)
                })
                if met:
                    total_progress += 100
                criteria_count += 1
        
        # Validar metas alvo (se houver)
        if self.mission.target_goals.exists():
            for goal in self.mission.target_goals.all():
                goal_progress = (goal.current_amount / goal.target_amount * 100) if goal.target_amount > 0 else 0
                target_progress = float(self.mission.goal_progress_target or Decimal('50'))
                met = goal_progress >= target_progress
                criteria_results.append({
                    'type': 'goal',
                    'name': goal.title,
                    'met': met,
                    'value': float(goal_progress),
                    'target': target_progress
                })
                if met:
                    total_progress += 100
                criteria_count += 1
        
        # Validar indicadores
        from .services import calculate_summary
        metrics = calculate_summary(self.user)
        
        if self.mission.target_tps is not None:
            current_tps = float(metrics.get('tps', 0))
            met = current_tps >= self.mission.target_tps
            criteria_results.append({
                'type': 'indicator',
                'name': 'TPS',
                'met': met,
                'value': current_tps,
                'target': self.mission.target_tps
            })
            if met:
                total_progress += 100
            criteria_count += 1
        
        if self.mission.target_rdr is not None:
            current_rdr = float(metrics.get('rdr', 100))
            met = current_rdr <= self.mission.target_rdr
            criteria_results.append({
                'type': 'indicator',
                'name': 'RDR',
                'met': met,
                'value': current_rdr,
                'target': self.mission.target_rdr
            })
            if met:
                total_progress += 100
            criteria_count += 1
        
        if criteria_count == 0:
            criteria_count = 1
        
        avg_progress = total_progress / criteria_count
        all_met = all(c['met'] for c in criteria_results)
        
        return {
            'progress_percentage': float(avg_progress),
            'is_completed': all_met,
            'metrics': {
                'criteria': criteria_results,
                'total_criteria': criteria_count,
                'met_criteria': sum(1 for c in criteria_results if c['met'])
            },
            'message': f"{sum(1 for c in criteria_results if c['met'])}/{criteria_count} critérios atendidos"
        }
    
    def validate_completion(self) -> Tuple[bool, str]:
        result = self.calculate_progress()
        if result['is_completed']:
            return True, "Parabéns! Você completou todos os critérios desta missão complexa!"
        pending = [c['name'] for c in result['metrics']['criteria'] if not c['met']]
        return False, f"Continue trabalhando em: {', '.join(pending)}"


class MissionValidatorFactory:
    """
    Factory para criar o validador apropriado baseado no tipo de missão.
    """
    
    _validators = {
        # Tipos antigos (mantidos para compatibilidade)
        'ONBOARDING': OnboardingMissionValidator,
        'TPS_IMPROVEMENT': TPSImprovementMissionValidator,
        'RDR_REDUCTION': RDRReductionMissionValidator,
        'ILI_BUILDING': ILIBuildingMissionValidator,
        'ADVANCED': AdvancedMissionValidator,
        
        # Novos tipos (Sprint 2)
        'ONBOARDING_TRANSACTIONS': OnboardingMissionValidator,
        'ONBOARDING_CATEGORIES': OnboardingMissionValidator,
        'ONBOARDING_GOALS': OnboardingMissionValidator,
        'CATEGORY_REDUCTION': CategoryReductionValidator,
        'CATEGORY_SPENDING_LIMIT': CategoryLimitValidator,
        'CATEGORY_ELIMINATION': CategoryLimitValidator,
        'GOAL_ACHIEVEMENT': GoalProgressValidator,
        'GOAL_CONSISTENCY': GoalContributionValidator,
        'GOAL_ACCELERATION': GoalContributionValidator,
        'SAVINGS_STREAK': GoalContributionValidator,
        'EXPENSE_CONTROL': CategoryLimitValidator,
        'INCOME_TRACKING': TransactionConsistencyValidator,
        'PAYMENT_DISCIPLINE': PaymentDisciplineValidator,
        'FINANCIAL_HEALTH': MultiCriteriaValidator,
        'WEALTH_BUILDING': MultiCriteriaValidator,
    }
    
    _validation_type_validators = {
        # Mapeamento por validation_type para casos especiais
        'CATEGORY_REDUCTION': CategoryReductionValidator,
        'CATEGORY_LIMIT': CategoryLimitValidator,
        'CATEGORY_ZERO': CategoryLimitValidator,
        'GOAL_PROGRESS': GoalProgressValidator,
        'GOAL_CONTRIBUTION': GoalContributionValidator,
        'GOAL_COMPLETION': GoalProgressValidator,
        'TRANSACTION_COUNT': OnboardingMissionValidator,
        'TRANSACTION_CONSISTENCY': TransactionConsistencyValidator,
        'PAYMENT_COUNT': PaymentDisciplineValidator,
        'INDICATOR_THRESHOLD': AdvancedMissionValidator,
        'INDICATOR_IMPROVEMENT': TPSImprovementMissionValidator,
        'INDICATOR_MAINTENANCE': IndicatorMaintenanceValidator,
        'MULTI_CRITERIA': MultiCriteriaValidator,
    }
    
    @classmethod
    def create_validator(cls, mission, user, mission_progress) -> BaseMissionValidator:
        """
        Cria e retorna o validador apropriado para o tipo de missão.
        
        Args:
            mission: Instância do modelo Mission
            user: Usuário
            mission_progress: Instância do modelo MissionProgress
            
        Returns:
            Instância do validador apropriado
            
        Raises:
            ValueError: Se o tipo de missão não for reconhecido
        """
        # Primeiro tenta pelo validation_type (mais específico)
        validator_class = cls._validation_type_validators.get(mission.validation_type)
        
        # Se não encontrar, tenta pelo mission_type
        if validator_class is None:
            validator_class = cls._validators.get(mission.mission_type)
        
        # Fallback para MultiCriteriaValidator
        if validator_class is None:
            logger.warning(f"Tipo de missão desconhecido: {mission.mission_type}, usando MultiCriteriaValidator")
            validator_class = MultiCriteriaValidator
        
        return validator_class(mission, user, mission_progress)


def update_mission_progress(mission_progress) -> Dict[str, Any]:
    """
    Atualiza o progresso de uma missão usando o validador apropriado.
    
    Args:
        mission_progress: Instância do modelo MissionProgress
        
    Returns:
        Dict com resultado da atualização
    """
    validator = MissionValidatorFactory.create_validator(
        mission_progress.mission,
        mission_progress.user,
        mission_progress
    )
    
    result = validator.calculate_progress()
    
    # Atualizar o modelo
    mission_progress.progress_percentage = result['progress_percentage']
    
    # Completar se necessário
    if result['is_completed'] and not mission_progress.completed_at:
        is_valid, message = validator.validate_completion()
        if is_valid:
            mission_progress.completed_at = timezone.now()
            mission_progress.is_completed = True
            logger.info(f"Missão completada: {mission_progress.mission.title} - {message}")
    
    mission_progress.save()
    
    return result
