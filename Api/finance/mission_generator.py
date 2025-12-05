"""
Gerador Unificado de Missões com Integração de IA.

Este módulo centraliza toda a lógica de geração de missões,
combinando IA (Gemini) com templates de fallback para garantir
que todas as missões geradas sejam válidas e alcançáveis.

A abordagem híbrida oferece:
1. Geração inteligente via IA Gemini (principal)
2. Templates como fallback quando IA não disponível
3. Validações rigorosas antes de salvar
4. Detecção de duplicatas semânticas
5. Distribuição inteligente por contexto/tier

Desenvolvido como parte do TCC - Sistema de Educação Financeira Gamificada.
"""

import json
import logging
import random
import time
from dataclasses import dataclass, field
from difflib import SequenceMatcher
from typing import Any, Dict, List, Optional, Tuple

from django.db.models import Avg

logger = logging.getLogger(__name__)


# =============================================================================
# CONFIGURAÇÕES E CONSTANTES
# =============================================================================

# Tipos de missão oficiais do sistema
MISSION_TYPES = [
    'ONBOARDING',           # Primeiros passos - requer min_transactions
    'TPS_IMPROVEMENT',      # Aumentar poupança - requer target_tps
    'RDR_REDUCTION',        # Reduzir gastos recorrentes - requer target_rdr
    'ILI_BUILDING',         # Construir reserva - requer min_ili
    'CATEGORY_REDUCTION',   # Reduzir gastos em categoria - requer target_reduction_percent
]

# Campos obrigatórios por tipo de missão
REQUIRED_FIELDS_BY_TYPE = {
    'ONBOARDING': {'field': 'min_transactions', 'min': 5, 'max': 50, 'type': int},
    'TPS_IMPROVEMENT': {'field': 'target_tps', 'min': 5, 'max': 50, 'type': float},
    'RDR_REDUCTION': {'field': 'target_rdr', 'min': 15, 'max': 70, 'type': float},
    'ILI_BUILDING': {'field': 'min_ili', 'min': 1, 'max': 12, 'type': float},
    'CATEGORY_REDUCTION': {'field': 'target_reduction_percent', 'min': 5, 'max': 40, 'type': float},
}


@dataclass
class MissionConfig:
    """Configuração centralizada para geração de missões."""
    
    # Recompensas por dificuldade
    XP_RANGES = {
        'EASY': (30, 80),
        'MEDIUM': (80, 180),
        'HARD': (180, 350),
    }
    
    # Duração por dificuldade (dias)
    DURATION_RANGES = {
        'EASY': (7, 14),
        'MEDIUM': (14, 21),
        'HARD': (21, 30),
    }


@dataclass
class UserContext:
    """Contexto do usuário para geração de missões personalizadas."""
    
    tier: str = 'BEGINNER'  # BEGINNER, INTERMEDIATE, ADVANCED
    level: int = 1
    tps: float = 0.0  # Taxa de Poupança atual (%)
    rdr: float = 50.0  # Razão Despesas/Receita atual (%)
    ili: float = 0.0  # Índice de Liquidez Imediata (meses)
    transaction_count: int = 0
    has_categories: bool = False
    top_expense_categories: List[str] = field(default_factory=list)
    
    @classmethod
    def from_user(cls, user) -> 'UserContext':
        """
        Cria contexto a partir de um usuário do Django.
        
        Args:
            user: Instância do modelo User do Django.
            
        Returns:
            UserContext: Contexto preenchido com dados do usuário.
        """
        from .services.indicators import calculate_summary
        from .models import Transaction, UserProfile
        
        try:
            profile = UserProfile.objects.get(user=user)
            level = profile.level
        except UserProfile.DoesNotExist:
            level = 1
        
        # Determinar tier baseado no nível
        if level <= 5:
            tier = 'BEGINNER'
        elif level <= 15:
            tier = 'INTERMEDIATE'
        else:
            tier = 'ADVANCED'
        
        # Calcular indicadores
        try:
            indicators = calculate_summary(user)
            tps = float(indicators.get('tps', 0))
            rdr = float(indicators.get('rdr', 50))
            ili = float(indicators.get('ili', 0))
        except Exception as e:
            logger.warning(f"Erro ao calcular indicadores para {user.id}: {e}")
            tps, rdr, ili = 0.0, 50.0, 0.0
        
        # Contar transações
        transaction_count = Transaction.objects.filter(user=user).count()
        
        # Verificar se tem categorias de despesa
        has_categories = Transaction.objects.filter(
            user=user, 
            type='EXPENSE',
            category__isnull=False
        ).exists()
        
        # Top categorias de despesa
        top_categories = list(
            Transaction.objects.filter(user=user, type='EXPENSE')
            .values_list('category__name', flat=True)
            .annotate(total=Avg('amount'))
            .order_by('-total')[:5]
        )
        
        return cls(
            tier=tier,
            level=level,
            tps=tps,
            rdr=rdr,
            ili=ili,
            transaction_count=transaction_count,
            has_categories=has_categories,
            top_expense_categories=[c for c in top_categories if c],
        )
    
    @classmethod
    def default_for_tier(cls, tier: str) -> 'UserContext':
        """
        Cria contexto padrão para uma tier específica.
        
        Args:
            tier: BEGINNER, INTERMEDIATE ou ADVANCED.
            
        Returns:
            UserContext: Contexto com valores padrão da tier.
        """
        defaults = {
            'BEGINNER': {
                'level': 3, 'tps': 5.0, 'rdr': 55.0, 'ili': 0.5,
                'transaction_count': 20,
            },
            'INTERMEDIATE': {
                'level': 10, 'tps': 18.0, 'rdr': 40.0, 'ili': 2.5,
                'transaction_count': 150,
            },
            'ADVANCED': {
                'level': 20, 'tps': 28.0, 'rdr': 28.0, 'ili': 6.0,
                'transaction_count': 500,
            },
        }
        
        config = defaults.get(tier, defaults['BEGINNER'])
        return cls(tier=tier, **config)


