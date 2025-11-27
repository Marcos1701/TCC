"""
Schemas de tipos de missão para edição dinâmica.

Este módulo define os templates de campos necessários para cada tipo de missão,
permitindo que o frontend exiba campos dinâmicos de acordo com o tipo selecionado.

Cada tipo de missão possui:
- Campos obrigatórios específicos
- Campos opcionais
- Validações e limites
- Dicas de preenchimento

Desenvolvido como parte do TCC - Sistema de Educação Financeira Gamificada.
"""

from typing import Any, Dict, List


# =============================================================================
# DEFINIÇÕES DE CAMPOS
# =============================================================================

class FieldType:
    """Tipos de campos disponíveis para formulários."""
    INTEGER = "integer"
    DECIMAL = "decimal"
    PERCENTAGE = "percentage"
    BOOLEAN = "boolean"
    SELECT = "select"
    CATEGORY_SELECT = "category_select"
    GOAL_SELECT = "goal_select"
    MULTI_SELECT = "multi_select"


# =============================================================================
# SCHEMAS DOS TIPOS DE MISSÃO
# =============================================================================

MISSION_TYPE_SCHEMAS: Dict[str, Dict[str, Any]] = {
    "ONBOARDING": {
        "name": "Primeiros Passos",
        "description": "Missões para familiarizar o usuário com o registro de transações e funcionalidades básicas do sistema.",
        "icon": "📝",
        "color": "#4CAF50",
        "validation_types": ["TRANSACTION_COUNT"],
        "default_validation_type": "TRANSACTION_COUNT",
        "required_fields": [
            {
                "key": "min_transactions",
                "label": "Transações Mínimas",
                "type": FieldType.INTEGER,
                "description": "Número mínimo de transações que o usuário deve registrar",
                "min": 1,
                "max": 100,
                "default": 10,
                "hint": "Recomendado: 5-20 para iniciantes",
                "icon": "📊",
            },
        ],
        "optional_fields": [
            {
                "key": "requires_consecutive_days",
                "label": "Requer dias consecutivos",
                "type": FieldType.BOOLEAN,
                "description": "Se o usuário precisa registrar em dias seguidos",
                "default": False,
            },
            {
                "key": "min_consecutive_days",
                "label": "Dias Consecutivos",
                "type": FieldType.INTEGER,
                "description": "Número de dias seguidos necessários",
                "min": 1,
                "max": 30,
                "default": 7,
                "depends_on": "requires_consecutive_days",
                "hint": "Só aplica se 'Requer dias consecutivos' estiver ativo",
            },
        ],
        "recommended_difficulty": "EASY",
        "recommended_duration": 7,
        "recommended_reward": {"EASY": 50, "MEDIUM": 75, "HARD": 100},
        "tips": [
            "Ideal para usuários que estão começando",
            "Mantenha metas alcançáveis para não desmotivar",
            "Duração curta (7 dias) funciona melhor",
        ],
    },
    
    "TPS_IMPROVEMENT": {
        "name": "Aumentar Poupança (TPS)",
        "description": "Missões para incentivar o aumento da Taxa de Poupança Pessoal do usuário.",
        "icon": "💰",
        "color": "#2196F3",
        "validation_types": ["INDICATOR_THRESHOLD", "INDICATOR_IMPROVEMENT"],
        "default_validation_type": "INDICATOR_THRESHOLD",
        "required_fields": [
            {
                "key": "target_tps",
                "label": "Meta TPS (%)",
                "type": FieldType.PERCENTAGE,
                "description": "Taxa de Poupança Pessoal mínima a ser atingida",
                "min": 1,
                "max": 80,
                "default": 15,
                "hint": "Média recomendada: 10-30%",
                "icon": "📈",
                "unit": "%",
            },
        ],
        "optional_fields": [
            {
                "key": "requires_consecutive_days",
                "label": "Manter por período",
                "type": FieldType.BOOLEAN,
                "description": "Se o TPS deve ser mantido por dias consecutivos",
                "default": False,
            },
            {
                "key": "min_consecutive_days",
                "label": "Dias de Manutenção",
                "type": FieldType.INTEGER,
                "description": "Quantos dias deve manter o TPS acima da meta",
                "min": 1,
                "max": 30,
                "default": 7,
                "depends_on": "requires_consecutive_days",
            },
            {
                "key": "savings_increase_amount",
                "label": "Aumento em R$",
                "type": FieldType.DECIMAL,
                "description": "Valor adicional em reais a poupar (alternativa ao %)",
                "min": 0,
                "max": 100000,
                "default": None,
                "hint": "Opcional: usar quando quiser valor fixo em vez de %",
                "unit": "R$",
            },
        ],
        "recommended_difficulty": "MEDIUM",
        "recommended_duration": 30,
        "recommended_reward": {"EASY": 100, "MEDIUM": 200, "HARD": 300},
        "tips": [
            "TPS = (Receitas - Despesas) / Receitas × 100",
            "Metas entre 10-20% são mais realistas para iniciantes",
            "Considere a renda média do usuário ao definir metas",
        ],
    },
    
    "RDR_REDUCTION": {
        "name": "Reduzir Gastos Recorrentes (RDR)",
        "description": "Missões para diminuir a Razão Dívida/Renda do usuário, focando em despesas fixas.",
        "icon": "📉",
        "color": "#FF9800",
        "validation_types": ["INDICATOR_THRESHOLD", "INDICATOR_IMPROVEMENT"],
        "default_validation_type": "INDICATOR_THRESHOLD",
        "required_fields": [
            {
                "key": "target_rdr",
                "label": "Meta RDR Máximo (%)",
                "type": FieldType.PERCENTAGE,
                "description": "Razão Dívida/Renda máxima permitida",
                "min": 5,
                "max": 95,
                "default": 40,
                "hint": "Ideal: manter abaixo de 30-40%",
                "icon": "📊",
                "unit": "%",
            },
        ],
        "optional_fields": [
            {
                "key": "requires_consecutive_days",
                "label": "Manter por período",
                "type": FieldType.BOOLEAN,
                "description": "Se o RDR deve ser mantido por dias consecutivos",
                "default": False,
            },
            {
                "key": "min_consecutive_days",
                "label": "Dias de Manutenção",
                "type": FieldType.INTEGER,
                "description": "Quantos dias deve manter o RDR abaixo da meta",
                "min": 1,
                "max": 30,
                "default": 14,
                "depends_on": "requires_consecutive_days",
            },
        ],
        "recommended_difficulty": "MEDIUM",
        "recommended_duration": 30,
        "recommended_reward": {"EASY": 100, "MEDIUM": 200, "HARD": 300},
        "tips": [
            "RDR = Despesas Recorrentes / Receitas × 100",
            "Incentive revisão de assinaturas e custos fixos",
            "Metas graduais são mais efetivas",
        ],
    },
    
    "ILI_BUILDING": {
        "name": "Construir Reserva (ILI)",
        "description": "Missões para aumentar o Índice de Liquidez Imediata, construindo reserva de emergência.",
        "icon": "🛡️",
        "color": "#9C27B0",
        "validation_types": ["INDICATOR_THRESHOLD"],
        "default_validation_type": "INDICATOR_THRESHOLD",
        "required_fields": [
            {
                "key": "min_ili",
                "label": "ILI Mínimo (meses)",
                "type": FieldType.DECIMAL,
                "description": "Meses de despesas em reserva de emergência",
                "min": 0.5,
                "max": 24,
                "default": 3,
                "hint": "Recomendado: 3-6 meses de despesas",
                "icon": "🏦",
                "unit": "meses",
            },
        ],
        "optional_fields": [
            {
                "key": "max_ili",
                "label": "ILI Máximo (meses)",
                "type": FieldType.DECIMAL,
                "description": "Limite superior para missões de faixa específica",
                "min": 0.5,
                "max": 24,
                "default": None,
                "hint": "Opcional: para criar missões de faixa (ex: 3-6 meses)",
                "unit": "meses",
            },
            {
                "key": "requires_consecutive_days",
                "label": "Manter por período",
                "type": FieldType.BOOLEAN,
                "description": "Se o ILI deve ser mantido por dias consecutivos",
                "default": False,
            },
            {
                "key": "min_consecutive_days",
                "label": "Dias de Manutenção",
                "type": FieldType.INTEGER,
                "description": "Quantos dias deve manter o ILI acima da meta",
                "min": 1,
                "max": 30,
                "default": 14,
                "depends_on": "requires_consecutive_days",
            },
        ],
        "recommended_difficulty": "HARD",
        "recommended_duration": 30,
        "recommended_reward": {"EASY": 150, "MEDIUM": 250, "HARD": 400},
        "tips": [
            "ILI = Reservas / Despesas Mensais Médias",
            "Especialistas recomendam 3-6 meses de reserva",
            "Missões de longo prazo funcionam melhor para este tipo",
        ],
    },
    
    "CATEGORY_REDUCTION": {
        "name": "Reduzir Gastos em Categoria",
        "description": "Missões para controlar gastos em categorias específicas problemáticas.",
        "icon": "📁",
        "color": "#F44336",
        "validation_types": ["CATEGORY_REDUCTION", "CATEGORY_LIMIT"],
        "default_validation_type": "CATEGORY_REDUCTION",
        "required_fields": [
            {
                "key": "target_reduction_percent",
                "label": "Redução Alvo (%)",
                "type": FieldType.PERCENTAGE,
                "description": "Percentual de redução em relação ao período anterior",
                "min": 5,
                "max": 80,
                "default": 15,
                "hint": "Reduções de 10-20% são mais alcançáveis",
                "icon": "📉",
                "unit": "%",
            },
        ],
        "optional_fields": [
            {
                "key": "target_category",
                "label": "Categoria Específica",
                "type": FieldType.CATEGORY_SELECT,
                "description": "Categoria alvo para a redução (deixe vazio para qualquer categoria)",
                "default": None,
                "hint": "Se não selecionada, usuário escolhe ao aceitar",
            },
            {
                "key": "category_spending_limit",
                "label": "Limite de Gastos (R$)",
                "type": FieldType.DECIMAL,
                "description": "Limite absoluto de gastos na categoria",
                "min": 0,
                "max": 100000,
                "default": None,
                "hint": "Alternativa: usar limite fixo em vez de %",
                "unit": "R$",
            },
            {
                "key": "target_categories",
                "label": "Múltiplas Categorias",
                "type": FieldType.MULTI_SELECT,
                "entity": "category",
                "description": "Várias categorias para monitorar juntas",
                "default": [],
            },
        ],
        "recommended_difficulty": "MEDIUM",
        "recommended_duration": 30,
        "recommended_reward": {"EASY": 75, "MEDIUM": 150, "HARD": 250},
        "tips": [
            "Categorias de lazer/entretenimento são bons alvos",
            "Reduções graduais têm maior taxa de sucesso",
            "Combine com dicas específicas da categoria",
        ],
    },
    
    "GOAL_ACHIEVEMENT": {
        "name": "Progredir em Meta",
        "description": "Missões para incentivar o progresso em metas financeiras definidas pelo usuário.",
        "icon": "🎯",
        "color": "#00BCD4",
        "validation_types": ["GOAL_PROGRESS", "GOAL_CONTRIBUTION"],
        "default_validation_type": "GOAL_PROGRESS",
        "required_fields": [
            {
                "key": "goal_progress_target",
                "label": "Progresso Alvo (%)",
                "type": FieldType.PERCENTAGE,
                "description": "Percentual de progresso a ser atingido na meta",
                "min": 5,
                "max": 100,
                "default": 50,
                "hint": "Defina marcos alcançáveis (25%, 50%, 75%, 100%)",
                "icon": "🏆",
                "unit": "%",
            },
        ],
        "optional_fields": [
            {
                "key": "target_goal",
                "label": "Meta Específica",
                "type": FieldType.GOAL_SELECT,
                "description": "Meta específica do usuário (deixe vazio para qualquer meta)",
                "default": None,
                "hint": "Se não selecionada, aplica-se a qualquer meta ativa",
            },
            {
                "key": "target_goals",
                "label": "Múltiplas Metas",
                "type": FieldType.MULTI_SELECT,
                "entity": "goal",
                "description": "Várias metas para monitorar juntas",
                "default": [],
            },
            {
                "key": "requires_consecutive_days",
                "label": "Progresso Contínuo",
                "type": FieldType.BOOLEAN,
                "description": "Se requer contribuições em dias consecutivos",
                "default": False,
            },
            {
                "key": "min_consecutive_days",
                "label": "Dias de Contribuição",
                "type": FieldType.INTEGER,
                "description": "Número de dias consecutivos com contribuição",
                "min": 1,
                "max": 30,
                "default": 7,
                "depends_on": "requires_consecutive_days",
            },
        ],
        "recommended_difficulty": "MEDIUM",
        "recommended_duration": 30,
        "recommended_reward": {"EASY": 100, "MEDIUM": 200, "HARD": 350},
        "tips": [
            "Vincule a metas existentes do usuário quando possível",
            "Marcos de 25% aumentam a motivação",
            "Combine com notificações de progresso",
        ],
    },
}


