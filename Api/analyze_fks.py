"""Análise de Foreign Keys para migração UUID"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.apps import apps
from django.db import models

def analyze_foreign_keys():
    target_models = ['Transaction', 'Goal', 'TransactionLink', 'Friendship']
    
    print("=" * 60)
    print("ANÁLISE DE FOREIGN KEYS PARA MIGRAÇÃO UUID")
    print("=" * 60)
    
    for model_name in target_models:
        model = apps.get_model('finance', model_name)
        print(f"\n{'='*60}")
        print(f"MODELO: {model_name}")
        print(f"{'='*60}")
        
        # Foreign Keys saindo (este model aponta para outros)
        related_fks = [f for f in model._meta.get_fields() 
                       if (f.many_to_one or f.one_to_one) and not f.auto_created]
        print(f"\n  FKs SAINDO ({len(related_fks)}):")
        for fk in related_fks:
            print(f"    → {fk.name:30} -> {fk.related_model.__name__}")
        
        # Foreign Keys entrando (outros models apontam para este)
        incoming_refs = [f for f in model._meta.related_objects]
        print(f"\n  FKs ENTRANDO ({len(incoming_refs)}):")
        for ref in incoming_refs:
            print(f"    ← {ref.related_model.__name__:20}.{ref.field.name}")
    
    print(f"\n{'='*60}")
    print("RESUMO:")
    print(f"{'='*60}")
    
    # Verificar quais FKs precisam ser convertidas
    print("\nFKs QUE PRECISAM SER CONVERTIDAS PARA UUID:")
    all_models = apps.get_app_config('finance').get_models()
    uuid_models = {'Transaction', 'Goal', 'TransactionLink', 'Friendship'}
    
    conversions_needed = []
    for model in all_models:
        for field in model._meta.get_fields():
            if (field.many_to_one or field.one_to_one) and not field.auto_created:
                target_model_name = field.related_model.__name__
                if target_model_name in uuid_models:
                    source_model_name = model.__name__
                    # Pular se já é UUID (TransactionLink já foi migrado)
                    if hasattr(field, 'target_field') and field.target_field and field.target_field.name == 'uuid':
                        print(f"  ✓ {source_model_name}.{field.name} -> {target_model_name} (JÁ USA UUID)")
                    else:
                        conversions_needed.append({
                            'source': source_model_name,
                            'field': field.name,
                            'target': target_model_name
                        })
    
    if conversions_needed:
        print("\n  PENDENTES:")
        for conv in conversions_needed:
            print(f"    • {conv['source']}.{conv['field']} -> {conv['target']}")
    else:
        print("\n  ✓ Todas as FKs já estão convertidas!")

if __name__ == '__main__':
    analyze_foreign_keys()
