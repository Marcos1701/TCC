
from django.core.management.base import BaseCommand
from finance.models import Mission
from decimal import Decimal
import logging

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Migra missões do formato antigo para o novo formato (Sprint 3)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Simula a migração sem salvar alterações',
        )
        parser.add_argument(
            '--verbose',
            action='store_true',
            help='Mostra informações detalhadas de cada missão',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        verbose = options['verbose']
        
        self.stdout.write(self.style.SUCCESS('🚀 Iniciando migração de missões...'))
        
        if dry_run:
            self.stdout.write(self.style.WARNING('⚠️  Modo DRY-RUN ativado - nenhuma alteração será salva'))
        
        mission_type_mapping = {
            'ONBOARDING': 'ONBOARDING_TRANSACTIONS',
            'TPS_IMPROVEMENT': 'TPS_IMPROVEMENT',
            'RDR_REDUCTION': 'RDR_REDUCTION',
            'ILI_BUILDING': 'ILI_BUILDING',
            'ADVANCED': 'FINANCIAL_HEALTH',
        }
        
        validation_type_mapping = {
            'SNAPSHOT': 'TRANSACTION_COUNT',
            'TEMPORAL': 'TRANSACTION_CONSISTENCY',
            'CATEGORY_REDUCTION': 'CATEGORY_REDUCTION',
            'SAVINGS_INCREASE': 'INDICATOR_IMPROVEMENT',
            'CONSISTENCY': 'TRANSACTION_CONSISTENCY',
        }
        
        missions = Mission.objects.all()
        total_missions = missions.count()
        updated_count = 0
        skipped_count = 0
        
        self.stdout.write(f'\n📊 Total de missões encontradas: {total_missions}')
        
        for mission in missions:
            old_mission_type = mission.mission_type
            old_validation_type = mission.validation_type
            
            needs_update = False
            changes = []
            
            if old_mission_type in mission_type_mapping:
                new_mission_type = mission_type_mapping[old_mission_type]
                if new_mission_type != old_mission_type:
                    mission.mission_type = new_mission_type
                    changes.append(f"mission_type: {old_mission_type} → {new_mission_type}")
                    needs_update = True
            
            if old_validation_type in validation_type_mapping:
                new_validation_type = validation_type_mapping[old_validation_type]
                if new_validation_type != old_validation_type:
                    mission.validation_type = new_validation_type
                    changes.append(f"validation_type: {old_validation_type} → {new_validation_type}")
                    needs_update = True
            
            if self._fill_new_fields(mission):
                changes.append("novos campos preenchidos")
                needs_update = True
            
            if not mission.is_system_generated:
                mission.is_system_generated = True
                mission.generation_context = {
                    'source': 'migration_sprint3',
                    'original_mission_type': old_mission_type,
                    'original_validation_type': old_validation_type,
                    'migrated_at': str(mission.updated_at)
                }
                changes.append("marcado como system_generated")
                needs_update = True
            
            if needs_update:
                if verbose:
                    self.stdout.write(f'\n  📝 Missão: {mission.title}')
                    for change in changes:
                        self.stdout.write(f'     - {change}')
                
                if not dry_run:
                    mission.save()
                
                updated_count += 1
            else:
                skipped_count += 1
        
        self.stdout.write('\n' + '='*60)
        self.stdout.write(self.style.SUCCESS(f'✅ Migração concluída!'))
        self.stdout.write(f'   Total processado: {total_missions}')
        self.stdout.write(self.style.SUCCESS(f'   Atualizadas: {updated_count}'))
        self.stdout.write(f'   Ignoradas: {skipped_count}')
        
        if dry_run:
            self.stdout.write(self.style.WARNING('\n⚠️  DRY-RUN: Nenhuma alteração foi salva no banco'))
    
    def _fill_new_fields(self, mission) -> bool:
        changed = False
        
        if mission.transaction_type_filter == 'ALL':
            if 'INCOME' in mission.mission_type:
                mission.transaction_type_filter = 'INCOME'
                changed = True
            elif 'EXPENSE' in mission.mission_type or 'CATEGORY' in mission.mission_type:
                mission.transaction_type_filter = 'EXPENSE'
                changed = True
        
        if 'CONSISTENCY' in mission.validation_type or 'TRANSACTION_CONSISTENCY' in mission.validation_type:
            if mission.min_transaction_frequency is None:
                mission.min_transaction_frequency = 3
                changed = True
        
        if 'PAYMENT' in mission.mission_type:
            if not mission.requires_payment_tracking:
                mission.requires_payment_tracking = True
                mission.min_payments_count = mission.min_payments_count or 5
                changed = True
        
        if 'REDUCTION' in mission.mission_type or 'CATEGORY_REDUCTION' in mission.validation_type:
            if mission.target_reduction_percent is None:
                mission.target_reduction_percent = Decimal('15.00')
                changed = True
        
        if 'LIMIT' in mission.mission_type or 'EXPENSE_CONTROL' in mission.mission_type:
            if mission.category_spending_limit is None:
                if mission.difficulty == 'EASY':
                    mission.category_spending_limit = Decimal('500.00')
                elif mission.difficulty == 'MEDIUM':
                    mission.category_spending_limit = Decimal('300.00')
                else:
                    mission.category_spending_limit = Decimal('200.00')
                changed = True
        
        if 'GOAL' in mission.mission_type:
            if mission.goal_progress_target is None:
                mission.goal_progress_target = Decimal('100.00')
                changed = True
        
        if 'MAINTENANCE' in mission.validation_type or 'STREAK' in mission.mission_type:
            if mission.min_consecutive_days is None:
                mission.min_consecutive_days = min(mission.duration_days, 7)
                changed = True
        
        return changed
