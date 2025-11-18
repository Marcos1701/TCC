#!/usr/bin/env python
"""
Script para testar as melhorias na geração de missões com IA.

Este script:
1. Limpa missões antigas (opcional)
2. Gera 20 novas missões usando o sistema híbrido otimizado
3. Valida resultados e exibe estatísticas
"""

import os
import sys
import django
import time
from datetime import datetime

# Setup Django
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'Api'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from finance.models import Mission
from finance.ai_services import generate_hybrid_missions

def print_header(text):
    print("\n" + "="*70)
    print(f"  {text}")
    print("="*70 + "\n")

def print_section(text):
    print(f"\n{'─'*70}")
    print(f"  {text}")
    print(f"{'─'*70}")

def main():
    print_header("🧪 TESTE DE GERAÇÃO DE MISSÕES - VERSÃO OTIMIZADA")
    
    # ========================================================================
    # ETAPA 1: Estado Inicial
    # ========================================================================
    print_section("📊 ETAPA 1: Estado Inicial")
    
    initial_count = Mission.objects.filter(is_active=True).count()
    print(f"Missões ativas no banco: {initial_count}")
    
    # Perguntar se deve limpar
    clean = input("\n⚠️  Deseja limpar missões antigas? (s/N): ").strip().lower()
    if clean == 's':
        Mission.objects.filter(is_active=True).delete()
        print(f"✅ {initial_count} missões removidas")
        initial_count = 0
    
    # ========================================================================
    # ETAPA 2: Geração de Missões
    # ========================================================================
    print_section("🤖 ETAPA 2: Gerando 20 Missões")
    
    print("Parâmetros:")
    print("  - Tier: BEGINNER")
    print("  - Scenario: low_activity")
    print("  - Count: 20")
    print("  - Use Templates: True")
    
    print("\nIniciando geração...")
    start_time = time.time()
    
    try:
        result = generate_hybrid_missions(
            tier='BEGINNER',
            scenario_key='low_activity',
            count=20,
            use_templates_first=True
        )
        
        end_time = time.time()
        duration = end_time - start_time
        
        # ====================================================================
        # ETAPA 3: Resultados
        # ====================================================================
        print_section("✅ ETAPA 3: Resultados")
        
        summary = result.get('summary', {})
        created = result.get('created', [])
        failed = result.get('failed', [])
        
        print(f"⏱️  Tempo total: {duration:.1f}s")
        print(f"\n📊 ESTATÍSTICAS:")
        print(f"  ✅ Criadas: {summary.get('total_created', 0)}")
        print(f"  ❌ Falhas: {summary.get('total_failed', 0)}")
        print(f"\n📋 ORIGEM:")
        print(f"  🎯 Templates: {summary.get('from_templates', 0)} ({summary.get('from_templates', 0)/20*100:.0f}%)")
        print(f"  🤖 IA: {summary.get('from_ai', 0)} ({summary.get('from_ai', 0)/20*100:.0f}%)")
        
        print(f"\n🔍 TIPOS DE FALHAS:")
        print(f"  - Validação: {summary.get('failed_validation', 0)}")
        print(f"  - Duplicatas: {summary.get('failed_duplicate', 0)}")
        print(f"  - API: {summary.get('failed_api', 0)}")
        print(f"  - Parsing: {summary.get('failed_parsing', 0)}")
        
        # ====================================================================
        # ETAPA 4: Qualidade
        # ====================================================================
        print_section("🎯 ETAPA 4: Validação de Qualidade")
        
        # Verificar placeholders
        missions_with_placeholders = []
        for mission_data in created:
            mission = Mission.objects.get(id=mission_data['id'])
            title = mission.title
            description = mission.description
            
            placeholders = []
            for text in [title, description]:
                import re
                found = re.findall(r'\{[^}]+\}', text)
                placeholders.extend(found)
            
            if placeholders:
                missions_with_placeholders.append({
                    'id': mission.id,
                    'title': title,
                    'placeholders': placeholders
                })
        
        if missions_with_placeholders:
            print(f"⚠️  ATENÇÃO: {len(missions_with_placeholders)} missões com placeholders:")
            for m in missions_with_placeholders:
                print(f"    - ID {m['id']}: {m['title']} → {m['placeholders']}")
        else:
            print("✅ Qualidade: 100% (zero placeholders)")
        
        # Diversidade de títulos
        unique_titles = set(m['title'] for m in created)
        print(f"\n✅ Diversidade: {len(unique_titles)}/{len(created)} títulos únicos ({len(unique_titles)/len(created)*100:.0f}%)")
        
        # Distribuição por dificuldade
        difficulties = {}
        for mission_data in created:
            mission = Mission.objects.get(id=mission_data['id'])
            diff = mission.difficulty
            difficulties[diff] = difficulties.get(diff, 0) + 1
        
        print(f"\n📊 Distribuição por Dificuldade:")
        for diff, count in sorted(difficulties.items()):
            print(f"  - {diff}: {count} ({count/len(created)*100:.0f}%)")
        
        # ====================================================================
        # ETAPA 5: Análise de Performance
        # ====================================================================
        print_section("🚀 ETAPA 5: Análise de Performance")
        
        avg_time_per_mission = duration / 20
        print(f"⏱️  Tempo médio por missão: {avg_time_per_mission:.1f}s")
        
        if summary.get('from_templates', 0) > 0:
            template_percentage = summary.get('from_templates', 0) / 20 * 100
            estimated_template_time = 0.1 * summary.get('from_templates', 0)  # Templates ~0.1s cada
            estimated_ai_time = duration - estimated_template_time
            
            print(f"\n💡 ECONOMIA:")
            print(f"  - Templates ({template_percentage:.0f}%): ~{estimated_template_time:.1f}s total")
            print(f"  - IA ({100-template_percentage:.0f}%): ~{estimated_ai_time:.1f}s total")
            print(f"  - Se tudo fosse IA: ~{duration * (20 / max(summary.get('from_ai', 1), 1)):.1f}s")
            print(f"  - Economia: ~{(1 - duration / (duration * (20 / max(summary.get('from_ai', 1), 1)))) * 100:.0f}%")
        
        # Taxa de sucesso
        success_rate = (summary.get('total_created', 0) / (summary.get('total_created', 0) + summary.get('total_failed', 0))) * 100 if (summary.get('total_created', 0) + summary.get('total_failed', 0)) > 0 else 0
        print(f"\n✅ Taxa de Sucesso: {success_rate:.0f}%")
        
        # ====================================================================
        # RESUMO FINAL
        # ====================================================================
        print_section("📝 RESUMO FINAL")
        
        print("✅ APROVADO" if (
            summary.get('total_created', 0) >= 17 and  # Pelo menos 85% de sucesso
            duration < 90 and  # Menos de 90 segundos
            len(missions_with_placeholders) == 0  # Zero placeholders
        ) else "⚠️  PRECISA MELHORIAS")
        
        print(f"\nCritérios:")
        print(f"  {'✅' if summary.get('total_created', 0) >= 17 else '❌'} Criadas >= 17 (atual: {summary.get('total_created', 0)})")
        print(f"  {'✅' if duration < 90 else '❌'} Tempo < 90s (atual: {duration:.1f}s)")
        print(f"  {'✅' if len(missions_with_placeholders) == 0 else '❌'} Zero placeholders (atual: {len(missions_with_placeholders)})")
        
    except Exception as e:
        print(f"\n❌ ERRO durante geração:")
        print(f"   {type(e).__name__}: {str(e)}")
        import traceback
        traceback.print_exc()
        return 1
    
    print_header("🎉 TESTE CONCLUÍDO")
    return 0

if __name__ == '__main__':
    sys.exit(main())
