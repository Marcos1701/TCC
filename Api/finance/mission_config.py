"""
Configuração Unificada do Sistema de Missões
=============================================

Este arquivo centraliza TODAS as definições de tipos de missão, validadores, 
e regras de geração. É a ÚNICA fonte de verdade para o sistema de missões.

Arquivos que dependem desta configuração:
- mission_generator.py (geração automática)
- mission_type_schemas.py (formulário admin)
- mission_templates.py (templates de texto)
- mission_types/factory.py (seleção de validadores)
- ai_services.py (prompts para IA)
"""

from dataclasses import dataclass, field
from decimal import Decimal
from typing import Any, Callable, Dict, List, Optional, Tuple, Type

# Importação dos validadores
from .mission_types.base import BaseMissionValidator
from .mission_types.onboarding import OnboardingMissionValidator
from .mission_types.indicators import (
    TPSImprovementMissionValidator,
    RDRReductionMissionValidator,
    ILIBuildingMissionValidator,
)
from .mission_types.categories import CategoryReductionValidator


# =============================================================================
# DEFINIÇÕES DE DIFICULDADE
# =============================================================================

@dataclass
class DifficultyConfig:
    """Configuração para cada nível de dificuldade."""
    value_range: Tuple[float, float]  # Range de valores para o campo principal
    duration_range: Tuple[int, int]   # Range de duração em dias
    xp_range: Tuple[int, int]         # Range de XP de recompensa
    color: str = "#4CAF50"


DIFFICULTY_CONFIGS = {
    'EASY': DifficultyConfig(
        value_range=(5, 15),
        duration_range=(7, 14),
        xp_range=(30, 80),
        color="#4CAF50"
    ),
    'MEDIUM': DifficultyConfig(
        value_range=(15, 30),
        duration_range=(14, 21),
        xp_range=(80, 180),
        color="#FF9800"
    ),
    'HARD': DifficultyConfig(
        value_range=(30, 50),
        duration_range=(21, 30),
        xp_range=(180, 350),
        color="#F44336"
    ),
}


# =============================================================================
# DEFINIÇÕES DE CAMPOS
# =============================================================================

@dataclass
class FieldConfig:
    """Configuração de um campo de missão."""
    key: str                          # Nome do campo no banco
    label: str                        # Label para exibição
    field_type: str                   # integer, decimal, percentage, category_select
    description: str = ""
    min_value: Optional[float] = None
    max_value: Optional[float] = None
    default_value: Optional[Any] = None
    unit: str = ""
    icon: str = ""
    hint: str = ""
    required: bool = True
    
    # Ranges específicos por dificuldade (sobrescrevem DIFFICULTY_CONFIGS)
    difficulty_ranges: Dict[str, Tuple[float, float]] = field(default_factory=dict)


# =============================================================================
# DEFINIÇÕES DE TIPOS DE MISSÃO
# =============================================================================

@dataclass
class MissionTypeConfig:
    """Configuração completa de um tipo de missão."""
    
    # Identificação
    key: str                          # ONBOARDING, TPS_IMPROVEMENT, etc.
    name: str                         # Nome para exibição
    description: str                  # Descrição do tipo
    icon: str
    color: str
    
    # Campo principal obrigatório
    required_field: FieldConfig
    
    # Campo opcional adicional
    optional_fields: List[FieldConfig] = field(default_factory=list)
    
    # Validador associado
    validator_class: Type[BaseMissionValidator] = None
    
    # Templates de título e descrição
    title_templates: List[str] = field(default_factory=list)
    description_templates: List[str] = field(default_factory=list)
    
    # Dificuldade recomendada e duração padrão
    recommended_difficulty: str = "MEDIUM"
    recommended_duration: int = 30
    
    # Dicas para criação manual
    tips: List[str] = field(default_factory=list)
    
    # Função de verificação de viabilidade
    # Recebe (context: UserContext, mission_data: Dict) -> Tuple[bool, List[str]]
    viability_check: Optional[Callable] = None
    
    # Prioridade para distribuição automática por tier
    tier_weights: Dict[str, int] = field(default_factory=dict)


# =============================================================================
# CONFIGURAÇÕES DOS TIPOS DE MISSÃO
# =============================================================================

