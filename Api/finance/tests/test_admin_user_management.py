
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
    
    
    def test_non_admin_cannot_access_user_list(self):
        self.client.force_authenticate(user=self.regular_user)
        response = self.client.get('/api/admin/users/')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    def test_non_admin_cannot_access_user_details(self):
        self.client.force_authenticate(user=self.regular_user)
        response = self.client.get(f'/api/admin/users/{self.beginner_user.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    def test_non_admin_cannot_deactivate_user(self):
        self.client.force_authenticate(user=self.regular_user)
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/deactivate/',
            {'reason': 'Test reason'}
        )
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    def test_unauthenticated_cannot_access(self):
        response = self.client.get('/api/admin/users/')
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
    
    
    def test_admin_can_list_users(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('results', response.data)
        
        self.assertGreaterEqual(len(response.data['results']), 6)
    
    def test_filter_by_tier_beginner(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/?tier=BEGINNER')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        for user in response.data['results']:
            self.assertLessEqual(user['level'], 5)
    
    def test_filter_by_tier_intermediate(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/?tier=INTERMEDIATE')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        for user in response.data['results']:
            self.assertGreaterEqual(user['level'], 6)
            self.assertLessEqual(user['level'], 15)
    
    def test_filter_by_tier_advanced(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/?tier=ADVANCED')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        for user in response.data['results']:
            self.assertGreaterEqual(user['level'], 16)
    
    def test_filter_by_active_status(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/?is_active=true')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        for user in response.data['results']:
            self.assertTrue(user['is_active'])
    
    def test_filter_by_inactive_status(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/?is_active=false')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        usernames = [u['username'] for u in response.data['results']]
        self.assertIn('inactive', usernames)
    
    def test_search_by_username(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/?search=beginner')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreater(len(response.data['results']), 0)
        
        self.assertIn('beginner', response.data['results'][0]['username'].lower())
    
    def test_search_by_email(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/?search=advanced@test.com')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreater(len(response.data['results']), 0)
    
    def test_ordering_by_date_joined(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/?ordering=-date_joined')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreater(len(response.data['results']), 0)
    
    
    def test_admin_can_view_user_details(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(f'/api/admin/users/{self.beginner_user.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        self.assertIn('id', response.data)
        self.assertIn('username', response.data)
        self.assertIn('email', response.data)
        self.assertIn('profile', response.data)
        self.assertIn('stats', response.data)
        self.assertIn('recent_transactions', response.data)
        self.assertIn('active_missions', response.data)
        self.assertIn('admin_actions', response.data)
        
        self.assertEqual(response.data['profile']['level'], 3)
        self.assertEqual(response.data['profile']['experience_points'], 200)
    
    def test_user_details_includes_statistics(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(f'/api/admin/users/{self.intermediate_user.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        stats = response.data['stats']
        self.assertIn('tps', stats)
        self.assertIn('rdr', stats)
        self.assertIn('ili', stats)
    
    
    def test_admin_can_deactivate_user(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/deactivate/',
            {'reason': 'Violação dos termos de uso'}
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['success'])
        self.assertFalse(response.data['is_active'])
        
        self.beginner_user.refresh_from_db()
        self.assertFalse(self.beginner_user.is_active)
    
    def test_deactivate_requires_reason(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/deactivate/',
            {}
        )
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', response.data)
    
    def test_cannot_deactivate_already_inactive(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            f'/api/admin/users/{self.inactive_user.id}/deactivate/',
            {'reason': 'Test'}
        )
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('já está desativado', response.data['error'])
    
    def test_deactivate_creates_admin_log(self):
        self.client.force_authenticate(user=self.admin_user)
        
        logs_before = AdminActionLog.objects.count()
        
        self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/deactivate/',
            {'reason': 'Test reason'}
        )
        
        logs_after = AdminActionLog.objects.count()
        self.assertEqual(logs_after, logs_before + 1)
        
        log = AdminActionLog.objects.latest('timestamp')
        self.assertEqual(log.admin_user, self.admin_user)
        self.assertEqual(log.target_user, self.beginner_user)
        self.assertEqual(log.action_type, AdminActionLog.ActionType.USER_DEACTIVATED)
        self.assertEqual(log.reason, 'Test reason')
    
    
    def test_admin_can_reactivate_user(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            f'/api/admin/users/{self.inactive_user.id}/reactivate/',
            {'reason': 'Apelação aceita'}
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['success'])
        self.assertTrue(response.data['is_active'])
        
        self.inactive_user.refresh_from_db()
        self.assertTrue(self.inactive_user.is_active)
    
    def test_reactivate_requires_reason(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            f'/api/admin/users/{self.inactive_user.id}/reactivate/',
            {}
        )
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', response.data)
    
    def test_cannot_reactivate_already_active(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/reactivate/',
            {'reason': 'Test'}
        )
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('já está ativo', response.data['error'])
    
    def test_reactivate_creates_admin_log(self):
        self.client.force_authenticate(user=self.admin_user)
        
        logs_before = AdminActionLog.objects.count()
        
        self.client.post(
            f'/api/admin/users/{self.inactive_user.id}/reactivate/',
            {'reason': 'Test reactivate'}
        )
        
        logs_after = AdminActionLog.objects.count()
        self.assertEqual(logs_after, logs_before + 1)
        
        log = AdminActionLog.objects.latest('timestamp')
        self.assertEqual(log.action_type, AdminActionLog.ActionType.USER_REACTIVATED)
    
    
    def test_admin_can_add_xp(self):
        self.client.force_authenticate(user=self.admin_user)
        
        old_xp = self.beginner_user.userprofile.experience_points
        old_level = self.beginner_user.userprofile.level
        
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/adjust_xp/',
            {
                'amount': 300,
                'reason': 'Participação em evento especial'
            }
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['success'])
        self.assertEqual(response.data['adjustment'], 300)
        self.assertEqual(response.data['old_xp'], old_xp)
        self.assertEqual(response.data['new_xp'], old_xp + 300)
        
        self.beginner_user.userprofile.refresh_from_db()
        self.assertEqual(self.beginner_user.userprofile.experience_points, old_xp + 300)
    
    def test_admin_can_remove_xp(self):
        self.client.force_authenticate(user=self.admin_user)
        
        old_xp = self.intermediate_user.userprofile.experience_points
        
        response = self.client.post(
            f'/api/admin/users/{self.intermediate_user.id}/adjust_xp/',
            {
                'amount': -200,
                'reason': 'Correção de erro no sistema'
            }
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['adjustment'], -200)
        self.assertEqual(response.data['new_xp'], old_xp - 200)
        
        self.intermediate_user.userprofile.refresh_from_db()
        self.assertEqual(self.intermediate_user.userprofile.experience_points, old_xp - 200)
    
    def test_xp_cannot_go_negative(self):
        self.client.force_authenticate(user=self.admin_user)
        
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/adjust_xp/',
            {
                'amount': -500,
                'reason': 'Test'
            }
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        self.assertEqual(response.data['new_xp'], 0)
        
        self.beginner_user.userprofile.refresh_from_db()
        self.assertEqual(self.beginner_user.userprofile.experience_points, 0)
    
    def test_xp_adjustment_validates_limits(self):
        self.client.force_authenticate(user=self.admin_user)
        
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/adjust_xp/',
            {
                'amount': 600,
                'reason': 'Test'
            }
        )
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('entre -500 e +500', response.data['error'])
        
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/adjust_xp/',
            {
                'amount': -600,
                'reason': 'Test'
            }
        )
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
    
    def test_xp_adjustment_requires_reason(self):
        self.client.force_authenticate(user=self.admin_user)
        
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/adjust_xp/',
            {'amount': 100}
        )
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('reason', response.data['error'].lower())
    
    def test_xp_adjustment_requires_non_zero_amount(self):
        self.client.force_authenticate(user=self.admin_user)
        
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/adjust_xp/',
            {
                'amount': 0,
                'reason': 'Test'
            }
        )
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('diferente de zero', response.data['error'])
    
    def test_xp_adjustment_recalculates_level(self):
        self.client.force_authenticate(user=self.admin_user)
        
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/adjust_xp/',
            {
                'amount': 300,
                'reason': 'Level up test'
            }
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['level_changed'])
        self.assertEqual(response.data['old_level'], 3)
        self.assertEqual(response.data['new_level'], 6)
        
        self.beginner_user.userprofile.refresh_from_db()
        self.assertEqual(self.beginner_user.userprofile.level, 6)
    
    def test_xp_adjustment_creates_admin_log(self):
        self.client.force_authenticate(user=self.admin_user)
        
        logs_before = AdminActionLog.objects.count()
        
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/adjust_xp/',
            {
                'amount': 150,
                'reason': 'Evento especial'
            }
        )
        
        logs_after = AdminActionLog.objects.count()
        self.assertEqual(logs_after, logs_before + 1)
        
        log = AdminActionLog.objects.latest('timestamp')
        self.assertEqual(log.action_type, AdminActionLog.ActionType.XP_ADJUSTED)
        self.assertIn('Evento especial', log.reason)
        self.assertIn('150', log.reason)
        self.assertIn('XP: 200', log.old_value)
        self.assertIn('XP: 350', log.new_value)
    
    
    def test_admin_can_view_action_history(self):
        self.client.force_authenticate(user=self.admin_user)
        
        AdminActionLog.log_action(
            admin_user=self.admin_user,
            target_user=self.beginner_user,
            action_type=AdminActionLog.ActionType.XP_ADJUSTED,
            old_value='100',
            new_value='200',
            reason='Test 1'
        )
        
        AdminActionLog.log_action(
            admin_user=self.admin_user,
            target_user=self.beginner_user,
            action_type=AdminActionLog.ActionType.PROFILE_UPDATED,
            old_value='Old',
            new_value='New',
            reason='Test 2'
        )
        
        response = self.client.get(f'/api/admin/users/{self.beginner_user.id}/admin_actions/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('results', response.data)
        self.assertGreaterEqual(len(response.data['results']), 2)
        
        first_action = response.data['results'][0]
        self.assertIn('action_type', first_action)
        self.assertIn('action_display', first_action)
        self.assertIn('admin', first_action)
        self.assertIn('timestamp', first_action)
        self.assertIn('reason', first_action)
    
    def test_action_history_pagination(self):
        self.client.force_authenticate(user=self.admin_user)
        
        for i in range(60):
            AdminActionLog.log_action(
                admin_user=self.admin_user,
                target_user=self.intermediate_user,
                action_type=AdminActionLog.ActionType.OTHER,
                reason=f'Test action {i}'
            )
        
        response = self.client.get(f'/api/admin/users/{self.intermediate_user.id}/admin_actions/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        self.assertEqual(len(response.data['results']), 50)
        
        self.assertIsNotNone(response.data.get('next'))
    
    def test_action_history_filter_by_type(self):
        self.client.force_authenticate(user=self.admin_user)
        
        AdminActionLog.log_action(
            admin_user=self.admin_user,
            target_user=self.advanced_user,
            action_type=AdminActionLog.ActionType.XP_ADJUSTED,
            reason='XP Test'
        )
        
        AdminActionLog.log_action(
            admin_user=self.admin_user,
            target_user=self.advanced_user,
            action_type=AdminActionLog.ActionType.USER_DEACTIVATED,
            reason='Deactivate Test'
        )
        
        response = self.client.get(
            f'/api/admin/users/{self.advanced_user.id}/admin_actions/?action_type=XP_ADJUSTED'
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        for action in response.data['results']:
            self.assertEqual(action['action_type'], 'XP_ADJUSTED')
    
    
    def test_admin_action_log_string_representation(self):
        log = AdminActionLog.log_action(
            admin_user=self.admin_user,
            target_user=self.beginner_user,
            action_type=AdminActionLog.ActionType.XP_ADJUSTED,
            reason='Test'
        )
        
        log_str = str(log)
        self.assertIn('admin', log_str)
        self.assertIn('beginner', log_str)
        self.assertIn('XP Ajustado', log_str)
    
    def test_admin_action_log_ordering(self):
        log1 = AdminActionLog.log_action(
            admin_user=self.admin_user,
            target_user=self.beginner_user,
            action_type=AdminActionLog.ActionType.OTHER,
            reason='First'
        )
        
        log2 = AdminActionLog.log_action(
            admin_user=self.admin_user,
            target_user=self.beginner_user,
            action_type=AdminActionLog.ActionType.OTHER,
            reason='Second'
        )
        
        log3 = AdminActionLog.log_action(
            admin_user=self.admin_user,
            target_user=self.beginner_user,
            action_type=AdminActionLog.ActionType.OTHER,
            reason='Third'
        )
        
        logs = AdminActionLog.objects.filter(target_user=self.beginner_user)
        
        self.assertEqual(logs[0].id, log3.id)
        self.assertEqual(logs[1].id, log2.id)
        self.assertEqual(logs[2].id, log1.id)
    
    def test_admin_action_log_handles_json_values(self):
        complex_value = {'level': 5, 'xp': 400, 'missions': [1, 2, 3]}
        
        log = AdminActionLog.log_action(
            admin_user=self.admin_user,
            target_user=self.beginner_user,
            action_type=AdminActionLog.ActionType.PROFILE_UPDATED,
            old_value=complex_value,
            new_value={'level': 6, 'xp': 500},
            reason='Test complex'
        )
        
        self.assertIsInstance(log.old_value, str)
        self.assertIsInstance(log.new_value, str)
        self.assertIn('"level"', log.old_value)
    
    def test_admin_action_log_can_be_null_admin(self):
        log = AdminActionLog.log_action(
            admin_user=None,
            target_user=self.beginner_user,
            action_type=AdminActionLog.ActionType.OTHER,
            reason='Automated system action'
        )
        
        self.assertIsNone(log.admin_user)
        self.assertIn('Sistema', str(log))
    
    
    def test_full_workflow_deactivate_and_reactivate(self):
        self.client.force_authenticate(user=self.admin_user)
        
        response1 = self.client.post(
            f'/api/admin/users/{self.intermediate_user.id}/deactivate/',
            {'reason': 'Teste completo'}
        )
        self.assertEqual(response1.status_code, status.HTTP_200_OK)
        
        self.intermediate_user.refresh_from_db()
        self.assertFalse(self.intermediate_user.is_active)
        
        logs = AdminActionLog.objects.filter(target_user=self.intermediate_user)
        self.assertEqual(logs.count(), 1)
        self.assertEqual(logs[0].action_type, AdminActionLog.ActionType.USER_DEACTIVATED)
        
        response2 = self.client.post(
            f'/api/admin/users/{self.intermediate_user.id}/reactivate/',
            {'reason': 'Teste completo - reativação'}
        )
        self.assertEqual(response2.status_code, status.HTTP_200_OK)
        
        self.intermediate_user.refresh_from_db()
        self.assertTrue(self.intermediate_user.is_active)
        
        logs = AdminActionLog.objects.filter(target_user=self.intermediate_user)
        self.assertEqual(logs.count(), 2)
    
    def test_full_workflow_xp_adjustment(self):
        self.client.force_authenticate(user=self.admin_user)
        
        old_xp = self.advanced_user.userprofile.experience_points
        old_level = self.advanced_user.userprofile.level
        
        response = self.client.post(
            f'/api/admin/users/{self.advanced_user.id}/adjust_xp/',
            {
                'amount': 250,
                'reason': 'Participação em campeonato'
            }
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        self.assertEqual(response.data['old_xp'], old_xp)
        self.assertEqual(response.data['new_xp'], old_xp + 250)
        
        self.advanced_user.userprofile.refresh_from_db()
        self.assertEqual(self.advanced_user.userprofile.experience_points, old_xp + 250)
        
        log = AdminActionLog.objects.filter(
            target_user=self.advanced_user,
            action_type=AdminActionLog.ActionType.XP_ADJUSTED
        ).first()
        
        self.assertIsNotNone(log)
        self.assertEqual(log.admin_user, self.admin_user)
        self.assertIn('Participação em campeonato', log.reason)
        self.assertIn(str(old_xp), log.old_value)
        self.assertIn(str(old_xp + 250), log.new_value)


class AdminActionLogModelTest(TestCase):
    
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
