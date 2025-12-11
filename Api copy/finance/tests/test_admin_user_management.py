"""
Testes para gerenciamento de usuários no painel administrativo REST.

URLs do painel administrativo:
- Lista de usuários: /api/admin-panel/usuarios/
- Detalhes do usuário: /api/admin-panel/usuarios/{id}/
- Toggle (ativar/desativar): /api/admin-panel/usuarios/{id}/toggle/
"""

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from datetime import timedelta
from decimal import Decimal

from finance.models import Category, Transaction, AdminActionLog, UserProfile, Mission, MissionProgress

User = get_user_model()


class AdminUserManagementTestCase(TestCase):
    """Testes para gerenciamento de usuários no painel administrativo REST."""
    
    # URLs base para os testes
    USERS_URL = '/api/admin-panel/usuarios/'
    
    def user_detail_url(self, user_id):
        """Retorna a URL para detalhes de um usuário específico."""
        return f'/api/admin-panel/usuarios/{user_id}/'
    
    def user_toggle_url(self, user_id):
        """Retorna a URL para toggle (ativar/desativar) de um usuário."""
        return f'/api/admin-panel/usuarios/{user_id}/toggle/'
    
    def setUp(self):
        self.admin_user = User.objects.create_user(
            username='admin',
            email='admin@test.com',
            password='adminpass123',
            is_staff=True,
            is_superuser=True
        )
        
        self.regular_user = User.objects.create_user(
            username='regular',
            email='regular@test.com',
            password='testpass123'
        )
        
        self.beginner_user = User.objects.create_user(
            username='beginner',
            email='beginner@test.com',
            password='testpass123'
        )
        self.beginner_user.userprofile.level = 3
        self.beginner_user.userprofile.experience_points = 200
        self.beginner_user.userprofile.save()
        
        self.intermediate_user = User.objects.create_user(
            username='intermediate',
            email='intermediate@test.com',
            password='testpass123'
        )
        self.intermediate_user.userprofile.level = 10
        self.intermediate_user.userprofile.experience_points = 900
        self.intermediate_user.userprofile.save()
        
        self.advanced_user = User.objects.create_user(
            username='advanced',
            email='advanced@test.com',
            password='testpass123'
        )
        self.advanced_user.userprofile.level = 20
        self.advanced_user.userprofile.experience_points = 1900
        self.advanced_user.userprofile.save()
        
        self.inactive_user = User.objects.create_user(
            username='inactive',
            email='inactive@test.com',
            password='testpass123',
            is_active=False
        )
        
        self.client = APIClient()
    
    # ==================== Testes de Permissão ====================
    
    def test_non_admin_cannot_access_user_list(self):
        """Usuário não-admin não pode acessar lista de usuários."""
        self.client.force_authenticate(user=self.regular_user)
        response = self.client.get(self.USERS_URL)
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    def test_non_admin_cannot_access_user_details(self):
        """Usuário não-admin não pode acessar detalhes de usuário."""
        self.client.force_authenticate(user=self.regular_user)
        response = self.client.get(self.user_detail_url(self.beginner_user.id))
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    def test_non_admin_cannot_toggle_user(self):
        """Usuário não-admin não pode ativar/desativar usuário."""
        self.client.force_authenticate(user=self.regular_user)
        response = self.client.post(
            self.user_toggle_url(self.beginner_user.id),
            {'reason': 'Test reason'}
        )
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    def test_unauthenticated_cannot_access(self):
        """Usuário não autenticado não pode acessar."""
        response = self.client.get(self.USERS_URL)
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
    
    # ==================== Testes de Listagem ====================
    
    def test_admin_can_list_users(self):
        """Admin pode listar usuários."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(self.USERS_URL)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('results', response.data)
        self.assertGreaterEqual(len(response.data['results']), 6)
    
    def test_filter_by_tier_beginner(self):
        """Admin pode filtrar usuários por tier BEGINNER."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(f'{self.USERS_URL}?tier=BEGINNER')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        for user in response.data['results']:
            self.assertLessEqual(user['level'], 5)
    
    def test_filter_by_tier_intermediate(self):
        """Admin pode filtrar usuários por tier INTERMEDIATE."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(f'{self.USERS_URL}?tier=INTERMEDIATE')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        for user in response.data['results']:
            self.assertGreaterEqual(user['level'], 6)
            self.assertLessEqual(user['level'], 15)
    
    def test_filter_by_tier_advanced(self):
        """Admin pode filtrar usuários por tier ADVANCED."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(f'{self.USERS_URL}?tier=ADVANCED')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        for user in response.data['results']:
            self.assertGreaterEqual(user['level'], 16)
    
    def test_filter_by_active_status(self):
        """Admin pode filtrar usuários ativos."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(f'{self.USERS_URL}?is_active=true')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        for user in response.data['results']:
            self.assertTrue(user['is_active'])
    
    def test_filter_by_inactive_status(self):
        """Admin pode filtrar usuários inativos."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(f'{self.USERS_URL}?is_active=false')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        usernames = [u['username'] for u in response.data['results']]
        self.assertIn('inactive', usernames)
    
    def test_search_by_username(self):
        """Admin pode buscar usuários por username."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(f'{self.USERS_URL}?search=beginner')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreater(len(response.data['results']), 0)
        self.assertIn('beginner', response.data['results'][0]['username'].lower())
    
    def test_search_by_email(self):
        """Admin pode buscar usuários por email."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(f'{self.USERS_URL}?search=advanced@test.com')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreater(len(response.data['results']), 0)
    
    def test_ordering_by_date_joined(self):
        """Admin pode ordenar usuários por data de cadastro."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(f'{self.USERS_URL}?ordering=-date_joined')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreater(len(response.data['results']), 0)
    
    # ==================== Testes de Detalhes ====================
    
    def test_admin_can_view_user_details(self):
        """Admin pode ver detalhes de um usuário."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(self.user_detail_url(self.beginner_user.id))
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verifica campos principais
        self.assertIn('id', response.data)
        self.assertIn('username', response.data)
        self.assertIn('email', response.data)
        self.assertIn('profile', response.data)
        self.assertIn('stats', response.data)
        self.assertIn('recent_transactions', response.data)
        self.assertIn('active_missions', response.data)
        self.assertIn('admin_actions', response.data)
        
        # Verifica valores do profile
        self.assertEqual(response.data['profile']['level'], 3)
        self.assertEqual(response.data['profile']['experience_points'], 200)
    
    def test_user_details_includes_statistics(self):
        """Detalhes do usuário incluem estatísticas financeiras."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(self.user_detail_url(self.intermediate_user.id))
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        stats = response.data['stats']
        self.assertIn('tps', stats)
        self.assertIn('rdr', stats)
        self.assertIn('ili', stats)
    
    # ==================== Testes de Ativação/Desativação ====================
    
    def test_admin_can_deactivate_user(self):
        """Admin pode desativar usuário via toggle."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            self.user_toggle_url(self.beginner_user.id),
            {'reason': 'Violação dos termos de uso'}
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['sucesso'])
        self.assertFalse(response.data['ativo'])
        
        self.beginner_user.refresh_from_db()
        self.assertFalse(self.beginner_user.is_active)
    
    def test_admin_cannot_deactivate_self(self):
        """Admin não pode desativar a si mesmo."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            self.user_toggle_url(self.admin_user.id),
            {'reason': 'Auto desativação'}
        )
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('erro', response.data)
    
    def test_toggle_creates_admin_log(self):
        """Toggle cria log de ação administrativa."""
        self.client.force_authenticate(user=self.admin_user)
        
        logs_before = AdminActionLog.objects.count()
        
        self.client.post(
            self.user_toggle_url(self.beginner_user.id),
            {'reason': 'Test reason'}
        )
        
        logs_after = AdminActionLog.objects.count()
        self.assertEqual(logs_after, logs_before + 1)
        
        log = AdminActionLog.objects.latest('timestamp')
        self.assertEqual(log.admin_user, self.admin_user)
        self.assertEqual(log.target_user, self.beginner_user)
        self.assertEqual(log.action_type, AdminActionLog.ActionType.USER_DEACTIVATED)
        self.assertIn('Test reason', log.reason)
    
    def test_admin_can_reactivate_user(self):
        """Admin pode reativar usuário via toggle."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            self.user_toggle_url(self.inactive_user.id),
            {'reason': 'Apelação aceita'}
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['sucesso'])
        self.assertTrue(response.data['ativo'])
        
        self.inactive_user.refresh_from_db()
        self.assertTrue(self.inactive_user.is_active)
    
    # ==================== Testes de Workflow Completo ====================
    
    def test_full_workflow_toggle_user(self):
        """Testa fluxo completo de desativar e reativar usuário."""
        self.client.force_authenticate(user=self.admin_user)
        
        # Desativar
        response1 = self.client.post(
            self.user_toggle_url(self.intermediate_user.id),
            {'reason': 'Teste completo'}
        )
        self.assertEqual(response1.status_code, status.HTTP_200_OK)
        
        self.intermediate_user.refresh_from_db()
        self.assertFalse(self.intermediate_user.is_active)
        
        # Reativar
        response2 = self.client.post(
            self.user_toggle_url(self.intermediate_user.id),
            {'reason': 'Teste completo - reativação'}
        )
        self.assertEqual(response2.status_code, status.HTTP_200_OK)
        
        self.intermediate_user.refresh_from_db()
        self.assertTrue(self.intermediate_user.is_active)


