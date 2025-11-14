"""
Testes para os Serializers do sistema de missões.

Testa a serialização/deserialização dos modelos refatorados,
especialmente os novos campos adicionados no Sprint 1.
"""

from decimal import Decimal
from django.test import TestCase
from django.contrib.auth import get_user_model
from django.utils import timezone

from finance.models import Mission, MissionProgress, Category, Goal
from finance.serializers import MissionSerializer, MissionProgressSerializer

User = get_user_model()


class MissionSerializerTest(TestCase):
    """Testes para MissionSerializer."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        
        # Get existing category (created by signal)
        self.category = Category.objects.get(
            user=self.user,
            name='Alimentação',
            type='EXPENSE'
        )
        
        # Create a goal for testing
        self.goal = Goal.objects.create(
            user=self.user,
            title='Casa Própria',
            target_amount=Decimal('100000.00'),
            current_amount=Decimal('0.00')
        )
        
        # Create basic mission
        self.mission = Mission.objects.create(
            title='Missão Teste',
            description='Descrição de teste',
            mission_type='CATEGORY_REDUCTION',
            validation_type='CATEGORY_REDUCTION',
            target_category=self.category,
            target_reduction_percent=Decimal('15.00'),
            duration_days=30,
            reward_points=300,
            min_transaction_frequency=3,
            transaction_type_filter='EXPENSE',
            requires_payment_tracking=False,
            is_system_generated=True,
            generation_context='test'
        )
        
        # Add target_categories (ManyToMany)
        self.mission.target_categories.add(self.category)
    
    def test_serialize_mission_basic_fields(self):
        """Testa serialização dos campos básicos."""
        serializer = MissionSerializer(self.mission)
        data = serializer.data
        
        # Campos básicos
        self.assertEqual(data['title'], 'Missão Teste')
        self.assertEqual(data['description'], 'Descrição de teste')
        self.assertEqual(data['mission_type'], 'CATEGORY_REDUCTION')
        self.assertEqual(data['validation_type'], 'CATEGORY_REDUCTION')
        self.assertEqual(data['reward_points'], 300)
        self.assertEqual(data['duration_days'], 30)
    
    def test_serialize_mission_new_fields(self):
        """Testa serialização dos novos campos do Sprint 1."""
        serializer = MissionSerializer(self.mission)
        data = serializer.data
        
        # Novos campos
        self.assertEqual(data['min_transaction_frequency'], 3)
        self.assertEqual(data['transaction_type_filter'], 'EXPENSE')
        self.assertEqual(data['requires_payment_tracking'], False)
        self.assertTrue(data['is_system_generated'])
        self.assertEqual(data['generation_context'], 'test')
    
    def test_serialize_mission_target_category(self):
        """Testa serialização de target_category aninhado."""
        serializer = MissionSerializer(self.mission)
        data = serializer.data
        
        # Target category deve ser serializado como objeto
        self.assertIsNotNone(data['target_category'])
        self.assertEqual(data['target_category']['name'], 'Alimentação')
        self.assertEqual(data['target_category']['type'], 'EXPENSE')
    
    def test_serialize_mission_target_categories(self):
        """Testa serialização de target_categories (ManyToMany)."""
        serializer = MissionSerializer(self.mission)
        data = serializer.data
        
        # Target categories deve ser uma lista
        self.assertIsInstance(data['target_categories'], list)
        self.assertEqual(len(data['target_categories']), 1)
        self.assertEqual(data['target_categories'][0]['name'], 'Alimentação')
    
    def test_serialize_mission_display_fields(self):
        """Testa campos de display (get_*_display)."""
        serializer = MissionSerializer(self.mission)
        data = serializer.data
        
        # Display fields
        self.assertIn('type_display', data)
        self.assertIn('validation_type_display', data)
        self.assertIn('difficulty_display', data)
    
    def test_serialize_mission_source_field(self):
        """Testa campo calculado 'source'."""
        serializer = MissionSerializer(self.mission)
        data = serializer.data
        
        # Missão é system generated
        self.assertEqual(data['source'], 'system')
        
        # Testar com missão de IA (priority < 5)
        ai_mission = Mission.objects.create(
            title='Missão IA',
            description='Gerada por IA',
            mission_type='SAVINGS_INCREASE',
            priority=3,
            duration_days=30,
            reward_points=100
        )
        serializer = MissionSerializer(ai_mission)
        self.assertEqual(serializer.data['source'], 'ai')
    
    def test_serialize_mission_target_info_indicators(self):
        """Testa target_info com indicadores financeiros."""
        mission_with_indicators = Mission.objects.create(
            title='Missão Indicadores',
            description='Com TPS e RDR',
            mission_type='FINANCIAL_HEALTH',
            target_tps=Decimal('20.00'),
            target_rdr=Decimal('30.00'),
            min_ili=Decimal('3.00'),
            duration_days=30,
            reward_points=500
        )
        
        serializer = MissionSerializer(mission_with_indicators)
        data = serializer.data
        
        # Target info deve conter os indicadores
        self.assertIn('target_info', data)
        targets = data['target_info']['targets']
        
        # Verificar TPS
        tps_target = next((t for t in targets if t['metric'] == 'TPS'), None)
        self.assertIsNotNone(tps_target)
        self.assertEqual(tps_target['value'], 20.0)
        self.assertEqual(tps_target['unit'], '%')
        
        # Verificar RDR
        rdr_target = next((t for t in targets if t['metric'] == 'RDR'), None)
        self.assertIsNotNone(rdr_target)
        self.assertEqual(rdr_target['value'], 30.0)
        
        # Verificar ILI
        ili_target = next((t for t in targets if t['metric'] == 'ILI'), None)
        self.assertIsNotNone(ili_target)
        self.assertEqual(ili_target['value'], 3.0)
        self.assertEqual(ili_target['unit'], 'meses')
    
    def test_serialize_mission_target_info_category(self):
        """Testa target_info com categoria alvo."""
        serializer = MissionSerializer(self.mission)
        data = serializer.data
        
        targets = data['target_info']['targets']
        
        # Deve conter informação da categoria
        cat_target = next((t for t in targets if t['metric'] == 'CATEGORY'), None)
        self.assertIsNotNone(cat_target)
        self.assertEqual(cat_target['label'], 'Alimentação')
    
    def test_deserialize_mission_create(self):
        """Testa deserialização para criar nova missão."""
        data = {
            'title': 'Nova Missão',
            'description': 'Descrição da nova missão',
            'mission_type': 'INCOME_TRACKING',
            'validation_type': 'TRANSACTION_COUNT',
            'min_transactions': 10,
            'duration_days': 30,
            'reward_points': 250,
            'min_transaction_frequency': 5,
            'transaction_type_filter': 'ALL',
            'is_system_generated': False
        }
        
        serializer = MissionSerializer(data=data)
        self.assertTrue(serializer.is_valid(), serializer.errors)
        
        mission = serializer.save()
        self.assertEqual(mission.title, 'Nova Missão')
        self.assertEqual(mission.min_transaction_frequency, 5)
        self.assertEqual(mission.transaction_type_filter, 'ALL')
        self.assertFalse(mission.is_system_generated)


class MissionProgressSerializerTest(TestCase):
    """Testes para MissionProgressSerializer."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        
        self.mission = Mission.objects.create(
            title='Missão Teste',
            description='Descrição',
            mission_type='TRANSACTION_CONSISTENCY',
            validation_type='TRANSACTION_CONSISTENCY',
            min_transaction_frequency=3,
            duration_days=30,
            reward_points=300
        )
        
        self.mission_progress = MissionProgress.objects.create(
            user=self.user,
            mission=self.mission,
            status=MissionProgress.Status.ACTIVE,
            progress=Decimal('50.00'),
            started_at=timezone.now(),
            baseline_category_spending=Decimal('1000.00'),
            baseline_period_days=30
        )
    
    def test_serialize_mission_progress_basic(self):
        """Testa serialização básica de MissionProgress."""
        serializer = MissionProgressSerializer(self.mission_progress)
        data = serializer.data
        
        self.assertEqual(data['status'], 'ACTIVE')
        self.assertEqual(float(data['progress']), 50.0)
        self.assertIsNotNone(data['started_at'])
    
    def test_serialize_mission_progress_new_fields(self):
        """Testa serialização dos novos campos de rastreamento."""
        serializer = MissionProgressSerializer(self.mission_progress)
        data = serializer.data
        
        # Novos campos de baseline
        self.assertEqual(float(data['baseline_category_spending']), 1000.0)
        self.assertEqual(data['baseline_period_days'], 30)
    
    def test_deserialize_mission_progress_create(self):
        """Testa deserialização para criar MissionProgress."""
        # Criar uma nova missão para não conflitar com o setUp
        new_mission = Mission.objects.create(
            title='Missão para Teste',
            description='Missão de teste',
            mission_type='BASIC_TRANSACTIONS',
            validation_type='BASIC',
            min_transactions=5,
            duration_days=30,
            reward_points=100
        )
        
        data = {
            'mission_id': new_mission.id,
            'status': 'PENDING',
            'progress': '0.00',
            'baseline_period_days': 30
        }
        
        # Criar um mock request para o context
        from unittest.mock import Mock
        mock_request = Mock()
        mock_request.user = self.user
        
        serializer = MissionProgressSerializer(data=data, context={'request': mock_request})
        self.assertTrue(serializer.is_valid(), serializer.errors)
        
        progress = serializer.save()
        self.assertEqual(progress.status, 'PENDING')
        self.assertEqual(progress.baseline_period_days, 30)
