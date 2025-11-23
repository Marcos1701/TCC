from django.db import migrations


class Migration(migrations.Migration):
    
    dependencies = [
        ('finance', '0039_auto_20241120_1420'),
    ]
    
    operations = [
        migrations.RemoveField(
            model_name='userachievement',
            name='achievement',
        ),
        migrations.RemoveField(
            model_name='userachievement',
            name='user',
        ),
        migrations.DeleteModel(
            name='Achievement',
        ),
        migrations.DeleteModel(
            name='UserAchievement',
        ),
        migrations.RemoveField(
            model_name='friendship',
            name='user',
        ),
        migrations.RemoveField(
            model_name='friendship',
            name='friend',
        ),
        migrations.DeleteModel(
            name='Friendship',
        ),
    ]