# =============================================================================
# TEMPLATES DE MISSÕES (FALLBACK QUANDO IA INDISPONÍVEL)
# =============================================================================

MISSION_TEMPLATES = {
    'ONBOARDING': [
        {
            'title_template': 'Registre suas primeiras {count} transações',
            'description_template': 'Comece sua jornada financeira registrando {count} transações. '
                'Cada registro ajuda você a entender para onde seu dinheiro está indo.',
            'difficulty_range': ['EASY'],
        },
        {
            'title_template': 'Mapeie seu fluxo financeiro: {count} registros',
            'description_template': 'Registre {count} transações para visualizar seu padrão de gastos. '
                'Conhecer seus hábitos é o primeiro passo para melhorá-los.',
            'difficulty_range': ['EASY', 'MEDIUM'],
        },
        {
            'title_template': 'Construindo o hábito: {count} transações',
            'description_template': 'Mantenha a consistência registrando {count} transações. '
                'O hábito de registrar é fundamental para o controle financeiro.',
            'difficulty_range': ['MEDIUM'],
        },
    ],
    
    'TPS_IMPROVEMENT': [
        {
            'title_template': 'Alcance {target}% de economia',
            'description_template': 'Eleve sua Taxa de Poupança para {target}%. '
                'A TPS mostra quanto da sua renda você está guardando. Quanto maior, melhor!',
            'difficulty_range': ['EASY', 'MEDIUM'],
        },
        {
            'title_template': 'Desafio de poupança: {target}%',
            'description_template': 'Aumente sua TPS para {target}% controlando gastos supérfluos. '
                'Identifique despesas que podem ser reduzidas ou eliminadas.',
            'difficulty_range': ['MEDIUM'],
        },
        {
            'title_template': 'Meta ambiciosa: {target}% de TPS',
            'description_template': 'Atinja {target}% de Taxa de Poupança. Revise todas as despesas, '
                'negocie contratos e elimine gastos desnecessários.',
            'difficulty_range': ['HARD'],
        },
    ],
    
    'RDR_REDUCTION': [
        {
            'title_template': 'Controle gastos fixos: máximo {target}%',
            'description_template': 'Reduza sua Razão Despesas/Renda para {target}%. '
                'Revise assinaturas, serviços e custos recorrentes.',
            'difficulty_range': ['MEDIUM'],
        },
        {
            'title_template': 'Liberte sua renda: RDR {target}%',
            'description_template': 'Mantenha despesas fixas abaixo de {target}% da renda. '
                'Cada percentual liberado aumenta sua margem de manobra.',
            'difficulty_range': ['MEDIUM', 'HARD'],
        },
        {
            'title_template': 'Reduza custos fixos para {target}%',
            'description_template': 'Diminua o comprometimento da sua renda para {target}%. '
                'Analise cada gasto recorrente e avalie sua real necessidade.',
            'difficulty_range': ['EASY', 'MEDIUM'],
        },
    ],
    
    'ILI_BUILDING': [
        {
            'title_template': 'Construa {target} meses de reserva',
            'description_template': 'Acumule o equivalente a {target} meses de despesas em reserva. '
                'Uma reserva de emergência traz segurança e tranquilidade.',
            'difficulty_range': ['MEDIUM', 'HARD'],
        },
        {
            'title_template': 'Primeiros passos: {target} meses de segurança',
            'description_template': 'Inicie sua reserva de emergência com meta de {target} meses. '
                'Comece pequeno, o importante é começar!',
            'difficulty_range': ['EASY'],
        },
        {
            'title_template': 'Rede de segurança: {target} meses',
            'description_template': 'Aumente sua reserva para cobrir {target} meses de despesas. '
                'Especialistas recomendam 3-6 meses para emergências.',
            'difficulty_range': ['MEDIUM'],
        },
    ],
    
    'CATEGORY_REDUCTION': [
        {
            'title_template': 'Reduza {target}% em gastos',
            'description_template': 'Diminua seus gastos em uma categoria específica em {target}%. '
                'Identifique onde você pode economizar sem perder qualidade de vida.',
            'difficulty_range': ['EASY', 'MEDIUM'],
            'category': 'category_reduction',
        },
    ],

GEMINI_MISSION_PROMPT = """Você é um especialista em educação financeira criando missões gamificadas para um aplicativo.

## CONTEXTO DO USUÁRIO
- Tier: {tier} ({tier_description})
- Nível: {level}
- TPS atual: {tps}% (Taxa de Poupança)
- RDR atual: {rdr}% (Razão Despesas/Renda)  
- ILI atual: {ili} meses (Reserva de emergência)
- Transações registradas: {transaction_count}
- Categorias principais: {categories}

## TIPOS DE MISSÃO (use EXATAMENTE estes valores)

1. **ONBOARDING** - Primeiros passos (registrar transações)
   - Campo OBRIGATÓRIO: "min_transactions" (int, 5-50)
   
2. **TPS_IMPROVEMENT** - Aumentar Taxa de Poupança
   - Campo OBRIGATÓRIO: "target_tps" (float, 5-50)
   
3. **RDR_REDUCTION** - Reduzir gastos recorrentes
   - Campo OBRIGATÓRIO: "target_rdr" (float, 15-70)
   
4. **ILI_BUILDING** - Construir reserva de emergência
   - Campo OBRIGATÓRIO: "min_ili" (float, 1-12)
   
5. **CATEGORY_REDUCTION** - Reduzir gastos em categoria
   - Campo OBRIGATÓRIO: "target_reduction_percent" (float, 5-40)
   
6. **GOAL_ACHIEVEMENT** - Progredir em meta financeira
   - Campo OBRIGATÓRIO: "goal_progress_target" (float, 10-100)

## DISTRIBUIÇÃO REQUERIDA
{distribution_text}

## REGRAS DE VALIDAÇÃO

1. **Missões devem ser ALCANÇÁVEIS**:
   - TPS_IMPROVEMENT: target_tps deve ser maior que TPS atual ({tps}%)
   - RDR_REDUCTION: target_rdr deve ser menor que RDR atual ({rdr}%)
   - ILI_BUILDING: min_ili deve ser maior que ILI atual ({ili})

2. **Dificuldade** (EASY, MEDIUM, HARD):
   - EASY: XP 30-80, duração 7-14 dias
   - MEDIUM: XP 80-180, duração 14-21 dias
   - HARD: XP 180-350, duração 21-30 dias

3. **Títulos e descrições**:
   - Títulos: máximo 150 caracteres, sem emojis, ÚNICOS
   - Descrições: claras, educacionais, motivadoras

## TAREFA
Gere {count} missões ÚNICAS e VARIADAS seguindo a distribuição acima.

## FORMATO DE RESPOSTA (JSON válido)
Retorne APENAS um array JSON, sem texto antes ou depois:

[
  {{
    "title": "Título único (max 150 chars)",
    "description": "Descrição educacional clara",
    "mission_type": "TIPO_DA_MISSAO",
    "difficulty": "EASY|MEDIUM|HARD",
    "duration_days": número (7-30),
    "xp_reward": número (30-350),
    "min_transactions": número ou null,
    "target_tps": número ou null,
    "target_rdr": número ou null,
    "min_ili": número ou null,
    "target_reduction_percent": número ou null,
    "goal_progress_target": número ou null
  }}
]
"""


# =============================================================================
# VALIDADORES
# =============================================================================

class MissionViabilityValidator:
    """
    Valida se uma missão é alcançável dado o contexto do usuário.
    
    Evita a geração de missões impossíveis ou sem sentido.
    """
    
    @staticmethod
    def validate_onboarding(
        min_transactions: int, 
        duration_days: int, 
        context: UserContext
    ) -> Tuple[bool, Optional[str]]:
        """
        Valida missão de onboarding.
        
        Args:
            min_transactions: Número mínimo de transações requerido.
            duration_days: Duração da missão em dias.
            context: Contexto do usuário.
            
        Returns:
            Tuple com (é_válida, mensagem_erro).
        """
        if context.transaction_count > 100:
            return False, "Usuário já passou da fase de onboarding"
        
        min_per_day = min_transactions / duration_days
        if min_per_day > 5:
            return False, f"Meta muito agressiva: {min_per_day:.1f} transações/dia"
        
        return True, None
    
    @staticmethod
    def validate_tps_improvement(
        target_tps: float, 
        duration_days: int, 
        context: UserContext
    ) -> Tuple[bool, Optional[str]]:
        """
        Valida missão de melhoria de TPS.
        
        Args:
            target_tps: Meta de TPS a alcançar.
            duration_days: Duração da missão em dias.
            context: Contexto do usuário.
            
        Returns:
            Tuple com (é_válida, mensagem_erro).
        """
        if context.tps >= target_tps:
            return False, f"TPS atual ({context.tps:.1f}%) já atinge a meta ({target_tps}%)"
        
        improvement_needed = target_tps - context.tps
        weeks = duration_days / 7
        improvement_per_week = improvement_needed / weeks if weeks > 0 else improvement_needed
        
        if improvement_per_week > 5:
            return False, f"Melhoria de {improvement_per_week:.1f}%/semana é muito agressiva"
        
        if context.tps < 5 and target_tps > 30:
            return False, "Meta muito alta para quem está começando"
        
        return True, None
    
    @staticmethod
    def validate_rdr_reduction(
        target_rdr: float, 
        duration_days: int, 
        context: UserContext
    ) -> Tuple[bool, Optional[str]]:
        """
        Valida missão de redução de RDR.
        
        Args:
            target_rdr: Meta de RDR a alcançar (quanto menor, melhor).
            duration_days: Duração da missão em dias.
            context: Contexto do usuário.
            
        Returns:
            Tuple com (é_válida, mensagem_erro).
        """
        if context.rdr <= target_rdr:
            return False, f"RDR atual ({context.rdr:.1f}%) já atinge a meta ({target_rdr}%)"
        
        if target_rdr < 15:
            return False, f"RDR de {target_rdr}% é irrealisticamente baixo"
        
        reduction_needed = context.rdr - target_rdr
        if reduction_needed > 20 and duration_days < 30:
            return False, f"Redução de {reduction_needed:.1f}% requer mais tempo"
        
        return True, None
    
    @staticmethod
    def validate_ili_building(
        min_ili: float, 
        duration_days: int, 
        context: UserContext
    ) -> Tuple[bool, Optional[str]]:
        """
        Valida missão de construção de reserva (ILI).
        
        Args:
            min_ili: Meta de ILI em meses.
            duration_days: Duração da missão em dias.
            context: Contexto do usuário.
            
        Returns:
            Tuple com (é_válida, mensagem_erro).
        """
        if context.ili >= min_ili:
            return False, f"ILI atual ({context.ili:.1f}) já atinge a meta ({min_ili})"
        
        # Verificar tier ANTES de outras validações
        if context.tier == 'BEGINNER' and min_ili > 4:
            return False, "Meta muito alta para iniciantes"
        
        improvement_needed = min_ili - context.ili
        if improvement_needed > 3 and duration_days <= 30:
            return False, f"Construir {improvement_needed:.1f} meses de reserva requer mais tempo"
        
        return True, None
    
    @staticmethod
    def validate_category_reduction(
        target_reduction_percent: float, 
        duration_days: int, 
        context: UserContext
    ) -> Tuple[bool, Optional[str]]:
        """
        Valida missão de redução em categoria.
        
        Args:
            target_reduction_percent: Percentual de redução alvo.
            duration_days: Duração da missão em dias.
            context: Contexto do usuário.
            
        Returns:
            Tuple com (é_válida, mensagem_erro).
        """
        if target_reduction_percent > 50:
            return False, f"Redução de {target_reduction_percent}% é irrealista"
        
        if not context.top_expense_categories:
            return False, "Usuário não tem categorias de despesa identificadas"
        
        return True, None
    
    @staticmethod
    def validate_goal_achievement(
        goal_progress_target: float, 
        duration_days: int, 
        context: UserContext
    ) -> Tuple[bool, Optional[str]]:
        """
        Valida missão de progresso em meta.
        
        Args:
            goal_progress_target: Percentual de progresso alvo.
            duration_days: Duração da missão em dias.
            context: Contexto do usuário.
            
        Returns:
            Tuple com (é_válida, mensagem_erro).
        """
        if not context.has_active_goals:
            return False, "Usuário não tem metas financeiras ativas"
        
        if goal_progress_target >= 100 and duration_days < 14:
            return False, "Completar 100% da meta requer mais tempo"
        
        return True, None


def validate_mission_data(mission_data: Dict[str, Any]) -> Tuple[bool, List[str]]:
    """
    Valida missão gerada ANTES de salvar no banco.
    
    Verifica:
    - mission_type válido (6 tipos)
    - Campos obrigatórios por tipo
    - Ranges de valores
    - Campos básicos (title, description)
    
    Args:
        mission_data: Dicionário com dados da missão gerada.
        
    Returns:
        Tuple com (é_válida, lista_de_erros).
    """
    errors = []
    mission_type = mission_data.get('mission_type')
    
    # 1. Validar mission_type
    if mission_type not in MISSION_TYPES:
        errors.append(f"mission_type inválido: '{mission_type}'")
        return False, errors
    
    # 2. Validar campos obrigatórios por tipo
    type_config = REQUIRED_FIELDS_BY_TYPE.get(mission_type)
    if type_config:
        field_name = type_config['field']
        field_value = mission_data.get(field_name)
        
        if field_value is None:
            errors.append(f"{mission_type} requer campo '{field_name}'")
        else:
            try:
                value = type_config['type'](field_value)
                if not (type_config['min'] <= value <= type_config['max']):
                    errors.append(
                        f"{field_name} deve estar entre {type_config['min']} e {type_config['max']}, "
                        f"recebeu: {value}"
                    )
            except (ValueError, TypeError):
                errors.append(f"{field_name} deve ser {type_config['type'].__name__}")
    
    # 3. Validar difficulty
    difficulty = mission_data.get('difficulty')
    if difficulty not in ['EASY', 'MEDIUM', 'HARD']:
        errors.append(f"difficulty inválida: '{difficulty}'")
    
    # 4. Validar duration_days
    duration = mission_data.get('duration_days')
    if not duration or duration < 7 or duration > 60:
        errors.append(f"duration_days deve estar entre 7 e 60, recebeu: {duration}")
    
    # 5. Validar XP por dificuldade
    xp = mission_data.get('xp_reward', mission_data.get('reward_points', 0))
    if difficulty and xp:
        ranges = MissionConfig.XP_RANGES
        if difficulty in ranges:
            min_xp, max_xp = ranges[difficulty]
            # Dar margem de tolerância de 20%
            if not (min_xp * 0.8 <= xp <= max_xp * 1.2):
                errors.append(f"XP para {difficulty} deve ser ~{min_xp}-{max_xp}, recebeu: {xp}")
    
    # 6. Validar campos básicos
    title = mission_data.get('title', '')
    if not title or len(title) > 150:
        errors.append("title é obrigatório e deve ter no máximo 150 caracteres")
    
    if not mission_data.get('description'):
        errors.append("description é obrigatório")
    
    return len(errors) == 0, errors


def check_mission_similarity(
    title: str, 
    description: str, 
    threshold_title: float = 0.85,
    threshold_desc: float = 0.80,
    check_inactive: bool = True
) -> Tuple[bool, Optional[str]]:
    """
    Verifica se já existe missão similar no banco (evita duplicação semântica).
    
    Args:
        title: Título da missão a verificar.
        description: Descrição da missão a verificar.
        threshold_title: Threshold de similaridade para títulos (0-1).
        threshold_desc: Threshold de similaridade para descrições (0-1).
        check_inactive: Se deve também verificar missões pendentes (inativas).
        
    Returns:
        Tuple com (é_duplicata, mensagem).
    """
    from .models import Mission
    
    # Verificar tanto ativas quanto pendentes para evitar duplicatas
    if check_inactive:
        existing = Mission.objects.all()
    else:
        existing = Mission.objects.filter(is_active=True)
    
    for mission in existing:
        title_normalized = title.lower().strip()
        existing_title_normalized = mission.title.lower().strip()
        
        title_similarity = SequenceMatcher(
            None, 
            title_normalized, 
            existing_title_normalized
        ).ratio()
        
        if title_similarity > threshold_title:
            return True, f"Título similar a: '{mission.title}' ({title_similarity:.0%})"
        
        desc_normalized = description.lower().strip()
        existing_desc_normalized = mission.description.lower().strip()
        
        desc_similarity = SequenceMatcher(
            None, 
            desc_normalized, 
            existing_desc_normalized
        ).ratio()
        
        if desc_similarity > threshold_desc:
            return True, f"Descrição similar a: '{mission.title}' ({desc_similarity:.0%})"
    
    return False, None


# =============================================================================
# GERADOR PRINCIPAL
# =============================================================================

class UnifiedMissionGenerator:
    """
    Gerador unificado de missões com suporte a IA.
    
    Estratégia:
    1. Tenta gerar via IA Gemini (mais criativo e personalizado)
    2. Fallback para templates se IA falhar
    3. Validação rigorosa antes de salvar
    """
    
    def __init__(self, context: Optional[UserContext] = None):
        """
        Inicializa o gerador.
        
        Args:
            context: Contexto do usuário. Se None, usa contexto padrão.
        """
        self.context = context or UserContext.default_for_tier('INTERMEDIATE')
        self.config = MissionConfig()
        self.validator = MissionViabilityValidator()
        self._used_titles: set = set()
        self._ai_available = self._check_ai_availability()
    
    def _check_ai_availability(self) -> bool:
        """
        Verifica se a IA (Gemini) está disponível.
        
        Returns:
            bool: True se Gemini está configurado e disponível.
        """
        try:
            from .ai_services import model
            return model is not None
        except Exception as e:
            logger.warning(f"IA não disponível: {e}")
            return False
    
    def generate_batch(
        self, 
        count: int = 10,
        distribution: Optional[Dict[str, int]] = None,
        use_ai: bool = True
    ) -> Dict[str, Any]:
        """
        Gera um lote de missões.
        
        Args:
            count: Número total de missões a gerar.
            distribution: Distribuição por tipo (opcional).
            use_ai: Se deve tentar usar IA (default: True).
        
        Returns:
            Dict com 'created', 'failed', 'summary' e 'source'.
        """
        if distribution is None:
            distribution = self._get_smart_distribution(count)
        
        created = []
        failed = []
        source = 'template'
        
        # Tentar IA primeiro se disponível e habilitada
        if use_ai and self._ai_available:
            try:
                ai_result = self._generate_via_ai(count, distribution)
                if ai_result['success']:
                    created = ai_result['missions']
                    source = 'gemini_ai'
                    logger.info(f"✅ {len(created)} missões geradas via IA Gemini")
                else:
                    logger.warning(f"IA falhou: {ai_result.get('error')}, usando templates")
            except Exception as e:
                logger.warning(f"Erro na geração via IA: {e}, usando templates")
        
        # Fallback para templates se IA não gerou missões suficientes
        if len(created) < count:
            remaining = count - len(created)
            logger.info(f"📋 Gerando {remaining} missões restantes via templates...")
            
            remaining_dist = self._adjust_distribution_for_remaining(
                distribution, 
                [m['mission_type'] for m in created],
                remaining
            )
            
            for mission_type, type_count in remaining_dist.items():
                for _ in range(type_count):
                    try:
                        mission_data = self._generate_from_template(mission_type)
                        if mission_data:
                            created.append(mission_data)
                            if source == 'gemini_ai':
                                source = 'hybrid'
                        else:
                            failed.append({
                                'tipo': mission_type,
                                'erro': 'Não foi possível gerar missão válida',
                            })
                    except Exception as e:
                        logger.error(f"Erro ao gerar missão {mission_type}: {e}")
                        failed.append({
                            'tipo': mission_type,
                            'erro': str(e),
                        })
        
        return {
            'created': created,
            'failed': failed,
            'source': source,
            'summary': {
                'total_created': len(created),
                'total_failed': len(failed),
                'generation_source': source,
                'distribution': {
                    t: len([m for m in created if m.get('mission_type') == t])
                    for t in MISSION_TYPES
                },
            },
        }
    
    def _generate_via_ai(
        self, 
        count: int, 
        distribution: Dict[str, int]
    ) -> Dict[str, Any]:
        """
        Gera missões usando IA Gemini.
        
        Args:
            count: Número de missões.
            distribution: Distribuição por tipo.
            
        Returns:
            Dict com 'success', 'missions' ou 'error'.
        """
        from .ai_services import model
        
        if not model:
            return {'success': False, 'error': 'Gemini não configurado'}
        
        # Construir texto de distribuição
        dist_lines = []
        for mission_type, type_count in distribution.items():
            if type_count > 0:
                dist_lines.append(f"- {type_count}x {mission_type}")
        distribution_text = '\n'.join(dist_lines)
        
        # Descrição do tier
        tier_descriptions = {
            'BEGINNER': 'Iniciante - níveis 1-5, aprendendo conceitos básicos',
            'INTERMEDIATE': 'Intermediário - níveis 6-15, otimizando finanças',
            'ADVANCED': 'Avançado - níveis 16+, estratégias sofisticadas',
        }
        
        # Montar prompt
        prompt = GEMINI_MISSION_PROMPT.format(
            tier=self.context.tier,
            tier_description=tier_descriptions.get(self.context.tier, ''),
            level=self.context.level,
            tps=f"{self.context.tps:.1f}",
            rdr=f"{self.context.rdr:.1f}",
            ili=f"{self.context.ili:.1f}",
            transaction_count=self.context.transaction_count,
            categories=', '.join(self.context.top_expense_categories[:3]) or 'Não identificadas',
            distribution_text=distribution_text,
            count=count,
        )
        
        try:
            start_time = time.time()
            response = model.generate_content(prompt)
            elapsed = time.time() - start_time
            logger.info(f"Gemini respondeu em {elapsed:.2f}s")
            
            response_text = response.text.strip()
            
            # Limpar markdown se presente (suporta vários formatos)
            if response_text.startswith('```'):
                lines = response_text.split('\n')
                # Remover primeira linha (```json ou ```)
                lines = lines[1:]
                # Remover última linha se for ```
                if lines and lines[-1].strip() == '```':
                    lines = lines[:-1]
                response_text = '\n'.join(lines)
            
            # Tentar encontrar o JSON se houver texto antes/depois
            if not response_text.startswith('['):
                start_idx = response_text.find('[')
                end_idx = response_text.rfind(']')
                if start_idx != -1 and end_idx != -1:
                    response_text = response_text[start_idx:end_idx+1]
            
            missions_data = json.loads(response_text)
            
            if not isinstance(missions_data, list):
                return {'success': False, 'error': 'Resposta não é uma lista'}
            
            # Validar e filtrar missões
            valid_missions = []
            for i, mission_data in enumerate(missions_data):
                # Adicionar campos padrão
                mission_data['is_active'] = False
                mission_data['is_system_generated'] = True
                mission_data['generation_context'] = {
                    'source': 'gemini_ai',
                    'tier': self.context.tier,
                    'context_tps': self.context.tps,
                    'context_rdr': self.context.rdr,
                    'context_ili': self.context.ili,
                }
                
                # Normalizar campo de XP
                if 'xp_reward' in mission_data and 'reward_points' not in mission_data:
                    mission_data['reward_points'] = mission_data.pop('xp_reward')
                
                # Validar estrutura
                is_valid, errors = validate_mission_data(mission_data)
                if not is_valid:
                    logger.warning(f"Missão {i+1} inválida: {errors}")
                    continue
                
                # Validar viabilidade
                is_viable, viab_error = self._validate_viability_for_data(mission_data)
                if not is_viable:
                    logger.warning(f"Missão {i+1} inviável: {viab_error}")
                    continue
                
                # Verificar duplicata
                is_dup, dup_msg = check_mission_similarity(
                    mission_data['title'], 
                    mission_data['description']
                )
                if is_dup:
                    logger.debug(f"Missão {i+1} é duplicata: {dup_msg}")
                    continue
                
                # Verificar título já usado neste batch
                if mission_data['title'] in self._used_titles:
                    logger.debug(f"Título já usado neste batch: {mission_data['title']}")
                    continue
                
                self._used_titles.add(mission_data['title'])
                valid_missions.append(mission_data)
            
            if not valid_missions:
                return {'success': False, 'error': 'Nenhuma missão válida gerada pela IA'}
            
            return {'success': True, 'missions': valid_missions}
            
        except json.JSONDecodeError as e:
            logger.error(f"Erro ao parsear JSON da IA: {e}")
            return {'success': False, 'error': f'JSON inválido: {e}'}
        except Exception as e:
            logger.error(f"Erro na chamada à IA: {e}")
            return {'success': False, 'error': str(e)}
    
    def _validate_viability_for_data(self, mission_data: Dict) -> Tuple[bool, Optional[str]]:
        """
        Valida viabilidade de uma missão baseada nos dados.
        
        Args:
            mission_data: Dados da missão.
            
        Returns:
            Tuple com (é_viável, mensagem_erro).
        """
        mission_type = mission_data.get('mission_type')
        duration = mission_data.get('duration_days', 14)
        
        if mission_type == 'ONBOARDING':
            min_trans = mission_data.get('min_transactions')
            if min_trans:
                return self.validator.validate_onboarding(int(min_trans), duration, self.context)
        
        elif mission_type == 'TPS_IMPROVEMENT':
            target = mission_data.get('target_tps')
            if target:
                return self.validator.validate_tps_improvement(float(target), duration, self.context)
        
        elif mission_type == 'RDR_REDUCTION':
            target = mission_data.get('target_rdr')
            if target:
                return self.validator.validate_rdr_reduction(float(target), duration, self.context)
        
        elif mission_type == 'ILI_BUILDING':
            target = mission_data.get('min_ili')
            if target:
                return self.validator.validate_ili_building(float(target), duration, self.context)
        
        elif mission_type == 'CATEGORY_REDUCTION':
            target = mission_data.get('target_reduction_percent')
            if target:
                return self.validator.validate_category_reduction(float(target), duration, self.context)
        
        elif mission_type == 'GOAL_ACHIEVEMENT':
            target = mission_data.get('goal_progress_target')
            if target:
                return self.validator.validate_goal_achievement(float(target), duration, self.context)
        
        return True, None
    
    def _generate_from_template(self, mission_type: str) -> Optional[Dict[str, Any]]:
        """
        Gera uma missão a partir de templates (fallback).
        
        Args:
            mission_type: Tipo da missão.
            
        Returns:
            Dict com dados da missão ou None.
        """
        templates = MISSION_TEMPLATES.get(mission_type, [])
        if not templates:
            logger.warning(f"Sem templates para tipo: {mission_type}")
            return None
        
        random.shuffle(templates)
        
        for template in templates:
            mission_data = self._instantiate_template(mission_type, template)
            if mission_data:
                return mission_data
        
        return None
    
    def _instantiate_template(
        self, 
        mission_type: str, 
        template: Dict
    ) -> Optional[Dict[str, Any]]:
        """
        Instancia um template com valores concretos.
        
        Args:
            mission_type: Tipo da missão.
            template: Template a instanciar.
            
        Returns:
            Dict com dados da missão ou None.
        """
        difficulty = self._select_difficulty(template.get('difficulty_range', ['MEDIUM']))
        duration = self._calculate_duration(difficulty)
        target_value = self._calculate_target_value(mission_type, difficulty)
        
        if target_value is None:
            return None
        
        type_config = REQUIRED_FIELDS_BY_TYPE.get(mission_type)
        field_name = type_config['field'] if type_config else None
        
        is_valid, error_msg = self._validate_viability_for_field(
            mission_type, field_name, target_value, duration
        )
        
        if not is_valid:
            logger.debug(f"Missão inviável ({mission_type}): {error_msg}")
            return None
        
        format_value = int(target_value) if target_value == int(target_value) else round(target_value, 1)
        title = template['title_template'].format(count=format_value, target=format_value)
        description = template['description_template'].format(count=format_value, target=format_value)
        
        if title in self._used_titles:
            return None
        self._used_titles.add(title)
        
        xp_reward = self._calculate_xp(difficulty)
        
        mission_data = {
            'title': title,
            'description': description,
            'mission_type': mission_type,
            'difficulty': difficulty,
            'duration_days': duration,
            'reward_points': xp_reward,
            'is_active': False,
            'is_system_generated': True,
            'generation_context': {
                'source': 'template',
                'tier': self.context.tier,
                'context_tps': self.context.tps,
                'context_rdr': self.context.rdr,
                'context_ili': self.context.ili,
            },
        }
        
        if field_name:
            mission_data[field_name] = target_value
        
        return mission_data
    
    def _validate_viability_for_field(
        self, 
        mission_type: str, 
        field_name: str, 
        target_value: float, 
        duration: int
    ) -> Tuple[bool, Optional[str]]:
        """Valida viabilidade por campo específico."""
        if mission_type == 'ONBOARDING':
            return self.validator.validate_onboarding(int(target_value), duration, self.context)
        elif mission_type == 'TPS_IMPROVEMENT':
            return self.validator.validate_tps_improvement(float(target_value), duration, self.context)
        elif mission_type == 'RDR_REDUCTION':
            return self.validator.validate_rdr_reduction(float(target_value), duration, self.context)
        elif mission_type == 'ILI_BUILDING':
            return self.validator.validate_ili_building(float(target_value), duration, self.context)
        elif mission_type == 'CATEGORY_REDUCTION':
            return self.validator.validate_category_reduction(float(target_value), duration, self.context)
        elif mission_type == 'GOAL_ACHIEVEMENT':
            return self.validator.validate_goal_achievement(float(target_value), duration, self.context)
        return True, None
    
    def _get_smart_distribution(self, count: int) -> Dict[str, int]:
        """
        Determina distribuição inteligente baseada no contexto.
        
        Args:
            count: Número total de missões.
            
        Returns:
            Dict com distribuição por tipo.
        """
        tier = self.context.tier
        
        if tier == 'BEGINNER':
            if self.context.transaction_count < 30:
                weights = {
                    'ONBOARDING': 4,
                    'TPS_IMPROVEMENT': 2,
                    'RDR_REDUCTION': 1,
                    'ILI_BUILDING': 1,
                    'CATEGORY_REDUCTION': 1,
                    'GOAL_ACHIEVEMENT': 1 if self.context.has_active_goals else 0,
                }
            else:
                weights = {
                    'ONBOARDING': 2,
                    'TPS_IMPROVEMENT': 3,
                    'RDR_REDUCTION': 2,
                    'ILI_BUILDING': 2,
                    'CATEGORY_REDUCTION': 1,
                    'GOAL_ACHIEVEMENT': 1 if self.context.has_active_goals else 0,
                }
        elif tier == 'INTERMEDIATE':
            weights = {
                'ONBOARDING': 1,
                'TPS_IMPROVEMENT': 3,
                'RDR_REDUCTION': 2,
                'ILI_BUILDING': 2,
                'CATEGORY_REDUCTION': 2,
                'GOAL_ACHIEVEMENT': 2 if self.context.has_active_goals else 0,
            }
        else:  # ADVANCED
            weights = {
                'ONBOARDING': 0,
                'TPS_IMPROVEMENT': 2,
                'RDR_REDUCTION': 2,
                'ILI_BUILDING': 3,
                'CATEGORY_REDUCTION': 2,
                'GOAL_ACHIEVEMENT': 3 if self.context.has_active_goals else 0,
            }
        
        # Ajustes contextuais
        if self.context.transaction_count > 200:
            weights['ONBOARDING'] = 0
        
        total_weight = sum(weights.values())
        if total_weight == 0:
            active_types = [t for t in MISSION_TYPES if t != 'GOAL_ACHIEVEMENT']
            return {t: count // len(active_types) for t in active_types}
        
        distribution = {}
        remaining = count
        
        for mission_type, weight in weights.items():
            if weight > 0:
                type_count = max(1, int((weight / total_weight) * count))
                type_count = min(type_count, remaining)
                distribution[mission_type] = type_count
                remaining -= type_count
        
        # Distribuir resto
        if remaining > 0:
            for mission_type in distribution:
                if remaining > 0:
                    distribution[mission_type] += 1
                    remaining -= 1
        
        return distribution
    
    def _adjust_distribution_for_remaining(
        self, 
        original: Dict[str, int], 
        already_created: List[str],
        remaining: int
    ) -> Dict[str, int]:
        """Ajusta distribuição para missões restantes."""
        from collections import Counter
        created_counts = Counter(already_created)
        
        adjusted = {}
        for mission_type, target in original.items():
            still_needed = max(0, target - created_counts.get(mission_type, 0))
            if still_needed > 0:
                adjusted[mission_type] = min(still_needed, remaining)
                remaining -= adjusted[mission_type]
        
        return adjusted
    
    def _select_difficulty(self, allowed: List[str]) -> str:
        """Seleciona dificuldade baseada no contexto."""
        tier = self.context.tier
        
        if tier == 'BEGINNER':
            probs = {'EASY': 0.6, 'MEDIUM': 0.35, 'HARD': 0.05}
        elif tier == 'INTERMEDIATE':
            probs = {'EASY': 0.25, 'MEDIUM': 0.5, 'HARD': 0.25}
        else:
            probs = {'EASY': 0.1, 'MEDIUM': 0.4, 'HARD': 0.5}
        
        filtered_probs = {d: p for d, p in probs.items() if d in allowed}
        total = sum(filtered_probs.values())
        if total == 0:
            return allowed[0]
        
        r = random.random() * total
        cumulative = 0
        for difficulty, prob in filtered_probs.items():
            cumulative += prob
            if r <= cumulative:
                return difficulty
        
        return allowed[0]
    
    def _calculate_duration(self, difficulty: str) -> int:
        """Calcula duração baseada na dificuldade."""
        min_d, max_d = self.config.DURATION_RANGES[difficulty]
        return random.randint(min_d, max_d)
    
    def _calculate_target_value(self, mission_type: str, difficulty: str) -> Optional[float]:
        """Calcula valor alvo apropriado para o tipo e contexto."""
        if mission_type == 'TPS_IMPROVEMENT':
            current = self.context.tps
            if difficulty == 'EASY':
                target = current + random.randint(3, 8)
            elif difficulty == 'MEDIUM':
                target = current + random.randint(8, 15)
            else:
                target = current + random.randint(15, 25)
            return max(5, min(50, round(target, 0)))
        
        elif mission_type == 'RDR_REDUCTION':
            current = self.context.rdr
            if difficulty == 'EASY':
                target = current - random.randint(3, 8)
            elif difficulty == 'MEDIUM':
                target = current - random.randint(8, 15)
            else:
                target = current - random.randint(15, 25)
            return max(15, min(70, round(target, 0)))
        
        elif mission_type == 'ILI_BUILDING':
            current = self.context.ili
            if difficulty == 'EASY':
                target = current + random.uniform(0.5, 1.5)
            elif difficulty == 'MEDIUM':
                target = current + random.uniform(1.5, 3)
            else:
                target = current + random.uniform(3, 5)
            return max(1, min(12, round(target, 1)))
        
        elif mission_type == 'ONBOARDING':
            if difficulty == 'EASY':
                return random.choice([5, 10])
            elif difficulty == 'MEDIUM':
                return random.choice([15, 20])
            else:
                return random.choice([25, 30])
        
        elif mission_type == 'CATEGORY_REDUCTION':
            if difficulty == 'EASY':
                return random.choice([10, 12, 15])
            elif difficulty == 'MEDIUM':
                return random.choice([15, 20, 25])
            else:
                return random.choice([25, 30, 35])
        
        elif mission_type == 'GOAL_ACHIEVEMENT':
            if difficulty == 'EASY':
                return random.choice([25, 30, 40])
            elif difficulty == 'MEDIUM':
                return random.choice([50, 60, 75])
            else:
                return random.choice([75, 90, 100])
        
        return None
    
    def _calculate_xp(self, difficulty: str) -> int:
        """Calcula XP de recompensa."""
        min_xp, max_xp = self.config.XP_RANGES[difficulty]
        return random.randint(min_xp, max_xp)


# =============================================================================
# FUNÇÃO PRINCIPAL DE GERAÇÃO
# =============================================================================

def generate_missions(
    quantidade: int = 10,
    tier: Optional[str] = None,
    user=None,
    use_ai: bool = True,
) -> Dict[str, Any]:
    """
    Função principal para geração de missões.
    
    Estratégia híbrida:
    1. Tenta gerar via IA Gemini (mais criativo)
    2. Fallback para templates se necessário
    3. Validação rigorosa antes de salvar
    
    Args:
        quantidade: Número de missões a gerar (5, 10 ou 20).
        tier: Tier específica ('BEGINNER', 'INTERMEDIATE', 'ADVANCED').
              Se None e user fornecido, calcula do usuário.
              Se ambos None, gera para todas as tiers.
        user: Usuário Django para contexto personalizado.
        use_ai: Se deve tentar usar IA (default: True).
    
    Returns:
        Dict com 'created', 'failed', 'summary' e 'source'.
    """
    from .models import Mission
    
    results = {
        'created': [],
        'failed': [],
        'source': 'template',
        'summary': {
            'total_created': 0,
            'total_failed': 0,
        },
    }
    
    if user:
        # Contexto personalizado para um usuário específico
        context = UserContext.from_user(user)
        generator = UnifiedMissionGenerator(context)
        batch_result = generator.generate_batch(quantidade, use_ai=use_ai)
        
        results['source'] = batch_result.get('source', 'template')
        
        for mission_data in batch_result['created']:
            try:
                mission = Mission.objects.create(**mission_data)
                results['created'].append({
                    'id': mission.id,
                    'titulo': mission.title,
                    'tipo': mission.mission_type,
                    'dificuldade': mission.difficulty,
                })
            except Exception as e:
                logger.error(f"Erro ao salvar missão: {e}")
                results['failed'].append({
                    'titulo': mission_data.get('title', 'Desconhecido'),
                    'erros': [str(e)],
                })
        
        results['failed'].extend(batch_result['failed'])
    
    elif tier:
        # Gerar para uma tier específica
        context = UserContext.default_for_tier(tier)
        generator = UnifiedMissionGenerator(context)
        batch_result = generator.generate_batch(quantidade, use_ai=use_ai)
        
        results['source'] = batch_result.get('source', 'template')
        
        for mission_data in batch_result['created']:
            try:
                mission = Mission.objects.create(**mission_data)
                results['created'].append({
                    'id': mission.id,
                    'titulo': mission.title,
                    'tipo': mission.mission_type,
                    'dificuldade': mission.difficulty,
                })
            except Exception as e:
                logger.error(f"Erro ao salvar missão: {e}")
                results['failed'].append({
                    'titulo': mission_data.get('title', 'Desconhecido'),
                    'erros': [str(e)],
                })
        
        results['failed'].extend(batch_result['failed'])
    
    else:
        # Gerar para todas as tiers
        per_tier = quantidade // 3
        extra = quantidade % 3
        
        tier_counts = {
            'BEGINNER': per_tier + (1 if extra > 0 else 0),
            'INTERMEDIATE': per_tier + (1 if extra > 1 else 0),
            'ADVANCED': per_tier,
        }
        
        all_sources = []
        
        for t, count in tier_counts.items():
            if count <= 0:
                continue
            
            context = UserContext.default_for_tier(t)
            generator = UnifiedMissionGenerator(context)
            batch_result = generator.generate_batch(count, use_ai=use_ai)
            
            all_sources.append(batch_result.get('source', 'template'))
            
            for mission_data in batch_result['created']:
                try:
                    mission = Mission.objects.create(**mission_data)
                    results['created'].append({
                        'id': mission.id,
                        'titulo': mission.title,
                        'tipo': mission.mission_type,
                        'dificuldade': mission.difficulty,
                        'tier': t,
                    })
                except Exception as e:
                    logger.error(f"Erro ao salvar missão: {e}")
                    results['failed'].append({
                        'titulo': mission_data.get('title', 'Desconhecido'),
                        'tier': t,
                        'erros': [str(e)],
                    })
            
            results['failed'].extend([
                {**f, 'tier': t} for f in batch_result['failed']
            ])
        
        # Determinar fonte geral
        if 'gemini_ai' in all_sources:
            results['source'] = 'gemini_ai' if all(s == 'gemini_ai' for s in all_sources) else 'hybrid'
        else:
            results['source'] = 'template'
    
    # Atualizar summary
    results['summary']['total_created'] = len(results['created'])
    results['summary']['total_failed'] = len(results['failed'])
    results['summary']['generation_source'] = results['source']
    
    logger.info(
        f"Geração concluída via {results['source']}: "
        f"{results['summary']['total_created']} criadas, "
        f"{results['summary']['total_failed']} falhas"
    )
    
    return results
