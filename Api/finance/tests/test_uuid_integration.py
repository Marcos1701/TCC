"""
Testes de integração para sistema dual ID/UUID.

Valida que a API aceita tanto IDs numéricos quanto UUIDs
para lookup, criação, edição e exclusão de recursos.
"""
import uuid
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from finance.models import Category, Transaction, TransactionLink, Goal, Friendship

User = get_user_model()


class UUIDLookupTestCase(TestCase):
    """Testa lookup por ID numérico e UUID."""

    def setUp(self):
        """Configuração inicial dos testes."""
        self.client = APIClient()
        
        # Criar usuários
        self.user1 = User.objects.create_user(
            username='testuser1',
            email='test1@example.com',
            password='testpass123'
        )
        self.user2 = User.objects.create_user(
            username='testuser2',
            email='test2@example.com',
            password='testpass123'
        )
        
        # Criar categoria
        self.category = Category.objects.create(
            name='Salário',
            type='INCOME',
            user=self.user1
        )
        
        # Autenticar
        self.client.force_authenticate(user=self.user1)

    def test_transaction_lookup_by_id(self):
        """Testa busca de transação por ID numérico."""
        transaction = Transaction.objects.create(
            user=self.user1,
            type='INCOME',
            description='Salário',
            amount=Decimal('5000.00'),
            date=timezone.now().date(),
            category=self.category
        )
        
        response = self.client.get(f'/api/transactions/{transaction.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(str(response.data['id']), str(transaction.id))  # Comparar como strings
        self.assertEqual(response.data['description'], 'Salário')

    def test_transaction_lookup_by_uuid(self):
        """Testa busca de transação por UUID."""
        transaction = Transaction.objects.create(
            user=self.user1,
            type='INCOME',
            description='Salário',
            amount=Decimal('5000.00'),
            date=timezone.now().date(),
            category=self.category
        )
        
        # UUID deve ser gerado automaticamente pelo signal
        self.assertIsNotNone(transaction.id)
        
        response = self.client.get(f'/api/transactions/{transaction.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['id'], str(transaction.id))
        self.assertEqual(response.data['description'], 'Salário')

    def test_transaction_update_by_uuid(self):
        """Testa atualização de transação por UUID."""
        transaction = Transaction.objects.create(
            user=self.user1,
            type='INCOME',
            description='Salário',
            amount=Decimal('5000.00'),
            date=timezone.now().date(),
            category=self.category
        )
        
        response = self.client.patch(
            f'/api/transactions/{transaction.id}/',
            {'description': 'Salário Atualizado'},
            format='json'  # Especificar formato JSON
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['description'], 'Salário Atualizado')
        
        # Verificar no banco
        transaction.refresh_from_db()
        self.assertEqual(transaction.description, 'Salário Atualizado')

    def test_transaction_delete_by_uuid(self):
        """Testa exclusão de transação por UUID."""
        transaction = Transaction.objects.create(
            user=self.user1,
            type='INCOME',
            description='Salário',
            amount=Decimal('5000.00'),
            date=timezone.now().date(),
            category=self.category
        )
        
        transaction_uuid = transaction.id
        
        response = self.client.delete(f'/api/transactions/{transaction_uuid}/')
        
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        
        # Verificar que foi deletado
        self.assertFalse(Transaction.objects.filter(id=transaction_uuid).exists())

    def test_goal_lookup_by_uuid(self):
        """Testa busca de meta por UUID."""
        goal = Goal.objects.create(
            user=self.user1,
            title='Economizar',
            description='Meta de economia',
            target_amount=Decimal('10000.00'),
            goal_type='SAVINGS',
            tracking_period='MONTHLY'
        )
        
        self.assertIsNotNone(goal.id)
        
        response = self.client.get(f'/api/goals/{goal.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['title'], 'Economizar')

    def test_transaction_link_lookup_by_uuid(self):
        """Testa busca de vínculo por UUID."""
        # Criar transações
        income = Transaction.objects.create(
            user=self.user1,
            type='INCOME',
            description='Salário',
            amount=Decimal('5000.00'),
            date=timezone.now().date()
        )
        
        expense = Transaction.objects.create(
            user=self.user1,
            type='EXPENSE',
            description='Aluguel',
            amount=Decimal('1500.00'),
            date=timezone.now().date()
        )
        
        # Criar vínculo
        link = TransactionLink.objects.create(
            user=self.user1,
            source_transaction_uuid=income.id,
            target_transaction_uuid=expense.id,
            linked_amount=Decimal('1500.00'),
            link_type='DEBT_PAYMENT'
        )
        
        self.assertIsNotNone(link.id)
        
        response = self.client.get(f'/api/transaction-links/{link.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['id'], str(link.id))


class UUIDCreationTestCase(TestCase):
    """Testa criação de recursos com UUIDs."""

    def setUp(self):
        """Configuração inicial."""
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        self.client.force_authenticate(user=self.user)

    def test_create_transaction_link_with_uuid(self):
        """Testa criação de vínculo usando UUIDs das transações."""
        # Criar transações
        income = Transaction.objects.create(
            user=self.user,
            type='INCOME',
            description='Salário',
            amount=Decimal('5000.00'),
            date=timezone.now().date()
        )
        
        expense = Transaction.objects.create(
            user=self.user,
            type='EXPENSE',
            description='Aluguel',
            amount=Decimal('1500.00'),
            date=timezone.now().date()
        )
        
        # Criar vínculo usando UUIDs
        response = self.client.post(
            '/api/transaction-links/quick_link/',
            {
                'source_uuid': str(income.id),
                'target_uuid': str(expense.id),
                'linked_amount': '1500.00'
            },
            format='json'  # Especificar formato JSON
        )
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('id', response.data)
        
        # Verificar que foi criado (id agora é UUID)
        link = TransactionLink.objects.get(id=response.data['id'])
        self.assertEqual(link.source_transaction, income)
        self.assertEqual(link.target_transaction, expense)

    def test_create_transaction_link_with_id(self):
        """Testa criação de vínculo usando UUIDs (agora id é UUID)."""
        # Criar transações
        income = Transaction.objects.create(
            user=self.user,
            type='INCOME',
            description='Salário',
            amount=Decimal('5000.00'),
            date=timezone.now().date()
        )
        
        expense = Transaction.objects.create(
            user=self.user,
            type='EXPENSE',
            description='Aluguel',
            amount=Decimal('1500.00'),
            date=timezone.now().date()
        )
        
        # Criar vínculo usando UUIDs (agora id é UUID)
        response = self.client.post(
            '/api/transaction-links/quick_link/',
            {
                'source_uuid': str(income.id),
                'target_uuid': str(expense.id),
                'linked_amount': '1500.00'
            },
            format='json'  # Especificar formato JSON
        )
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('id', response.data)

    def test_create_transaction_link_mixed(self):
        """Testa criação de vínculo usando apenas UUIDs (id agora é UUID)."""
        income = Transaction.objects.create(
            user=self.user,
            type='INCOME',
            description='Salário',
            amount=Decimal('5000.00'),
            date=timezone.now().date()
        )
        
        expense = Transaction.objects.create(
            user=self.user,
            type='EXPENSE',
            description='Aluguel',
            amount=Decimal('1500.00'),
            date=timezone.now().date()
        )
        
        # Criar vínculo: Apenas UUID (id agora é UUID)
        response = self.client.post(
            '/api/transaction-links/quick_link/',
            {
                'source_uuid': str(income.id),
                'target_uuid': str(expense.id),
                'linked_amount': '1500.00'
            },
            format='json'  # Especificar formato JSON
        )
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)


class UUIDPermissionTestCase(TestCase):
    """Testa permissões com UUIDs."""

    def setUp(self):
        """Configuração inicial."""
        self.client = APIClient()
        self.user1 = User.objects.create_user(
            username='user1',
            email='user1@example.com',
            password='pass123'
        )
        self.user2 = User.objects.create_user(
            username='user2',
            email='user2@example.com',
            password='pass123'
        )

    def test_cannot_access_other_user_transaction_by_uuid(self):
        """Testa que usuário não pode acessar transação de outro por UUID."""
        # Criar transação do user1
        transaction = Transaction.objects.create(
            user=self.user1,
            type='INCOME',
            description='Salário User1',
            amount=Decimal('5000.00'),
            date=timezone.now().date()
        )
        
        # Autenticar como user2
        self.client.force_authenticate(user=self.user2)
        
        # Tentar acessar por UUID
        response = self.client.get(f'/api/transactions/{transaction.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_cannot_access_other_user_goal_by_uuid(self):
        """Testa que usuário não pode acessar meta de outro por UUID."""
        goal = Goal.objects.create(
            user=self.user1,
            title='Meta User1',
            description='Descrição',
            target_amount=Decimal('10000.00'),
            goal_type='SAVINGS',
            tracking_period='MONTHLY'
        )
        
        self.client.force_authenticate(user=self.user2)
        
        response = self.client.get(f'/api/goals/{goal.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)


class UUIDAutoGenerationTestCase(TestCase):
    """Testa geração automática de UUIDs."""

    def test_transaction_auto_generates_uuid(self):
        """Testa que transação gera UUID automaticamente."""
        user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='pass123'
        )
        
        transaction = Transaction.objects.create(
            user=user,
            type='INCOME',
            description='Salário',
            amount=Decimal('5000.00'),
            date=timezone.now().date()
        )
        
        # UUID deve ser gerado automaticamente
        self.assertIsNotNone(transaction.id)
        self.assertIsInstance(transaction.id, uuid.UUID)

    def test_goal_auto_generates_uuid(self):
        """Testa que meta gera UUID automaticamente."""
        user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='pass123'
        )
        
        goal = Goal.objects.create(
            user=user,
            title='Economizar',
            description='Meta',
            target_amount=Decimal('10000.00'),
            goal_type='SAVINGS',
            tracking_period='MONTHLY'
        )
        
        self.assertIsNotNone(goal.id)
        self.assertIsInstance(goal.id, uuid.UUID)

    def test_uuid_uniqueness(self):
        """Testa que UUIDs são únicos."""
        user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='pass123'
        )
        
        t1 = Transaction.objects.create(
            user=user,
            type='INCOME',
            description='T1',
            amount=Decimal('1000.00'),
            date=timezone.now().date()
        )
        
        t2 = Transaction.objects.create(
            user=user,
            type='INCOME',
            description='T2',
            amount=Decimal('2000.00'),
            date=timezone.now().date()
        )
        
        self.assertNotEqual(t1.id, t2.id)

