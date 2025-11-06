"""
Script para adicionar coluna is_system_default manualmente.
Execute com: python add_column_manually.py
"""
import os
import sys
import django

# Setup Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import connection

def add_is_system_default_column():
    """Adiciona coluna is_system_default à tabela finance_category."""
    with connection.cursor() as cursor:
        try:
            # Verificar se coluna já existe
            cursor.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='finance_category' 
                AND column_name='is_system_default';
            """)
            
            if cursor.fetchone():
                print("✓ Coluna 'is_system_default' já existe.")
                return
            
            # Adicionar coluna
            print("Adicionando coluna 'is_system_default'...")
            cursor.execute("""
                ALTER TABLE finance_category 
                ADD COLUMN is_system_default BOOLEAN DEFAULT FALSE NOT NULL;
            """)
            
            print("✓ Coluna adicionada com sucesso!")
            
            # Atualizar categorias existentes como padrão
            print("Marcando categorias existentes como padrão do sistema...")
            cursor.execute("""
                UPDATE finance_category 
                SET is_system_default = TRUE 
                WHERE id IN (
                    SELECT id FROM finance_category 
                    ORDER BY created_at 
                    LIMIT 100
                );
            """)
            
            rows_updated = cursor.rowcount
            print(f"✓ {rows_updated} categorias marcadas como padrão do sistema.")
            
        except Exception as e:
            print(f"✗ Erro: {e}")
            raise

if __name__ == '__main__':
    print("=" * 60)
    print("ADICIONANDO COLUNA is_system_default")
    print("=" * 60)
    add_is_system_default_column()
    print("=" * 60)
    print("✓ CONCLUÍDO!")
    print("=" * 60)
