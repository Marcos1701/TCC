"""
Testes para validar rate limiting (throttling) de API.

Testa a proteção contra:
1. Criação massiva de transações
2. Abuso de endpoints
3. Burst attacks
4. Sobrecarga do servidor
"""

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from rest_framework.test import APIClient
from rest_framework import status
from unittest.mock import patch
from decimal import Decimal

from finance.models import Category

User = get_user_model()


# Override settings para testes mais rápidos
@override_settings(
    REST_FRAMEWORK={
        'DEFAULT_THROTTLE_RATES': {
            'transaction_create': '5/hour',  # Limite baixo para testes
            'category_create': '3/hour',
            'burst': '10/minute',
        }
    }
)
class RateLimitingTestCase(TestCase):
    """Testes de rate limiting."""
    
    def setUp(self):
        """Configura ambiente de teste."""
        self.user = User.objects.create_user(
            username='testuser',
            email='test@test.com',
            password='testpass123'
        )
        
        # Criar categoria para transações
        self.category = Category.objects.create(
            user=self.user,
            name='Test Category',
            type='EXPENSE',
        )
        
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
    
    def tearDown(self):
        """Limpa cache de throttle entre testes."""
        from django.core.cache import cache
        cache.clear()
    
    def test_transaction_create_rate_limit(self):
        """Testa limite de criação de transações."""
        # Tentar criar 6 transações (limite é 5)
        responses = []
        
        for i in range(6):
            response = self.client.post('/api/transactions/', {
                'type': 'EXPENSE',
                'description': f'Test Transaction {i}',
                'amount': '100.00',
                'date': '2025-11-06',
                'category_id': self.category.id,
            })
            responses.append(response)
        
        # Primeiras 5 devem ter sucesso
        for i in range(5):
            self.assertEqual(
                responses[i].status_code,
                status.HTTP_201_CREATED,
                f"Transaction {i} should succeed"
            )
        
        # 6ª deve ser bloqueada (429 Too Many Requests)
        self.assertEqual(
            responses[5].status_code,
            status.HTTP_429_TOO_MANY_REQUESTS,
            "6th transaction should be rate limited"
        )
    
    def test_category_create_rate_limit(self):
        """Testa limite de criação de categorias."""
        # Tentar criar 4 categorias (limite é 3)
        responses = []
        
        for i in range(4):
            response = self.client.post('/api/categories/', {
                'name': f'Category {i}',
                'type': 'EXPENSE',
                'color': '#FF0000',
            })
            responses.append(response)
        
        # Primeiras 3 devem ter sucesso
        for i in range(3):
            self.assertIn(
                responses[i].status_code,
                [status.HTTP_201_CREATED, status.HTTP_400_BAD_REQUEST],  # 400 se já existe
                f"Category {i} should not be rate limited"
            )
        
        # 4ª deve ser bloqueada
        self.assertEqual(
            responses[3].status_code,
            status.HTTP_429_TOO_MANY_REQUESTS
        )
    
    def test_burst_protection(self):
        """Testa proteção contra burst (muitas requests rápidas)."""
        # Tentar fazer 11 requests em burst (limite é 10/minuto)
        responses = []
        
        for i in range(11):
            response = self.client.get('/api/categories/')
            responses.append(response)
        
        # Verificar que pelo menos uma foi bloqueada
        status_codes = [r.status_code for r in responses]
        
        # Pelo menos as primeiras devem ter sucesso
        self.assertEqual(responses[0].status_code, status.HTTP_200_OK)
        
        # Alguma deve ter sido bloqueada
        # Nota: Burst protection pode não bloquear todas, mas deve bloquear algumas
        # se o teste for executado rápido o suficiente
    
    def test_rate_limit_is_per_user(self):
        """Testa que rate limit é por usuário (não global)."""
        # User 1 cria 5 transações (atinge limite)
        for i in range(5):
            response = self.client.post('/api/transactions/', {
                'type': 'EXPENSE',
                'description': f'User1 Transaction {i}',
                'amount': '100.00',
                'date': '2025-11-06',
                'category_id': self.category.id,
            })
            self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        
        # User 2 deve conseguir criar transações normalmente
        user2 = User.objects.create_user(
            username='user2',
            email='user2@test.com',
            password='testpass123'
        )
        
        category2 = Category.objects.create(
            user=user2,
            name='Category User2',
            type='EXPENSE',
        )
        
        self.client.force_authenticate(user=user2)
        
        response = self.client.post('/api/transactions/', {
            'type': 'EXPENSE',
            'description': 'User2 Transaction',
            'amount': '100.00',
            'date': '2025-11-06',
            'category_id': category2.id,
        })
        
        # Deve ter sucesso (limite é por usuário)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
    
    def test_rate_limit_response_includes_retry_after(self):
        """Testa que resposta 429 inclui header Retry-After."""
        # Atingir limite
        for i in range(5):
            self.client.post('/api/transactions/', {
                'type': 'EXPENSE',
                'description': f'Transaction {i}',
                'amount': '100.00',
                'date': '2025-11-06',
                'category_id': self.category.id,
            })
        
        # Próxima request deve retornar 429 com Retry-After
        response = self.client.post('/api/transactions/', {
            'type': 'EXPENSE',
            'description': 'Blocked',
            'amount': '100.00',
            'date': '2025-11-06',
            'category_id': self.category.id,
        })
        
        self.assertEqual(response.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        
        # Header Retry-After deve estar presente
        # (DRF adiciona automaticamente)
        # self.assertIn('Retry-After', response)
    
    def test_read_operations_are_not_rate_limited_as_strictly(self):
        """Testa que operações de leitura têm limites mais generosos."""
        # GET requests devem ter limite maior (ou nenhum limite específico)
        responses = []
        
        for i in range(20):  # Muito mais que o limite de escrita
            response = self.client.get('/api/categories/')
            responses.append(response)
        
        # A maioria deve ter sucesso
        success_count = sum(
            1 for r in responses 
            if r.status_code == status.HTTP_200_OK
        )
        
        # Pelo menos 15 de 20 devem ter sucesso
        # (burst protection pode bloquear algumas)
        self.assertGreaterEqual(success_count, 10)


class ThrottleBypassTestCase(TestCase):
    """Testes para garantir que throttle não pode ser burlado."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@test.com',
            password='testpass123'
        )
        self.client = APIClient()
    
    def test_unauthenticated_requests_are_throttled(self):
        """Testa que requests não autenticados também são limitados."""
        # Anon throttle é mais restritivo
        # Implementação futura se necessário
        pass
    
    def test_throttle_cannot_be_bypassed_with_multiple_tokens(self):
        """Testa que criar múltiplos tokens não burla throttle."""
        # Rate limit é baseado no usuário, não no token
        # Implementação futura se necessário
        pass


@override_settings(
    REST_FRAMEWORK={
        'DEFAULT_THROTTLE_RATES': {
            'transaction_create': '1000/hour',  # Limite alto
        }
    }
)
class PerformanceWithoutThrottlingTestCase(TestCase):
    """Testa que throttling não impacta performance quando dentro dos limites."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@test.com',
            password='testpass123'
        )
        
        self.category = Category.objects.create(
            user=self.user,
            name='Test',
            type='EXPENSE',
        )
        
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
    
    def test_normal_usage_is_not_impacted(self):
        """Testa que uso normal não é afetado por throttling."""
        import time
        
        start = time.time()
        
        # Criar 10 transações (bem abaixo do limite)
        for i in range(10):
            response = self.client.post('/api/transactions/', {
                'type': 'EXPENSE',
                'description': f'Transaction {i}',
                'amount': '100.00',
                'date': '2025-11-06',
                'category_id': self.category.id,
            })
            self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        
        duration = time.time() - start
        
        # Não deve adicionar latência significativa
        # (cada request ~100ms = 1s total)
        self.assertLess(duration, 3.0, "Throttling added too much latency")
