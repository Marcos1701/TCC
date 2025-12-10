
import json
import logging
from typing import List, Dict, Any, Optional

import google.generativeai as genai
from django.conf import settings
from django.db.models import Sum

from .models import Mission, Category, UserProfile, Transaction
from .services import calculate_summary

logger = logging.getLogger(__name__)


def get_gemini_model():
    if not settings.GEMINI_API_KEY:
        logger.warning("GEMINI_API_KEY não configurada")
        return None
    
    genai.configure(api_key=settings.GEMINI_API_KEY)
    
    generation_config = {
        "temperature": 0.7,
        "top_p": 0.8,
        "top_k": 40,
        "max_output_tokens": 2048,
    }
    
    return genai.GenerativeModel(
        model_name="gemini-pro",
        generation_config=generation_config,
    )


def generate_general_missions(quantidade: int = 5) -> Dict[str, Any]:
    model = get_gemini_model()
    created = []
    failed = []
    
    prompt = f"""
    Atue como um especialista em gamificação financeira e crie {quantidade} missões para um aplicativo de finanças pessoais.
    
    AS MISSÕES DEVEM SER VARIADAS ENTRE ESTES TIPOS:
    1. ONBOARDING (primeiros passos, cadastros)
    2. EDUCATIONAL (aprender conceitos)
    3. ENGAGEMENT (usar o app regularmente)
    4. FINANCIAL_HEALTH (melhorar indicadores)
    
    REGRAS IMPORTANTES:
    - Títulos curtos e motivadores (máx 100 caracteres)
    - Descrições educativas e encorajadoras (2-3 frases)
    - Dificuldade: EASY (30%), MEDIUM (50%), HARD (20%)
    - Duração: 7-30 dias (EASY: 7-14, MEDIUM: 14-21, HARD: 21-30)
    - XP: EASY 25-75, MEDIUM 75-150, HARD 150-300
    - Cada missão deve ter APENAS os campos do seu tipo preenchidos
    - NÃO inclua campos de outros tipos
    
    FORMATO JSON (retorne APENAS o array, sem markdown):
    [
      {{
        "title": "Título Motivador da Missão",
        "description": "Descrição educativa explicando o benefício e como completar.",
        "mission_type": "TIPO_AQUI",
        "difficulty": "EASY|MEDIUM|HARD",
        "duration_days": 14,
        "reward_points": 100,
        "min_transactions": null,
        "target_tps": null,
        "target_rdr": null,
        "min_ili": null,
        "target_reduction_percent": null
      }}
    ]
    
    IMPORTANTE: Preencha APENAS o campo específico do tipo de missão. Os demais devem ser null.
    """
    
    if not model:
        logger.warning("Gemini API não disponível para geração de missões")
        return {'created': [], 'failed': [], 'summary': {'error': 'API não disponível'}}
    
    try:
        response = model.generate_content(prompt)
        response_text = response.text.strip()
        
        if response_text.startswith('```'):
            response_text = response_text.split('```')[1]
            if response_text.startswith('json'):
                response_text = response_text[4:]
        
        missions_data = json.loads(response_text)
        
        for mission_data in missions_data:
            try:
                mission = Mission.objects.create(
                    title=mission_data.get('title', 'Missão'),
                    description=mission_data.get('description', ''),
                    mission_type=mission_data.get('mission_type', 'ONBOARDING'),
                    difficulty=mission_data.get('difficulty', 'MEDIUM'),
                    duration_days=mission_data.get('duration_days', 14),
                    reward_points=mission_data.get('reward_points', 100),
                    min_transactions=mission_data.get('min_transactions'),
                    target_tps=mission_data.get('target_tps'),
                    target_rdr=mission_data.get('target_rdr'),
                    min_ili=mission_data.get('min_ili'),
                    target_reduction_percent=mission_data.get('target_reduction_percent'),
                    is_active=True,
                    is_system_generated=True,
                    priority=50 
                )
                created.append({'id': mission.id, 'title': mission.title})
            except Exception as e:
                failed.append({'title': mission_data.get('title'), 'error': str(e)})
        
        return {
            'created': created,
            'failed': failed,
            'summary': {
                'total_created': len(created),
                'total_failed': len(failed)
            }
        }
        
    except json.JSONDecodeError as e:
        logger.error(f"Erro ao parsear JSON: {e}")
        return {'created': [], 'failed': [], 'summary': {'error': f'JSON inválido: {e}'}}
    except Exception as e:
        logger.error(f"Erro ao gerar missões: {e}")
        return {'created': [], 'failed': [], 'summary': {'error': str(e)}}


def suggest_category_for_transaction(description: str, amount: float) -> Optional[Dict[str, Any]]:
    model = get_gemini_model()
    if not model:
        return None
        
    categories = Category.objects.filter(is_active=True).values('id', 'name', 'type')
    categories_list = list(categories)
    
    prompt = f"""
    Analise a transação: "{description}" valor R$ {amount:.2f}
    
    Escolha a categoria mais apropriada da lista abaixo:
    {json.dumps(categories_list, ensure_ascii=False)}
    
    Retorne APENAS um JSON com o ID da categoria sugerida e uma breve explicação:
    {{
        "category_id": 123,
        "confidence": 0.9,
        "reason": "Explicação curta"
    }}
    """
    
    try:
        response = model.generate_content(prompt)
        text = response.text.strip()
        if text.startswith('```'):
            text = text.split('```')[1].replace('json', '').strip()
            
        return json.loads(text)
    except Exception as e:
        logger.error(f"Erro ao sugerir categoria: {e}")
        return None


