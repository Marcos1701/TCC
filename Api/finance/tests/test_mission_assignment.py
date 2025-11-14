"""
Testes para as funções de atribuição contextual de missões.
Sprint 3: Análise contextual e atribuição inteligente.
"""
from decimal import Decimal
from datetime import date, timedelta
from django.test import TestCase
from django.contrib.auth import get_user_model
from django.utils import timezone

from finance.models import (
    Category, 
    Transaction, 
    Goal, 
    Mission, 
    MissionProgress,
    UserProfile
)
from finance.services import (
    analyze_user_context,
    identify_improvement_opportunities,
    calculate_mission_priorities,
    assign_missions_smartly
)

User = get_user_model()


class AnalyzeUserContextTestCase(TestCase):
    """Testes para analyze_user_context()"""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username="contextuser",
            email="context@test.com",
            password="testpass123"
        )
        
        # Criar categorias
        self.cat_food = Category.objects.create(
            user=self.user,
            name="Alimentação",
            group=Category.CategoryGroup.ESSENTIAL_EXPENSE
        )
        self.cat_transport = Category.objects.create(
            user=self.user,
            name="Transporte",
            group=Category.CategoryGroup.ESSENTIAL_EXPENSE
        )
        self.cat_savings = Category.objects.create(
            user=self.user,
            name="Poupança",
            group=Category.CategoryGroup.SAVINGS
        )
        
        # Criar transações recentes
        today = timezone.now().date()
        for i in range(15):
            Transaction.objects.create(
                user=self.user,
                type=Transaction.TransactionType.EXPENSE,
                category=self.cat_food,
                amount=Decimal("150.00"),
                description=f"Mercado {i}",
                date=today - timedelta(days=i)
            )
        
        # Meta próxima de vencer
        self.goal = Goal.objects.create(
            user=self.user,
            title="Viagem",
            target_amount=Decimal("5000.00"),
            current_amount=Decimal("2000.00"),
            deadline=today + timedelta(days=20)
        )
    
    def test_analyze_user_context_structure(self):
        """Testa estrutura do retorno de analyze_user_context"""
        context = analyze_user_context(self.user)
        
        # Verificar chaves principais
        self.assertIn('recent_transactions', context)
        self.assertIn('top_spending_categories', context)
        self.assertIn('expiring_goals', context)
        self.assertIn('at_risk_indicators', context)
        self.assertIn('spending_patterns', context)
        self.assertIn('transaction_count', context)
        self.assertIn('days_active', context)
        self.assertIn('summary', context)
    
    def test_analyze_recent_transactions(self):
        """Testa análise de transações recentes"""
        context = analyze_user_context(self.user)
        
        recent = context['recent_transactions']
        self.assertGreater(len(recent), 0)
        self.assertLessEqual(len(recent), 20)  # Limite de 20
    
    def test_analyze_top_spending_categories(self):
        """Testa identificação de categorias com maior gasto"""
        context = analyze_user_context(self.user)
        
        top_cats = context['top_spending_categories']
        self.assertGreater(len(top_cats), 0)
        
        # Alimentação deve estar no topo
        self.assertEqual(top_cats[0]['category_name'], 'Alimentação')
        self.assertGreater(top_cats[0]['total_spent'], 0)
    
    def test_analyze_expiring_goals(self):
        """Testa identificação de metas próximas de vencer"""
        context = analyze_user_context(self.user)
        
        expiring = context['expiring_goals']
        self.assertEqual(len(expiring), 1)
        self.assertEqual(expiring[0]['name'], 'Viagem')
        self.assertLess(expiring[0]['days_remaining'], 30)


class IdentifyImprovementOpportunitiesTestCase(TestCase):
    """Testes para identify_improvement_opportunities()"""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username="improvuser",
            email="improv@test.com",
            password="testpass123"
        )
        
        self.cat_entertainment = Category.objects.create(
            user=self.user,
            name="Entretenimento",
            group=Category.CategoryGroup.LIFESTYLE_EXPENSE
        )
        
        self.cat_savings = Category.objects.create(
            user=self.user,
            name="Poupança",
            group=Category.CategoryGroup.SAVINGS
        )
        
        # Configurar perfil com metas
        profile, _ = UserProfile.objects.get_or_create(user=self.user)
        profile.target_tps = 20
        profile.target_rdr = 35
        profile.target_ili = Decimal("6.0")
        profile.save()
    
    def test_identify_category_growth(self):
        """Testa detecção de categorias com gasto crescente"""
        today = timezone.now().date()
        
        # Período anterior (30-60 dias): R$ 200/mês
        for i in range(30, 60):
            Transaction.objects.create(
                user=self.user,
                type=Transaction.TransactionType.EXPENSE,
                category=self.cat_entertainment,
                amount=Decimal("200.00"),
                date=today - timedelta(days=i)
            )
        
        # Período recente (0-30 dias): R$ 500/mês (crescimento de 150%)
        for i in range(0, 30):
            Transaction.objects.create(
                user=self.user,
                type=Transaction.TransactionType.EXPENSE,
                category=self.cat_entertainment,
                amount=Decimal("500.00"),
                date=today - timedelta(days=i)
            )
        
        opportunities = identify_improvement_opportunities(self.user)
        
        # Deve identificar crescimento em Entretenimento
        category_growth_opps = [o for o in opportunities if o['type'] == 'CATEGORY_GROWTH']
        self.assertGreater(len(category_growth_opps), 0)
        self.assertIn('Entretenimento', category_growth_opps[0]['description'])
    
    def test_identify_stagnant_goal(self):
        """Testa detecção de metas estagnadas"""
        today = timezone.now().date()
        
        # Meta sem progresso há 20 dias
        goal = Goal.objects.create(
            user=self.user,
            title="Emergência",
            target_amount=Decimal("10000.00"),
            current_amount=Decimal("3000.00"),
            deadline=today + timedelta(days=90)
        )
        
        # Última contribuição foi há 25 dias
        Transaction.objects.create(
            user=self.user,
            type=Transaction.TransactionType.INCOME,
            category=self.cat_savings,
            amount=Decimal("500.00"),
            date=today - timedelta(days=25)
        )
        
        opportunities = identify_improvement_opportunities(self.user)
        
        # Deve identificar meta estagnada
        stagnant_opps = [o for o in opportunities if o['type'] == 'GOAL_STAGNANT']
        self.assertGreater(len(stagnant_opps), 0)


