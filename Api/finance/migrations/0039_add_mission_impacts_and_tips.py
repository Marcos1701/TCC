# Generated manually on 2025-11-12
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0038_remove_debt_types'),  # Ajustar conforme última migration
    ]

    operations = [
        migrations.AddField(
            model_name='mission',
            name='impacts',
            field=models.JSONField(blank=True, default=list, help_text='Lista de impactos ao completar (título, descrição, ícone, cor)'),
        ),
        migrations.AddField(
            model_name='mission',
            name='tips',
            field=models.JSONField(blank=True, default=list, help_text='Lista de dicas contextuais (título, descrição, prioridade)'),
        ),
    ]
