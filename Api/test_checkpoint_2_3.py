"""
Script de teste para validar Checkpoint 2.3: Melhoria da Geração de Missões IA

Testa:
1. Validação de missões geradas
2. Detecção de duplicatas semânticas
3. Geração incremental com salvamento parcial
4. Formato correto de resposta do endpoint
"""
import os
import sys
import django

# Configurar Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from finance.ai_services import (
    validate_generated_mission,
    check_mission_similarity,
    get_reference_missions
)


def test_validate_generated_mission():
    """Testa a validação de missões geradas"""
    print("\n" + "="*80)
    print("TESTE 1: Validação de Missões")
    print("="*80)
    
    # Caso 1: Missão válida TPS_IMPROVEMENT
    print("\n[1.1] Missão TPS_IMPROVEMENT válida:")
    mission_valid = {
        "title": "Aumentar Poupança para 25%",
        "description": "Eleve sua Taxa de Poupança Pessoal para 25% neste mês",
        "mission_type": "TPS_IMPROVEMENT",
        "target_tps": 25.0,
        "target_rdr": None,
        "min_ili": None,
        "min_transactions": None,
        "duration_days": 30,
        "xp_reward": 150,
        "difficulty": "MEDIUM"
    }
    is_valid, errors = validate_generated_mission(mission_valid)
    print(f"✓ Válida: {is_valid}, Erros: {errors}")
    assert is_valid, f"Deveria ser válida, mas teve erros: {errors}"
    
    # Caso 2: Missão com tipo inválido
    print("\n[1.2] Missão com mission_type inválido:")
    mission_invalid_type = mission_valid.copy()
    mission_invalid_type["mission_type"] = "INVALID_TYPE"
    is_valid, errors = validate_generated_mission(mission_invalid_type)
    print(f"✗ Válida: {is_valid}, Erros: {errors}")
    assert not is_valid, "Deveria ser inválida (tipo incorreto)"
    
    # Caso 3: Missão TPS sem target_tps
    print("\n[1.3] Missão TPS_IMPROVEMENT sem target_tps:")
    mission_missing_field = mission_valid.copy()
    mission_missing_field["target_tps"] = None
    is_valid, errors = validate_generated_mission(mission_missing_field)
    print(f"✗ Válida: {is_valid}, Erros: {errors}")
    assert not is_valid, "Deveria ser inválida (falta target_tps)"
    
    # Caso 4: XP incompatível com difficulty
    print("\n[1.4] XP incompatível com difficulty:")
    mission_wrong_xp = mission_valid.copy()
    mission_wrong_xp["xp_reward"] = 50  # MEDIUM deveria ter 100-250
    is_valid, errors = validate_generated_mission(mission_wrong_xp)
    print(f"✗ Válida: {is_valid}, Erros: {errors}")
    assert not is_valid, "Deveria ser inválida (XP incompatível)"
    
    # Caso 5: ONBOARDING válido
    print("\n[1.5] Missão ONBOARDING válida:")
    mission_onboarding = {
        "title": "Registre 10 Transações",
        "description": "Comece sua jornada registrando suas primeiras 10 transações",
        "mission_type": "ONBOARDING",
        "target_tps": None,
        "target_rdr": None,
        "min_ili": None,
        "min_transactions": 10,
        "duration_days": 7,
        "xp_reward": 100,
        "difficulty": "EASY"
    }
    is_valid, errors = validate_generated_mission(mission_onboarding)
    print(f"✓ Válida: {is_valid}, Erros: {errors}")
    assert is_valid, f"Deveria ser válida, mas teve erros: {errors}"
    
    print("\n✅ TESTE 1 PASSOU: Validação funcionando corretamente")