MISSION_TYPES: Dict[str, MissionTypeConfig] = {
    
    'ONBOARDING': MissionTypeConfig(
        key='ONBOARDING',
        name='Primeiros Passos',
        description='Missões para familiarizar o usuário com o registro de transações.',
        icon='📝',
        color='#4CAF50',
        
        required_field=FieldConfig(
            key='min_transactions',
            label='Transações Mínimas',
            field_type='integer',
            description='Número mínimo de transações que o usuário deve registrar',
            min_value=5,
            max_value=50,
            default_value=10,
            icon='📊',
            hint='Recomendado: 5-15 para iniciantes',
            difficulty_ranges={
                'EASY': (5, 15),
                'MEDIUM': (15, 30),
                'HARD': (30, 50),
            }
        ),
        
        validator_class=OnboardingMissionValidator,
        
        title_templates=[
            'Registre suas primeiras {min_transactions} transações',
            'Mapeando seu fluxo: {min_transactions} registros',
            'Construindo o hábito: {min_transactions} transações',
        ],
        description_templates=[
            'Comece sua jornada financeira registrando {min_transactions} transações.',
            'Registre {min_transactions} transações para visualizar seu padrão de gastos.',
        ],
        
        recommended_difficulty='EASY',
        recommended_duration=7,
        
        tips=[
            'Ideal para usuários que estão começando',
            'Metas de 5-15 transações são mais alcançáveis',
            'Duração curta (7 dias) funciona melhor',
        ],
        
        tier_weights={
            'BEGINNER': 4,
            'INTERMEDIATE': 1,
            'ADVANCED': 0,
        },
    ),
    
    'TPS_IMPROVEMENT': MissionTypeConfig(
        key='TPS_IMPROVEMENT',
        name='Aumentar Poupança (TPS)',
        description='Missões para incentivar o aumento da Taxa de Poupança Pessoal.',
        icon='💰',
        color='#2196F3',
        
        required_field=FieldConfig(
            key='target_tps',
            label='Meta TPS (%)',
            field_type='percentage',
            description='Taxa de Poupança Pessoal mínima a ser atingida',
            min_value=1,
            max_value=80,
            default_value=15,
            unit='%',
            icon='📈',
            hint='Média recomendada: 10-30%',
            difficulty_ranges={
                'EASY': (5, 15),
                'MEDIUM': (15, 25),
                'HARD': (25, 40),
            }
        ),
        
        validator_class=TPSImprovementMissionValidator,
        
        title_templates=[
            'Alcance {target_tps}% de economia',
            'Desafio de poupança: {target_tps}%',
            'Meta ambiciosa: {target_tps}% de TPS',
        ],
        description_templates=[
            'Eleve sua Taxa de Poupança para {target_tps}%.',
            'Aumente sua TPS para {target_tps}% controlando gastos supérfluos.',
        ],
        
        recommended_difficulty='MEDIUM',
        recommended_duration=30,
        
        tips=[
            'TPS = (Receitas - Despesas) / Receitas × 100',
            'Metas entre 10-20% são mais realistas para iniciantes',
            'Considere a renda média do usuário ao definir metas',
        ],
        
        tier_weights={
            'BEGINNER': 2,
            'INTERMEDIATE': 3,
            'ADVANCED': 2,
        },
    ),
    
    'RDR_REDUCTION': MissionTypeConfig(
        key='RDR_REDUCTION',
        name='Reduzir Gastos Recorrentes (RDR)',
        description='Missões para diminuir a Razão Despesas/Renda focando em despesas fixas.',
        icon='📉',
        color='#FF5722',
        
        required_field=FieldConfig(
            key='target_rdr',
            label='Meta RDR Máximo (%)',
            field_type='percentage',
            description='Razão Despesas/Renda máxima permitida',
            min_value=5,
            max_value=95,
            default_value=40,
            unit='%',
            icon='📊',
            hint='Ideal: manter abaixo de 30-40%',
            difficulty_ranges={
                'EASY': (50, 70),   # Mais fácil se o alvo for mais alto
                'MEDIUM': (35, 50),
                'HARD': (20, 35),
            }
        ),
        
        validator_class=RDRReductionMissionValidator,
        
        title_templates=[
            'Controle gastos fixos: máximo {target_rdr}%',
            'Liberte sua renda: RDR {target_rdr}%',
            'Reduza custos fixos para {target_rdr}%',
        ],
        description_templates=[
            'Reduza sua Razão Despesas/Renda para {target_rdr}%.',
            'Mantenha despesas fixas abaixo de {target_rdr}% da renda.',
        ],
        
        recommended_difficulty='MEDIUM',
        recommended_duration=30,
        
        tips=[
            'RDR = Despesas Recorrentes / Receitas × 100',
            'Incentive revisão de assinaturas e custos fixos',
            'Metas graduais são mais efetivas',
        ],
        
        tier_weights={
            'BEGINNER': 1,
            'INTERMEDIATE': 2,
            'ADVANCED': 2,
        },
    ),
    
    'ILI_BUILDING': MissionTypeConfig(
        key='ILI_BUILDING',
        name='Construir Reserva (ILI)',
        description='Missões para aumentar o Índice de Liquidez Imediata (reserva de emergência).',
        icon='🛡️',
        color='#9C27B0',
        
        required_field=FieldConfig(
            key='min_ili',
            label='ILI Mínimo (meses)',
            field_type='decimal',
            description='Meses de despesas em reserva de emergência',
            min_value=0.5,
            max_value=24,
            default_value=3,
            unit='meses',
            icon='🏦',
            hint='Recomendado: 3-6 meses de despesas',
            difficulty_ranges={
                'EASY': (1, 3),
                'MEDIUM': (3, 6),
                'HARD': (6, 12),
            }
        ),
        
        validator_class=ILIBuildingMissionValidator,
        
        title_templates=[
            'Construa {min_ili} meses de reserva',
            'Primeiros passos: {min_ili} meses de segurança',
            'Rede de segurança: {min_ili} meses',
        ],
        description_templates=[
            'Acumule o equivalente a {min_ili} meses de despesas em reserva.',
            'Aumente sua reserva de emergência para {min_ili} meses.',
        ],
        
        recommended_difficulty='HARD',
        recommended_duration=30,
        
        tips=[
            'ILI = Reservas / Despesas Mensais Médias',
            'Especialistas recomendam 3-6 meses de reserva',
            'Missões de longo prazo funcionam melhor para este tipo',
        ],
        
        tier_weights={
            'BEGINNER': 1,
            'INTERMEDIATE': 2,
            'ADVANCED': 3,
        },
    ),
    
    'CATEGORY_REDUCTION': MissionTypeConfig(
        key='CATEGORY_REDUCTION',
        name='Reduzir Gastos em Categoria',
        description='Missões para controlar gastos em categorias específicas.',
        icon='📁',
        color='#795548',
        
        required_field=FieldConfig(
            key='target_reduction_percent',
            label='Redução Alvo (%)',
            field_type='percentage',
            description='Percentual de redução em relação ao período anterior',
            min_value=5,
            max_value=80,
            default_value=15,
            unit='%',
            icon='📉',
            hint='Reduções de 10-20% são mais alcançáveis',
            difficulty_ranges={
                'EASY': (5, 15),
                'MEDIUM': (15, 25),
                'HARD': (25, 40),
            }
        ),
        
        optional_fields=[
            FieldConfig(
                key='target_category',
                label='Categoria Específica',
                field_type='category_select',
                description='Categoria alvo para a redução',
                required=False,
                hint='Se não selecionada, usuário escolhe ao aceitar',
            ),
        ],
        
        validator_class=CategoryReductionValidator,
        
        title_templates=[
            'Reduza {target_reduction_percent}% em gastos',
            'Desafio de economia: {target_reduction_percent}%',
            'Controle inteligente: -{target_reduction_percent}%',
        ],
        description_templates=[
            'Reduza gastos em uma categoria específica em {target_reduction_percent}%.',
            'Corte {target_reduction_percent}% dos gastos em uma categoria.',
        ],
        
        recommended_difficulty='MEDIUM',
        recommended_duration=30,
        
        tips=[
            'Categorias de lazer/entretenimento são bons alvos',
            'Reduções graduais têm maior taxa de sucesso',
            'Combine com dicas específicas da categoria',
        ],
        
        tier_weights={
            'BEGINNER': 1,
            'INTERMEDIATE': 2,
            'ADVANCED': 2,
        },
    ),
}


