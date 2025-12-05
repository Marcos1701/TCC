"""
Testes para o gerador unificado de missões.

Este módulo testa as funcionalidades do UnifiedMissionGenerator,
garantindo que:
- Missões são geradas com parâmetros válidos
- Validações de viabilidade funcionam corretamente
- Distribuição por tipo respeita o contexto do usuário
- Missões impossíveis são rejeitadas

Desenvolvido como parte do TCC - Sistema de Educação Financeira Gamificada.
"""

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
    """Testes para a classe UserContext."""

    def test_default_for_tier_beginner(self):
        """Contexto padrão para iniciantes tem valores apropriados."""
        ctx = UserContext.default_for_tier('BEGINNER')
        
        self.assertEqual(ctx.tier, 'BEGINNER')
        self.assertEqual(ctx.level, 3)
        self.assertLess(ctx.tps, 10)
        self.assertGreater(ctx.rdr, 50)
        self.assertLess(ctx.ili, 1)
    
    def test_default_for_tier_intermediate(self):
        """Contexto padrão para intermediários tem valores apropriados."""
        ctx = UserContext.default_for_tier('INTERMEDIATE')
        
        self.assertEqual(ctx.tier, 'INTERMEDIATE')
        self.assertEqual(ctx.level, 10)
        self.assertGreater(ctx.tps, 10)
        self.assertLess(ctx.rdr, 50)
    
    def test_default_for_tier_advanced(self):
        """Contexto padrão para avançados tem valores apropriados."""
        ctx = UserContext.default_for_tier('ADVANCED')
        
        self.assertEqual(ctx.tier, 'ADVANCED')
        self.assertGreater(ctx.level, 15)
        self.assertGreater(ctx.tps, 25)
        self.assertLess(ctx.rdr, 30)


