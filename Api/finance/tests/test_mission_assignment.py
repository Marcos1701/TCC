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
    
    def setUp(self):
        self.user = User.objects.create_user(
            username="contextuser",
            email="context@test.com",
            password="testpass123"
        )
        
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
        
        self.goal = Goal.objects.create(
            user=self.user,
            title="Viagem",
            target_amount=Decimal("5000.00"),
            current_amount=Decimal("2000.00"),
            deadline=today + timedelta(days=20)
        )
    
    def test_analyze_user_context_structure(self):
        context = analyze_user_context(self.user)
        
        self.assertIn('recent_transactions', context)
        self.assertIn('top_spending_categories', context)
        self.assertIn('expiring_goals', context)
        self.assertIn('at_risk_indicators', context)
        self.assertIn('spending_patterns', context)
        self.assertIn('transaction_count', context)
        self.assertIn('days_active', context)
        self.assertIn('summary', context)
    
    def test_analyze_recent_transactions(self):
        context = analyze_user_context(self.user)
        
        recent = context['recent_transactions']
        self.assertGreater(len(recent), 0)
        self.assertLessEqual(len(recent), 20)
    
    def test_analyze_top_spending_categories(self):
        context = analyze_user_context(self.user)
        
        top_cats = context['top_spending_categories']
        self.assertGreater(len(top_cats), 0)
        
        self.assertEqual(top_cats[0]['category_name'], 'Alimentação')
        self.assertGreater(top_cats[0]['total_spent'], 0)
    
    def test_analyze_expiring_goals(self):
        context = analyze_user_context(self.user)
        
        expiring = context['expiring_goals']
        self.assertEqual(len(expiring), 1)
        self.assertEqual(expiring[0]['name'], 'Viagem')
        self.assertLess(expiring[0]['days_remaining'], 30)


class IdentifyImprovementOpportunitiesTestCase(TestCase):
    
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
        
        profile, _ = UserProfile.objects.get_or_create(user=self.user)
        profile.target_tps = 20
        profile.target_rdr = 35
        profile.target_ili = Decimal("6.0")
        profile.save()
    
    def test_identify_category_growth(self):
        today = timezone.now().date()
        
        for i in range(30, 60):
            Transaction.objects.create(
                user=self.user,
                type=Transaction.TransactionType.EXPENSE,
                category=self.cat_entertainment,
                amount=Decimal("200.00"),
                date=today - timedelta(days=i)
            )
        
        for i in range(0, 30):
            Transaction.objects.create(
                user=self.user,
                type=Transaction.TransactionType.EXPENSE,
                category=self.cat_entertainment,
                amount=Decimal("500.00"),
                date=today - timedelta(days=i)
            )
        
        opportunities = identify_improvement_opportunities(self.user)
        
        category_growth_opps = [o for o in opportunities if o['type'] == 'CATEGORY_GROWTH']
        self.assertGreater(len(category_growth_opps), 0)
        self.assertIn('Entretenimento', category_growth_opps[0]['description'])
    
    def test_identify_stagnant_goal(self):
        today = timezone.now().date()
        
        goal = Goal.objects.create(
            user=self.user,
            title="Emergência",
            target_amount=Decimal("10000.00"),
            current_amount=Decimal("3000.00"),
            deadline=today + timedelta(days=90),
            target_category=self.cat_savings
        )
        
        Transaction.objects.create(
            user=self.user,
            type=Transaction.TransactionType.INCOME,
            category=self.cat_savings,
            amount=Decimal("500.00"),
            date=today - timedelta(days=25)
        )
        
        opportunities = identify_improvement_opportunities(self.user)
        
        stagnant_opps = [o for o in opportunities if o['type'] == 'GOAL_STAGNANT']
        self.assertGreater(len(stagnant_opps), 0)


class CalculateMissionPrioritiesTestCase(TestCase):
    
    def setUp(self):
        self.user = User.objects.create_user(
            username="priouser",
            email="prio@test.com",
            password="testpass123"
        )
        
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
        priorities = calculate_mission_priorities(self.user)
        
        self.assertIsInstance(priorities, list)
        if len(priorities) > 0:
            self.assertIsInstance(priorities[0], tuple)
            self.assertIsInstance(priorities[0][0], Mission)
            self.assertIsInstance(priorities[0][1], float)
    
    def test_priorities_ordered_by_score(self):
        priorities = calculate_mission_priorities(self.user)
        
        scores = [score for _, score in priorities]
        self.assertEqual(scores, sorted(scores, reverse=True))


class AssignMissionsSmartlyTestCase(TestCase):
    
    def setUp(self):
        self.user = User.objects.create_user(
            username="smartuser",
            email="smart@test.com",
            password="testpass123"
        )
        
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
        assigned = assign_missions_smartly(self.user, max_active=3)
        
        self.assertLessEqual(len(assigned), 3)
    
    def test_assign_creates_mission_progress(self):
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
        first = assign_missions_smartly(self.user, max_active=2)
        first_ids = {p.mission.id for p in first}
        
        second = assign_missions_smartly(self.user, max_active=2)
        second_ids = {p.mission.id for p in second}
        
        self.assertEqual(first_ids, second_ids)
    
    def test_assign_fills_available_slots(self):
        assigned = assign_missions_smartly(self.user, max_active=5)
        initial_count = len(assigned)
        
        self.assertGreaterEqual(initial_count, 3)
        
        assigned[0].status = MissionProgress.Status.COMPLETED
        assigned[0].save()
        
        new_assigned = assign_missions_smartly(self.user, max_active=5)
        active_new = [p for p in new_assigned if p.status in [
            MissionProgress.Status.PENDING,
            MissionProgress.Status.ACTIVE
        ]]
        
        self.assertEqual(len(active_new), initial_count)
