"""Testes para os endpoints da API de missões."""

from decimal import Decimal
from typing import Any, Dict

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APIClient

from finance.models import Category, Goal, Mission

User = get_user_model()


class MissionApiTestCase(TestCase):
    """Testes de integração para `/api/missions/` e ações relacionadas."""

    def setUp(self) -> None:
        """Configura usuários, dados auxiliares e URLs base da API."""
        self.client = APIClient()
        self.missions_url = reverse("mission-list")
        self.by_validation_url = reverse("mission-by-validation-type")
        self.statistics_url = reverse("mission-statistics")

        self.admin_user = User.objects.create_user(
            username="admin",
            email="admin@test.com",
            password="adminpass123",
            is_staff=True,
            is_superuser=True,
        )
        self.regular_user = User.objects.create_user(
            username="regular",
            email="regular@test.com",
            password="regularpass123",
        )

        self.category_food = Category.objects.create(
            name="Alimentação",
            type=Category.CategoryType.EXPENSE,
            color="#FF5733",
            group=Category.CategoryGroup.ESSENTIAL_EXPENSE,
            user=None,
        )
        self.category_transport = Category.objects.create(
            name="Transporte",
            type=Category.CategoryType.EXPENSE,
            color="#3355FF",
            group=Category.CategoryGroup.ESSENTIAL_EXPENSE,
            user=None,
        )

        self.goal = Goal.objects.create(
            user=self.regular_user,
            title="Reserva de emergência",
            description="Economizar para emergências",
            target_amount=Decimal("1000.00"),
            current_amount=Decimal("100.00"),
            initial_amount=Decimal("100.00"),
        )

        self.active_mission = self._create_mission(
            title="Missão Ativa Base",
            min_transactions=3,
        )
        self.inactive_mission = self._create_mission(
            title="Missão Inativa",
            is_active=False,
            min_transactions=20,
        )
        self.category_mission = self._create_mission(
            title="Missão Categoria",
            validation_type=Mission.ValidationType.CATEGORY_LIMIT,
            target_category=self.category_food,
        )
        self.goal_mission = self._create_mission(
            title="Missão Meta",
            validation_type=Mission.ValidationType.GOAL_PROGRESS,
            target_goal=self.goal,
            min_transactions=8,
        )
        self.advanced_mission = self._create_mission(
            title="Missão Avançada",
            min_transactions=18,
        )

    def _create_mission(self, **overrides: Any) -> Mission:
        """Cria uma missão com valores padrão seguros para os testes."""
        sequence = Mission.objects.count() + 1
        payload: Dict[str, Any] = {
            "title": overrides.pop("title", f"Missão {sequence}"),
            "description": overrides.pop(
                "description",
                "Missão criada para testar filtros e estatísticas.",
            ),
            "reward_points": overrides.pop("reward_points", 100),
            "difficulty": overrides.pop(
                "difficulty",
                Mission.Difficulty.MEDIUM,
            ),
            "mission_type": overrides.pop(
                "mission_type",
                Mission.MissionType.ONBOARDING_TRANSACTIONS,
            ),
            "priority": overrides.pop("priority", sequence),
            "min_transactions": overrides.pop("min_transactions", None),
            "duration_days": overrides.pop("duration_days", 30),
            "is_active": overrides.pop("is_active", True),
            "validation_type": overrides.pop(
                "validation_type",
                Mission.ValidationType.TRANSACTION_COUNT,
            ),
            "requires_consecutive_days": overrides.pop(
                "requires_consecutive_days",
                False,
            ),
            "min_consecutive_days": overrides.pop(
                "min_consecutive_days",
                None,
            ),
            "target_category": overrides.pop("target_category", None),
            "target_goal": overrides.pop("target_goal", None),
            "transaction_type_filter": overrides.pop(
                "transaction_type_filter",
                "ALL",
            ),
            "is_system_generated": overrides.pop("is_system_generated", True),
            "generation_context": overrides.pop("generation_context", {}),
        }

        mission = Mission.objects.create(**payload)

        # Relacionamentos ManyToMany (se fornecidos)
        target_categories = overrides.pop("target_categories", None)
        if target_categories:
            mission.target_categories.set(target_categories)

        target_goals = overrides.pop("target_goals", None)
        if target_goals:
            mission.target_goals.set(target_goals)

        return mission

    def test_authentication_required_for_missions_list(self) -> None:
        """Garante que a listagem de missões exige autenticação."""
        response = self.client.get(self.missions_url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_regular_user_only_sees_active_missions(self) -> None:
        """Usuário comum não enxerga missões inativas."""
        self.client.force_authenticate(user=self.regular_user)
        response = self.client.get(self.missions_url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        titles = {mission["title"] for mission in response.data["results"]}
        self.assertNotIn(self.inactive_mission.title, titles)
        self.assertIn(self.active_mission.title, titles)

    def test_admin_user_sees_inactive_missions(self) -> None:
        """Admins visualizam inclusive missões desativadas."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(self.missions_url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        titles = {mission["title"] for mission in response.data["results"]}
        self.assertIn(self.inactive_mission.title, titles)

    def test_tier_filter_excludes_high_requirement_missions(self) -> None:
        """Filtro `tier=BEGINNER` remove missões com requisito alto de transações."""
        self.client.force_authenticate(user=self.regular_user)
        response = self.client.get(f"{self.missions_url}?tier=BEGINNER")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        titles = {mission["title"] for mission in response.data["results"]}
        self.assertNotIn(self.inactive_mission.title, titles)
        self.assertNotIn(self.advanced_mission.title, titles)
        self.assertIn(self.active_mission.title, titles)

    def test_has_category_filter_returns_only_missions_with_category(self) -> None:
        """Filtro `has_category=true` retorna apenas missões com categoria alvo."""
        self.client.force_authenticate(user=self.regular_user)
        response = self.client.get(f"{self.missions_url}?has_category=true")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreater(len(response.data["results"]), 0)
        for mission in response.data["results"]:
            self.assertIsNotNone(mission["target_category"])

    def test_has_goal_filter_returns_only_missions_with_goal(self) -> None:
        """Filtro `has_goal=true` retorna apenas missões que miram alguma meta."""
        self.client.force_authenticate(user=self.regular_user)
        response = self.client.get(f"{self.missions_url}?has_goal=true")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreater(len(response.data["results"]), 0)
        for mission in response.data["results"]:
            self.assertIsNotNone(mission["target_goal"])

    def test_by_validation_type_action_groups_missions(self) -> None:
        """A ação `by_validation_type` agrupa missões corretamente."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(self.by_validation_url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn(self.category_mission.validation_type, response.data)
        grouped = response.data[self.category_mission.validation_type]
        self.assertTrue(
            any(
                item["title"] == self.category_mission.title
                for item in grouped
            )
        )

    def test_statistics_endpoint_returns_computed_counters(self) -> None:
        """O endpoint de estatísticas retorna contadores coerentes."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(self.statistics_url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["total"], Mission.objects.count())
        self.assertEqual(
            response.data["active"], Mission.objects.filter(is_active=True).count()
        )
        self.assertEqual(
            response.data["inactive"], Mission.objects.filter(is_active=False).count()
        )
        self.assertEqual(response.data["with_category"], 1)
        self.assertEqual(response.data["with_goal"], 1)
