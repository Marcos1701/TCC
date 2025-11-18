#!/usr/bin/env python
"""
Script para testar o sistema de geração assíncrona de missões.

Testa:
1. Celery workers estão rodando
2. Redis está acessível
3. Task assíncrona funciona
4. Polling de status funciona
"""

import os
import sys
import time

# Setup Django
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'Api'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

import django
django.setup()

from django.core.cache import cache
from celery import current_app

def test_redis_connection():
    """Testa conexão com Redis"""
    print("\n=== TESTE 1: Redis ===")
    try:
        cache.set('test_key', 'test_value', timeout=10)
        value = cache.get('test_key')
        if value == 'test_value':
            print("✅ Redis: Conectado e funcional")
            return True
        else:
            print("❌ Redis: Valor incorreto")
            return False
    except Exception as e:
        print(f"❌ Redis: Erro - {e}")
        return False

def test_celery_config():
    """Testa configuração do Celery"""
    print("\n=== TESTE 2: Celery Config ===")
    try:
        broker_url = current_app.conf.broker_url
        result_backend = current_app.conf.result_backend
        print(f"✅ Broker: {broker_url}")
        print(f"✅ Backend: {result_backend}")
        return True
    except Exception as e:
        print(f"❌ Celery Config: {e}")
        return False

def test_celery_workers():
    """Verifica se workers estão rodando"""
    print("\n=== TESTE 3: Celery Workers ===")
    try:
        inspector = current_app.control.inspect()
        active = inspector.active()
        
        if active:
            print(f"✅ Workers ativos: {len(active)}")
            for worker, tasks in active.items():
                print(f"   - {worker}: {len(tasks)} tasks")
            return True
        else:
            print("⚠️  Nenhum worker ativo")
            print("   Execute: celery -A config worker -l info")
            return False
    except Exception as e:
        print(f"❌ Workers: {e}")
        return False

def test_async_task():
    """Testa task assíncrona de geração"""
    print("\n=== TESTE 4: Task Assíncrona ===")
    try:
        from finance.tasks import generate_missions_async
        
        print("Iniciando task de geração (1 missão de teste)...")
        task = generate_missions_async.delay(
            tier='BEGINNER',
            scenario_key='low_activity',
            count=1,
            use_templates_first=True
        )
        
        print(f"✅ Task iniciada: {task.id}")
        print("Aguardando conclusão (max 30s)...")
        
        # Polling
        for i in range(30):
            time.sleep(1)
            
            if task.ready():
                if task.successful():
                    result = task.result
                    created = result.get('summary', {}).get('total_created', 0)
                    print(f"✅ Task concluída: {created} missão(ões) criada(s)")
                    return True
                else:
                    print(f"❌ Task falhou: {task.info}")
                    return False
            
            if i % 5 == 0:
                print(f"   Aguardando... ({i}s)")
        
        print("⚠️  Timeout após 30s")
        return False
        
    except Exception as e:
        print(f"❌ Task: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    print("="*70)
    print("  TESTE DO SISTEMA DE GERAÇÃO ASSÍNCRONA")
    print("="*70)
    
    results = []
    
    # Teste 1: Redis
    results.append(("Redis", test_redis_connection()))
    
    # Teste 2: Celery Config
    results.append(("Celery Config", test_celery_config()))
    
    # Teste 3: Workers
    workers_ok = test_celery_workers()
    results.append(("Workers", workers_ok))
    
    # Teste 4: Task (apenas se workers ok)
    if workers_ok:
        results.append(("Task Async", test_async_task()))
    else:
        print("\n⚠️  Pulando teste de task (workers não disponíveis)")
        results.append(("Task Async", None))
    
    # Resumo
    print("\n" + "="*70)
    print("  RESUMO DOS TESTES")
    print("="*70)
    
    for name, result in results:
        if result is True:
            status = "✅ PASSOU"
        elif result is False:
            status = "❌ FALHOU"
        else:
            status = "⚠️  PULADO"
        
        print(f"{name:20} {status}")
    
    print("\n" + "="*70)
    
    all_passed = all(r is True or r is None for r in [r[1] for r in results])
    
    if all_passed:
        print("✅ Sistema pronto para geração assíncrona!")
    else:
        print("❌ Alguns testes falharam - verifique configuração")
    
    return 0 if all_passed else 1

if __name__ == '__main__':
    sys.exit(main())
