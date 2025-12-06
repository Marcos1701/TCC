
import json
import logging
import random
import time
from dataclasses import dataclass, field
from difflib import SequenceMatcher
from typing import Any, Dict, List, Optional, Tuple

from django.db.models import Avg

logger = logging.getLogger(__name__)



MISSION_TYPES = [
    'ONBOARDING',
    'TPS_IMPROVEMENT',
    'RDR_REDUCTION',
    'ILI_BUILDING',
    'CATEGORY_REDUCTION',
]

REQUIRED_FIELDS_BY_TYPE = {
    'ONBOARDING': {'field': 'min_transactions', 'min': 5, 'max': 50, 'type': int},
    'TPS_IMPROVEMENT': {'field': 'target_tps', 'min': 5, 'max': 50, 'type': float},
    'RDR_REDUCTION': {'field': 'target_rdr', 'min': 15, 'max': 70, 'type': float},
    'ILI_BUILDING': {'field': 'min_ili', 'min': 1, 'max': 12, 'type': float},
    'CATEGORY_REDUCTION': {'field': 'target_reduction_percent', 'min': 5, 'max': 40, 'type': float},
}


@dataclass
class MissionConfig:
    
    XP_RANGES = {
        'EASY': (30, 80),
        'MEDIUM': (80, 180),
        'HARD': (180, 350),
    }
    
    DURATION_RANGES = {
        'EASY': (7, 14),
        'MEDIUM': (14, 21),
        'HARD': (21, 30),
    }


@dataclass
class UserContext:
    
    tier: str = 'BEGINNER'
    level: int = 1
    tps: float = 0.0
    rdr: float = 50.0
    ili: float = 0.0
    transaction_count: int = 0
    has_categories: bool = False
    top_expense_categories: List[str] = field(default_factory=list)
    
    @classmethod
    def from_user(cls, user) -> 'UserContext':
        from .services.indicators import calculate_summary
        from .models import Transaction, UserProfile
        
        try:
            profile = UserProfile.objects.get(user=user)
            level = profile.level
        except UserProfile.DoesNotExist:
            level = 1
        
        if level <= 5:
            tier = 'BEGINNER'
        elif level <= 15:
            tier = 'INTERMEDIATE'
        else:
            tier = 'ADVANCED'
        
        try:
            indicators = calculate_summary(user)
            tps = float(indicators.get('tps', 0))
            rdr = float(indicators.get('rdr', 50))
            ili = float(indicators.get('ili', 0))
        except Exception as e:
            logger.warning(f"Erro ao calcular indicadores para {user.id}: {e}")
            tps, rdr, ili = 0.0, 50.0, 0.0
        
        transaction_count = Transaction.objects.filter(user=user).count()
        
        has_categories = Transaction.objects.filter(
            user=user, 
            type='EXPENSE',
            category__isnull=False
        ).exists()
        
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

- Tier: {tier} ({tier_description})
- Nível: {level}
- TPS atual: {tps}% (Taxa de Poupança)
- RDR atual: {rdr}% (Razão Despesas/Renda)  
- ILI atual: {ili} meses (Reserva de emergência)
- Transações registradas: {transaction_count}
- Categorias principais: {categories}


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

{distribution_text}


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

