from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from django.contrib.auth import get_user_model
from finance.models import Transaction, Category

User = get_user_model()

class SoftDeleteTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser', 
            password='testpassword123'
        )
        self.client.force_authenticate(user=self.user)
        
        self.category = Category.objects.create(
            user=self.user,
            name="Test Category",
            type=Category.CategoryType.EXPENSE,
            color="#FF0000"
        )
        
        self.transaction = Transaction.objects.create(
            user=self.user,
            description="Test Transaction",
            amount=100.00,
            type=Transaction.TransactionType.EXPENSE,
            category=self.category
        )
        
        self.url = reverse('transaction-detail', args=[self.transaction.id])
        self.list_url = reverse('transaction-list')

    def test_soft_delete_transaction(self):
        """
        Ensure deleting a transaction performs a soft delete.
        """
        # 1. Delete the transaction
        response = self.client.delete(self.url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        
        # 2. Verify it's not in the list
        response = self.client.get(self.list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 0)
        
        # 3. Verify it still exists in DB with deleted_at set
        transaction = Transaction.objects.get(id=self.transaction.id)
        self.assertIsNotNone(transaction.deleted_at)
        
    def test_soft_deleted_transaction_not_in_queryset(self):
        """
        Ensure soft deleted transactions are excluded from default queryset.
        """
        self.transaction.soft_delete()
        
        # Verify it's not in the list
        response = self.client.get(self.list_url)
        self.assertEqual(len(response.data['results']), 0)
        
        # Verify we can still access it directly via model if needed (but API 404s)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
