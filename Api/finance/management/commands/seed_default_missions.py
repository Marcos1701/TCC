"""
Comando para popular o banco de dados com missões padrão.

Cria 60 missões distribuídas entre os três tiers:
- BEGINNER: 20 missões (5 onboarding + 15 variadas)
- INTERMEDIATE: 20 missões (mix TPS/RDR/ILI)
- ADVANCED: 20 missões (desafios complexos)

Uso:
    python manage.py seed_default_missions

Opções:
    --clear: Remove todas as missões existentes antes de criar
    --tier TIER: Cria apenas para um tier específico (BEGINNER, INTERMEDIATE, ADVANCED)
"""

from django.core.management.base import BaseCommand
from finance.models import Mission, Category
from decimal import Decimal


class Command(BaseCommand):
    help = 'Popula o banco com missões padrão para todos os tiers'

    def add_arguments(self, parser):
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Remove todas as missões existentes antes de criar novas',
        )
        parser.add_argument(
            '--tier',
            type=str,
            choices=['BEGINNER', 'INTERMEDIATE', 'ADVANCED'],
            help='Criar missões apenas para um tier específico',
        )

    def handle(self, *args, **options):
        if options['clear']:
            count = Mission.objects.all().count()
            Mission.objects.all().delete()
            self.stdout.write(
                self.style.WARNING(f'🗑️  {count} missões removidas')
            )

        tier_filter = options.get('tier')
        tiers_to_create = [tier_filter] if tier_filter else ['BEGINNER', 'INTERMEDIATE', 'ADVANCED']

        total_created = 0
        for tier in tiers_to_create:
            self.stdout.write(f'\n📋 Criando missões para {tier}...')
            
            if tier == 'BEGINNER':
                created = self._create_beginner_missions()
            elif tier == 'INTERMEDIATE':
                created = self._create_intermediate_missions()
            else:  # ADVANCED
                created = self._create_advanced_missions()
            
            total_created += created
            self.stdout.write(
                self.style.SUCCESS(f'✅ {created} missões criadas para {tier}')
            )

        self.stdout.write(
            self.style.SUCCESS(f'\n🎉 Total: {total_created} missões criadas com sucesso!')
        )

    def _create_beginner_missions(self):
        """Cria 20 missões para iniciantes (níveis 1-5)."""
        missions = [
            # ===== ONBOARDING (5 missões) =====
            {
                'title': '🎯 Primeiros Passos',
                'description': 'Registre sua primeira transação no sistema e comece sua jornada financeira!',
                'mission_type': 'ONBOARDING',
                'difficulty': 'EASY',
                'priority': 1,
                'reward_points': 50,
                'duration_days': 7,
                'validation_type': 'SNAPSHOT',
                'min_transactions': 1,
                'is_active': True,
            },
            {
                'title': '📊 Conhecendo suas Finanças',
                'description': 'Registre pelo menos 5 transações para termos uma visão inicial dos seus hábitos.',
                'mission_type': 'ONBOARDING',
                'difficulty': 'EASY',
                'priority': 1,
                'reward_points': 100,
                'duration_days': 14,
                'validation_type': 'SNAPSHOT',
                'min_transactions': 5,
                'is_active': True,
            },
            {
                'title': '🎯 Primeira Meta',
                'description': 'Crie sua primeira meta financeira. Pode ser de economia ou redução de gastos!',
                'mission_type': 'ONBOARDING',
                'difficulty': 'EASY',
                'priority': 1,
                'reward_points': 150,
                'duration_days': 14,
                'validation_type': 'GOAL_PROGRESS',
                'goal_progress_target': Decimal('1.00'),  # Qualquer progresso
                'is_active': True,
            },
            {
                'title': '👥 Conecte-se',
                'description': 'Adicione seu primeiro amigo e compare seu progresso!',
                'mission_type': 'ONBOARDING',
                'difficulty': 'EASY',
                'priority': 1,
                'reward_points': 100,
                'duration_days': 30,
                'validation_type': 'SNAPSHOT',
                'is_active': True,
            },
            {
                'title': '📈 Uma Semana Consistente',
                'description': 'Registre pelo menos uma transação por dia durante 7 dias consecutivos.',
                'mission_type': 'ONBOARDING',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 200,
                'duration_days': 14,
                'validation_type': 'CONSISTENCY',
                'requires_consecutive_days': True,
                'min_consecutive_days': 7,
                'is_active': True,
            },
            
            # ===== TPS IMPROVEMENT (5 missões) =====
            {
                'title': '💰 Economizando os Primeiros 5%',
                'description': 'Alcance uma Taxa de Poupança de pelo menos 5%. Pequenos passos fazem diferença!',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'EASY',
                'priority': 2,
                'reward_points': 150,
                'duration_days': 30,
                'validation_type': 'SNAPSHOT',
                'target_tps': Decimal('5.00'),
                'is_active': True,
            },
            {
                'title': '💰 Rumo aos 10%',
                'description': 'Melhore sua poupança para 10% da renda. Você está no caminho certo!',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 200,
                'duration_days': 30,
                'validation_type': 'SNAPSHOT',
                'target_tps': Decimal('10.00'),
                'is_active': True,
            },
            {
                'title': '💵 Aumente suas Receitas',
                'description': 'Registre pelo menos uma receita extra (freelance, venda, etc.) este mês.',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 180,
                'duration_days': 30,
                'validation_type': 'SAVINGS_INCREASE',
                'savings_increase_amount': Decimal('50.00'),
                'is_active': True,
            },
            {
                'title': '🎯 Economize R$ 100',
                'description': 'Aumente suas economias em pelo menos R$ 100 neste período.',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 200,
                'duration_days': 30,
                'validation_type': 'SAVINGS_INCREASE',
                'savings_increase_amount': Decimal('100.00'),
                'is_active': True,
            },
            {
                'title': '📊 Poupança Acima da Média',
                'description': 'Mantenha sua Taxa de Poupança acima de 15% por 14 dias.',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 250,
                'duration_days': 30,
                'validation_type': 'TEMPORAL',
                'target_tps': Decimal('15.00'),
                'is_active': True,
            },
            
            # ===== RDR REDUCTION (5 missões) =====
            {
                'title': '🎯 Controle de Gastos Básico',
                'description': 'Mantenha sua percentual de gastos fixos abaixo de 80%. Evite gastos impulsivos!',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'EASY',
                'priority': 2,
                'reward_points': 150,
                'duration_days': 30,
                'validation_type': 'SNAPSHOT',
                'target_rdr': Decimal('80.00'),
                'is_active': True,
            },
            {
                'title': '📉 Reduzindo Despesas',
                'description': 'Diminua sua percentual de gastos fixos para menos de 70%. Você consegue!',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 200,
                'duration_days': 30,
                'validation_type': 'SNAPSHOT',
                'target_rdr': Decimal('70.00'),
                'is_active': True,
            },
            {
                'title': '🍔 Semana Sem Fast Food',
                'description': 'Não gaste com alimentação fora de casa por 7 dias consecutivos.',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 180,
                'duration_days': 14,
                'validation_type': 'CATEGORY_LIMIT',
                'category_spending_limit': Decimal('0.00'),
                'is_active': True,
            },
            {
                'title': '🎮 Lazer Consciente',
                'description': 'Limite seus gastos com lazer e entretenimento em até R$ 150 este mês.',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 200,
                'duration_days': 30,
                'validation_type': 'CATEGORY_LIMIT',
                'category_spending_limit': Decimal('150.00'),
                'is_active': True,
            },
            {
                'title': '💳 Cortando Assinaturas',
                'description': 'Reduza gastos com assinaturas em pelo menos 20% comparado ao mês anterior.',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 220,
                'duration_days': 30,
                'validation_type': 'CATEGORY_REDUCTION',
                'target_reduction_percent': Decimal('20.00'),
                'is_active': True,
            },
            
            # ===== ILI BUILDING (5 missões) =====
            {
                'title': '🚀 Construindo Reserva',
                'description': 'Alcance um Reserva de Emergência de pelo menos 10. Segurança primeiro!',
                'mission_type': 'ILI_BUILDING',
                'difficulty': 'EASY',
                'priority': 2,
                'reward_points': 150,
                'duration_days': 30,
                'validation_type': 'SNAPSHOT',
                'min_ili': Decimal('10.00'),
                'is_active': True,
            },
            {
                'title': '🛡️ Reserva de Emergência Iniciada',
                'description': 'Atinja reserva de 20 - você está criando seu colchão de segurança!',
                'mission_type': 'ILI_BUILDING',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 200,
                'duration_days': 60,
                'validation_type': 'SNAPSHOT',
                'min_ili': Decimal('20.00'),
                'is_active': True,
            },
            {
                'title': '💪 Reserva Sólida',
                'description': 'Chegue a uma reserva de 30 - você está cada vez mais preparado!',
                'mission_type': 'ILI_BUILDING',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 250,
                'duration_days': 60,
                'validation_type': 'SNAPSHOT',
                'min_ili': Decimal('30.00'),
                'is_active': True,
            },
            {
                'title': '🎯 Meta de Poupança',
                'description': 'Crie e complete uma meta de economia de pelo menos R$ 500.',
                'mission_type': 'ILI_BUILDING',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 300,
                'duration_days': 90,
                'validation_type': 'GOAL_PROGRESS',
                'goal_progress_target': Decimal('100.00'),
                'is_active': True,
            },
            {
                'title': '📈 Crescimento Consistente',
                'description': 'Aumente sua reserva em pelo menos 10 dias em 30 dias.',
                'mission_type': 'ILI_BUILDING',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 220,
                'duration_days': 30,
                'validation_type': 'TEMPORAL',
                'min_ili': Decimal('10.00'),  # Incremento mínimo
                'is_active': True,
            },
        ]

        return self._batch_create_missions(missions)

    def _create_intermediate_missions(self):
        """Cria 20 missões para intermediários (níveis 6-15)."""
        missions = [
            # ===== TPS IMPROVEMENT (6 missões) =====
            {
                'title': '💰 Poupança de 20% - Excelente!',
                'description': 'Alcance uma Taxa de Poupança de 20%. Você está indo muito bem!',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 250,
                'duration_days': 30,
                'validation_type': 'SNAPSHOT',
                'target_tps': Decimal('20.00'),
                'is_active': True,
            },
            {
                'title': '🎯 Poupança de 25% - Expert',
                'description': 'Atinja 25% de poupança. Você domina suas finanças!',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 300,
                'duration_days': 30,
                'validation_type': 'SNAPSHOT',
                'target_tps': Decimal('25.00'),
                'is_active': True,
            },
            {
                'title': '💵 Economize R$ 500',
                'description': 'Aumente suas economias em pelo menos R$ 500 neste período.',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 350,
                'duration_days': 60,
                'validation_type': 'SAVINGS_INCREASE',
                'savings_increase_amount': Decimal('500.00'),
                'is_active': True,
            },
            {
                'title': '📊 Poupança Consistente Alto',
                'description': 'Mantenha sua poupança acima de 18% por 30 dias consecutivos.',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 400,
                'duration_days': 45,
                'validation_type': 'TEMPORAL',
                'target_tps': Decimal('18.00'),
                'is_active': True,
            },
            {
                'title': '💰 Investimentos Iniciados',
                'description': 'Registre pelo menos 3 transações de investimento neste trimestre.',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 280,
                'duration_days': 90,
                'validation_type': 'SNAPSHOT',
                'min_transactions': 3,
                'is_active': True,
            },
            {
                'title': '🎯 Meta Ambiciosa',
                'description': 'Complete uma meta de poupança de pelo menos R$ 1.000.',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 450,
                'duration_days': 90,
                'validation_type': 'GOAL_PROGRESS',
                'goal_progress_target': Decimal('100.00'),
                'is_active': True,
            },
            
            # ===== RDR REDUCTION (7 missões) =====
            {
                'title': '📉 Gastos Fixos Controlados - 60%',
                'description': 'Mantenha sua percentual de gastos fixos abaixo de 60%. Controle total!',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 250,
                'duration_days': 30,
                'validation_type': 'SNAPSHOT',
                'target_rdr': Decimal('60.00'),
                'is_active': True,
            },
            {
                'title': '🎯 Gastos Fixos Mínimos - 50%',
                'description': 'Mantenha seus gastos fixos de 50% ou menos. Você é um mestre em controle!',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 350,
                'duration_days': 30,
                'validation_type': 'SNAPSHOT',
                'target_rdr': Decimal('50.00'),
                'is_active': True,
            },
            {
                'title': '🍔 Alimentação Econômica',
                'description': 'Reduza gastos com alimentação em 30% comparado ao mês anterior.',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 280,
                'duration_days': 30,
                'validation_type': 'CATEGORY_REDUCTION',
                'target_reduction_percent': Decimal('30.00'),
                'is_active': True,
            },
            {
                'title': '🚗 Transporte Eficiente',
                'description': 'Limite gastos com transporte em até R$ 300 este mês.',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 260,
                'duration_days': 30,
                'validation_type': 'CATEGORY_LIMIT',
                'category_spending_limit': Decimal('300.00'),
                'is_active': True,
            },
            {
                'title': '🎮 Lazer Otimizado',
                'description': 'Reduza gastos com lazer em 40% sem perder a diversão!',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 320,
                'duration_days': 30,
                'validation_type': 'CATEGORY_REDUCTION',
                'target_reduction_percent': Decimal('40.00'),
                'is_active': True,
            },
            {
                'title': '💳 Dívidas sob Controle',
                'description': 'Reduza pagamentos de dívidas em 25% através de quitações.',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 400,
                'duration_days': 60,
                'validation_type': 'CATEGORY_REDUCTION',
                'target_reduction_percent': Decimal('25.00'),
                'is_active': True,
            },
            {
                'title': '🛒 Compras Planejadas',
                'description': 'Não ultrapasse R$ 400 em compras não essenciais este mês.',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 270,
                'duration_days': 30,
                'validation_type': 'CATEGORY_LIMIT',
                'category_spending_limit': Decimal('400.00'),
                'is_active': True,
            },
            
            # ===== ILI BUILDING (5 missões) =====
            {
                'title': '🛡️ Reserva de 50 dias - Segurança Forte',
                'description': 'Alcance um Nível de Impulso de 50. Sua reserva está sólida!',
                'mission_type': 'ILI_BUILDING',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 300,
                'duration_days': 60,
                'validation_type': 'SNAPSHOT',
                'min_ili': Decimal('50.00'),
                'is_active': True,
            },
            {
                'title': '💪 Reserva de 75 dias - Quase Lá!',
                'description': 'Atinja Reserva de 75 dias. Você está construindo riqueza real!',
                'mission_type': 'ILI_BUILDING',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 400,
                'duration_days': 90,
                'validation_type': 'SNAPSHOT',
                'min_ili': Decimal('75.00'),
                'is_active': True,
            },
            {
                'title': '🎯 Fundo de Emergência R$ 2.000',
                'description': 'Complete uma meta de economia de pelo menos R$ 2.000.',
                'mission_type': 'ILI_BUILDING',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 500,
                'duration_days': 120,
                'validation_type': 'GOAL_PROGRESS',
                'goal_progress_target': Decimal('100.00'),
                'is_active': True,
            },
            {
                'title': '📈 Crescimento Acelerado',
                'description': 'Aumente sua reserva em pelo menos 20 dias em 45 dias.',
                'mission_type': 'ILI_BUILDING',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 380,
                'duration_days': 45,
                'validation_type': 'TEMPORAL',
                'min_ili': Decimal('20.00'),
                'is_active': True,
            },
            {
                'title': '💰 Múltiplas Metas',
                'description': 'Tenha pelo menos 3 metas ativas simultaneamente e progrida em todas.',
                'mission_type': 'ILI_BUILDING',
                'difficulty': 'MEDIUM',
                'priority': 2,
                'reward_points': 320,
                'duration_days': 60,
                'validation_type': 'SNAPSHOT',
                'is_active': True,
            },
            
            # ===== ADVANCED (2 missões) =====
            {
                'title': '🏆 Mestre da Consistência',
                'description': 'Registre pelo menos uma transação por dia durante 30 dias consecutivos.',
                'mission_type': 'ADVANCED',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 500,
                'duration_days': 45,
                'validation_type': 'CONSISTENCY',
                'requires_consecutive_days': True,
                'min_consecutive_days': 30,
                'is_active': True,
            },
            {
                'title': '📊 Equilíbrio Perfeito',
                'description': 'Mantenha Poupança > 20%, Gastos Fixos < 60% e Reserva > 50 dias simultaneamente por 14 dias.',
                'mission_type': 'ADVANCED',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 600,
                'duration_days': 30,
                'validation_type': 'TEMPORAL',
                'target_tps': Decimal('20.00'),
                'target_rdr': Decimal('60.00'),
                'min_ili': Decimal('50.00'),
                'is_active': True,
            },
        ]

        return self._batch_create_missions(missions)

    def _create_advanced_missions(self):
        """Cria 20 missões para avançados (níveis 16+)."""
        missions = [
            # ===== TPS IMPROVEMENT (6 missões) =====
            {
                'title': '💎 Poupança de 30% - Elite',
                'description': 'Alcance uma Taxa de Poupança de 30%. Você é exemplo!',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 500,
                'duration_days': 30,
                'validation_type': 'SNAPSHOT',
                'target_tps': Decimal('30.00'),
                'is_active': True,
            },
            {
                'title': '🏆 Poupança de 40% - Lendário',
                'description': 'Atinja 40% de poupança. Você está no topo!',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 700,
                'duration_days': 30,
                'validation_type': 'SNAPSHOT',
                'target_tps': Decimal('40.00'),
                'is_active': True,
            },
            {
                'title': '💰 Economize R$ 1.500',
                'description': 'Aumente suas economias em pelo menos R$ 1.500 neste período.',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 600,
                'duration_days': 60,
                'validation_type': 'SAVINGS_INCREASE',
                'savings_increase_amount': Decimal('1500.00'),
                'is_active': True,
            },
            {
                'title': '📊 Poupança Máxima Sustentado',
                'description': 'Mantenha sua poupança acima de 35% por 60 dias consecutivos.',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 800,
                'duration_days': 90,
                'validation_type': 'TEMPORAL',
                'target_tps': Decimal('35.00'),
                'is_active': True,
            },
            {
                'title': '💎 Portfólio Diversificado',
                'description': 'Registre investimentos em pelo menos 5 categorias diferentes.',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 550,
                'duration_days': 90,
                'validation_type': 'SNAPSHOT',
                'min_transactions': 5,
                'is_active': True,
            },
            {
                'title': '🎯 Meta de R$ 5.000',
                'description': 'Complete uma meta de poupança de pelo menos R$ 5.000.',
                'mission_type': 'TPS_IMPROVEMENT',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 900,
                'duration_days': 180,
                'validation_type': 'GOAL_PROGRESS',
                'goal_progress_target': Decimal('100.00'),
                'is_active': True,
            },
            
            # ===== RDR REDUCTION (6 missões) =====
            {
                'title': '🎯 Gastos Fixos Reduzidos - 40%',
                'description': 'Alcance Gastos Fixos em 40% ou menos. Controle absoluto!',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 500,
                'duration_days': 30,
                'validation_type': 'SNAPSHOT',
                'target_rdr': Decimal('40.00'),
                'is_active': True,
            },
            {
                'title': '💎 Gastos Fixos em 30% - Perfeição',
                'description': 'Atinja Gastos Fixos em 30%. Você é um mestre absoluto!',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 700,
                'duration_days': 30,
                'validation_type': 'SNAPSHOT',
                'target_rdr': Decimal('30.00'),
                'is_active': True,
            },
            {
                'title': '🍔 Alimentação Otimizada',
                'description': 'Reduza gastos com alimentação em 50% mantendo qualidade.',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 550,
                'duration_days': 30,
                'validation_type': 'CATEGORY_REDUCTION',
                'target_reduction_percent': Decimal('50.00'),
                'is_active': True,
            },
            {
                'title': '🏠 Despesas Fixas Mínimas',
                'description': 'Reduza gastos fixos (moradia, contas) em 20%.',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 600,
                'duration_days': 60,
                'validation_type': 'CATEGORY_REDUCTION',
                'target_reduction_percent': Decimal('20.00'),
                'is_active': True,
            },
            {
                'title': '💳 Zero Dívidas',
                'description': 'Elimine completamente gastos com pagamento de dívidas.',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 800,
                'duration_days': 90,
                'validation_type': 'CATEGORY_LIMIT',
                'category_spending_limit': Decimal('0.00'),
                'is_active': True,
            },
            {
                'title': '🎮 Lazer Grátis',
                'description': 'Não gaste com lazer por 30 dias - aproveite opções gratuitas!',
                'mission_type': 'RDR_REDUCTION',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 500,
                'duration_days': 30,
                'validation_type': 'CATEGORY_LIMIT',
                'category_spending_limit': Decimal('0.00'),
                'is_active': True,
            },
            
            # ===== ILI BUILDING (5 missões) =====
            {
                'title': '🏆 Reserva de 100 dias - Clube dos 100 Dias',
                'description': 'Alcance um Nível de Impulso de 100. Você chegou ao topo!',
                'mission_type': 'ILI_BUILDING',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 600,
                'duration_days': 120,
                'validation_type': 'SNAPSHOT',
                'min_ili': Decimal('100.00'),
                'is_active': True,
            },
            {
                'title': '💎 Reserva de 150 dias - Além do Esperado',
                'description': 'Atinja Reserva de 150 dias. Sua independência financeira está próxima!',
                'mission_type': 'ILI_BUILDING',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 800,
                'duration_days': 180,
                'validation_type': 'SNAPSHOT',
                'min_ili': Decimal('150.00'),
                'is_active': True,
            },
            {
                'title': '🎯 Fundo de R$ 10.000',
                'description': 'Complete uma meta de economia de R$ 10.000 ou mais.',
                'mission_type': 'ILI_BUILDING',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 1000,
                'duration_days': 365,
                'validation_type': 'GOAL_PROGRESS',
                'goal_progress_target': Decimal('100.00'),
                'is_active': True,
            },
            {
                'title': '📈 Crescimento Explosivo',
                'description': 'Aumente sua reserva em pelo menos 40 dias em 60 dias.',
                'mission_type': 'ILI_BUILDING',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 650,
                'duration_days': 60,
                'validation_type': 'TEMPORAL',
                'min_ili': Decimal('40.00'),
                'is_active': True,
            },
            {
                'title': '💰 Mestre de Metas',
                'description': 'Complete 5 metas de economia de pelo menos R$ 1.000 cada.',
                'mission_type': 'ILI_BUILDING',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 900,
                'duration_days': 180,
                'validation_type': 'SNAPSHOT',
                'is_active': True,
            },
            
            # ===== ADVANCED (3 missões) =====
            {
                'title': '🏆 Consistência Absoluta',
                'description': 'Registre transações todos os dias por 90 dias consecutivos.',
                'mission_type': 'ADVANCED',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 1000,
                'duration_days': 120,
                'validation_type': 'CONSISTENCY',
                'requires_consecutive_days': True,
                'min_consecutive_days': 90,
                'is_active': True,
            },
            {
                'title': '📊 Equilíbrio Perfeito Sustentado',
                'description': 'Mantenha Poupança > 30%, Gastos Fixos < 40% e Reserva > 100 dias por 30 dias.',
                'mission_type': 'ADVANCED',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 1200,
                'duration_days': 45,
                'validation_type': 'TEMPORAL',
                'target_tps': Decimal('30.00'),
                'target_rdr': Decimal('40.00'),
                'min_ili': Decimal('100.00'),
                'is_active': True,
            },
            {
                'title': '💎 Independência Financeira',
                'description': 'Alcance Poupança > 50%, Gastos Fixos < 30% e Reserva > 200 dias simultaneamente.',
                'mission_type': 'ADVANCED',
                'difficulty': 'HARD',
                'priority': 3,
                'reward_points': 2000,
                'duration_days': 90,
                'validation_type': 'SNAPSHOT',
                'target_tps': Decimal('50.00'),
                'target_rdr': Decimal('30.00'),
                'min_ili': Decimal('200.00'),
                'is_active': True,
            },
        ]

        return self._batch_create_missions(missions)

    def _batch_create_missions(self, missions_data):
        """
        Cria missões em lote a partir de uma lista de dicionários.
        
        Args:
            missions_data: Lista de dicts com dados das missões
            
        Returns:
            int: Número de missões criadas
        """
        created_count = 0
        skipped_count = 0

        for data in missions_data:
            # Verificar se missão já existe (por título)
            existing = Mission.objects.filter(
                title=data['title'],
                is_active=True
            ).exists()

            if existing:
                self.stdout.write(
                    self.style.WARNING(f'  ⏭️  Pulando: {data["title"]} (já existe)')
                )
                skipped_count += 1
                continue

            try:
                # Buscar categoria se especificada
                target_category = None
                if data.get('target_category_name'):
                    target_category = Category.objects.filter(
                        name__icontains=data['target_category_name'],
                        user__isnull=True  # Apenas categorias globais
                    ).first()

                # Criar missão
                Mission.objects.create(
                    title=data['title'],
                    description=data['description'],
                    mission_type=data['mission_type'],
                    difficulty=data['difficulty'],
                    priority=data['priority'],
                    reward_points=data['reward_points'],
                    duration_days=data['duration_days'],
                    validation_type=data.get('validation_type', 'SNAPSHOT'),
                    target_tps=data.get('target_tps'),
                    target_rdr=data.get('target_rdr'),
                    min_ili=data.get('min_ili'),
                    min_transactions=data.get('min_transactions'),
                    target_category=target_category,
                    category_spending_limit=data.get('category_spending_limit'),
                    target_reduction_percent=data.get('target_reduction_percent'),
                    goal_progress_target=data.get('goal_progress_target'),
                    savings_increase_amount=data.get('savings_increase_amount'),
                    requires_consecutive_days=data.get('requires_consecutive_days', False),
                    min_consecutive_days=data.get('min_consecutive_days'),
                    is_active=data['is_active'],
                )
                
                self.stdout.write(f'  ✅ {data["title"]}')
                created_count += 1

            except Exception as e:
                self.stdout.write(
                    self.style.ERROR(f'  ❌ Erro ao criar "{data["title"]}": {str(e)}')
                )

        if skipped_count > 0:
            self.stdout.write(
                self.style.WARNING(f'  ℹ️  {skipped_count} missões puladas (já existentes)')
            )

        return created_count
