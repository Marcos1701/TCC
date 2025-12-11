import logging

from django.core.management.base import BaseCommand

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Gera missões adicionais usando Gemini AI ou templates'

    def add_arguments(self, parser):
        parser.add_argument(
            '--count',
            type=int,
            default=10,
            help='Número de missões a gerar (padrão: 10)',
        )
        parser.add_argument(
            '--tier',
            type=str,
            choices=['BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'ALL'],
            default='ALL',
            help='Tier para gerar missões (padrão: ALL)',
        )
        parser.add_argument(
            '--templates-only',
            action='store_true',
            help='Usar apenas templates, sem IA',
        )

    def handle(self, *args, **options):
        from finance.ai_services import generate_general_missions
        from finance.mission_templates import generate_mission_batch_from_templates
        from finance.models import Mission

        count = options['count']
        tier = options['tier']
        use_templates_only = options['templates_only']

        self.stdout.write(f'Gerando {count} missões...')

        tiers = ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'] if tier == 'ALL' else [tier]

        total_created = 0
        for t in tiers:
            self.stdout.write(f'\n📋 Tier: {t}')
            
            # Métricas padrão para geração
            metrics = {
                'tps': 15 if t == 'BEGINNER' else 20 if t == 'INTERMEDIATE' else 30,
                'rdr': 40 if t == 'BEGINNER' else 30 if t == 'INTERMEDIATE' else 20,
                'ili': 1 if t == 'BEGINNER' else 3 if t == 'INTERMEDIATE' else 6,
            }
            
            per_tier = count // len(tiers)
            
            if use_templates_only:
                # Usa apenas templates
                missions_data = generate_mission_batch_from_templates(
                    tier=t,
                    current_metrics=metrics,
                    count=per_tier
                )
                source = 'templates'
            else:
                # Tenta usar IA via generate_general_missions
                try:
                    result = generate_general_missions(quantidade=per_tier)
                    missions_data = result.get('created', []) if isinstance(result, dict) else []
                    source = 'gemini_ai'
                    if not missions_data:
                        # Fallback para templates se IA falhar
                        self.stdout.write(self.style.WARNING('  ⚠️  IA não retornou missões, usando templates...'))
                        missions_data = generate_mission_batch_from_templates(
                            tier=t,
                            current_metrics=metrics,
                            count=per_tier
                        )
                        source = 'templates (fallback)'
                except Exception as e:
                    self.stdout.write(self.style.WARNING(f'  ⚠️  Erro na IA: {e}'))
                    missions_data = generate_mission_batch_from_templates(
                        tier=t,
                        current_metrics=metrics,
                        count=per_tier
                    )
                    source = 'templates (fallback)'
            
            # Criar missões no banco
            created = 0
            for data in missions_data:
                if isinstance(data, dict):
                    try:
                        # Remove campos que não devem ser passados diretamente
                        data.pop('id', None)
                        data.pop('created_at', None)
                        data.pop('updated_at', None)
                        mission = Mission.objects.create(**data)
                        created += 1
                        self.stdout.write(f'  ✅ {mission.title}')
                    except Exception as e:
                        self.stdout.write(self.style.ERROR(f'  ❌ Erro: {e}'))
            
            self.stdout.write(f'  📊 {created} missões criadas via {source}')
            total_created += created

        self.stdout.write(self.style.SUCCESS(f'\n🎉 Total: {total_created} missões criadas!'))