class MissionViabilityValidatorTestCase(TestCase):
    """Testes para o validador de viabilidade de missões."""

    def setUp(self):
        """Configura contextos padrão para testes."""
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
        """Missão de onboarding é válida para iniciantes."""
        is_valid, msg = self.validator.validate_onboarding(
            min_transactions=10, duration_days=7, context=self.beginner_ctx
        )
        self.assertTrue(is_valid)
        self.assertIsNone(msg)
    
    def test_onboarding_invalid_for_advanced(self):
        """Missão de onboarding não faz sentido para usuários avançados."""
        is_valid, msg = self.validator.validate_onboarding(
            min_transactions=10, duration_days=7, context=self.advanced_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("onboarding", msg.lower())
    
    def test_onboarding_too_aggressive(self):
        """Rejeita missão de onboarding muito agressiva."""
        is_valid, msg = self.validator.validate_onboarding(
            min_transactions=50, duration_days=7, context=self.beginner_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("agressiva", msg.lower())

    def test_tps_improvement_valid(self):
        """Missão de TPS válida quando meta é maior que atual."""
        is_valid, msg = self.validator.validate_tps_improvement(
            target_tps=20.0, duration_days=30, context=self.beginner_ctx
        )
        self.assertTrue(is_valid)
    
    def test_tps_improvement_already_achieved(self):
        """Rejeita missão de TPS quando meta já atingida."""
        is_valid, msg = self.validator.validate_tps_improvement(
            target_tps=15.0, duration_days=30, context=self.intermediate_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("já atinge", msg.lower())
    
    def test_tps_improvement_too_aggressive(self):
        """Rejeita missão de TPS muito agressiva."""
        is_valid, msg = self.validator.validate_tps_improvement(
            target_tps=40.0, duration_days=7, context=self.beginner_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("agressiva", msg.lower())

    def test_rdr_reduction_valid(self):
        """Missão de RDR válida quando meta é menor que atual."""
        is_valid, msg = self.validator.validate_rdr_reduction(
            target_rdr=40.0, duration_days=30, context=self.beginner_ctx
        )
        self.assertTrue(is_valid)
    
    def test_rdr_reduction_already_achieved(self):
        """Rejeita missão de RDR quando meta já atingida."""
        is_valid, msg = self.validator.validate_rdr_reduction(
            target_rdr=50.0, duration_days=30, context=self.intermediate_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("já atinge", msg.lower())
    
    def test_rdr_reduction_unrealistic(self):
        """Rejeita RDR muito baixo como irreal."""
        is_valid, msg = self.validator.validate_rdr_reduction(
            target_rdr=10.0, duration_days=30, context=self.beginner_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("irrealisticamente", msg.lower())

    def test_ili_building_valid(self):
        """Missão de ILI válida quando meta é maior que atual."""
        is_valid, msg = self.validator.validate_ili_building(
            min_ili=2.0, duration_days=30, context=self.beginner_ctx
        )
        self.assertTrue(is_valid)
    
    def test_ili_building_already_achieved(self):
        """Rejeita missão de ILI quando meta já atingida."""
        is_valid, msg = self.validator.validate_ili_building(
            min_ili=5.0, duration_days=30, context=self.advanced_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("já atinge", msg.lower())
    
    def test_ili_building_too_ambitious_for_beginner(self):
        """Rejeita ILI muito alto para iniciantes."""
        is_valid, msg = self.validator.validate_ili_building(
            min_ili=10.0, duration_days=30, context=self.beginner_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("iniciantes", msg.lower())

    def test_category_reduction_valid(self):
        """Missão de redução de categoria válida."""
        is_valid, msg = self.validator.validate_category_reduction(
            target_reduction_percent=15.0, duration_days=30, context=self.advanced_ctx
        )
        self.assertTrue(is_valid)
    
    def test_category_reduction_unrealistic(self):
        """Rejeita redução de categoria irreal."""
        is_valid, msg = self.validator.validate_category_reduction(
            target_reduction_percent=60.0, duration_days=30, context=self.advanced_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("irrealista", msg.lower())
    
    def test_category_reduction_no_categories(self):
        """Rejeita quando usuário não tem categorias identificadas."""
        is_valid, msg = self.validator.validate_category_reduction(
            target_reduction_percent=15.0, duration_days=30, context=self.beginner_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("categorias", msg.lower())

    def test_goal_achievement_valid(self):
        """Missão de meta válida quando usuário tem metas."""
        is_valid, msg = self.validator.validate_goal_achievement(
            goal_progress_target=50.0, duration_days=30, context=self.intermediate_ctx
        )
        self.assertTrue(is_valid)
    
    def test_goal_achievement_no_goals(self):
        """Rejeita quando usuário não tem metas ativas."""
        is_valid, msg = self.validator.validate_goal_achievement(
            goal_progress_target=50.0, duration_days=30, context=self.beginner_ctx
        )
        self.assertFalse(is_valid)
        self.assertIn("metas", msg.lower())


class UnifiedMissionGeneratorTestCase(TestCase):
    """Testes para o gerador unificado de missões."""

    def test_generate_batch_beginner(self):
        """Gera lote de missões para iniciantes."""
        ctx = UserContext.default_for_tier('BEGINNER')
        generator = UnifiedMissionGenerator(ctx)
        
        result = generator.generate_batch(count=5)
        
        self.assertIn('created', result)
        self.assertIn('failed', result)
        # Deve gerar pelo menos algumas missões válidas
        self.assertGreater(len(result['created']), 0)
    
    def test_generate_batch_intermediate(self):
        """Gera lote de missões para intermediários."""
        ctx = UserContext.default_for_tier('INTERMEDIATE')
        generator = UnifiedMissionGenerator(ctx)
        
        result = generator.generate_batch(count=5)
        
        self.assertGreater(len(result['created']), 0)
    
    def test_generate_batch_advanced(self):
        """Gera lote de missões para avançados."""
        ctx = UserContext.default_for_tier('ADVANCED')
        generator = UnifiedMissionGenerator(ctx)
        
        result = generator.generate_batch(count=5)
        
        self.assertGreater(len(result['created']), 0)
    
    def test_smart_distribution_beginner(self):
        """Distribuição para iniciantes favorece onboarding."""
        ctx = UserContext(
            tier='BEGINNER', level=2, tps=0.0, rdr=60.0, ili=0.0,
            transaction_count=5, has_active_goals=False,
        )
        generator = UnifiedMissionGenerator(ctx)
        
        dist = generator._get_smart_distribution(10)
        
        # Onboarding deve ter peso maior para iniciantes com poucas transações
        self.assertIn('ONBOARDING', dist)
        self.assertGreater(dist.get('ONBOARDING', 0), 0)
    
    def test_smart_distribution_no_goals(self):
        """Não gera missões de meta quando usuário não tem metas."""
        ctx = UserContext(
            tier='INTERMEDIATE', level=10, tps=15.0, rdr=40.0, ili=3.0,
            transaction_count=100, has_active_goals=False,
        )
        generator = UnifiedMissionGenerator(ctx)
        
        dist = generator._get_smart_distribution(10)
        
        # GOAL_ACHIEVEMENT deve ser 0 quando não há metas
        self.assertEqual(dist.get('GOAL_ACHIEVEMENT', 0), 0)
    
    def test_no_duplicate_titles(self):
        """Não gera missões com títulos duplicados."""
        ctx = UserContext.default_for_tier('INTERMEDIATE')
        generator = UnifiedMissionGenerator(ctx)
        
        result = generator.generate_batch(count=10)
        
        titles = [m.get('title') for m in result['created']]
        unique_titles = set(titles)
        
        # Todos os títulos devem ser únicos
        self.assertEqual(len(titles), len(unique_titles))
    
    def test_missions_have_required_fields(self):
        """Missões geradas têm todos os campos obrigatórios."""
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
        """XP está dentro do range da dificuldade."""
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
        """Duração está dentro do range da dificuldade."""
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
    """Testes de integração para a função generate_missions."""

    def setUp(self):
        """Cria usuário e perfil para testes."""
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
        """Gera missões para todas as tiers quando não especificado."""
        result = generate_missions(quantidade=9)  # 3 por tier
        
        self.assertIn('created', result)
        self.assertIn('summary', result)
        # Deve ter criado algumas missões
        self.assertGreater(result['summary']['total_created'], 0)
    
    def test_generate_for_specific_tier(self):
        """Gera missões para tier específica."""
        result = generate_missions(quantidade=5, tier='BEGINNER')
        
        self.assertIn('created', result)
        # Deve ter criado missões
        self.assertGreater(len(result['created']), 0)
    
    def test_missions_saved_to_database(self):
        """Missões geradas são salvas no banco."""
        initial_count = Mission.objects.count()
        
        result = generate_missions(quantidade=5, tier='INTERMEDIATE')
        
        final_count = Mission.objects.count()
        created_count = result['summary']['total_created']
        
        self.assertEqual(final_count - initial_count, created_count)
    
    def test_generated_missions_are_inactive_pending_validation(self):
        """Missões geradas ficam inativas (pendentes de validação)."""
        result = generate_missions(quantidade=3, tier='BEGINNER')
        
        for mission_data in result['created']:
            mission = Mission.objects.get(id=mission_data['id'])
            self.assertFalse(mission.is_active)  # Pendentes de validação
    
    def test_generated_missions_are_system_generated(self):
        """Missões geradas têm is_system_generated=True."""
        result = generate_missions(quantidade=3, tier='BEGINNER')
        
        for mission_data in result['created']:
            mission = Mission.objects.get(id=mission_data['id'])
            self.assertTrue(mission.is_system_generated)
    
    def test_generated_missions_have_generation_context(self):
        """Missões geradas incluem contexto de geração."""
        result = generate_missions(quantidade=3, tier='BEGINNER', use_ai=False)
        
        for mission_data in result['created']:
            mission = Mission.objects.get(id=mission_data['id'])
            self.assertIsNotNone(mission.generation_context)
            self.assertIn('source', mission.generation_context)
            # Source pode ser 'template' ou 'gemini_ai'
            self.assertIn(
                mission.generation_context['source'], 
                ['template', 'gemini_ai']
            )
