from django.test import TestCase
from django.contrib.auth import get_user_model

User = get_user_model()

class SimplificationPhase2Tests(TestCase):
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@test.com',
            password='testpass123'
        )
    
    def test_core_models_existem(self):
        from finance.models import (
            UserProfile,
            Category,
            Transaction,
            TransactionLink,
            Goal,
            Mission,
            MissionProgress
        )
        
        self.assertTrue(UserProfile)
        self.assertTrue(Category)
        self.assertTrue(Transaction)
        self.assertTrue(TransactionLink)
        self.assertTrue(Goal)
        self.assertTrue(Mission)
        self.assertTrue(MissionProgress)
    
    def test_modelos_removidos_nao_existem(self):
        with self.assertRaises(ImportError):
            from finance.models import Friendship
        
        with self.assertRaises(ImportError):
            from finance.models import Achievement
        
       with self.assertRaises(ImportError):
            from finance.models import UserAchievement
    
    def test_user_profile_funciona(self):
        from finance.models import UserProfile
        
        profile, created = UserProfile.objects.get_or_create(user=self.user)
        
        self.assertTrue(created or profile.id is not None)
        self.assertEqual(profile.user, self.user)
        self.assertEqual(profile.level, 1)
        self.assertEqual(profile.experience_points, 0)
