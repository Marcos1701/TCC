
from django.core.management.base import BaseCommand
from finance.models import Mission
from finance.mission_templates import (
    ONBOARDING_TEMPLATES,
    TPS_TEMPLATES,
    RDR_TEMPLATES,
    ILI_TEMPLATES,
    CATEGORY_TEMPLATES,
    generate_mission_batch_from_templates
)
from finance.mission_config import MISSION_TYPE_TO_VALIDATION
import random


class Command(BaseCommand):
    help = 'Gera missões em lote a partir de templates (com ou sem IA)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--count',
            type=int,
            default=30,
            help='Número total de missões a gerar',
        )
        parser.add_argument(
            '--type',
            type=str,
            choices=[
                'ONBOARDING',
                'TPS_IMPROVEMENT',
                'RDR_REDUCTION',
                'ILI_BUILDING',
                'CATEGORY_REDUCTION',
                'BEHAVIOR',
                'ADVANCED'
            ],
            help='Tipo específico de missão (padrão: todos)',
        )
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Remove todas as missões existentes antes de criar',
        )
        parser.add_argument(
            '--use-ai',
            type=bool,
            default=True,
            help='Usar IA para personalização (padrão: True)',
        )

    def handle(self, *args, **options):
        if options['clear']:
            count = Mission.objects.all().count()
            Mission.objects.all().delete()
            self.stdout.write(
                self.style.WARNING(f'🗑️  {count} missões removidas')
            )

        count = options['count']
        mission_type = options.get('type')
        use_ai = options['use_ai']

        template_map = {
            'ONBOARDING': ONBOARDING_TEMPLATES,
            'TPS_IMPROVEMENT': TPS_TEMPLATES,
            'RDR_REDUCTION': RDR_TEMPLATES,
            'ILI_BUILDING': ILI_TEMPLATES,
            'CATEGORY_REDUCTION': CATEGORY_TEMPLATES,
        }

        if mission_type:
            templates_to_use = {mission_type: template_map[mission_type]}
        else:
            templates_to_use = template_map

        missions_per_type = count // len(templates_to_use)
        remainder = count % len(templates_to_use)

        total_created = 0

        for idx, (mtype, templates) in enumerate(templates_to_use.items()):
            type_count = missions_per_type + (1 if idx < remainder else 0)

            self.stdout.write(f'\n📋 Gerando {type_count} missões de {mtype}...')

            if use_ai:
                try:
                    self.stdout.write(
                        self.style.WARNING('⚠️  Geração com IA não implementada ainda')
                    )
                    created = self._generate_without_ai(templates, mtype, type_count)
                except Exception as e:
                    self.stdout.write(
                        self.style.WARNING(f'⚠️  Erro ao usar IA: {e}')
                    )
                    self.stdout.write('Gerando sem IA...')
                    created = self._generate_without_ai(templates, mtype, type_count)
            else:
                created = self._generate_without_ai(templates, mtype, type_count)

            total_created += created
            self.stdout.write(
                self.style.SUCCESS(f'✅ {created} missões de {mtype} criadas')
            )

        self.stdout.write(
            self.style.SUCCESS(f'\n🎉 Total: {total_created} missões geradas!')
        )

    def _generate_without_ai(self, templates, mission_type, count):
        created = 0

        for i in range(count):
            template = templates[i % len(templates)]

            mission_data = self._expand_template(template, mission_type)

            mission, was_created = Mission.objects.get_or_create(
                title=mission_data['title'],
                defaults=mission_data
            )

            if was_created:
                created += 1

        return created

    def _expand_template(self, template, mission_type):
        data = {
            'description': template['description'],
            'difficulty': template.get('difficulty', 'MEDIUM'),
            'reward_points': template.get('xp_reward', 100),
            'duration_days': template.get('duration_days', 30),
            'mission_type': mission_type,
            'is_active': True,
        }

        title = template['title']

        if 'min_transactions' in template:
            counts = template['min_transactions']
            count = random.choice(counts)
            title = title.format(count=count)
            description = template['description'].format(count=count)
            data['title'] = title
            data['description'] = description
            data['min_transactions'] = count
            data['validation_type'] = 'TRANSACTION_COUNT'

        elif 'target_tps_ranges' in template:
            ranges = template['target_tps_ranges']
            min_val, max_val = random.choice(ranges)
            target = random.randint(min_val, max_val)
            title = title.format(target=target)
            description = template['description'].format(target=target)
            data['title'] = title
            data['description'] = description
            data['target_tps'] = target
            data['validation_type'] = MISSION_TYPE_TO_VALIDATION.get('TPS_IMPROVEMENT', 'INDICATOR_THRESHOLD')

        elif 'target_rdr_ranges' in template:
            ranges = template['target_rdr_ranges']
            min_val, max_val = random.choice(ranges)
            target = random.randint(min_val, max_val)
            title = title.format(target=target)
            description = template['description'].format(target=target)
            data['title'] = title
            data['description'] = description
            data['target_rdr'] = target
            data['validation_type'] = MISSION_TYPE_TO_VALIDATION.get('RDR_REDUCTION', 'INDICATOR_THRESHOLD')

        elif 'min_ili_ranges' in template:
            ranges = template['min_ili_ranges']
            min_val, max_val = random.choice(ranges)
            target = round(random.uniform(min_val, max_val), 1)
            title = title.format(target=int(target))
            description = template['description'].format(target=int(target))
            data['title'] = title
            data['description'] = description
            data['min_ili'] = target
            data['validation_type'] = 'INDICATOR_THRESHOLD'

        elif 'reduction_percent_ranges' in template:
            ranges = template['reduction_percent_ranges']
            min_val, max_val = random.choice(ranges)
            percent = random.randint(min_val, max_val)
            title = title.format(percent=percent)
            description = template['description'].format(percent=percent)
            data['title'] = title
            data['description'] = description
            data['target_percentage_change'] = percent
            data['validation_type'] = MISSION_TYPE_TO_VALIDATION.get('CATEGORY_REDUCTION', 'CATEGORY_REDUCTION')

        elif '{days}' in title or '{days}' in template['description']:
            days = template.get('duration_days', 30)
            title = title.replace('{days}', str(days))
            description = template['description'].replace('{days}', str(days))
            data['title'] = title
            data['description'] = description
            data['validation_type'] = template.get('validation_type', 'TRANSACTION_CONSISTENCY')

        elif 'criteria' in template:
            criteria_list = template['criteria']
            criteria = random.choice(criteria_list)
            
            title_formatted = title
            desc_formatted = template['description']
            
            if '{tps}' in title or '{tps}' in desc_formatted:
                tps_val = criteria.get('target_tps', 25)
                title_formatted = title_formatted.replace('{tps}', str(tps_val))
                desc_formatted = desc_formatted.replace('{tps}', str(tps_val))
                data['target_tps'] = tps_val
            
            if '{rdr}' in title or '{rdr}' in desc_formatted:
                rdr_val = criteria.get('target_rdr', 30)
                title_formatted = title_formatted.replace('{rdr}', str(rdr_val))
                desc_formatted = desc_formatted.replace('{rdr}', str(rdr_val))
                data['target_rdr'] = rdr_val
            
            if '{ili}' in title or '{ili}' in desc_formatted:
                ili_val = criteria.get('min_ili', 6)
                title_formatted = title_formatted.replace('{ili}', str(int(ili_val)))
                desc_formatted = desc_formatted.replace('{ili}', str(int(ili_val)))
                data['min_ili'] = ili_val
            
            data['title'] = title_formatted
            data['description'] = desc_formatted
            data['validation_type'] = 'MULTI_CRITERIA'

        else:
            data['title'] = title
            data['description'] = template['description']

        if 'description' not in data:
            data['description'] = template['description']

        priority_map = {'EASY': 1, 'MEDIUM': 2, 'HARD': 3}
        data['priority'] = priority_map.get(data['difficulty'], 2)

        return data

    def _create_missions_from_data(self, missions_data, mission_type):
        created = 0

        for data in missions_data:
            if 'mission_type' not in data:
                data['mission_type'] = mission_type

            mission, was_created = Mission.objects.get_or_create(
                title=data.get('title'),
                defaults=data
            )

            if was_created:
                created += 1

        return created
