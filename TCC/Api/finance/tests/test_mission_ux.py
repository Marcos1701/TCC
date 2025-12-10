from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APIClient
from finance.models.mission import Mission, MissionProgress

User = get_user_model()

class MissionUXTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser_ux',
            password='testpassword123',
            email='testux@example.com'
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
        
        self.mission = Mission.objects.create(
            title='Test Mission UX',
            description='Test Description',
            mission_type='TPS_IMPROVEMENT',
            reward_points=100,
            difficulty='EASY',
            duration_days=7
        )
        
        self.progress = MissionProgress.objects.create(
            user=self.user,
            mission=self.mission,
            status=MissionProgress.Status.PENDING,
            progress=0
        )

    def test_start_mission_success(self):
        url = reverse('mission-start', kwargs={'pk': self.mission.id})
        response = self.client.post(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.progress.refresh_from_db()
        self.assertEqual(self.progress.status, MissionProgress.Status.ACTIVE)
        self.assertIsNotNone(self.progress.started_at)

    def test_start_mission_idempotent(self):
        # Start once
        self.progress.status = MissionProgress.Status.ACTIVE
        self.progress.save()
        
        url = reverse('mission-start', kwargs={'pk': self.mission.id})
        response = self.client.post(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.progress.refresh_from_db()
        self.assertEqual(self.progress.status, MissionProgress.Status.ACTIVE)

    def test_skip_mission_success(self):
        url = reverse('mission-skip', kwargs={'pk': self.mission.id})
        response = self.client.post(url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.progress.refresh_from_db()
        self.assertEqual(self.progress.status, MissionProgress.Status.SKIPPED)

    def test_cannot_skip_completed_mission(self):
        self.progress.status = MissionProgress.Status.COMPLETED
        self.progress.save()
        
        url = reverse('mission-skip', kwargs={'pk': self.mission.id})
        response = self.client.post(url)
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('Cannot skip', response.data['error'])

    def test_cannot_start_completed_mission(self):
        self.progress.status = MissionProgress.Status.COMPLETED
        self.progress.save()
        
        url = reverse('mission-start', kwargs={'pk': self.mission.id})
        response = self.client.post(url)
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('Cannot start', response.data['error'])
