import uuid
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from finance.models import Category, Transaction, TransactionLink, Friendship

User = get_user_model()


class UUIDLookupTestCase(TestCase):

    def setUp(self):
        self.client = APIClient()
        
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
        
        self.category = Category.objects.create(
            name='Salário',
            type='INCOME',
            user=self.user1
        )
        
        self.client.force_authenticate(user=self.user1)

    def test_transaction_lookup_by_id(self):
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
        self.assertEqual(str(response.data['id']), str(transaction.id))
        self.assertEqual(response.data['description'], 'Salário')

    def test_transaction_lookup_by_uuid(self):
        transaction = Transaction.objects.create(
            user=self.user1,
            type='INCOME',
            description='Salário',
            amount=Decimal('5000.00'),
            date=timezone.now().date(),
            category=self.category
        )
        
        self.assertIsNotNone(transaction.id)
        
        response = self.client.get(f'/api/transactions/{transaction.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['id'], str(transaction.id))
        self.assertEqual(response.data['description'], 'Salário')

    def test_transaction_update_by_uuid(self):
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
            format='json'
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['description'], 'Salário Atualizado')
        
        transaction.refresh_from_db()
        self.assertEqual(transaction.description, 'Salário Atualizado')

    def test_transaction_delete_by_uuid(self):
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
        
        self.assertFalse(Transaction.objects.filter(id=transaction_uuid).exists())


    def test_transaction_link_lookup_by_uuid(self):
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

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='testpass123'
        )
        self.client.force_authenticate(user=self.user)

    def test_create_transaction_link_with_uuid(self):
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
        
        response = self.client.post(
            '/api/transaction-links/quick_link/',
            {
                'source_uuid': str(income.id),
                'target_uuid': str(expense.id),
                'linked_amount': '1500.00'
            },
            format='json'
        )
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('id', response.data)
        
        link = TransactionLink.objects.get(id=response.data['id'])
        self.assertEqual(link.source_transaction, income)
        self.assertEqual(link.target_transaction, expense)

    def test_create_transaction_link_with_id(self):
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
        
        response = self.client.post(
            '/api/transaction-links/quick_link/',
            {
                'source_uuid': str(income.id),
                'target_uuid': str(expense.id),
                'linked_amount': '1500.00'
            },
            format='json'
        )
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('id', response.data)

    def test_create_transaction_link_mixed(self):
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
        
        response = self.client.post(
            '/api/transaction-links/quick_link/',
            {
                'source_uuid': str(income.id),
                'target_uuid': str(expense.id),
                'linked_amount': '1500.00'
            },
            format='json'
        )
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)


class UUIDPermissionTestCase(TestCase):

    def setUp(self):
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
        transaction = Transaction.objects.create(
            user=self.user1,
            type='INCOME',
            description='Salário User1',
            amount=Decimal('5000.00'),
            date=timezone.now().date()
        )
        
        self.client.force_authenticate(user=self.user2)
        
        response = self.client.get(f'/api/transactions/{transaction.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)



class UUIDAutoGenerationTestCase(TestCase):

    def test_transaction_auto_generates_uuid(self):
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
        
        self.assertIsNotNone(transaction.id)
        self.assertIsInstance(transaction.id, uuid.UUID)


    def test_uuid_uniqueness(self):
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