class CalculateMissionPrioritiesTestCase(TestCase):
    """Testes para calculate_mission_priorities()"""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username="priouser",
            email="prio@test.com",
            password="testpass123"
        )
        
        # Criar missões de teste
        self.mission_tps = Mission.objects.create(
            title="Aumentar TPS",
            description="Melhore sua taxa de poupança",
            mission_type=Mission.MissionType.TPS_IMPROVEMENT,
            priority=1,
            reward_points=100,
            difficulty=Mission.Difficulty.MEDIUM,
            is_active=True
        )
        
        self.mission_ili = Mission.objects.create(
            title="Construir Reserva",
            description="Aumente sua reserva de emergência",
            mission_type=Mission.MissionType.ILI_BUILDING,
            priority=2,
            reward_points=150,
            difficulty=Mission.Difficulty.HARD,
            is_active=True
        )
        
        self.mission_onboard = Mission.objects.create(
            title="Primeiras Transações",
            description="Registre suas primeiras transações",
            mission_type=Mission.MissionType.ONBOARDING_TRANSACTIONS,
            priority=1,
            reward_points=50,
            difficulty=Mission.Difficulty.EASY,
            min_transactions=0,
            is_active=True
        )
    
    def test_calculate_priorities_returns_tuples(self):
        """Testa que retorna lista de tuplas (Mission, score)"""
        priorities = calculate_mission_priorities(self.user)
        
        self.assertIsInstance(priorities, list)
        if len(priorities) > 0:
            self.assertIsInstance(priorities[0], tuple)
            self.assertIsInstance(priorities[0][0], Mission)
            self.assertIsInstance(priorities[0][1], float)
    
    def test_priorities_ordered_by_score(self):
        """Testa que prioridades estão ordenadas por score decrescente"""
        priorities = calculate_mission_priorities(self.user)
        
        scores = [score for _, score in priorities]
        self.assertEqual(scores, sorted(scores, reverse=True))


class AssignMissionsSmartlyTestCase(TestCase):
    """Testes para assign_missions_smartly()"""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username="smartuser",
            email="smart@test.com",
            password="testpass123"
        )
        
        # Criar missões
        for i in range(5):
            Mission.objects.create(
                title=f"Missão {i}",
                description=f"Descrição {i}",
                mission_type=Mission.MissionType.TPS_IMPROVEMENT,
                priority=i+1,
                reward_points=100,
                is_active=True
            )
    
    def test_assign_respects_max_active(self):
        """Testa que respeita limite de missões ativas"""
        assigned = assign_missions_smartly(self.user, max_active=3)
        
        self.assertLessEqual(len(assigned), 3)
    
    def test_assign_creates_mission_progress(self):
        """Testa que cria MissionProgress para missões atribuídas"""
        assigned = assign_missions_smartly(self.user, max_active=2)
        
        self.assertGreater(len(assigned), 0)
        
        for progress in assigned:
            self.assertIsInstance(progress, MissionProgress)
            self.assertEqual(progress.user, self.user)
            self.assertIn(progress.status, [
                MissionProgress.Status.PENDING,
                MissionProgress.Status.ACTIVE
            ])
    
    def test_assign_avoids_duplicates(self):
        """Testa que não atribui missões duplicadas"""
        # Primeira atribuição
        first = assign_missions_smartly(self.user, max_active=2)
        first_ids = {p.mission.id for p in first}
        
        # Segunda atribuição deve retornar as mesmas
        second = assign_missions_smartly(self.user, max_active=2)
        second_ids = {p.mission.id for p in second}
        
        self.assertEqual(first_ids, second_ids)
    
    def test_assign_fills_available_slots(self):
        """Testa que preenche slots disponíveis quando uma missão é completada"""
        # Sistema já criou 3 missões de onboarding
        # Atribuir novas missões (max_active=5 para ter slots)
        assigned = assign_missions_smartly(self.user, max_active=5)
        initial_count = len(assigned)
        
        # Deve ter pelo menos as 3 de onboarding
        self.assertGreaterEqual(initial_count, 3)
        
        # Completar uma missão
        assigned[0].status = MissionProgress.Status.COMPLETED
        assigned[0].save()
        
        # Atribuir novamente deve preencher o slot vago
        new_assigned = assign_missions_smartly(self.user, max_active=5)
        active_new = [p for p in new_assigned if p.status in [
            MissionProgress.Status.PENDING,
            MissionProgress.Status.IN_PROGRESS
        ]]
        
        # Deve ter preenchido o slot (initial_count total, pois uma foi completada)
        self.assertEqual(len(active_new), initial_count)