# =============================================================================
# CAMPOS COMUNS A TODOS OS TIPOS
# =============================================================================

COMMON_FIELDS: List[Dict[str, Any]] = [
    {
        "key": "title",
        "label": "Título",
        "type": "text",
        "description": "Título descritivo da missão",
        "required": True,
        "max_length": 150,
        "hint": "Seja claro e motivador",
    },
    {
        "key": "description",
        "label": "Descrição",
        "type": "textarea",
        "description": "Descrição detalhada do objetivo",
        "required": True,
        "max_length": 500,
        "hint": "Explique o que o usuário deve fazer e por que é importante",
    },
    {
        "key": "difficulty",
        "label": "Dificuldade",
        "type": FieldType.SELECT,
        "description": "Nível de dificuldade da missão",
        "required": True,
        "options": [
            {"value": "EASY", "label": "Fácil", "color": "#4CAF50"},
            {"value": "MEDIUM", "label": "Média", "color": "#FF9800"},
            {"value": "HARD", "label": "Difícil", "color": "#F44336"},
        ],
        "default": "MEDIUM",
    },
    {
        "key": "reward_points",
        "label": "Recompensa (XP)",
        "type": FieldType.INTEGER,
        "description": "Pontos de experiência concedidos ao completar",
        "required": True,
        "min": 10,
        "max": 1000,
        "default": 100,
        "hint": "Fácil: 50-100, Média: 100-200, Difícil: 200-400",
    },
    {
        "key": "duration_days",
        "label": "Duração (dias)",
        "type": FieldType.INTEGER,
        "description": "Prazo em dias para conclusão",
        "required": True,
        "min": 1,
        "max": 365,
        "default": 30,
        "hint": "7-14 dias para fáceis, 21-30 para médias/difíceis",
    },
    {
        "key": "priority",
        "label": "Prioridade",
        "type": FieldType.INTEGER,
        "description": "Ordem de prioridade (menor = mais prioritário)",
        "required": False,
        "min": 1,
        "max": 100,
        "default": 50,
        "hint": "1-10: Alta prioridade, 50: Normal, 90+: Sistema",
    },
    {
        "key": "is_active",
        "label": "Ativo",
        "type": FieldType.BOOLEAN,
        "description": "Se a missão está disponível aos usuários",
        "required": False,
        "default": True,
    },
]


