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
            description = template['description'].format(count=count)
            data['title'] = title
            data['description'] = description
            data['min_transactions'] = count
            data['validation_type'] = 'TRANSACTION_COUNT'

        # Para TPS: preencher {target}
        elif 'target_tps_ranges' in template:
            ranges = template['target_tps_ranges']
            min_val, max_val = random.choice(ranges)
            target = random.randint(min_val, max_val)
            title = title.format(target=target)
            description = template['description'].format(target=target)
            data['title'] = title
            data['description'] = description
            data['target_tps'] = target
            data['validation_type'] = 'INDICATOR_IMPROVEMENT'

        # Para RDR: preencher {target}
        elif 'target_rdr_ranges' in template:
            ranges = template['target_rdr_ranges']
            min_val, max_val = random.choice(ranges)
            target = random.randint(min_val, max_val)
            title = title.format(target=target)
            description = template['description'].format(target=target)
            data['title'] = title
            data['description'] = description
            data['target_rdr'] = target
            data['validation_type'] = 'INDICATOR_IMPROVEMENT'

        # Para ILI: preencher {target}
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

        # Para CATEGORY: preencher {percent}
        elif 'reduction_percent_ranges' in template:
            ranges = template['reduction_percent_ranges']
            min_val, max_val = random.choice(ranges)
            percent = random.randint(min_val, max_val)
            title = title.format(percent=percent)
            description = template['description'].format(percent=percent)
            data['title'] = title
            data['description'] = description
            data['target_reduction_percent'] = percent
            data['validation_type'] = 'CATEGORY_REDUCTION'

        # Para GOAL: preencher {percent}
        elif 'progress_percent_ranges' in template:
            ranges = template['progress_percent_ranges']
            min_val, max_val = random.choice(ranges)
            percent = random.randint(min_val, max_val)
            title = title.format(percent=percent)
            description = template['description'].format(percent=percent)
            data['title'] = title
            data['description'] = description
            data['goal_progress_target'] = percent
            data['validation_type'] = 'GOAL_PROGRESS'

        # Para BEHAVIOR com {days}
        elif '{days}' in title or '{days}' in template['description']:
            days = template.get('duration_days', 30)
            title = title.replace('{days}', str(days))
            description = template['description'].replace('{days}', str(days))
            data['title'] = title
            data['description'] = description
            data['validation_type'] = template.get('validation_type', 'TRANSACTION_CONSISTENCY')

        # Para ADVANCED com múltiplos critérios
        elif 'criteria' in template:
            criteria_list = template['criteria']
            criteria = random.choice(criteria_list)
            
            # Substituir todos os placeholders
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
            # Template sem placeholders
            data['title'] = title
            data['description'] = template['description']

        # Descrição já foi formatada acima, mas garantir que não tenha placeholders restantes
        if 'description' not in data:
            data['description'] = template['description']

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
