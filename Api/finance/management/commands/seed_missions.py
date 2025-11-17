"""
Comando para gerar missões em lote a partir de templates usando IA.

Utiliza os templates definidos em mission_templates.py e a IA para:
1. Gerar variações contextualizadas de missões
2. Personalizar títulos e descrições
3. Criar missões para diferentes perfis de usuário
4. Garantir diversidade e coerência

Uso:
    python manage.py seed_missions --count 50
    python manage.py seed_missions --type TPS_IMPROVEMENT --count 10
    python manage.py seed_missions --clear

Opções:
    --count: Número de missões a gerar (padrão: 30)
    --type: Tipo específico de missão (padrão: todos)
    --clear: Remove todas as missões existentes antes de criar
    --use-ai: Usa IA para personalização (padrão: True)
"""

from django.core.management.base import BaseCommand
from finance.models import Mission
from finance.mission_templates import (
    ONBOARDING_TEMPLATES,
    TPS_TEMPLATES,
    RDR_TEMPLATES,
    ILI_TEMPLATES,
    CATEGORY_TEMPLATES,
    GOAL_TEMPLATES,
    BEHAVIOR_TEMPLATES,
    ADVANCED_TEMPLATES,
    generate_mission_batch_from_templates
)
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
                'GOAL_ACHIEVEMENT',
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

        # Mapear tipos para templates
        template_map = {
            'ONBOARDING': ONBOARDING_TEMPLATES,
            'TPS_IMPROVEMENT': TPS_TEMPLATES,
            'RDR_REDUCTION': RDR_TEMPLATES,
            'ILI_BUILDING': ILI_TEMPLATES,
            'CATEGORY_REDUCTION': CATEGORY_TEMPLATES,
            'GOAL_ACHIEVEMENT': GOAL_TEMPLATES,
            'BEHAVIOR': BEHAVIOR_TEMPLATES,
            'ADVANCED': ADVANCED_TEMPLATES,
        }

        # Se tipo específico, usar apenas aquele template
        if mission_type:
            templates_to_use = {mission_type: template_map[mission_type]}
        else:
            templates_to_use = template_map

        # Distribuir count entre os tipos
        missions_per_type = count // len(templates_to_use)
        remainder = count % len(templates_to_use)

        total_created = 0

        for idx, (mtype, templates) in enumerate(templates_to_use.items()):
            # Distribuir remainder nos primeiros tipos
            type_count = missions_per_type + (1 if idx < remainder else 0)

            self.stdout.write(f'\n📋 Gerando {type_count} missões de {mtype}...')

            # Gerar missões usando templates
            if use_ai:
                # Usar geração com IA
                try:
                    # TODO: Implementar chamada correta com métricas do usuário
                    # Por enquanto, gerar sem IA
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
                # Gerar sem IA (apenas expandir templates)
                created = self._generate_without_ai(templates, mtype, type_count)

            total_created += created
            self.stdout.write(
                self.style.SUCCESS(f'✅ {created} missões de {mtype} criadas')
            )

        self.stdout.write(
            self.style.SUCCESS(f'\n🎉 Total: {total_created} missões geradas!')
        )

    def _generate_without_ai(self, templates, mission_type, count):
        """Gera missões expandindo templates sem usar IA"""
        created = 0

        # Repetir templates até atingir count
        for i in range(count):
            template = templates[i % len(templates)]

            # Expandir template com valores variados
            mission_data = self._expand_template(template, mission_type)

            # Criar missão
            mission, was_created = Mission.objects.get_or_create(
                title=mission_data['title'],
                defaults=mission_data
            )

            if was_created:
                created += 1

        return created

    def _expand_template(self, template, mission_type):
        """Expande um template com valores concretos"""
        data = {
            'description': template['description'],
            'difficulty': template.get('difficulty', 'MEDIUM'),
            'reward_points': template.get('xp_reward', 100),
            'duration_days': template.get('duration_days', 30),
            'mission_type': mission_type,
            'is_active': True,
        }

        # Expandir placeholders no título
        title = template['title']

        # Para ONBOARDING: preencher {count}
        if 'min_transactions' in template:
            counts = template['min_transactions']
            count = random.choice(counts)
            title = title.format(count=count)
            data['title'] = title
            data['min_transactions'] = count
            data['validation_type'] = 'TRANSACTION_COUNT'

        # Para TPS: preencher {target}
        elif 'target_tps_ranges' in template:
            ranges = template['target_tps_ranges']
            min_val, max_val = random.choice(ranges)
            target = random.randint(min_val, max_val)
            title = title.format(target=target)
            data['title'] = title
            data['target_tps'] = target
            data['validation_type'] = 'INDICATOR_THRESHOLD'

        # Para RDR: preencher {target}
        elif 'target_rdr_ranges' in template:
            ranges = template['target_rdr_ranges']
            min_val, max_val = random.choice(ranges)
            target = random.randint(min_val, max_val)
            title = title.format(target=target)
            data['title'] = title
            data['target_rdr'] = target
            data['validation_type'] = 'INDICATOR_THRESHOLD'

        # Para ILI: preencher {target}
        elif 'target_ili_ranges' in template:
            ranges = template['target_ili_ranges']
            min_val, max_val = random.choice(ranges)
            target = round(random.uniform(min_val, max_val), 1)
            title = title.format(target=target)
            data['title'] = title
            data['min_ili'] = target
            data['validation_type'] = 'INDICATOR_THRESHOLD'

        # Para CATEGORY: preencher {percent}
        elif 'reduction_percent_ranges' in template:
            ranges = template['reduction_percent_ranges']
            min_val, max_val = random.choice(ranges)
            percent = random.randint(min_val, max_val)
            title = title.format(percent=percent)
            data['title'] = title
            data['target_reduction_percent'] = percent
            data['validation_type'] = 'CATEGORY_REDUCTION'

        # Para GOAL: preencher {percent}
        elif 'progress_percent_ranges' in template:
            ranges = template['progress_percent_ranges']
            min_val, max_val = random.choice(ranges)
            percent = random.randint(min_val, max_val)
            title = title.format(percent=percent)
            data['title'] = title
            data['goal_progress_target'] = percent
            data['validation_type'] = 'GOAL_PROGRESS'

        else:
            # Template sem placeholders
            data['title'] = title

        # Expandir placeholders na descrição
        description = template['description']
        if '{count}' in description and 'min_transactions' in data:
            description = description.format(count=data['min_transactions'])
        elif '{target}' in description:
            if 'target_tps' in data:
                description = description.format(target=data['target_tps'])
            elif 'target_rdr' in data:
                description = description.format(target=data['target_rdr'])
            elif 'min_ili' in data:
                description = description.format(target=data['min_ili'])
        elif '{percent}' in description:
            if 'target_reduction_percent' in data:
                description = description.format(percent=data['target_reduction_percent'])
            elif 'goal_progress_target' in data:
                description = description.format(percent=data['goal_progress_target'])

        data['description'] = description

        # Definir prioridade baseada na dificuldade
        priority_map = {'EASY': 1, 'MEDIUM': 2, 'HARD': 3}
        data['priority'] = priority_map.get(data['difficulty'], 2)

        return data

    def _create_missions_from_data(self, missions_data, mission_type):
        """Cria missões a partir de dados retornados pela IA"""
        created = 0

        for data in missions_data:
            # Adicionar mission_type se não presente
            if 'mission_type' not in data:
                data['mission_type'] = mission_type

            # Criar missão
            mission, was_created = Mission.objects.get_or_create(
                title=data.get('title'),
                defaults=data
            )

            if was_created:
                created += 1

        return created
