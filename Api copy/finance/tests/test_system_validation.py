from decimal import Decimal
from django.test import TestCase
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.db.models.deletion import ProtectedError
from rest_framework.test import APIClient
from rest_framework import status
from finance.models import Category, Transaction, Mission

User = get_user_model()

class SystemValidationTestCase(TestCase):
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='validation_user',
            email='val@example.com',
            password='testpass123'
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
        
        self.category = Category.objects.create(
            user=self.user,
            name='Test Validations',
            type='EXPENSE',
            color='#FF0000'
        )

    def test_category_deletion_protection(self):
        """
        Validation 1: Ensure category cannot be deleted if it has linked transactions.
        Frontend prevents this, but Backend must also enforce it (or return 500/400).
        """
        # Create transaction linked to category
        Transaction.objects.create(
            user=self.user,
            type='EXPENSE',
            amount=Decimal('50.00'),
            date=timezone.now().date(),
            category=self.category,
            description='Test Transaction'
        )
        
        # Try to delete category via API
        response = self.client.delete(f'/api/categories/{self.category.id}/')
        
        # Should fail. Depending on implementation, it might be 400 or 500 (ProtectedError).
        # ideally 400 or 409 Conflict, but Django ProtectedError usuall causes 500 if not handled.
        # We check that it is NOT 204.
        self.assertNotEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        
        # Verify category still exists
        self.assertTrue(Category.objects.filter(id=self.category.id).exists())

    def test_mission_generation_integrity(self):
        """
        Validation 2: Verify Mission generation works without Goals dependency.
        """
        # Create a mission manually
        mission = Mission.objects.create(
            title='Validation Mission',
            description='Testing creation',
            mission_type='CATEGORY_REDUCTION',
            validation_type='CATEGORY_REDUCTION',
            target_category=self.category,
            target_reduction_percent=Decimal('10.00'),
            duration_days=7,
            reward_points=100,
            min_transaction_frequency=1,
            is_system_generated=True
        )
        
        self.assertIsNotNone(mission.id)
        
        # Verify serialization works (often reveals broken related fields)
        response = self.client.get(f'/api/missions/{mission.id}/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['title'], 'Validation Mission')

    def test_tps_rdr_calculation_flow(self):
        """
        Validation 3: Simulate a flow that affects indicators (TPS/RDR) implicitly.
        Just ensuring that adding transactions doesn't crash any signal or calculation listeners.
        """
        # Add Income
        self.client.post('/api/transactions/', {
            'type': 'INCOME',
            'description': 'Salary',
            'amount': '5000.00',
            'date': str(timezone.now().date())
        })
        
        # Add Expense
        response = self.client.post('/api/transactions/', {
            'type': 'EXPENSE',
            'description': 'Rent',
            'amount': '1500.00',
            'date': str(timezone.now().date()),
            'category_id': self.category.id
        })
        
        if response.status_code != status.HTTP_201_CREATED:
            print(f"\nTest Failed. Response: {response.data}")
            
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        # If signals for updating indicators were broken (e.g. referencing Goals), this might crash.