# =============================================================================
# TIPOS DE VALIDAÇÃO
# =============================================================================

VALIDATION_TYPES: Dict[str, Dict[str, Any]] = {
    "TRANSACTION_COUNT": {
        "name": "Contagem de Transações",
        "description": "Valida pelo número de transações registradas",
        "icon": "📝",
        "applicable_to": ["ONBOARDING"],
    },
    "INDICATOR_THRESHOLD": {
        "name": "Limite de Indicador",
        "description": "Valida quando indicador atinge valor específico",
        "icon": "📊",
        "applicable_to": ["TPS_IMPROVEMENT", "RDR_REDUCTION", "ILI_BUILDING"],
    },
    "INDICATOR_IMPROVEMENT": {
        "name": "Melhoria de Indicador",
        "description": "Valida pela melhoria percentual do indicador",
        "icon": "📈",
        "applicable_to": ["TPS_IMPROVEMENT", "RDR_REDUCTION"],
    },
    "CATEGORY_REDUCTION": {
        "name": "Redução em Categoria",
        "description": "Valida pela redução de gastos em categoria",
        "icon": "📉",
        "applicable_to": ["CATEGORY_REDUCTION"],
    },
    "CATEGORY_LIMIT": {
        "name": "Limite de Categoria",
        "description": "Valida pelo limite de gastos em categoria",
        "icon": "🚫",
        "applicable_to": ["CATEGORY_REDUCTION"],
    },
    "GOAL_PROGRESS": {
        "name": "Progresso em Meta",
        "description": "Valida pelo percentual de progresso na meta",
        "icon": "🎯",
        "applicable_to": ["GOAL_ACHIEVEMENT"],
    },
    "GOAL_CONTRIBUTION": {
        "name": "Contribuição em Meta",
        "description": "Valida por contribuições regulares na meta",
        "icon": "💵",
        "applicable_to": ["GOAL_ACHIEVEMENT"],
    },
    "TEMPORAL": {
        "name": "Período de Tempo",
        "description": "Valida por manter critério por período específico",
        "icon": "⏰",
        "applicable_to": ["TPS_IMPROVEMENT", "RDR_REDUCTION", "ILI_BUILDING"],
    },
}


# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

def get_mission_type_schema(mission_type: str) -> Dict[str, Any]:
    """
    Retorna o schema completo para um tipo de missão específico.
    
    Args:
        mission_type: Código do tipo de missão (ex: 'ONBOARDING')
        
    Returns:
        Dicionário com schema completo incluindo campos comuns
    """
    if mission_type not in MISSION_TYPE_SCHEMAS:
        return {}
    
    schema = MISSION_TYPE_SCHEMAS[mission_type].copy()
    schema["common_fields"] = COMMON_FIELDS
    schema["type"] = mission_type
    
    return schema


def get_all_mission_type_schemas() -> Dict[str, Any]:
    """
    Retorna todos os schemas de tipos de missão.
    
    Returns:
        Dicionário com todos os schemas e informações auxiliares
    """
    return {
        "types": MISSION_TYPE_SCHEMAS,
        "common_fields": COMMON_FIELDS,
        "validation_types": VALIDATION_TYPES,
        "field_types": {
            "integer": "Número inteiro",
            "decimal": "Número decimal",
            "percentage": "Percentual (0-100)",
            "boolean": "Sim/Não",
            "select": "Seleção única",
            "category_select": "Selecionar categoria",
            "goal_select": "Selecionar meta",
            "multi_select": "Seleção múltipla",
        },
    }


