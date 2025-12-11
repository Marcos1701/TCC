
from abc import ABC, abstractmethod
from typing import Any, Dict, Tuple


class BaseMissionValidator(ABC):
    
    def __init__(self, mission, user, mission_progress):
        self.mission = mission
        self.user = user
        self.mission_progress = mission_progress
        
    @abstractmethod
    def calculate_progress(self) -> Dict[str, Any]:
        pass
    
    @abstractmethod
    def validate_completion(self) -> Tuple[bool, str]:
        pass
    
    def get_current_metrics(self) -> Dict[str, Any]:
        from ..services import calculate_summary
        return calculate_summary(self.user)
