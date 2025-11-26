"""
Views para gerenciamento de categorias.
"""

import logging

from django.db.models import Q
from rest_framework import permissions, viewsets
from rest_framework.exceptions import ValidationError

from .base import (
    Category,
    CategorySerializer,
    Transaction,
    BurstRateThrottle,
    CategoryCreateThrottle,
)

logger = logging.getLogger(__name__)


class CategoryViewSet(viewsets.ModelViewSet):
    """
    ViewSet para CRUD de categorias.
    
    Endpoints:
    - GET /categories/ - Listar categorias
    - POST /categories/ - Criar categoria
    - GET /categories/{id}/ - Detalhe
    - PUT/PATCH /categories/{id}/ - Atualizar
    - DELETE /categories/{id}/ - Remover
    """
    
    serializer_class = CategorySerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_throttles(self):
        if self.action == 'create':
            return [CategoryCreateThrottle(), BurstRateThrottle()]
        return super().get_throttles()

    def get_queryset(self):
        user = self.request.user
        
        qs = Category.objects.filter(
            Q(user=user) | Q(user=None)
        )
        
        category_type = self.request.query_params.get("type")
        if category_type:
            qs = qs.filter(type=category_type)
        
        group = self.request.query_params.get("group")
        if group:
            qs = qs.filter(group=group)
        
        return qs.order_by("name")

    def perform_create(self, serializer):
        user = self.request.user
        data = serializer.validated_data
        
        is_creating_global = data.get('is_system_default', False)
        
        if is_creating_global and not user.is_staff:
            raise ValidationError({
                'is_system_default': 'Permissão negada para criar categorias de sistema.'
            })
        
        if is_creating_global and user.is_staff:
            self._create_global_category(serializer, data)
            return
        
        self._create_user_category(serializer, user, data)
    
    def _create_global_category(self, serializer, data):
        name = data.get('name', '').strip()
        category_type = data.get('type')
        
        existing = Category.objects.filter(
            user__isnull=True,
            name__iexact=name,
            type=category_type
        ).exists()
        
        if existing:
            raise ValidationError({
                'name': f'Categoria global "{name}" ({category_type}) já existe.'
            })
        
        serializer.save(user=None, is_system_default=True)
    
    def _create_user_category(self, serializer, user, data):
        custom_categories = Category.objects.filter(
            user=user, 
            is_system_default=False
        ).count()
        
        if custom_categories >= 100:
            raise ValidationError({
                'non_field_errors': 'Limite de 100 categorias personalizadas atingido.'
            })
        
        name = data.get('name', '').strip()
        category_type = data.get('type')
        
        existing = Category.objects.filter(
            user=user,
            name__iexact=name,
            type=category_type
        ).exists()
        
        if existing:
            raise ValidationError({
                'name': f'Categoria "{name}" ({category_type}) já existe.'
            })
        
        serializer.save(user=user, is_system_default=False)
    
    def perform_update(self, serializer):
        instance = self.get_object()
        user = self.request.user
        
        self._validate_update_permission(instance, user)
        self._validate_name_uniqueness(instance, user, serializer.validated_data)
        self._validate_system_default_unchanged(instance, serializer.validated_data)
        
        serializer.save()
    
    def _validate_update_permission(self, instance, user):
        if instance.user is None and not user.is_staff:
            raise ValidationError({
                'non_field_errors': 'Permissão negada para editar categorias globais.'
            })
        
        if instance.user is not None and instance.user != user:
            raise ValidationError({
                'non_field_errors': 'Permissão negada para editar categorias de outros usuários.'
            })
    
    def _validate_name_uniqueness(self, instance, user, data):
        if 'name' not in data:
            return
            
        name = data['name'].strip()
        category_type = data.get('type', instance.type)
        
        if instance.user is None:
            existing = Category.objects.filter(
                user__isnull=True,
                name__iexact=name,
                type=category_type
            ).exclude(pk=instance.pk).exists()
            
            if existing:
                raise ValidationError({
                    'name': f'Categoria global "{name}" ({category_type}) já existe.'
                })
        else:
            existing = Category.objects.filter(
                user=user,
                name__iexact=name,
                type=category_type
            ).exclude(pk=instance.pk).exists()
            
            if existing:
                raise ValidationError({
                    'name': f'Categoria "{name}" ({category_type}) já existe.'
                })
    
    def _validate_system_default_unchanged(self, instance, data):
        if 'is_system_default' in data and data['is_system_default'] != instance.is_system_default:
            raise ValidationError({
                'is_system_default': 'Status de categoria de sistema imutável.'
            })
    
    def perform_destroy(self, instance):
        user = self.request.user
        logger.info(
            f"Tentando deletar categoria ID={instance.id}, name={instance.name}, "
            f"user={instance.user}, is_system_default={instance.is_system_default}"
        )
        
        self._validate_delete_permission(instance, user)
        self._validate_no_linked_transactions(instance)
        
        logger.info(f"Deletando categoria {instance.name}")
        instance.delete()
        logger.info(f"Categoria {instance.name} deletada com sucesso")
    
    def _validate_delete_permission(self, instance, user):
        if instance.user is None and not user.is_staff:
            logger.warning(
                f"Usuário não-admin {user} tentou deletar categoria global: {instance.name}"
            )
            raise ValidationError({
                'non_field_errors': 'Permissão negada para excluir categorias globais.'
            })
        
        if instance.user is not None and instance.user != user:
            logger.warning(
                f"Usuário {user} tentou deletar categoria de outro usuário: {instance.user}"
            )
            raise ValidationError({
                'non_field_errors': 'Permissão negada para excluir categorias de outros usuários.'
            })
    
    def _validate_no_linked_transactions(self, instance):
        transaction_count = Transaction.objects.filter(category=instance).count()
        if transaction_count > 0:
            logger.warning(
                f"Categoria {instance.name} possui {transaction_count} transações vinculadas"
            )
            raise ValidationError({
                'non_field_errors': f'Categoria possui {transaction_count} transações vinculadas. Reatribua antes de excluir.'
            })
