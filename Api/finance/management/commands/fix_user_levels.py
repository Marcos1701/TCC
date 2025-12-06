
from django.core.management.base import BaseCommand
from django.db import transaction
from finance.models import UserProfile
from finance.services import _xp_threshold


class Command(BaseCommand):
    help = 'Corrige níveis de usuários com XP acumulado acima do threshold'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Mostra o que seria corrigido sem fazer alterações',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        
        if dry_run:
            self.stdout.write(self.style.WARNING('Modo DRY RUN - Nenhuma alteração será feita'))
        
        profiles = UserProfile.objects.select_related('user').all()
        
        fixed_count = 0
        total_count = profiles.count()
        
        self.stdout.write(f'Verificando {total_count} perfis...\n')
        
        for profile in profiles:
            threshold = _xp_threshold(profile.level)
            
            if profile.experience_points >= threshold:
                old_level = profile.level
                old_xp = profile.experience_points
                
                new_level = old_level
                new_xp = old_xp
                
                while new_xp >= _xp_threshold(new_level):
                    new_xp -= _xp_threshold(new_level)
                    new_level += 1
                
                self.stdout.write(
                    self.style.WARNING(
                        f'Usuário: {profile.user.username} (ID: {profile.user.id})\n'
                        f'  Antes: Level {old_level}, XP {old_xp} (Threshold: {threshold})\n'
                        f'  Depois: Level {new_level}, XP {new_xp} (Threshold: {_xp_threshold(new_level)})'
                    )
                )
                
                if not dry_run:
                    with transaction.atomic():
                        profile.level = new_level
                        profile.experience_points = new_xp
                        profile.save(update_fields=['level', 'experience_points'])
                    
                    self.stdout.write(
                        self.style.SUCCESS(f'  ✓ Corrigido!\n')
                    )
                else:
                    self.stdout.write('\n')
                
                fixed_count += 1
        
        if fixed_count == 0:
            self.stdout.write(
                self.style.SUCCESS('\n✓ Nenhum perfil precisou de correção!')
            )
        else:
            if dry_run:
                self.stdout.write(
                    self.style.WARNING(
                        f'\n{fixed_count} perfil(is) precisam de correção.'
                        f'\nExecute sem --dry-run para aplicar as correções.'
                    )
                )
            else:
                self.stdout.write(
                    self.style.SUCCESS(
                        f'\n✓ {fixed_count} perfil(is) corrigido(s) com sucesso!'
                    )
                )
