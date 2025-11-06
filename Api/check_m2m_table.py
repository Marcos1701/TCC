"""Verificar estrutura da tabela M2M"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import connection

cursor = connection.cursor()
cursor.execute("""
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name = 'finance_goal_tracked_categories'
    ORDER BY ordinal_position
""")

print("Estrutura da tabela finance_goal_tracked_categories:")
print("-" * 50)
for row in cursor.fetchall():
    print(f"  {row[0]:20} {row[1]}")

# Verificar se há dados
cursor.execute("SELECT COUNT(*) FROM finance_goal_tracked_categories")
count = cursor.fetchone()[0]
print(f"\nTotal de registros: {count}")