# =============================================================================
# FUNÇÕES DE UTILIDADE
# =============================================================================

def get_mission_type_config(mission_type: str) -> Optional[MissionTypeConfig]:
    """Retorna a configuração completa de um tipo de missão."""
    return MISSION_TYPES.get(mission_type)


def get_all_mission_types() -> List[str]:
    """Retorna lista de todos os tipos de missão válidos."""
    return list(MISSION_TYPES.keys())


def get_validator_for_type(mission_type: str) -> Optional[Type[BaseMissionValidator]]:
    """Retorna a classe do validador para um tipo de missão."""
    config = get_mission_type_config(mission_type)
    if config:
        return config.validator_class
    return None


def get_required_field_key(mission_type: str) -> Optional[str]:
    """Retorna o nome do campo obrigatório para um tipo de missão."""
    config = get_mission_type_config(mission_type)
    if config:
        return config.required_field.key
    return None


def get_value_range_for_difficulty(
    mission_type: str, 
    difficulty: str
) -> Tuple[float, float]:
    """Retorna o range de valores adequado para tipo + dificuldade."""
    config = get_mission_type_config(mission_type)
    if not config:
        return (10, 50)
    
    # Primeiro tenta os ranges específicos do campo
    if config.required_field.difficulty_ranges:
        if difficulty in config.required_field.difficulty_ranges:
            return config.required_field.difficulty_ranges[difficulty]
    
    # Fallback para configs globais de dificuldade
    diff_config = DIFFICULTY_CONFIGS.get(difficulty)
    if diff_config:
        return diff_config.value_range
    
    return (10, 50)


