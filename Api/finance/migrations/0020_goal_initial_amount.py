# Generated manually

from decimal import Decimal
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0019_goal_tracked_categories'),
    ]

    operations = [
        migrations.AddField(
            model_name='goal',
            name='initial_amount',
            field=models.DecimalField(decimal_places=2, default=Decimal('0.00'), help_text='Valor inicial da meta (transações anteriores à criação)', max_digits=12),
        ),
    ]
