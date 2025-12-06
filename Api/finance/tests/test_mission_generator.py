
from decimal import Decimal
from unittest.mock import MagicMock, patch

from django.contrib.auth import get_user_model
from django.test import TestCase

from finance.mission_generator import (
    MissionConfig,
    MissionViabilityValidator,
    UnifiedMissionGenerator,
    UserContext,
    generate_missions,
)
from finance.models import Mission, UserProfile

User = get_user_model()


class UserContextTestCase(TestCase):

    def test_default_for_tier_beginner(self):
        ctx = UserContext.default_for_tier('BEGINNER')
        
        self.assertEqual(ctx.tier, 'BEGINNER')
        self.assertEqual(ctx.level, 3)
        self.assertLess(ctx.tps, 10)
        self.assertGreater(ctx.rdr, 50)
        self.assertLess(ctx.ili, 1)
    
    def test_default_for_tier_intermediate(self):
        ctx = UserContext.default_for_tier('INTERMEDIATE')
        
        self.assertEqual(ctx.tier, 'INTERMEDIATE')
        self.assertEqual(ctx.level, 10)
        self.assertGreater(ctx.tps, 10)
        self.assertLess(ctx.rdr, 50)
    
    def test_default_for_tier_advanced(self):
        ctx = UserContext.default_for_tier('ADVANCED')
        
        self.assertEqual(ctx.tier, 'ADVANCED')
        self.assertGreater(ctx.level, 15)
        self.assertGreater(ctx.tps, 25)
        self.assertLess(ctx.rdr, 30)


