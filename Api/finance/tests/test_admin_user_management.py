"""
Testes para Admin User Management (Checkpoint 2.4).

Testa os endpoints de gestão administrativa de usuários:
1. Listagem de usuários com filtros avançados
2. Visualização de detalhes completos
3. Desativação/reativação de usuários
4. Ajuste manual de XP
5. Histórico de ações administrativas
6. Permissões e segurança
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
    """Testes para endpoints de gestão de usuários admin."""
    
    def setUp(self):
        """Configura ambiente de teste."""
        # Criar admin/staff user
        self.admin_user = User.objects.create_user(
            username='admin',
            email='admin@test.com',
            password='adminpass123',
            is_staff=True,
            is_superuser=True
        )
        
        # Criar usuário regular
        self.regular_user = User.objects.create_user(
            username='regular',
            email='regular@test.com',
            password='testpass123'
        )
        
        # Criar usuários de teste com diferentes níveis
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
        
        # Criar usuário inativo
        self.inactive_user = User.objects.create_user(
            username='inactive',
            email='inactive@test.com',
            password='testpass123',
            is_active=False
        )
        
        # Cliente API
        self.client = APIClient()
    
    # ==================== TESTES DE PERMISSÃO ====================
    
    def test_non_admin_cannot_access_user_list(self):
        """Testa que usuário não-admin não pode listar usuários."""
        self.client.force_authenticate(user=self.regular_user)
        response = self.client.get('/api/admin/users/')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    def test_non_admin_cannot_access_user_details(self):
        """Testa que usuário não-admin não pode ver detalhes de outros."""
        self.client.force_authenticate(user=self.regular_user)
        response = self.client.get(f'/api/admin/users/{self.beginner_user.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    def test_non_admin_cannot_deactivate_user(self):
        """Testa que usuário não-admin não pode desativar usuários."""
        self.client.force_authenticate(user=self.regular_user)
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/deactivate/',
            {'reason': 'Test reason'}
        )
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
    
    def test_unauthenticated_cannot_access(self):
        """Testa que usuário não autenticado não pode acessar."""
        response = self.client.get('/api/admin/users/')
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
    
    # ==================== TESTES DE LISTAGEM ====================
    
    def test_admin_can_list_users(self):
        """Testa que admin pode listar todos os usuários."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('results', response.data)
        
        # Deve ter pelo menos 7 usuários (admin + regular + 3 tiers + inactive)
        self.assertGreaterEqual(len(response.data['results']), 6)
    
    def test_filter_by_tier_beginner(self):
        """Testa filtro por tier BEGINNER (level 1-5)."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/?tier=BEGINNER')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verificar que todos têm level entre 1-5
        for user in response.data['results']:
            self.assertLessEqual(user['level'], 5)
    
    def test_filter_by_tier_intermediate(self):
        """Testa filtro por tier INTERMEDIATE (level 6-15)."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/?tier=INTERMEDIATE')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verificar que todos têm level entre 6-15
        for user in response.data['results']:
            self.assertGreaterEqual(user['level'], 6)
            self.assertLessEqual(user['level'], 15)
    
    def test_filter_by_tier_advanced(self):
        """Testa filtro por tier ADVANCED (level 16+)."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/?tier=ADVANCED')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verificar que todos têm level >= 16
        for user in response.data['results']:
            self.assertGreaterEqual(user['level'], 16)
    
    def test_filter_by_active_status(self):
        """Testa filtro por status ativo."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/?is_active=true')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Todos devem estar ativos
        for user in response.data['results']:
            self.assertTrue(user['is_active'])
    
    def test_filter_by_inactive_status(self):
        """Testa filtro por status inativo."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/?is_active=false')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Deve incluir o inactive_user
        usernames = [u['username'] for u in response.data['results']]
        self.assertIn('inactive', usernames)
    
    def test_search_by_username(self):
        """Testa busca por username."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/?search=beginner')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreater(len(response.data['results']), 0)
        
        # Deve conter 'beginner' no username
        self.assertIn('beginner', response.data['results'][0]['username'].lower())
    
    def test_search_by_email(self):
        """Testa busca por email."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/?search=advanced@test.com')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreater(len(response.data['results']), 0)
    
    def test_ordering_by_date_joined(self):
        """Testa ordenação por data de cadastro."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/admin/users/?ordering=-date_joined')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreater(len(response.data['results']), 0)
    
    # ==================== TESTES DE DETALHES ====================
    
    def test_admin_can_view_user_details(self):
        """Testa que admin pode ver detalhes completos de um usuário."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(f'/api/admin/users/{self.beginner_user.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verificar estrutura da resposta
        self.assertIn('id', response.data)
        self.assertIn('username', response.data)
        self.assertIn('email', response.data)
        self.assertIn('profile', response.data)
        self.assertIn('stats', response.data)
        self.assertIn('recent_transactions', response.data)
        self.assertIn('active_missions', response.data)
        self.assertIn('admin_actions', response.data)
        
        # Verificar dados do perfil
        self.assertEqual(response.data['profile']['level'], 3)
        self.assertEqual(response.data['profile']['experience_points'], 200)
    
    def test_user_details_includes_statistics(self):
        """Testa que detalhes incluem estatísticas calculadas."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(f'/api/admin/users/{self.intermediate_user.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Stats deve ter indicadores
        stats = response.data['stats']
        self.assertIn('tps', stats)
        self.assertIn('rdr', stats)
        self.assertIn('ili', stats)
    
    # ==================== TESTES DE DESATIVAÇÃO ====================
    
    def test_admin_can_deactivate_user(self):
        """Testa que admin pode desativar um usuário."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/deactivate/',
            {'reason': 'Violação dos termos de uso'}
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['success'])
        self.assertFalse(response.data['is_active'])
        
        # Verificar que usuário foi realmente desativado
        self.beginner_user.refresh_from_db()
        self.assertFalse(self.beginner_user.is_active)
    
    def test_deactivate_requires_reason(self):
        """Testa que desativação requer campo 'reason'."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/deactivate/',
            {}
        )
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', response.data)
    
    def test_cannot_deactivate_already_inactive(self):
        """Testa que não pode desativar usuário já inativo."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            f'/api/admin/users/{self.inactive_user.id}/deactivate/',
            {'reason': 'Test'}
        )
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('já está desativado', response.data['error'])
    
    def test_deactivate_creates_admin_log(self):
        """Testa que desativação cria log de ação."""
        self.client.force_authenticate(user=self.admin_user)
        
        # Contar logs antes
        logs_before = AdminActionLog.objects.count()
        
        self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/deactivate/',
            {'reason': 'Test reason'}
        )
        
        # Deve ter criado 1 log
        logs_after = AdminActionLog.objects.count()
        self.assertEqual(logs_after, logs_before + 1)
        
        # Verificar conteúdo do log
        log = AdminActionLog.objects.latest('timestamp')
        self.assertEqual(log.admin_user, self.admin_user)
        self.assertEqual(log.target_user, self.beginner_user)
        self.assertEqual(log.action_type, AdminActionLog.ActionType.USER_DEACTIVATED)
        self.assertEqual(log.reason, 'Test reason')
    
    # ==================== TESTES DE REATIVAÇÃO ====================
    
    def test_admin_can_reactivate_user(self):
        """Testa que admin pode reativar um usuário."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            f'/api/admin/users/{self.inactive_user.id}/reactivate/',
            {'reason': 'Apelação aceita'}
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['success'])
        self.assertTrue(response.data['is_active'])
        
        # Verificar que usuário foi realmente reativado
        self.inactive_user.refresh_from_db()
        self.assertTrue(self.inactive_user.is_active)
    
    def test_reactivate_requires_reason(self):
        """Testa que reativação requer campo 'reason'."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            f'/api/admin/users/{self.inactive_user.id}/reactivate/',
            {}
        )
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', response.data)
    
    def test_cannot_reactivate_already_active(self):
        """Testa que não pode reativar usuário já ativo."""
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/reactivate/',
            {'reason': 'Test'}
        )
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('já está ativo', response.data['error'])
    
    def test_reactivate_creates_admin_log(self):
        """Testa que reativação cria log de ação."""
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
    
    # ==================== TESTES DE AJUSTE DE XP ====================
    
    def test_admin_can_add_xp(self):
        """Testa que admin pode adicionar XP a um usuário."""
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
        
        # Verificar no banco
        self.beginner_user.userprofile.refresh_from_db()
        self.assertEqual(self.beginner_user.userprofile.experience_points, old_xp + 300)
    
    def test_admin_can_remove_xp(self):
        """Testa que admin pode remover XP de um usuário."""
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
        
        # Verificar no banco
        self.intermediate_user.userprofile.refresh_from_db()
        self.assertEqual(self.intermediate_user.userprofile.experience_points, old_xp - 200)
    
    def test_xp_cannot_go_negative(self):
        """Testa que XP não pode ficar negativo."""
        self.client.force_authenticate(user=self.admin_user)
        
        # beginner_user tem 200 XP, tentar remover 500
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/adjust_xp/',
            {
                'amount': -500,
                'reason': 'Test'
            }
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # XP deve ser 0, não negativo
        self.assertEqual(response.data['new_xp'], 0)
        
        self.beginner_user.userprofile.refresh_from_db()
        self.assertEqual(self.beginner_user.userprofile.experience_points, 0)
    
    def test_xp_adjustment_validates_limits(self):
        """Testa validação de limites (-500 a +500)."""
        self.client.force_authenticate(user=self.admin_user)
        
        # Testar acima do limite
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/adjust_xp/',
            {
                'amount': 600,
                'reason': 'Test'
            }
        )
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('entre -500 e +500', response.data['error'])
        
        # Testar abaixo do limite
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/adjust_xp/',
            {
                'amount': -600,
                'reason': 'Test'
            }
        )
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
    
    def test_xp_adjustment_requires_reason(self):
        """Testa que ajuste de XP requer motivo."""
        self.client.force_authenticate(user=self.admin_user)
        
        response = self.client.post(
            f'/api/admin/users/{self.beginner_user.id}/adjust_xp/',
            {'amount': 100}
        )
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('reason', response.data['error'].lower())
    
    def test_xp_adjustment_requires_non_zero_amount(self):
        """Testa que amount não pode ser zero."""
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
        """Testa que ajuste de XP recalcula o nível automaticamente."""
        self.client.force_authenticate(user=self.admin_user)
        
        # beginner_user tem level 3 (200 XP)
        # Adicionar 300 XP = 500 XP total = level 6 (500 // 100 + 1)
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
        """Testa que ajuste de XP cria log com valores antes/depois."""
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
        self.assertIn('150', log.reason)  # Ajuste no reason
        self.assertIn('XP: 200', log.old_value)  # Valor antigo
        self.assertIn('XP: 350', log.new_value)  # Valor novo
    
    # ==================== TESTES DE HISTÓRICO DE AÇÕES ====================
    
    def test_admin_can_view_action_history(self):
        """Testa que admin pode ver histórico de ações de um usuário."""
        self.client.force_authenticate(user=self.admin_user)
        
        # Criar algumas ações primeiro
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
        
        # Verificar estrutura
        first_action = response.data['results'][0]
        self.assertIn('action_type', first_action)
        self.assertIn('action_display', first_action)
        self.assertIn('admin', first_action)
        self.assertIn('timestamp', first_action)
        self.assertIn('reason', first_action)
    
    def test_action_history_pagination(self):
        """Testa paginação do histórico (50 itens por página)."""
        self.client.force_authenticate(user=self.admin_user)
        
        # Criar 60 ações
        for i in range(60):
            AdminActionLog.log_action(
                admin_user=self.admin_user,
                target_user=self.intermediate_user,
                action_type=AdminActionLog.ActionType.OTHER,
                reason=f'Test action {i}'
            )
        
        response = self.client.get(f'/api/admin/users/{self.intermediate_user.id}/admin_actions/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Primeira página deve ter 50 itens
        self.assertEqual(len(response.data['results']), 50)
        
        # Deve ter link para próxima página
        self.assertIsNotNone(response.data.get('next'))
    
    def test_action_history_filter_by_type(self):
        """Testa filtro de histórico por tipo de ação."""
        self.client.force_authenticate(user=self.admin_user)
        
        # Criar ações de tipos diferentes
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
        
        # Filtrar apenas XP_ADJUSTED
        response = self.client.get(
            f'/api/admin/users/{self.advanced_user.id}/admin_actions/?action_type=XP_ADJUSTED'
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Todos devem ser XP_ADJUSTED
        for action in response.data['results']:
            self.assertEqual(action['action_type'], 'XP_ADJUSTED')
    
    # ==================== TESTES DO MODELO ADMINACTIONLOG ====================
    
    def test_admin_action_log_string_representation(self):
        """Testa representação em string do log."""
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
        """Testa que logs são ordenados por timestamp descendente."""
        # Criar 3 logs
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
        
        # Buscar todos
        logs = AdminActionLog.objects.filter(target_user=self.beginner_user)
        
        # Mais recente deve ser o primeiro
        self.assertEqual(logs[0].id, log3.id)
        self.assertEqual(logs[1].id, log2.id)
        self.assertEqual(logs[2].id, log1.id)
    
    def test_admin_action_log_handles_json_values(self):
        """Testa que log_action converte valores complexos para JSON."""
        complex_value = {'level': 5, 'xp': 400, 'missions': [1, 2, 3]}
        
        log = AdminActionLog.log_action(
            admin_user=self.admin_user,
            target_user=self.beginner_user,
            action_type=AdminActionLog.ActionType.PROFILE_UPDATED,
            old_value=complex_value,
            new_value={'level': 6, 'xp': 500},
            reason='Test complex'
        )
        
        # Deve ter convertido para string JSON
        self.assertIsInstance(log.old_value, str)
        self.assertIsInstance(log.new_value, str)
        self.assertIn('"level"', log.old_value)
    
    def test_admin_action_log_can_be_null_admin(self):
        """Testa que admin_user pode ser null (ação do sistema)."""
        log = AdminActionLog.log_action(
            admin_user=None,
            target_user=self.beginner_user,
            action_type=AdminActionLog.ActionType.OTHER,
            reason='Automated system action'
        )
        
        self.assertIsNone(log.admin_user)
        self.assertIn('Sistema', str(log))
    
    # ==================== TESTES INTEGRADOS ====================
    
    def test_full_workflow_deactivate_and_reactivate(self):
        """Testa workflow completo: desativar -> verificar log -> reativar."""
        self.client.force_authenticate(user=self.admin_user)
        
        # 1. Desativar
        response1 = self.client.post(
            f'/api/admin/users/{self.intermediate_user.id}/deactivate/',
            {'reason': 'Teste completo'}
        )
        self.assertEqual(response1.status_code, status.HTTP_200_OK)
        
        # 2. Verificar que foi desativado
        self.intermediate_user.refresh_from_db()
        self.assertFalse(self.intermediate_user.is_active)
        
        # 3. Verificar log
        logs = AdminActionLog.objects.filter(target_user=self.intermediate_user)
        self.assertEqual(logs.count(), 1)
        self.assertEqual(logs[0].action_type, AdminActionLog.ActionType.USER_DEACTIVATED)
        
        # 4. Reativar
        response2 = self.client.post(
            f'/api/admin/users/{self.intermediate_user.id}/reactivate/',
            {'reason': 'Teste completo - reativação'}
        )
        self.assertEqual(response2.status_code, status.HTTP_200_OK)
        
        # 5. Verificar que foi reativado
        self.intermediate_user.refresh_from_db()
        self.assertTrue(self.intermediate_user.is_active)
        
        # 6. Verificar ambos os logs
        logs = AdminActionLog.objects.filter(target_user=self.intermediate_user)
        self.assertEqual(logs.count(), 2)
    
    def test_full_workflow_xp_adjustment(self):
        """Testa workflow completo de ajuste de XP com verificação de log."""
        self.client.force_authenticate(user=self.admin_user)
        
        # Estado inicial
        old_xp = self.advanced_user.userprofile.experience_points
        old_level = self.advanced_user.userprofile.level
        
        # Ajustar XP
        response = self.client.post(
            f'/api/admin/users/{self.advanced_user.id}/adjust_xp/',
            {
                'amount': 250,
                'reason': 'Participação em campeonato'
            }
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verificar resposta
        self.assertEqual(response.data['old_xp'], old_xp)
        self.assertEqual(response.data['new_xp'], old_xp + 250)
        
        # Verificar banco
        self.advanced_user.userprofile.refresh_from_db()
        self.assertEqual(self.advanced_user.userprofile.experience_points, old_xp + 250)
        
        # Verificar log
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
    """Testes específicos do modelo AdminActionLog."""
    
    def setUp(self):
        """Configura ambiente de teste."""
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
            5  # Criado há menos de 5 segundos
        )
    
    def test_action_type_choices(self):
        """Testa que todos os tipos de ação estão definidos."""
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
