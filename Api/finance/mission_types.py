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


class MissionValidatorFactory:
    """
    Factory para criar o validador apropriado baseado no tipo de missão.
    """
    
    _validators = {
        'ONBOARDING': OnboardingMissionValidator,
        'TPS_IMPROVEMENT': TPSImprovementMissionValidator,
        'RDR_REDUCTION': RDRReductionMissionValidator,
        'ILI_BUILDING': ILIBuildingMissionValidator,
        'ADVANCED': AdvancedMissionValidator,
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
        mission_type = mission.mission_type
        validator_class = cls._validators.get(mission_type)
        
        if validator_class is None:
            logger.warning(f"Tipo de missão desconhecido: {mission_type}, usando AdvancedMissionValidator")
            validator_class = AdvancedMissionValidator
        
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