class AdminActionLogModelTest(TestCase):
    """Testes para o modelo AdminActionLog."""
    
    def setUp(self):
        self.admin = User.objects.create_user(
            username='admin',
            password='admin123',
            is_staff=True
        )
        
        self.user = User.objects.create_user(
            username='testuser',
            password='test123'
        )
    
    def test_create_log_with_all_fields(self):
        """Testa criação de log com todos os campos."""
        log = AdminActionLog.objects.create(
            admin_user=self.admin,
            target_user=self.user,
            action_type=AdminActionLog.ActionType.XP_ADJUSTED,
            old_value='100',
            new_value='200',
            reason='Test reason',
            ip_address='127.0.0.1'
        )
        
        self.assertEqual(log.admin_user, self.admin)
        self.assertEqual(log.target_user, self.user)
        self.assertEqual(log.action_type, 'XP_ADJUSTED')
        self.assertEqual(log.ip_address, '127.0.0.1')
    
    def test_log_timestamp_auto_generated(self):
        """Testa que timestamp é gerado automaticamente."""
        log = AdminActionLog.log_action(
            admin_user=self.admin,
            target_user=self.user,
            action_type=AdminActionLog.ActionType.OTHER,
            reason='Test'
        )
        
        self.assertIsNotNone(log.timestamp)
        self.assertLessEqual(
            (timezone.now() - log.timestamp).total_seconds(),
            5
        )
    
    def test_action_type_choices(self):
        """Testa que todos os tipos de ação esperados existem."""
        expected_types = [
            'USER_DEACTIVATED',
            'USER_REACTIVATED',
            'XP_ADJUSTED',
            'LEVEL_ADJUSTED',
            'PROFILE_UPDATED',
            'MISSIONS_RESET',
            'TRANSACTIONS_DELETED',
            'OTHER'
        ]
        
        for action_type in expected_types:
            self.assertIn(
                action_type,
                [choice[0] for choice in AdminActionLog.ActionType.choices]
            )
    
    def test_admin_action_log_ordering(self):
        """Testa ordenação de logs (mais recentes primeiro)."""
        log1 = AdminActionLog.log_action(
            admin_user=self.admin,
            target_user=self.user,
            action_type=AdminActionLog.ActionType.OTHER,
            reason='First'
        )
        
        log2 = AdminActionLog.log_action(
            admin_user=self.admin,
            target_user=self.user,
            action_type=AdminActionLog.ActionType.OTHER,
            reason='Second'
        )
        
        log3 = AdminActionLog.log_action(
            admin_user=self.admin,
            target_user=self.user,
            action_type=AdminActionLog.ActionType.OTHER,
            reason='Third'
        )
        
        logs = AdminActionLog.objects.filter(target_user=self.user)
        
        # Mais recentes primeiro
        self.assertEqual(logs[0].id, log3.id)
        self.assertEqual(logs[1].id, log2.id)
        self.assertEqual(logs[2].id, log1.id)
    
    def test_admin_action_log_handles_json_values(self):
        """Testa que valores complexos são convertidos para JSON."""
        complex_value = {'level': 5, 'xp': 400, 'missions': [1, 2, 3]}
        
        log = AdminActionLog.log_action(
            admin_user=self.admin,
            target_user=self.user,
            action_type=AdminActionLog.ActionType.PROFILE_UPDATED,
            old_value=complex_value,
            new_value={'level': 6, 'xp': 500},
            reason='Test complex'
        )
        
        self.assertIsInstance(log.old_value, str)
        self.assertIsInstance(log.new_value, str)
        self.assertIn('"level"', log.old_value)
    
    def test_admin_action_log_can_be_null_admin(self):
        """Testa que admin pode ser nulo (ações do sistema)."""
        log = AdminActionLog.log_action(
            admin_user=None,
            target_user=self.user,
            action_type=AdminActionLog.ActionType.OTHER,
            reason='Automated system action'
        )
        
        self.assertIsNone(log.admin_user)
        self.assertIn('Sistema', str(log))