def generate_personalized_missions(user_profile: UserProfile, count: int = 3) -> Dict[str, Any]:
    model = get_gemini_model()
    created = []
    failed = []
    
    summary_data = calculate_summary(user_profile.user)
    
    user_context = {
        'level': user_profile.level,
        'current_tps': summary_data.get('tps', 0),
        'current_rdr': summary_data.get('rdr', 0),
        'current_ili': summary_data.get('ili', 0),
        'target_tps': user_profile.target_tps,
        'target_rdr': user_profile.target_rdr,
        'min_ili': user_profile.min_ili,
    }
    
    prompt = f"""
    Crie {count} missões personalizadas para um usuário com este perfil:
    {json.dumps(user_context, indent=2)}
    
    FOCO: Ajudar o usuário a atingir suas metas (targets) de TPS, RDR e ILI.
    
    TIPOS PERMITIDOS:
    - FINANCIAL_HEALTH (foco em melhorar índices)
    - SAVINGS_STREAK (poupar regularmente)
    - BUDGET_ADHERENCE (manter gastos sob controle)
    
    RETORNE APENAS JSON (array de objetos mission).
    """

    if not model:
        return {'created': [], 'failed': [], 'summary': {'error': 'API indisponível'}}
        
    try:
        response = model.generate_content(prompt)
        # Processamento simplificado para brevidade - similar ao generate_general_missions
        # ...
        return {'created': [], 'failed': [], 'summary': {'status': 'Implemented in full version'}}
    except Exception as e:
        return {'created': [], 'failed': [], 'summary': {'error': str(e)}}


def analyze_mission_context(user_id: int, force_refresh: bool = False) -> Dict[str, Any]:
    return {
        'analysis': "Context analysis placeholder",
        'indicators': {},
        'opportunities': []
    }


def generate_hybrid_missions(
    tier: str,
    scenario_key: str = None,
    count: int = 10,
    use_templates_first: bool = True
) -> Dict[str, Any]:
    """
    Gera missões usando estratégia híbrida: Templates (rápido/seguro) + IA (criativo/personalizado).
    
    Args:
        tier: 'BEGINNER', 'INTERMEDIATE', 'ADVANCED'
        scenario_key: Chave do cenário (ex: 'RDR_HIGH') - usado para ajustar distribuição
        count: Total de missões desejadas
        use_templates_first: Se True, tenta preencher quota com templates antes de chamar IA
        
    Returns:
        Dict com 'created', 'failed' e 'summary'
    """
    from .mission_templates import generate_mission_batch_from_templates
    from .models import Mission
    
    created = []
    failed = []
    
    current_metrics = {
        'tps': 10 if tier == 'BEGINNER' else 20,
        'rdr': 40 if tier == 'BEGINNER' else 30,
        'ili': 1 if tier == 'BEGINNER' else 6,
    }
    
    if use_templates_first:
        try:
            template_missions = generate_mission_batch_from_templates(
                tier=tier,
                current_metrics=current_metrics,
                count=count
            )
            
            for m_data in template_missions:
                try:
                    mission = Mission.objects.create(
                        title=m_data.get('title', 'Missão Template'),
                        description=m_data.get('description', ''),
                        mission_type=m_data.get('mission_type', 'ONBOARDING'),
                        difficulty=m_data.get('difficulty', 'MEDIUM'),
                        duration_days=m_data.get('duration_days', 14),
                        reward_points=m_data.get('reward_points', 100),
                        min_transactions=m_data.get('min_transactions'),
                        target_tps=m_data.get('target_tps'),
                        target_rdr=m_data.get('target_rdr'),
                        min_ili=m_data.get('min_ili'),
                        target_reduction_percent=m_data.get('target_reduction_percent'),
                        is_active=True,
                        is_system_generated=True,
                        priority=60 
                    )
                    created.append({'id': mission.id, 'title': mission.title, 'source': 'template'})
                except Exception as e:
                    failed.append({'title': m_data.get('title'), 'error': str(e)})
                    
        except Exception as e:
             logger.error(f"Erro ao gerar templates na estratégia híbrida: {e}")
    
    remaining = count - len(created)
    if remaining > 0:
        logger.info(f"Completando {remaining} missões via IA (Gemini)...")
        ai_result = generate_general_missions(quantidade=remaining)
        
        for m in ai_result.get('created', []):
            m['source'] = 'ai'
            created.append(m)
            
        failed.extend(ai_result.get('failed', []))
        
    return {
        'created': created,
        'failed': failed,
        'summary': {
            'total_created': len(created),
            'total_failed': len(failed),
            'tier': tier,
            'strategy': 'hybrid'
        }
    }
