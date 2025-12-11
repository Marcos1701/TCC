from django.core.management.base import BaseCommand

from finance.models import Mission


class Command(BaseCommand):
    help = 'Cria missões padrão simplificadas para cada tier'

    def handle(self, *args, **kwargs):
        self.stdout.write('Criando missões padrão...')

        missions_data = [
            # BEGINNER - Primeiros passos
            {
                'title': 'Primeiros Passos',
                'description': 'Registre suas primeiras 5 transações para começar sua jornada financeira.',
                'mission_type': Mission.MissionType.ONBOARDING,
                'validation_type': Mission.ValidationType.TRANSACTION_COUNT,
                'difficulty': Mission.Difficulty.EASY,
                'reward_points': 50,
                'duration_days': 7,
                'min_transactions': 5,
                'priority': 1,
            },
            {
                'title': 'Poupança Iniciante',
                'description': 'Alcance uma Taxa de Poupança (TPS) de pelo menos 5%.',
                'mission_type': Mission.MissionType.TPS_IMPROVEMENT,
                'validation_type': Mission.ValidationType.INDICATOR_THRESHOLD,
                'difficulty': Mission.Difficulty.EASY,
                'reward_points': 75,
                'duration_days': 30,
                'target_tps': 5,
                'priority': 2,
            },
            {
                'title': 'Construindo sua Reserva',
                'description': 'Construa uma reserva de emergência que cubra pelo menos 1 mês de despesas.',
                'mission_type': Mission.MissionType.ILI_BUILDING,
                'validation_type': Mission.ValidationType.INDICATOR_THRESHOLD,
                'difficulty': Mission.Difficulty.MEDIUM,
                'reward_points': 100,
                'duration_days': 60,
                'min_ili': 1,
                'priority': 3,
            },

            # INTERMEDIATE
            {
                'title': 'Poupança Sólida',
                'description': 'Mantenha sua TPS acima de 15% durante 30 dias.',
                'mission_type': Mission.MissionType.TPS_IMPROVEMENT,
                'validation_type': Mission.ValidationType.INDICATOR_THRESHOLD,
                'difficulty': Mission.Difficulty.MEDIUM,
                'reward_points': 150,
                'duration_days': 30,
                'target_tps': 15,
                'min_transactions': 10,
                'priority': 4,
            },
            {
                'title': 'Reserva de 3 Meses',
                'description': 'Construa uma reserva que cubra 3 meses de despesas essenciais.',
                'mission_type': Mission.MissionType.ILI_BUILDING,
                'validation_type': Mission.ValidationType.INDICATOR_THRESHOLD,
                'difficulty': Mission.Difficulty.MEDIUM,
                'reward_points': 200,
                'duration_days': 90,
                'min_ili': 3,
                'priority': 5,
            },
            {
                'title': 'Controle de Gastos',
                'description': 'Reduza seus gastos em uma categoria específica em 10%.',
                'mission_type': Mission.MissionType.CATEGORY_REDUCTION,
                'validation_type': Mission.ValidationType.CATEGORY_REDUCTION,
                'difficulty': Mission.Difficulty.MEDIUM,
                'reward_points': 125,
                'duration_days': 30,
                'priority': 6,
            },

            # ADVANCED
            {
                'title': 'Poupança Expert',
                'description': 'Alcance uma TPS de 25% ou mais.',
                'mission_type': Mission.MissionType.TPS_IMPROVEMENT,
                'validation_type': Mission.ValidationType.INDICATOR_THRESHOLD,
                'difficulty': Mission.Difficulty.HARD,
                'reward_points': 250,
                'duration_days': 30,
                'target_tps': 25,
                'min_transactions': 20,
                'priority': 7,
            },
            {
                'title': 'Reserva de 6 Meses',
                'description': 'Construa uma reserva de emergência de 6 meses - o ideal recomendado.',
                'mission_type': Mission.MissionType.ILI_BUILDING,
                'validation_type': Mission.ValidationType.INDICATOR_THRESHOLD,
                'difficulty': Mission.Difficulty.HARD,
                'reward_points': 300,
                'duration_days': 180,
                'min_ili': 6,
                'priority': 8,
            },
            {
                'title': 'Dívidas sob Controle',
                'description': 'Mantenha sua RDR (Razão Dívida-Renda) abaixo de 30%.',
                'mission_type': Mission.MissionType.RDR_REDUCTION,
                'validation_type': Mission.ValidationType.INDICATOR_THRESHOLD,
                'difficulty': Mission.Difficulty.HARD,
                'reward_points': 200,
                'duration_days': 60,
                'target_rdr': 30,
                'priority': 9,
            },
        ]

        created = 0
        for data in missions_data:
            mission, was_created = Mission.objects.get_or_create(
                title=data['title'],
                defaults=data
            )
            if was_created:
                created += 1
                self.stdout.write(f'  ✅ Criada: {mission.title}')
            else:
                self.stdout.write(f'  ⏭️  Já existe: {mission.title}')

        self.stdout.write(self.style.SUCCESS(f'Concluído! {created} novas missões criadas.'))
