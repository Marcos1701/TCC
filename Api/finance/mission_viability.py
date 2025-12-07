"""
Mission Viability Checker
=========================

Validates whether a mission is achievable for a given user context.
Prevents creation of impossible or improbable missions.
"""

from datetime import timedelta
from decimal import Decimal
from typing import Any, Dict, List, Optional, Tuple

from django.utils import timezone


class MissionViabilityChecker:
    """Validates if a mission is achievable for a user."""
    
    # Maximum improvement per day for each indicator (conservative estimates)
    MAX_DAILY_TPS_IMPROVEMENT = 1.0   # 1% per day max
    MAX_DAILY_RDR_REDUCTION = 0.5     # 0.5% per day max
    MAX_DAILY_ILI_INCREASE = 0.05     # 0.05 months per day max
    
    def __init__(self, user=None, context=None):
        """
        Initialize checker with user or context.
        
        Args:
            user: Django user object (optional)
            context: UserContext dataclass (optional)
        """
        self.user = user
        self.context = context
        
        # If user provided but no context, build context
        if user and not context:
            self._build_context_from_user()
    
    def _build_context_from_user(self):
        """Build a context dict from user data."""
        if not self.user:
            return
        
        from .mission_generator import UserContext
        self.context = UserContext.from_user(self.user)
    
    def check(self, mission_data: Dict[str, Any]) -> Tuple[bool, List[str]]:
        """
        Check if a mission is viable.
        
        Args:
            mission_data: Dictionary with mission configuration
            
        Returns:
            Tuple of (is_viable, list_of_issues)
        """
        issues = []
        
        mission_type = mission_data.get('mission_type', '')
        
        # Common validations
        issues.extend(self._check_common_rules(mission_data))
        
        # Type-specific validations
        if mission_type == 'ONBOARDING':
            issues.extend(self._check_onboarding(mission_data))
        elif mission_type == 'TPS_IMPROVEMENT':
            issues.extend(self._check_tps(mission_data))
        elif mission_type == 'RDR_REDUCTION':
            issues.extend(self._check_rdr(mission_data))
        elif mission_type == 'ILI_BUILDING':
            issues.extend(self._check_ili(mission_data))
        elif mission_type == 'CATEGORY_REDUCTION':
            issues.extend(self._check_category(mission_data))
        else:
            issues.append(f"Tipo de missão desconhecido: {mission_type}")
        
        return len(issues) == 0, issues
    
    def _check_common_rules(self, data: Dict) -> List[str]:
        """Check rules common to all mission types."""
        issues = []
        
        # Duration check
        duration = data.get('duration_days', 30)
        if duration < 7:
            issues.append("Duração mínima recomendada é 7 dias")
        if duration > 365:
            issues.append("Duração máxima é 365 dias")
        
        # Reward check
        reward = data.get('reward_points', 0)
        if reward < 10:
            issues.append("Recompensa mínima é 10 XP")
        if reward > 1000:
            issues.append("Recompensa máxima é 1000 XP")
        
        # Title/description check
        title = data.get('title', '')
        if len(title) < 5:
            issues.append("Título muito curto (mínimo 5 caracteres)")
        if len(title) > 150:
            issues.append("Título muito longo (máximo 150 caracteres)")
        
        description = data.get('description', '')
        if len(description) < 10:
            issues.append("Descrição muito curta (mínimo 10 caracteres)")
        
        return issues
    
    def _check_onboarding(self, data: Dict) -> List[str]:
        """Check onboarding mission viability."""
        issues = []
        
        min_transactions = data.get('min_transactions', 0)
        
        if min_transactions < 5:
            issues.append("min_transactions deve ser pelo menos 5")
        if min_transactions > 50:
            issues.append("min_transactions não deve exceder 50")
        
        # Check if user already has too many transactions (mission would be too easy)
        if self.context:
            current_count = getattr(self.context, 'transaction_count', 0)
            if current_count > 200 and min_transactions < 20:
                issues.append(
                    f"Usuário já tem {current_count} transações. "
                    f"Meta de {min_transactions} pode ser muito fácil."
                )
        
        return issues
    
    def _check_tps(self, data: Dict) -> List[str]:
        """Check TPS improvement mission viability."""
        issues = []
        
        target_tps = data.get('target_tps', 0)
        duration = data.get('duration_days', 30)
        
        # Basic range check
        if target_tps < 1 or target_tps > 80:
            issues.append("target_tps deve estar entre 1% e 80%")
            return issues
        
        # Check against user's current TPS
        if self.context:
            current_tps = getattr(self.context, 'tps', 0)
            
            # Target must be higher than current
            if target_tps <= current_tps:
                issues.append(
                    f"Meta TPS ({target_tps}%) deve ser maior que TPS atual ({current_tps:.1f}%)"
                )
            
            # Check if improvement is achievable in given time
            improvement_needed = target_tps - current_tps
            max_possible = duration * self.MAX_DAILY_TPS_IMPROVEMENT
            
            if improvement_needed > max_possible:
                issues.append(
                    f"Melhoria de {improvement_needed:.1f}% em {duration} dias "
                    f"pode ser muito agressiva (máx sugerido: {max_possible:.1f}%)"
                )
            
            # Warn about very high targets
            if target_tps > 50:
                issues.append(
                    f"TPS de {target_tps}% é muito alto. "
                    f"Poucos usuários conseguem manter TPS > 50%"
                )
        
        return issues
    
    def _check_rdr(self, data: Dict) -> List[str]:
        """Check RDR reduction mission viability."""
        issues = []
        
        target_rdr = data.get('target_rdr', 50)
        duration = data.get('duration_days', 30)
        
        # Basic range check
        if target_rdr < 5 or target_rdr > 95:
            issues.append("target_rdr deve estar entre 5% e 95%")
            return issues
        
        # Check against user's current RDR
        if self.context:
            current_rdr = getattr(self.context, 'rdr', 50)
            
            # Target must be lower than current
            if target_rdr >= current_rdr:
                issues.append(
                    f"Meta RDR ({target_rdr}%) deve ser menor que RDR atual ({current_rdr:.1f}%)"
                )
            
            # Check if reduction is achievable in given time
            reduction_needed = current_rdr - target_rdr
            max_possible = duration * self.MAX_DAILY_RDR_REDUCTION
            
            if reduction_needed > max_possible:
                issues.append(
                    f"Redução de {reduction_needed:.1f}% em {duration} dias "
                    f"pode ser muito agressiva (máx sugerido: {max_possible:.1f}%)"
                )
            
            # Warn about very low targets
            if target_rdr < 20:
                issues.append(
                    f"RDR de {target_rdr}% é muito baixo. "
                    f"A maioria das pessoas não consegue manter abaixo de 20%"
                )
        
        return issues
    
    def _check_ili(self, data: Dict) -> List[str]:
        """Check ILI building mission viability."""
        issues = []
        
        min_ili = data.get('min_ili', 3)
        if isinstance(min_ili, Decimal):
            min_ili = float(min_ili)
        
        duration = data.get('duration_days', 30)
        
        # Basic range check
        if min_ili < 0.5 or min_ili > 24:
            issues.append("min_ili deve estar entre 0.5 e 24 meses")
            return issues
        
        # Check against user's current ILI
        if self.context:
            current_ili = getattr(self.context, 'ili', 0)
            
            # Target must be higher than current
            if min_ili <= current_ili:
                issues.append(
                    f"Meta ILI ({min_ili:.1f} meses) deve ser maior que ILI atual ({current_ili:.1f} meses)"
                )
            
            # Check if increase is achievable in given time
            increase_needed = min_ili - current_ili
            max_possible = duration * self.MAX_DAILY_ILI_INCREASE
            
            if increase_needed > max_possible:
                issues.append(
                    f"Aumento de {increase_needed:.1f} meses em {duration} dias "
                    f"pode ser muito agressivo (máx sugerido: {max_possible:.1f} meses)"
                )
            
            # Realistic warning
            if min_ili > 12:
                issues.append(
                    f"ILI de {min_ili:.1f} meses é um objetivo de longo prazo. "
                    f"Considere uma meta mais próxima."
                )
        
        return issues
    
    def _check_category(self, data: Dict) -> List[str]:
        """Check category reduction mission viability."""
        issues = []
        
        target_percent = data.get('target_reduction_percent', 15)
        if isinstance(target_percent, Decimal):
            target_percent = float(target_percent)
        
        # Basic range check
        if target_percent < 5 or target_percent > 80:
            issues.append("target_reduction_percent deve estar entre 5% e 80%")
        
        # Warn about aggressive reductions
        if target_percent > 40:
            issues.append(
                f"Redução de {target_percent}% é muito agressiva. "
                f"Recomendado: 10-30%"
            )
        
        # Check if user has category history
        if self.user:
            self._check_category_history(data, issues)
        
        return issues
    
    def _check_category_history(self, data: Dict, issues: List[str]):
        """Check if user has history in the target category."""
        from .models import Transaction
        
        target_category = data.get('target_category')
        target_category_id = data.get('target_category_id')
        
        category_id = target_category_id or (target_category.id if target_category else None)
        
        if category_id:
            # Check for recent transactions in this category
            recent_count = Transaction.objects.filter(
                user=self.user,
                category_id=category_id,
                date__gte=timezone.now().date() - timedelta(days=60)
            ).count()
            
            if recent_count < 3:
                issues.append(
                    f"Usuário tem apenas {recent_count} transações recentes nesta categoria. "
                    f"Insuficiente para comparação."
                )
        else:
            # No specific category - check if user has any categorized expenses
            if self.context and not getattr(self.context, 'has_categories', False):
                issues.append(
                    "Usuário não tem transações categorizadas. "
                    "Não é possível calcular redução."
                )


def validate_mission_viability(
    mission_data: Dict[str, Any],
    user=None,
    context=None
) -> Tuple[bool, List[str]]:
    """
    Convenience function to validate mission viability.
    
    Args:
        mission_data: Mission configuration dictionary
        user: Optional Django user object
        context: Optional UserContext dataclass
        
    Returns:
        Tuple of (is_viable, list_of_issues)
    """
    checker = MissionViabilityChecker(user=user, context=context)
    return checker.check(mission_data)