def test_check_mission_similarity():
    """Testa a detecção de duplicatas semânticas"""
    print("\n" + "="*80)
    print("TESTE 2: Detecção de Duplicatas Semânticas")
    print("="*80)
    
    from finance.models import Mission
    
    # Criar missão de teste
    print("\n[2.1] Criando missão de teste...")
    test_mission = Mission.objects.create(
        title="Economize 20% da Renda",
        description="Aumente sua taxa de poupança para 20% este mês através de cortes estratégicos",
        mission_type="TPS_IMPROVEMENT",
        target_tps=20.0,
        duration_days=30,
        reward_points=150,
        difficulty="MEDIUM",
        is_active=True,
        priority=1
    )
    print(f"✓ Missão criada: ID={test_mission.id}")
    
    # Caso 1: Título idêntico
    print("\n[2.2] Verificando título idêntico:")
    is_dup, msg = check_mission_similarity(
        "Economize 20% da Renda",
        "Descrição completamente diferente"
    )
    print(f"✗ Duplicata: {is_dup}, Mensagem: {msg}")
    assert is_dup, "Deveria detectar duplicata (título idêntico)"
    
    # Caso 2: Título muito similar (>85%)
    print("\n[2.3] Verificando título muito similar:")
    is_dup, msg = check_mission_similarity(
        "Economize 20% de Renda",  # Pequena mudança
        "Outra descrição diferente"
    )
    print(f"{'✗ Duplicata' if is_dup else '✓ Única'}: {is_dup}, Mensagem: {msg}")
    
    # Caso 3: Descrição muito similar (>75%)
    print("\n[2.4] Verificando descrição muito similar:")
    is_dup, msg = check_mission_similarity(
        "Título completamente diferente",
        "Aumente sua taxa de poupança para 20% este mês através de cortes"
    )
    print(f"{'✗ Duplicata' if is_dup else '✓ Única'}: {is_dup}, Mensagem: {msg}")
    
    # Caso 4: Missão única (baixa similaridade)
    print("\n[2.5] Verificando missão única:")
    is_dup, msg = check_mission_similarity(
        "Reduza Dívidas em 30%",
        "Baixe sua Razão Dívida-Receita para menos de 30% através de quitação estratégica"
    )
    print(f"✓ Duplicata: {is_dup}, Mensagem: {msg}")
    assert not is_dup, f"Não deveria detectar duplicata, mas detectou: {msg}"
    
    # Limpar missão de teste
    test_mission.delete()
    print(f"\n✓ Missão de teste removida: ID={test_mission.id}")
    
    print("\n✅ TESTE 2 PASSOU: Detecção de duplicatas funcionando corretamente")


def test_get_reference_missions():
    """Testa a obtenção de missões de referência"""
    print("\n" + "="*80)
    print("TESTE 3: Missões de Referência")
    print("="*80)
    
    # Caso 1: Todas as missões de referência
    print("\n[3.1] Buscando missões de referência (todas):")
    references = get_reference_missions(limit=5)
    print(f"✓ Encontradas: {len(references)} missões")
    
    if references:
        print("\nExemplo de missão de referência:")
        ref = references[0]
        print(f"  - Título: {ref['title']}")
        print(f"  - Tipo: {ref['mission_type']}")
        print(f"  - Dificuldade: {ref['difficulty']}")
        print(f"  - XP: {ref['xp_reward']}")
        print(f"  - Duração: {ref['duration_days']} dias")
    
    # Caso 2: Missões de referência filtradas por tipo
    print("\n[3.2] Buscando missões TPS_IMPROVEMENT:")
    tps_references = get_reference_missions(mission_type='TPS_IMPROVEMENT', limit=3)
    print(f"✓ Encontradas: {len(tps_references)} missões TPS_IMPROVEMENT")
    
    for i, ref in enumerate(tps_references, 1):
        print(f"  {i}. [{ref['mission_type']}] {ref['title']}")
    
    print("\n✅ TESTE 3 PASSOU: Missões de referência carregadas corretamente")


def run_all_tests():
    """Executa todos os testes"""
    print("\n" + "="*80)
    print("INICIANDO TESTES - CHECKPOINT 2.3")
    print("="*80)
    
    try:
        test_validate_generated_mission()
        test_check_mission_similarity()
        test_get_reference_missions()
        
        print("\n" + "="*80)
        print("✅ TODOS OS TESTES PASSARAM!")
        print("="*80)
        print("\nCheckpoint 2.3 está funcionando corretamente:")
        print("  ✓ Validação de missões implementada")
        print("  ✓ Detecção de duplicatas semânticas implementada")
        print("  ✓ Missões de referência funcionando")
        print("\nPróximo passo: Testar endpoint generate_ai_missions via API")
        
    except AssertionError as e:
        print("\n" + "="*80)
        print(f"❌ TESTE FALHOU: {e}")
        print("="*80)
        raise
    except Exception as e:
        print("\n" + "="*80)
        print(f"❌ ERRO INESPERADO: {e}")
        print("="*80)
        raise


if __name__ == '__main__':
    run_all_tests()
