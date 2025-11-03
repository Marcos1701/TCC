from decimal import Decimal
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("finance", "0005_mission_max_ili_mission_min_ili_and_more"),
    ]

    operations = [
        # Adicionar novos campos ao modelo Mission
        migrations.AddField(
            model_name='mission',
            name='mission_type',
            field=models.CharField(
                choices=[
                    ('ONBOARDING', 'Integração inicial'),
                    ('TPS_IMPROVEMENT', 'Melhoria de poupança'),
                    ('RDR_REDUCTION', 'Redução de dívidas'),
                    ('ILI_BUILDING', 'Construção de reserva'),
                    ('ADVANCED', 'Avançado')
                ],
                default='ONBOARDING',
                help_text='Tipo de missão que determina quando será aplicada',
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='mission',
            name='priority',
            field=models.PositiveIntegerField(
                default=1,
                help_text='Ordem de prioridade para aplicação automática (menor = mais prioritário)',
            ),
        ),
        migrations.AddField(
            model_name='mission',
            name='min_transactions',
            field=models.PositiveIntegerField(
                blank=True,
                help_text='Número mínimo de transações registradas para desbloquear esta missão',
                null=True,
            ),
        ),
        migrations.AlterField(
            model_name='mission',
            name='target_tps',
            field=models.PositiveIntegerField(
                blank=True,
                help_text='TPS mínimo necessário (se aplicável)',
                null=True,
            ),
        ),
        migrations.AlterField(
            model_name='mission',
            name='target_rdr',
            field=models.PositiveIntegerField(
                blank=True,
                help_text='RDR máximo permitido (se aplicável)',
                null=True,
            ),
        ),
        migrations.AlterField(
            model_name='mission',
            name='min_ili',
            field=models.DecimalField(
                blank=True,
                decimal_places=1,
                help_text='ILI mínimo necessário',
                max_digits=4,
                null=True,
            ),
        ),
        migrations.AlterField(
            model_name='mission',
            name='max_ili',
            field=models.DecimalField(
                blank=True,
                decimal_places=1,
                help_text='ILI máximo permitido',
                max_digits=4,
                null=True,
            ),
        ),
        migrations.AlterModelOptions(
            name='mission',
            options={'ordering': ('priority', 'title')},
        ),
        
        # Adicionar novos campos ao modelo MissionProgress
        migrations.AddField(
            model_name='missionprogress',
            name='initial_tps',
            field=models.DecimalField(
                blank=True,
                decimal_places=2,
                max_digits=5,
                null=True,
            ),
        ),
        migrations.AddField(
            model_name='missionprogress',
            name='initial_rdr',
            field=models.DecimalField(
                blank=True,
                decimal_places=2,
                max_digits=5,
                null=True,
            ),
        ),
        migrations.AddField(
            model_name='missionprogress',
            name='initial_ili',
            field=models.DecimalField(
                blank=True,
                decimal_places=2,
                max_digits=5,
                null=True,
            ),
        ),
        migrations.AddField(
            model_name='missionprogress',
            name='initial_transaction_count',
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.AlterField(
            model_name='missionprogress',
            name='status',
            field=models.CharField(
                choices=[
                    ('PENDING', 'Pendente'),
                    ('ACTIVE', 'Em andamento'),
                    ('COMPLETED', 'Concluída'),
                    ('FAILED', 'Falhou')
                ],
                default='PENDING',
                max_length=10,
            ),
        ),
        migrations.AlterModelOptions(
            name='missionprogress',
            options={'ordering': ('mission__priority', 'mission__title')},
        ),
    ]
