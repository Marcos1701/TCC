"""
Classe base abstrata para validadores de missões.
"""

from abc import ABC, abstractmethod
from typing import Any, Dict, Tuple


class BaseMissionValidator(ABC):
    """
    Classe base abstrata para validadores de missões.
    
    Cada tipo de missão deve implementar sua própria lógica de:
    - Cálculo de progresso
    - Validação de conclusão
    - Tracking de métricas específicas
    """
    
    def __init__(self, mission, user, mission_progress):
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
        """Retorna métricas atuais do usuário relevantes para esta missão."""
        from ..services import calculate_summary
        return calculate_summary(self.user)
