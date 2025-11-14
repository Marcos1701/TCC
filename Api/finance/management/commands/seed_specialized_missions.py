"""
Comando para popular o banco com missões especializadas (Sprint 4).

Cria missões específicas para os novos tipos implementados na refatoração:
- CATEGORY_REDUCTION: Reduzir gastos em categorias
- CATEGORY_SPENDING_LIMIT: Manter limites de gastos
- CATEGORY_ELIMINATION: Eliminar gastos supérfluos
- GOAL_ACHIEVEMENT: Completar metas
- GOAL_CONSISTENCY: Contribuir regularmente
- SAVINGS_STREAK: Sequência de poupança
- PAYMENT_DISCIPLINE: Pagar contas em dia
- INCOME_TRACKING: Registrar receitas

Uso:
    python manage.py seed_specialized_missions

Opções:
    --clear: Remove missões especializadas existentes antes de criar
"""

from django.core.management.base import BaseCommand
from finance.models import Mission, Category
from decimal import Decimal


class Command(BaseCommand):
    help = 'Popula o banco com missões especializadas (novos tipos)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Remove missões especializadas existentes antes de criar',
        )

    def handle(self, *args, **options):
        if options['clear']:
            # Remove apenas missões dos novos tipos
            new_types = [
                'CATEGORY_REDUCTION', 'CATEGORY_SPENDING_LIMIT', 'CATEGORY_ELIMINATION',
                'GOAL_ACHIEVEMENT', 'GOAL_CONSISTENCY', 'GOAL_ACCELERATION',
                'SAVINGS_STREAK', 'EXPENSE_CONTROL', 'INCOME_TRACKING',
                'PAYMENT_DISCIPLINE', 'ONBOARDING_CATEGORIES', 'ONBOARDING_GOALS'
            ]
            count = Mission.objects.filter(mission_type__in=new_types).count()
            Mission.objects.filter(mission_type__in=new_types).delete()
            self.stdout.write(
                self.style.WARNING(f'🗑️  {count} missões especializadas removidas')
            )

        self.stdout.write(self.style.SUCCESS('🚀 Criando missões especializadas...'))

        created = 0
        created += self._create_category_missions()
        created += self._create_goal_missions()
        created += self._create_behavior_missions()
        created += self._create_onboarding_missions()

        self.stdout.write(
            self.style.SUCCESS(f'\n🎉 Total: {created} missões especializadas criadas!')
        )

    def _create_category_missions(self):
        """Cria missões focadas em categorias."""
        missions = [
            # CATEGORY_REDUCTION
            {
                'title': '🎯 Reduzir Alimentação em 15%',
                'description': 'Diminua seus gastos com alimentação em 15% comparado ao mês anterior. Planeje refeições e evite desperdícios!',
                'mission_type': 'CATEGORY_REDUCTION',
                'difficulty': 'MEDIUM',
                'priority': 3,
                'reward_points': 300,
                'duration_days': 30,
                'validation_type': 'CATEGORY_REDUCTION',
                'target_reduction_percent': Decimal('15.00'),
                'transaction_type_filter': 'EXPENSE',
                'is_active': True,
                'impacts': [
                    {
                        'title': 'Redução de Despesas',
                        'description': 'Diminui gastos mensais fixos',
                        'icon': '💰',
                        'color': 'green'
                    }
                ],
                'tips': [
                    {
                        'title': 'Planeje suas refeições',
                        'description': 'Faça um cardápio semanal para evitar compras impulsivas',
                        'priority': 1
                    },
                    {
                        'title': 'Aproveite promoções',
                        'description': 'Compare preços e compre produtos em oferta',
                        'priority': 2
                    }
                ]
            },
            {
                'title': '🚗 Economizar 20% no Transporte',
                'description': 'Reduza gastos com transporte em 20%. Considere alternativas como carona ou transporte público.',
                'mission_type': 'CATEGORY_REDUCTION',
                'difficulty': 'MEDIUM',
                'priority': 3,
                'reward_points': 350,
                'duration_days': 30,
                'validation_type': 'CATEGORY_REDUCTION',
                'target_reduction_percent': Decimal('20.00'),
                'transaction_type_filter': 'EXPENSE',
                'is_active': True,
            },
            {
                'title': '🎮 Cortar 30% em Lazer',
                'description': 'Reduza gastos com entretenimento em 30%. Busque alternativas gratuitas ou mais econômicas.',
                'mission_type': 'CATEGORY_REDUCTION',
                'difficulty': 'HARD',
                'priority': 4,
                'reward_points': 400,
                'duration_days': 30,
                'validation_type': 'CATEGORY_REDUCTION',
                'target_reduction_percent': Decimal('30.00'),
                'transaction_type_filter': 'EXPENSE',
                'is_active': True,
            },
            
            # CATEGORY_SPENDING_LIMIT
            {
                'title': '🛍️ Limite de R$ 500 em Compras',
                'description': 'Mantenha seus gastos com compras abaixo de R$ 500 no mês. Planeje antes de comprar!',
                'mission_type': 'CATEGORY_SPENDING_LIMIT',
                'difficulty': 'MEDIUM',
                'priority': 3,
                'reward_points': 250,
                'duration_days': 30,
                'validation_type': 'CATEGORY_LIMIT',
                'category_spending_limit': Decimal('500.00'),
                'transaction_type_filter': 'EXPENSE',
                'is_active': True,
            },
            {
                'title': '☕ Limite de R$ 150 em Cafeteria',
                'description': 'Controle gastos com café e lanches, mantendo abaixo de R$ 150 no mês.',
                'mission_type': 'CATEGORY_SPENDING_LIMIT',
                'difficulty': 'EASY',
                'priority': 2,
                'reward_points': 200,
                'duration_days': 30,
                'validation_type': 'CATEGORY_LIMIT',
                'category_spending_limit': Decimal('150.00'),
                'transaction_type_filter': 'EXPENSE',
                'is_active': True,
            },
            
            # CATEGORY_ELIMINATION
            {
                'title': '🚭 Mês Sem Gastos Supérfluos',
                'description': 'Passe 30 dias sem gastar com cigarro, álcool ou outros vícios. Sua saúde e carteira agradecem!',
                'mission_type': 'CATEGORY_ELIMINATION',
                'difficulty': 'HARD',
                'priority': 5,
                'reward_points': 500,
                'duration_days': 30,
                'validation_type': 'CATEGORY_ZERO',
                'category_spending_limit': Decimal('0.00'),
                'transaction_type_filter': 'EXPENSE',
                'is_active': True,
            },
            
            # EXPENSE_CONTROL
            {
                'title': '📊 Controle Total de Despesas',
                'description': 'Mantenha suas despesas totais abaixo de R$ 2000 no mês. Planejamento é tudo!',
                'mission_type': 'EXPENSE_CONTROL',
                'difficulty': 'MEDIUM',
                'priority': 3,
                'reward_points': 400,
                'duration_days': 30,
                'validation_type': 'CATEGORY_LIMIT',
                'category_spending_limit': Decimal('2000.00'),
                'transaction_type_filter': 'EXPENSE',
                'is_active': True,
            },
        ]
        
        count = 0
        for mission_data in missions:
            Mission.objects.get_or_create(
                title=mission_data['title'],
                defaults=mission_data
            )
            count += 1
        
        self.stdout.write(f'  ✅ {count} missões de categoria criadas')
        return count

    def _create_goal_missions(self):
        """Cria missões focadas em metas."""
        missions = [
            # GOAL_ACHIEVEMENT
            {
                'title': '🎯 Completar Primeira Meta',
                'description': 'Alcance 100% de uma meta que você criou. Persistência é a chave!',
                'mission_type': 'GOAL_ACHIEVEMENT',
                'difficulty': 'MEDIUM',
                'priority': 3,
                'reward_points': 500,
                'duration_days': 60,
                'validation_type': 'GOAL_COMPLETION',
                'goal_progress_target': Decimal('100.00'),
                'is_active': True,
                'impacts': [
                    {
                        'title': 'Meta Concluída',
                        'description': 'Aumenta motivação e disciplina financeira',
                        'icon': '🎯',
                        'color': 'blue'
                    }
                ],
            },
            {
                'title': '📈 Meio Caminho Andado',
                'description': 'Atinja 50% de progresso em qualquer meta ativa. Você está no caminho certo!',
                'mission_type': 'GOAL_ACHIEVEMENT',
                'difficulty': 'EASY',
                'priority': 2,
                'reward_points': 250,
                'duration_days': 30,
                'validation_type': 'GOAL_PROGRESS',
                'goal_progress_target': Decimal('50.00'),
                'is_active': True,
            },
            
            # GOAL_CONSISTENCY
            {
                'title': '💪 Contribuidor Consistente',
                'description': 'Contribua R$ 200 para uma meta durante o mês. Pequenas contribuições regulares fazem a diferença!',
                'mission_type': 'GOAL_CONSISTENCY',
                'difficulty': 'MEDIUM',
                'priority': 3,
                'reward_points': 300,
                'duration_days': 30,
                'validation_type': 'GOAL_CONTRIBUTION',
                'savings_increase_amount': Decimal('200.00'),
                'is_active': True,
            },
            {
                'title': '🚀 Acelerar Meta Principal',
                'description': 'Contribua R$ 500 para sua meta mais importante. Acelere seu progresso!',
                'mission_type': 'GOAL_ACCELERATION',
                'difficulty': 'HARD',
                'priority': 4,
                'reward_points': 600,
                'duration_days': 30,
                'validation_type': 'GOAL_CONTRIBUTION',
                'savings_increase_amount': Decimal('500.00'),
                'is_active': True,
            },
            
            # SAVINGS_STREAK
            {
                'title': '🔥 Sequência de 7 Dias Poupando',
                'description': 'Registre economia ou contribua para metas durante 7 dias consecutivos!',
                'mission_type': 'SAVINGS_STREAK',
                'difficulty': 'MEDIUM',
                'priority': 3,
                'reward_points': 350,
                'duration_days': 14,
                'validation_type': 'TRANSACTION_CONSISTENCY',
                'min_transaction_frequency': 7,
                'transaction_type_filter': 'ALL',
                'requires_consecutive_days': True,
                'min_consecutive_days': 7,
                'is_active': True,
            },
            {
                'title': '🔥 Mês Completo Poupando',
                'description': 'Contribua para economia todos os dias durante 30 dias. Disciplina máxima!',
                'mission_type': 'SAVINGS_STREAK',
                'difficulty': 'HARD',
                'priority': 5,
                'reward_points': 800,
                'duration_days': 30,
                'validation_type': 'TRANSACTION_CONSISTENCY',
                'min_transaction_frequency': 30,
                'transaction_type_filter': 'ALL',
                'requires_consecutive_days': True,
                'min_consecutive_days': 30,
                'is_active': True,
            },
        ]
        
        count = 0
        for mission_data in missions:
            Mission.objects.get_or_create(
                title=mission_data['title'],
                defaults=mission_data
            )
            count += 1
        
        self.stdout.write(f'  ✅ {count} missões de metas criadas')
        return count

    def _create_behavior_missions(self):
        """Cria missões focadas em comportamentos financeiros."""
        missions = [
            # PAYMENT_DISCIPLINE
            {
                'title': '💳 Pagador Disciplinado',
                'description': 'Registre e marque como pagas 5 contas diferentes no mês. Evite juros e multas!',
                'mission_type': 'PAYMENT_DISCIPLINE',
                'difficulty': 'EASY',
                'priority': 2,
                'reward_points': 250,
                'duration_days': 30,
                'validation_type': 'PAYMENT_COUNT',
                'requires_payment_tracking': True,
                'min_payments_count': 5,
                'transaction_type_filter': 'EXPENSE',
                'is_active': True,
                'impacts': [
                    {
                        'title': 'Sem Juros',
                        'description': 'Evita multas e juros por atraso',
                        'icon': '💳',
                        'color': 'green'
                    }
                ],
                'tips': [
                    {
                        'title': 'Configure lembretes',
                        'description': 'Use alarmes para não esquecer vencimentos',
                        'priority': 1
                    }
                ]
            },
            {
                'title': '📅 Mestre dos Pagamentos',
                'description': 'Registre e pague 10 contas durante o mês. Organização financeira total!',
                'mission_type': 'PAYMENT_DISCIPLINE',
                'difficulty': 'MEDIUM',
                'priority': 3,
                'reward_points': 400,
                'duration_days': 30,
                'validation_type': 'PAYMENT_COUNT',
                'requires_payment_tracking': True,
                'min_payments_count': 10,
                'transaction_type_filter': 'EXPENSE',
                'is_active': True,
            },
            
            # INCOME_TRACKING
            {
                'title': '💵 Rastreador de Receitas',
                'description': 'Registre pelo menos 3 receitas durante o mês. Saiba exatamente quanto entra!',
                'mission_type': 'INCOME_TRACKING',
                'difficulty': 'EASY',
                'priority': 2,
                'reward_points': 200,
                'duration_days': 30,
                'validation_type': 'TRANSACTION_COUNT',
                'min_transaction_frequency': 3,
                'transaction_type_filter': 'INCOME',
                'is_active': True,
            },
            {
                'title': '💰 Registrador Consistente',
                'description': 'Registre transações semanalmente durante todo o mês (mínimo 3 por semana).',
                'mission_type': 'INCOME_TRACKING',
                'difficulty': 'MEDIUM',
                'priority': 3,
                'reward_points': 350,
                'duration_days': 30,
                'validation_type': 'TRANSACTION_CONSISTENCY',
                'min_transaction_frequency': 3,
                'transaction_type_filter': 'ALL',
                'is_active': True,
            },
        ]
        
        count = 0
        for mission_data in missions:
            Mission.objects.get_or_create(
                title=mission_data['title'],
                defaults=mission_data
            )
            count += 1
        
        self.stdout.write(f'  ✅ {count} missões de comportamento criadas')
        return count

    def _create_onboarding_missions(self):
        """Cria missões de onboarding especializadas."""
        missions = [
            # ONBOARDING_CATEGORIES
            {
                'title': '📁 Organizador de Categorias',
                'description': 'Crie pelo menos 5 categorias personalizadas para organizar suas transações.',
                'mission_type': 'ONBOARDING_CATEGORIES',
                'difficulty': 'EASY',
                'priority': 1,
                'reward_points': 150,
                'duration_days': 14,
                'validation_type': 'TRANSACTION_COUNT',
                'min_transactions': 5,
                'transaction_type_filter': 'ALL',
                'is_active': True,
            },
            {
                'title': '🎨 Mestre das Categorias',
                'description': 'Use pelo menos 10 categorias diferentes em suas transações durante o mês.',
                'mission_type': 'ONBOARDING_CATEGORIES',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 300,
                'duration_days': 30,
                'validation_type': 'TRANSACTION_COUNT',
                'min_transactions': 10,
                'transaction_type_filter': 'ALL',
                'is_active': True,
            },
            
            # ONBOARDING_GOALS
            {
                'title': '🎯 Primeira Meta Criada',
                'description': 'Crie sua primeira meta financeira. Defina um objetivo e vá em frente!',
                'mission_type': 'ONBOARDING_GOALS',
                'difficulty': 'EASY',
                'priority': 1,
                'reward_points': 200,
                'duration_days': 7,
                'validation_type': 'GOAL_PROGRESS',
                'goal_progress_target': Decimal('1.00'),
                'is_active': True,
            },
            {
                'title': '🚀 Planejador Completo',
                'description': 'Crie 3 metas diferentes (curto, médio e longo prazo). Planeje seu futuro!',
                'mission_type': 'ONBOARDING_GOALS',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 400,
                'duration_days': 14,
                'validation_type': 'GOAL_PROGRESS',
                'goal_progress_target': Decimal('1.00'),
                'is_active': True,
            },
        ]
        
        count = 0
        for mission_data in missions:
            Mission.objects.get_or_create(
                title=mission_data['title'],
                defaults=mission_data
            )
            count += 1
        
        self.stdout.write(f'  ✅ {count} missões de onboarding especializadas criadas')
        return count