Gere {count} missões ÚNICAS e VARIADAS seguindo a distribuição acima.

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
    Valida se uma missão é alcançável dado o contexto do usuário.
    
    Evita a geração de missões impossíveis ou sem sentido.
        Valida missão de onboarding.
        
        Args:
            min_transactions: Número mínimo de transações requerido.
            duration_days: Duração da missão em dias.
            context: Contexto do usuário.
            
        Returns:
            Tuple com (é_válida, mensagem_erro).
        Valida missão de melhoria de TPS.
        
        Args:
            target_tps: Meta de TPS a alcançar.
            duration_days: Duração da missão em dias.
            context: Contexto do usuário.
            
        Returns:
            Tuple com (é_válida, mensagem_erro).
        Valida missão de redução de RDR.
        
        Args:
            target_rdr: Meta de RDR a alcançar (quanto menor, melhor).
            duration_days: Duração da missão em dias.
            context: Contexto do usuário.
            
        Returns:
            Tuple com (é_válida, mensagem_erro).
        Valida missão de construção de reserva (ILI).
        
        Args:
            min_ili: Meta de ILI em meses.
            duration_days: Duração da missão em dias.
            context: Contexto do usuário.
            
        Returns:
            Tuple com (é_válida, mensagem_erro).
        Valida missão de redução em categoria.
        
        Args:
            target_reduction_percent: Percentual de redução alvo.
            duration_days: Duração da missão em dias.
            context: Contexto do usuário.
            
        Returns:
            Tuple com (é_válida, mensagem_erro).
        Valida missão de progresso em meta.
        
        Args:
            goal_progress_target: Percentual de progresso alvo.
            duration_days: Duração da missão em dias.
            context: Contexto do usuário.
            
        Returns:
            Tuple com (é_válida, mensagem_erro).
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
    Verifica se já existe missão similar no banco (evita duplicação semântica).
    
    Args:
        title: Título da missão a verificar.
        description: Descrição da missão a verificar.
        threshold_title: Threshold de similaridade para títulos (0-1).
        threshold_desc: Threshold de similaridade para descrições (0-1).
        check_inactive: Se deve também verificar missões pendentes (inativas).
        
    Returns:
        Tuple com (é_duplicata, mensagem).
    Gerador unificado de missões com suporte a IA.
    
    Estratégia:
    1. Tenta gerar via IA Gemini (mais criativo e personalizado)
    2. Fallback para templates se IA falhar
    3. Validação rigorosa antes de salvar
        Inicializa o gerador.
        
        Args:
            context: Contexto do usuário. Se None, usa contexto padrão.
        Verifica se a IA (Gemini) está disponível.
        
        Returns:
            bool: True se Gemini está configurado e disponível.
        Gera um lote de missões.
        
        Args:
            count: Número total de missões a gerar.
            distribution: Distribuição por tipo (opcional).
            use_ai: Se deve tentar usar IA (default: True).
        
        Returns:
            Dict com 'created', 'failed', 'summary' e 'source'.
        Gera missões usando IA Gemini.
        
        Args:
            count: Número de missões.
            distribution: Distribuição por tipo.
            
        Returns:
            Dict com 'success', 'missions' ou 'error'.
        Valida viabilidade de uma missão baseada nos dados.
        
        Args:
            mission_data: Dados da missão.
            
        Returns:
            Tuple com (é_viável, mensagem_erro).
        Gera uma missão a partir de templates (fallback).
        
        Args:
            mission_type: Tipo da missão.
            
        Returns:
            Dict com dados da missão ou None.
        Instancia um template com valores concretos.
        
        Args:
            mission_type: Tipo da missão.
            template: Template a instanciar.
            
        Returns:
            Dict com dados da missão ou None.
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
        else:
            weights = {
                'ONBOARDING': 0,
                'TPS_IMPROVEMENT': 2,
                'RDR_REDUCTION': 2,
                'ILI_BUILDING': 3,
                'CATEGORY_REDUCTION': 2,
                'GOAL_ACHIEVEMENT': 3 if self.context.has_active_goals else 0,
            }
        
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
        min_d, max_d = self.config.DURATION_RANGES[difficulty]
        return random.randint(min_d, max_d)
    
    def _calculate_target_value(self, mission_type: str, difficulty: str) -> Optional[float]:
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
        min_xp, max_xp = self.config.XP_RANGES[difficulty]
        return random.randint(min_xp, max_xp)



def generate_missions(
    quantidade: int = 10,
    tier: Optional[str] = None,
    user=None,
    use_ai: bool = True,
) -> Dict[str, Any]:
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
        
        if 'gemini_ai' in all_sources:
            results['source'] = 'gemini_ai' if all(s == 'gemini_ai' for s in all_sources) else 'hybrid'
        else:
            results['source'] = 'template'
    
    results['summary']['total_created'] = len(results['created'])
    results['summary']['total_failed'] = len(results['failed'])
    results['summary']['generation_source'] = results['source']
    
    logger.info(
        f"Geração concluída via {results['source']}: "
        f"{results['summary']['total_created']} criadas, "
        f"{results['summary']['total_failed']} falhas"
    )
    
    return results
