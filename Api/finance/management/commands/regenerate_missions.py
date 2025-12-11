"""
Management command para regenerar missões usando Gemini e redistribuir aos usuários.

Uso:
    python manage.py regenerate_missions [options]

Opções:
    --quantidade N     Número de missões a gerar (default: 15)
    --skip-delete      Não deletar missões existentes
    --skip-redistribute  Não redistribuir aos usuários
    --dry-run          Simular sem fazer alterações
"""

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.contrib.auth import get_user_model

User = get_user_model()


class Command(BaseCommand):
    help = 'Remove missões existentes, gera novas via Gemini e redistribui aos usuários'
    
    def add_arguments(self, parser):
        parser.add_argument(
            '--quantidade',
            type=int,
            default=15,
            help='Número de missões a gerar (default: 15)',
        )
        parser.add_argument(
            '--skip-delete',
            action='store_true',
            help='Não deletar missões existentes',
        )
        parser.add_argument(
            '--skip-redistribute',
            action='store_true',
            help='Não redistribuir aos usuários após gerar',
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Simular sem fazer alterações no banco',
        )
    
    def handle(self, *args, **options):
        from finance.models import Mission, MissionProgress
        from finance.mission_generator import generate_missions
        from finance.services.missions import assign_missions_smartly
        
        quantidade = options['quantidade']
        skip_delete = options['skip_delete']
        skip_redistribute = options['skip_redistribute']
        dry_run = options['dry_run']
        
        self.stdout.write(self.style.NOTICE(
            f"\n{'[DRY RUN] ' if dry_run else ''}Regenerando missões...\n"
        ))
        
        # 1. Estatísticas atuais
        missions_count = Mission.objects.count()
        progress_count = MissionProgress.objects.count()
        users_count = User.objects.filter(is_active=True).count()
        
        self.stdout.write(f"📊 Estado atual:")
        self.stdout.write(f"   - Missões: {missions_count}")
        self.stdout.write(f"   - Progressos de usuários: {progress_count}")
        self.stdout.write(f"   - Usuários ativos: {users_count}")
        self.stdout.write("")
        
        if dry_run:
            self.stdout.write(self.style.WARNING("Modo DRY RUN - nenhuma alteração será feita"))
            return
        
        try:
            with transaction.atomic():
                # 2. Deletar missões existentes
                if not skip_delete:
                    self._delete_existing_missions()
                
                # 3. Gerar novas missões via Gemini
                self._generate_new_missions(quantidade)
                
                # 4. Redistribuir aos usuários
                if not skip_redistribute:
                    self._redistribute_to_users()
                
        except Exception as e:
            raise CommandError(f"Erro durante regeneração: {e}")
        
        self.stdout.write(self.style.SUCCESS("\n✅ Regeneração concluída com sucesso!"))
    
    def _delete_existing_missions(self):
        from finance.models import Mission, MissionProgress
        
        self.stdout.write(self.style.WARNING("\n🗑️  Removendo missões existentes..."))
        
        # Primeiro remove progressos (dependência)
        progress_deleted, _ = MissionProgress.objects.all().delete()
        self.stdout.write(f"   - {progress_deleted} progressos de usuários removidos")
        
        # Depois remove missões
        missions_deleted, _ = Mission.objects.all().delete()
        self.stdout.write(f"   - {missions_deleted} missões removidas")
    
    def _generate_new_missions(self, quantidade: int):
        from finance.mission_generator import generate_missions
        
        self.stdout.write(self.style.NOTICE(f"\n🤖 Gerando {quantidade} novas missões via Gemini..."))
        
        # Gera missões distribuídas por tier
        result = generate_missions(quantidade=quantidade, use_ai=True)
        
        created_count = len(result.get('created', []))
        failed_count = len(result.get('failed', []))
        source = result.get('source', 'unknown')
        
        self.stdout.write(f"   - Fonte: {source}")
        self.stdout.write(f"   - Criadas: {created_count}")
        
        if failed_count > 0:
            self.stdout.write(self.style.WARNING(f"   - Falhas: {failed_count}"))
            for failure in result.get('failed', [])[:5]:
                self.stdout.write(f"     • {failure.get('titulo', 'Desconhecido')}: {failure.get('erros', [])}")
        
        # Ativa as missões geradas
        self._activate_new_missions()
        
        # Mostra resumo por tipo
        self._show_missions_summary()
    
    def _activate_new_missions(self):
        from finance.models import Mission
        
        # Ativa todas as missões recém-criadas (elas vêm desativadas por padrão)
        inactive_count = Mission.objects.filter(is_active=False).count()
        if inactive_count > 0:
            Mission.objects.filter(is_active=False).update(is_active=True)
            self.stdout.write(f"   - {inactive_count} missões ativadas")
    
    def _show_missions_summary(self):
        from finance.models import Mission
        from collections import Counter
        
        missions = Mission.objects.all()
        
        # Por tipo
        by_type = Counter(missions.values_list('mission_type', flat=True))
        self.stdout.write("\n   📊 Distribuição por tipo:")
        for mission_type, count in by_type.most_common():
            self.stdout.write(f"      - {mission_type}: {count}")
        
        # Por transaction_type_filter
        by_filter = Counter(missions.values_list('transaction_type_filter', flat=True))
        self.stdout.write("\n   📊 Distribuição por tipo de transação:")
        for filter_type, count in by_filter.most_common():
            self.stdout.write(f"      - {filter_type}: {count}")
    
    def _redistribute_to_users(self):
        from finance.services.missions import assign_missions_smartly
        
        self.stdout.write(self.style.NOTICE("\n👥 Redistribuindo missões aos usuários..."))
        
        users = User.objects.filter(is_active=True)
        total_assigned = 0
        
        for user in users:
            try:
                assigned = assign_missions_smartly(user, max_active=3)
                assigned_count = len(assigned)
                total_assigned += assigned_count
                self.stdout.write(f"   - {user.username}: {assigned_count} missões atribuídas")
            except Exception as e:
                self.stdout.write(self.style.ERROR(f"   - {user.username}: erro - {e}"))
        
        self.stdout.write(f"\n   Total: {total_assigned} atribuições para {users.count()} usuários")