class MissionViabilityValidatorTestCase(TestCase):

    def setUp(self):
        self.validator = MissionViabilityValidator()
        self.beginner_ctx = UserContext(
            tier='BEGINNER', level=3, tps=5.0, rdr=55.0, ili=0.5,
            transaction_count=20, has_active_goals=False,
        )
        self.intermediate_ctx = UserContext(
            tier='INTERMEDIATE', level=10, tps=18.0, rdr=40.0, ili=2.5,
            transaction_count=150, has_active_goals=True,
        )
        self.advanced_ctx = UserContext(
            tier='ADVANCED', level=20, tps=28.0, rdr=28.0, ili=6.0,
            transaction_count=500, has_active_goals=True,
            top_expense_categories=['Alimentação', 'Transporte'],
        )

    def test_onboarding_valid_for_beginner(self):
        is_valid, msg = self.validator.validate_onboarding(
            min_transactions=10, duration_days=7, context=self.beginner_ctx
        )
        self.assertTrue(is_valid)
        self.assertIsNone(msg)
    
    def test_onboarding_invalid_for_advanced(self):
        is_valid, msg = self.validator.validate_onboarding(
            min_transactions=10, duration_days=7, context=self.advanced_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("onboarding", msg.lower())
    
    def test_onboarding_too_aggressive(self):
        is_valid, msg = self.validator.validate_onboarding(
            min_transactions=50, duration_days=7, context=self.beginner_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("agressiva", msg.lower())

    def test_tps_improvement_valid(self):
        is_valid, msg = self.validator.validate_tps_improvement(
            target_tps=20.0, duration_days=30, context=self.beginner_ctx
        )
        self.assertTrue(is_valid)
    
    def test_tps_improvement_already_achieved(self):
        is_valid, msg = self.validator.validate_tps_improvement(
            target_tps=15.0, duration_days=30, context=self.intermediate_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("já atinge", msg.lower())
    
    def test_tps_improvement_too_aggressive(self):
        is_valid, msg = self.validator.validate_tps_improvement(
            target_tps=40.0, duration_days=7, context=self.beginner_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("agressiva", msg.lower())

    def test_rdr_reduction_valid(self):
        is_valid, msg = self.validator.validate_rdr_reduction(
            target_rdr=40.0, duration_days=30, context=self.beginner_ctx
        )
        self.assertTrue(is_valid)
    
    def test_rdr_reduction_already_achieved(self):
        is_valid, msg = self.validator.validate_rdr_reduction(
            target_rdr=50.0, duration_days=30, context=self.intermediate_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("já atinge", msg.lower())
    
    def test_rdr_reduction_unrealistic(self):
        is_valid, msg = self.validator.validate_rdr_reduction(
            target_rdr=10.0, duration_days=30, context=self.beginner_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("irrealisticamente", msg.lower())

    def test_ili_building_valid(self):
        is_valid, msg = self.validator.validate_ili_building(
            min_ili=2.0, duration_days=30, context=self.beginner_ctx
        )
        self.assertTrue(is_valid)
    
    def test_ili_building_already_achieved(self):
        is_valid, msg = self.validator.validate_ili_building(
            min_ili=5.0, duration_days=30, context=self.advanced_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("já atinge", msg.lower())
    
    def test_ili_building_too_ambitious_for_beginner(self):
        is_valid, msg = self.validator.validate_ili_building(
            min_ili=10.0, duration_days=30, context=self.beginner_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("iniciantes", msg.lower())

    def test_category_reduction_valid(self):
        is_valid, msg = self.validator.validate_category_reduction(
            target_reduction_percent=15.0, duration_days=30, context=self.advanced_ctx
        )
        self.assertTrue(is_valid)
    
    def test_category_reduction_unrealistic(self):
        is_valid, msg = self.validator.validate_category_reduction(
            target_reduction_percent=60.0, duration_days=30, context=self.advanced_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("irrealista", msg.lower())
    
    def test_category_reduction_no_categories(self):
        is_valid, msg = self.validator.validate_category_reduction(
            target_reduction_percent=15.0, duration_days=30, context=self.beginner_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("categorias", msg.lower())

    def test_goal_achievement_valid(self):
        is_valid, msg = self.validator.validate_goal_achievement(
            goal_progress_target=50.0, duration_days=30, context=self.intermediate_ctx
        )
        self.assertTrue(is_valid)
    
    def test_goal_achievement_no_goals(self):
        is_valid, msg = self.validator.validate_goal_achievement(
            goal_progress_target=50.0, duration_days=30, context=self.beginner_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("metas", msg.lower())


class UnifiedMissionGeneratorTestCase(TestCase):

    def test_generate_batch_beginner(self):
        ctx = UserContext.default_for_tier('BEGINNER')
        generator = UnifiedMissionGenerator(ctx)
        
        result = generator.generate_batch(count=5)
        
        self.assertIn('created', result)
        self.assertIn('failed', result)
        self.assertGreater(len(result['created']), 0)
    
    def test_generate_batch_intermediate(self):
        ctx = UserContext.default_for_tier('INTERMEDIATE')
        generator = UnifiedMissionGenerator(ctx)
        
        result = generator.generate_batch(count=5)
        
        self.assertGreater(len(result['created']), 0)
    
    def test_generate_batch_advanced(self):
        ctx = UserContext.default_for_tier('ADVANCED')
        generator = UnifiedMissionGenerator(ctx)
        
        result = generator.generate_batch(count=5)
        
        self.assertGreater(len(result['created']), 0)
    
    def test_smart_distribution_beginner(self):
        ctx = UserContext(
            tier='BEGINNER', level=2, tps=0.0, rdr=60.0, ili=0.0,
            transaction_count=5, has_active_goals=False,
        )
        generator = UnifiedMissionGenerator(ctx)
        
        dist = generator._get_smart_distribution(10)
        
        self.assertIn('ONBOARDING', dist)
        self.assertGreater(dist.get('ONBOARDING', 0), 0)
    
    def test_smart_distribution_no_goals(self):
        ctx = UserContext(
            tier='INTERMEDIATE', level=10, tps=15.0, rdr=40.0, ili=3.0,
            transaction_count=100, has_active_goals=False,
        )
        generator = UnifiedMissionGenerator(ctx)
        
        dist = generator._get_smart_distribution(10)
        
        self.assertEqual(dist.get('GOAL_ACHIEVEMENT', 0), 0)
    
    def test_no_duplicate_titles(self):
        ctx = UserContext.default_for_tier('INTERMEDIATE')
        generator = UnifiedMissionGenerator(ctx)
        
        result = generator.generate_batch(count=10)
        
        titles = [m.get('title') for m in result['created']]
        unique_titles = set(titles)
        
        self.assertEqual(len(titles), len(unique_titles))
    
    def test_missions_have_required_fields(self):
        ctx = UserContext.default_for_tier('INTERMEDIATE')
        generator = UnifiedMissionGenerator(ctx)
        
        result = generator.generate_batch(count=5)
        
        required_fields = [
            'title', 'description', 'mission_type', 'difficulty',
            'duration_days', 'reward_points', 'is_active',
        ]
        
        for mission in result['created']:
            for field in required_fields:
                self.assertIn(field, mission, f"Campo {field} ausente")
                self.assertIsNotNone(mission[field], f"Campo {field} é None")
    
    def test_xp_within_difficulty_range(self):
        config = MissionConfig()
        ctx = UserContext.default_for_tier('INTERMEDIATE')
        generator = UnifiedMissionGenerator(ctx)
        
        result = generator.generate_batch(count=10)
        
        for mission in result['created']:
            difficulty = mission['difficulty']
            xp = mission['reward_points']
            min_xp, max_xp = config.XP_RANGES[difficulty]
            
            self.assertGreaterEqual(
                xp, min_xp, 
                f"XP {xp} abaixo do mínimo {min_xp} para {difficulty}"
            )
            self.assertLessEqual(
                xp, max_xp, 
                f"XP {xp} acima do máximo {max_xp} para {difficulty}"
            )
    
    def test_duration_within_difficulty_range(self):
        config = MissionConfig()
        ctx = UserContext.default_for_tier('INTERMEDIATE')
        generator = UnifiedMissionGenerator(ctx)
        
        result = generator.generate_batch(count=10)
        
        for mission in result['created']:
            difficulty = mission['difficulty']
            duration = mission['duration_days']
            min_d, max_d = config.DURATION_RANGES[difficulty]
            
            self.assertGreaterEqual(
                duration, min_d,
                f"Duração {duration} abaixo do mínimo {min_d} para {difficulty}"
            )
            self.assertLessEqual(
                duration, max_d,
                f"Duração {duration} acima do máximo {max_d} para {difficulty}"
            )


class GenerateMissionsIntegrationTestCase(TestCase):

    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@test.com',
            password='testpass123',
        )
        self.profile, _ = UserProfile.objects.get_or_create(
            user=self.user,
            defaults={'level': 5}
        )

    def test_generate_for_all_tiers(self):
        result = generate_missions(quantidade=9)
        
        self.assertIn('created', result)
        self.assertIn('summary', result)
        self.assertGreater(result['summary']['total_created'], 0)
    
    def test_generate_for_specific_tier(self):
        result = generate_missions(quantidade=5, tier='BEGINNER')
        
        self.assertIn('created', result)
        self.assertGreater(len(result['created']), 0)
    
    def test_missions_saved_to_database(self):
        initial_count = Mission.objects.count()
        
        result = generate_missions(quantidade=5, tier='INTERMEDIATE')
        
        final_count = Mission.objects.count()
        created_count = result['summary']['total_created']
        
        self.assertEqual(final_count - initial_count, created_count)
    
    def test_generated_missions_are_inactive_pending_validation(self):
        result = generate_missions(quantidade=3, tier='BEGINNER')
        
        for mission_data in result['created']:
            mission = Mission.objects.get(id=mission_data['id'])
            self.assertFalse(mission.is_active)
    
    def test_generated_missions_are_system_generated(self):
        result = generate_missions(quantidade=3, tier='BEGINNER')
        
        for mission_data in result['created']:
            mission = Mission.objects.get(id=mission_data['id'])
            self.assertTrue(mission.is_system_generated)
    
    def test_generated_missions_have_generation_context(self):
        result = generate_missions(quantidade=3, tier='BEGINNER', use_ai=False)
        
        for mission_data in result['created']:
            mission = Mission.objects.get(id=mission_data['id'])
            self.assertIsNotNone(mission.generation_context)
            self.assertIn('source', mission.generation_context)
            self.assertIn(
                mission.generation_context['source'], 
                ['template', 'gemini_ai']
            )
