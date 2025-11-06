# Recreate M2M table with UUID foreign key
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0032_recreate_goal_m2m_with_uuid'),
    ]

    operations = [
        # Criar tabela M2M manualmente com goal_id como UUID
        migrations.RunSQL(
            sql='''
                CREATE TABLE IF NOT EXISTS finance_goal_tracked_categories (
                    id BIGSERIAL PRIMARY KEY,
                    goal_id UUID NOT NULL REFERENCES finance_goal(id) ON DELETE CASCADE,
                    category_id BIGINT NOT NULL REFERENCES finance_category(id) ON DELETE CASCADE,
                    UNIQUE (goal_id, category_id)
                );
                
                CREATE INDEX IF NOT EXISTS finance_goal_tracked_categories_goal_id_idx 
                ON finance_goal_tracked_categories(goal_id);
                
                CREATE INDEX IF NOT EXISTS finance_goal_tracked_categories_category_id_idx 
                ON finance_goal_tracked_categories(category_id);
            ''',
            reverse_sql='DROP TABLE IF EXISTS finance_goal_tracked_categories CASCADE;'
        ),
    ]
