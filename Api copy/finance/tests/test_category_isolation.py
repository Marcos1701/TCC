"""
Testes para validar isolamento de categorias entre usuários.

Testa a implementação de segurança que garante que:
1. Usuários só veem suas próprias categorias
2. Categorias não são compartilhadas entre usuários
3. Novos usuários recebem categorias padrão automaticamente
4. Conformidade com LGPD
"""

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status

from finance.models import Category

User = get_user_model()


class CategoryIsolationTestCase(TestCase):
    """Testes de isolamento de categorias por usuário."""
    
    def setUp(self):
        """Configura ambiente de teste."""
        # Criar dois usuários
        self.user1 = User.objects.create_user(
            username='user1',
            email='user1@test.com',
            password='testpass123'
        )
        self.user2 = User.objects.create_user(
            username='user2',
            email='user2@test.com',
            password='testpass123'
        )
        
        self.client = APIClient()
    
    def test_new_user_receives_default_categories(self):
        """Testa se novo usuário recebe categorias padrão automaticamente."""
        # Usuários criados no setUp devem ter categorias padrão
        user1_categories = Category.objects.filter(user=self.user1)
        user2_categories = Category.objects.filter(user=self.user2)
        
        # Deve ter pelo menos 10 categorias padrão
        self.assertGreaterEqual(user1_categories.count(), 10)
        self.assertGreaterEqual(user2_categories.count(), 10)
        
        # Todas devem ser marcadas como system_default
        self.assertTrue(
            all(cat.is_system_default for cat in user1_categories)
        )
    
    def test_user_cannot_see_other_user_categories(self):
        """Testa se usuário não vê categorias de outro usuário via API."""
        # User1 cria categoria personalizada
        custom_cat = Category.objects.create(
            user=self.user1,
            name='Categoria Privada User1',
            type='EXPENSE',
            is_system_default=False
        )
        
        # User2 tenta listar categorias
        self.client.force_authenticate(user=self.user2)
        response = self.client.get('/api/categories/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verificar que categoria do user1 NÃO aparece
        category_ids = [cat['id'] for cat in response.data]
        self.assertNotIn(custom_cat.id, category_ids)
    
    def test_user_can_only_create_categories_for_themselves(self):
        """Testa se usuário só pode criar categorias para si mesmo."""
        self.client.force_authenticate(user=self.user1)
        
        response = self.client.post('/api/categories/', {
            'name': 'Minha Categoria',
            'type': 'EXPENSE',
            'color': '#FF0000',
            'group': 'LIFESTYLE_EXPENSE'
        })
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        
        # Verificar que categoria foi criada para user1
        category = Category.objects.get(id=response.data['id'])
        self.assertEqual(category.user, self.user1)
        self.assertFalse(category.is_system_default)
    
    def test_categories_are_isolated_in_database(self):
        """Testa isolamento em nível de banco de dados."""
        # User1 cria categoria
        cat1 = Category.objects.create(
            user=self.user1,
            name='Cat User1',
            type='INCOME',
        )
        
        # User2 cria categoria com mesmo nome
        cat2 = Category.objects.create(
            user=self.user2,
            name='Cat User1',  # Mesmo nome!
            type='INCOME',
        )
        
        # Devem ser categorias diferentes
        self.assertNotEqual(cat1.id, cat2.id)
        
        # User1 só vê sua categoria
        user1_cats = Category.objects.filter(
            user=self.user1,
            name='Cat User1'
        )
        self.assertEqual(user1_cats.count(), 1)
        self.assertEqual(user1_cats.first().id, cat1.id)
    
    def test_no_global_categories_exist(self):
        """Testa que não existem categorias globais (user=None)."""
        global_categories = Category.objects.filter(user__isnull=True)
        self.assertEqual(
            global_categories.count(),
            0,
            "Não devem existir categorias globais (user=None)"
        )
    
    def test_user_cannot_access_other_user_category_by_id(self):
        """Testa que usuário não pode acessar categoria de outro por ID direto."""
        # User1 cria categoria
        cat = Category.objects.create(
            user=self.user1,
            name='Privada',
            type='EXPENSE',
        )
        
        # User2 tenta acessar por ID
        self.client.force_authenticate(user=self.user2)
        response = self.client.get(f'/api/categories/{cat.id}/')
        
        # Deve retornar 404 (não encontrado) ao invés de 403
        # Isso previne information disclosure
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
    
    def test_user_cannot_update_other_user_category(self):
        """Testa que usuário não pode atualizar categoria de outro."""
        # User1 cria categoria
        cat = Category.objects.create(
            user=self.user1,
            name='Original',
            type='EXPENSE',
        )
        
        # User2 tenta atualizar
        self.client.force_authenticate(user=self.user2)
        response = self.client.patch(f'/api/categories/{cat.id}/', {
            'name': 'Hackeado'
        })
        
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        
        # Verificar que categoria não foi alterada
        cat.refresh_from_db()
        self.assertEqual(cat.name, 'Original')
    
    def test_user_cannot_delete_other_user_category(self):
        """Testa que usuário não pode deletar categoria de outro."""
        # User1 cria categoria
        cat = Category.objects.create(
            user=self.user1,
            name='Importante',
            type='EXPENSE',
        )
        
        # User2 tenta deletar
        self.client.force_authenticate(user=self.user2)
        response = self.client.delete(f'/api/categories/{cat.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        
        # Verificar que categoria ainda existe
        self.assertTrue(
            Category.objects.filter(id=cat.id).exists()
        )
    
    def test_category_queryset_filtering(self):
        """Testa que queryset filtra corretamente por usuário."""
        # Criar 5 categorias para user1
        for i in range(5):
            Category.objects.create(
                user=self.user1,
                name=f'Cat {i}',
                type='EXPENSE',
            )
        
        # Criar 3 categorias para user2
        for i in range(3):
            Category.objects.create(
                user=self.user2,
                name=f'Cat {i}',
                type='INCOME',
            )
        
        # User1 deve ver apenas suas categorias (+ padrões)
        self.client.force_authenticate(user=self.user1)
        response = self.client.get('/api/categories/')
        
        # Contar categorias (padrões + 5 criadas)
        self.assertGreaterEqual(len(response.data), 5)
        
        # Verificar que todas pertencem ao user1
        for cat in response.data:
            category = Category.objects.get(id=cat['id'])
            self.assertEqual(category.user, self.user1)


class CategorySecurityTestCase(TestCase):
    """Testes de segurança adicionais."""
    
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser',
            email='test@test.com',
            password='testpass123'
        )
        self.client = APIClient()
    
    def test_unauthenticated_cannot_list_categories(self):
        """Testa que usuário não autenticado não pode listar categorias."""
        response = self.client.get('/api/categories/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
    
    def test_unauthenticated_cannot_create_category(self):
        """Testa que usuário não autenticado não pode criar categoria."""
        response = self.client.post('/api/categories/', {
            'name': 'Teste',
            'type': 'EXPENSE'
        })
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