def get_required_fields_for_type(mission_type: str) -> List[str]:
    """
    Retorna lista de campos obrigatórios para um tipo de missão.
    
    Args:
        mission_type: Código do tipo de missão
        
    Returns:
        Lista com as keys dos campos obrigatórios
    """
    schema = MISSION_TYPE_SCHEMAS.get(mission_type, {})
    required_fields = schema.get("required_fields", [])
    return [field["key"] for field in required_fields]


def validate_mission_data_for_type(mission_type: str, data: Dict) -> List[str]:
    """
    Valida se os dados da missão atendem aos requisitos do tipo.
    
    Args:
        mission_type: Código do tipo de missão
        data: Dados da missão a validar
        
    Returns:
        Lista de erros encontrados (vazia se válido)
    """
    errors = []
    schema = MISSION_TYPE_SCHEMAS.get(mission_type)
    
    if not schema:
        errors.append(f"Tipo de missão desconhecido: {mission_type}")
        return errors
    
    # Validar campos obrigatórios
    for field in schema.get("required_fields", []):
        key = field["key"]
        value = data.get(key)
        
        if value is None:
            errors.append(f"Campo obrigatório não preenchido: {field['label']}")
            continue
        
        # Converter para numérico se necessário
        field_type = field.get("type", "")
        if field_type in (FieldType.INTEGER, FieldType.DECIMAL, FieldType.PERCENTAGE):
            try:
                if field_type == FieldType.INTEGER:
                    value = int(value)
                else:
                    value = float(value)
            except (ValueError, TypeError):
                errors.append(f"{field['label']}: valor deve ser numérico")
                continue
        
        # Validar limites
        if "min" in field and value < field["min"]:
            errors.append(f"{field['label']}: valor mínimo é {field['min']}")
        
        if "max" in field and value > field["max"]:
            errors.append(f"{field['label']}: valor máximo é {field['max']}")
    
    # Validar campos opcionais com dependências
    for field in schema.get("optional_fields", []):
        key = field["key"]
        value = data.get(key)
        depends_on = field.get("depends_on")
        
        if depends_on and data.get(depends_on) and value is None:
            errors.append(f"{field['label']}: obrigatório quando '{depends_on}' está ativo")
    
    return errors


def get_default_values_for_type(mission_type: str, difficulty: str = "MEDIUM") -> Dict:
    """
    Retorna valores padrão recomendados para um tipo de missão.
    
    Args:
        mission_type: Código do tipo de missão
        difficulty: Nível de dificuldade
        
    Returns:
        Dicionário com valores padrão
    """
    schema = MISSION_TYPE_SCHEMAS.get(mission_type, {})
    
    defaults = {
        "mission_type": mission_type,
        "difficulty": difficulty,
        "duration_days": schema.get("recommended_duration", 30),
        "reward_points": schema.get("recommended_reward", {}).get(difficulty, 100),
        "is_active": True,
        "priority": 50,
    }
    
    # Adicionar defaults dos campos obrigatórios
    for field in schema.get("required_fields", []):
        if field.get("default") is not None:
            defaults[field["key"]] = field["default"]
    
    return defaults
