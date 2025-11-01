from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("finance", "0002_seed_missions"),
    ]

    operations = [
        migrations.AddField(
            model_name="transaction",
            name="is_recurring",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="transaction",
            name="recurrence_end_date",
            field=models.DateField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="transaction",
            name="recurrence_unit",
            field=models.CharField(
                blank=True,
                choices=[
                    ("DAYS", "Dias"),
                    ("WEEKS", "Semanas"),
                    ("MONTHS", "Meses"),
                ],
                max_length=10,
                null=True,
            ),
        ),
        migrations.AddField(
            model_name="transaction",
            name="recurrence_value",
            field=models.PositiveIntegerField(blank=True, null=True),
        ),
    ]