def generate_title_from_template(
    mission_type: str, 
    template_values: Dict[str, Any]
) -> str:
    """Gera um título usando templates do tipo de missão."""
    import random
    
    config = get_mission_type_config(mission_type)
    if not config or not config.title_templates:
        return f"Missão {mission_type}"
    
    template = random.choice(config.title_templates)
    try:
        return template.format(**template_values)
    except KeyError:
        return template


def generate_description_from_template(
    mission_type: str, 
    template_values: Dict[str, Any]
) -> str:
    """Gera uma descrição usando templates do tipo de missão."""
    import random
    
    config = get_mission_type_config(mission_type)
    if not config or not config.description_templates:
        return f"Complete esta missão de {mission_type}."
    
    template = random.choice(config.description_templates)
    try:
        return template.format(**template_values)
    except KeyError:
        return template


def get_tier_distribution(tier: str, total_count: int) -> Dict[str, int]:
    """Retorna distribuição de tipos de missão para um tier específico."""
    weights = {}
    total_weight = 0
    
    for mission_type, config in MISSION_TYPES.items():
        weight = config.tier_weights.get(tier, 1)
        if weight > 0:
            weights[mission_type] = weight
            total_weight += weight
    
    if total_weight == 0:
        # Fallback: distribuição igual
        return {k: total_count // len(MISSION_TYPES) for k in MISSION_TYPES}
    
    distribution = {}
    remaining = total_count
    
    for mission_type, weight in weights.items():
        count = max(1, int((weight / total_weight) * total_count))
        count = min(count, remaining)
        distribution[mission_type] = count
        remaining -= count
    
    # Distribui o restante
    if remaining > 0:
        for mission_type in distribution:
            if remaining > 0:
                distribution[mission_type] += 1
                remaining -= 1
    
    return distribution


def validate_mission_data(
    mission_type: str, 
    data: Dict[str, Any]
) -> Tuple[bool, List[str]]:
    """Valida dados de uma missão de acordo com sua configuração."""
    errors = []
    
    config = get_mission_type_config(mission_type)
    if not config:
        return False, [f"Tipo de missão desconhecido: {mission_type}"]
    
    # Verifica campo obrigatório
    required_field = config.required_field
    value = data.get(required_field.key)
    
    if value is None:
        errors.append(f"Campo obrigatório não preenchido: {required_field.label}")
    else:
        # Valida range
        if required_field.min_value is not None and value < required_field.min_value:
            errors.append(f"{required_field.label}: valor mínimo é {required_field.min_value}")
        
        if required_field.max_value is not None and value > required_field.max_value:
            errors.append(f"{required_field.label}: valor máximo é {required_field.max_value}")
    
    # Validações específicas por tipo
    if mission_type == 'CATEGORY_REDUCTION':
        # target_category é opcional, mas se não tiver, precisa ser definido depois
        pass
    
    return len(errors) == 0, errors


# =============================================================================
# EXPORTAÇÕES PARA COMPATIBILIDADE
# =============================================================================

# Mapeamento mission_type → validation_type para garantir validators corretos
# Mantido para compatibilidade com código legado
MISSION_TYPE_TO_VALIDATION = {
    'ONBOARDING': 'TRANSACTION_COUNT',
    'TPS_IMPROVEMENT': 'INDICATOR_THRESHOLD',
    'RDR_REDUCTION': 'INDICATOR_THRESHOLD',
    'ILI_BUILDING': 'INDICATOR_THRESHOLD',
    'CATEGORY_REDUCTION': 'CATEGORY_REDUCTION',
}

# Lista de tipos válidos (para validação)
VALID_MISSION_TYPES = list(MISSION_TYPES.keys())

# Campos obrigatórios por tipo (formato legado para compatibilidade)
REQUIRED_FIELDS_BY_TYPE = {
    mission_type: {
        'field': config.required_field.key,
        'min': config.required_field.min_value,
        'max': config.required_field.max_value,
        'type': float if config.required_field.field_type in ('decimal', 'percentage') else int,
    }
    for mission_type, config in MISSION_TYPES.items()
}
