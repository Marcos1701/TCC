"""
Mixins customizados para ViewSets com suporte a UUID.
Permite aceitar tanto ID numérico quanto UUID nas URLs.
"""
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.response import Response
import uuid as uuid_lib


class UUIDLookupMixin:
    """
    Mixin que permite lookup por ID ou UUID.
    
    Uso:
        class MyViewSet(UUIDLookupMixin, viewsets.ModelViewSet):
            queryset = MyModel.objects.all()
            ...
    
    Aceita URLs:
        /api/resource/123/        # ID numérico (retrocompatibilidade)
        /api/resource/<uuid>/     # UUID (novo formato seguro)
    """
    
    def get_object(self):
        """
        Sobrescreve get_object para aceitar tanto pk (int) quanto uuid (str).
        """
        queryset = self.filter_queryset(self.get_queryset())
        lookup_url_kwarg = self.lookup_url_kwarg or self.lookup_field
        lookup_value = self.kwargs.get(lookup_url_kwarg)
        
        if not lookup_value:
            return super().get_object()
        
        # Tentar interpretar como UUID primeiro
        try:
            uuid_obj = uuid_lib.UUID(lookup_value)
            filter_kwargs = {'uuid': uuid_obj}
            obj = get_object_or_404(queryset, **filter_kwargs)
        except (ValueError, AttributeError):
            # Não é UUID, tentar como ID numérico
            try:
                pk = int(lookup_value)
                filter_kwargs = {'pk': pk}
                obj = get_object_or_404(queryset, **filter_kwargs)
            except (ValueError, TypeError):
                from rest_framework.exceptions import NotFound
                raise NotFound('Recurso não encontrado.')
        
        # Verificar permissões
        self.check_object_permissions(self.request, obj)
        
        return obj


class UUIDResponseMixin:
    """
    Mixin que modifica responses para priorizar UUID sobre ID.
    
    Em um futuro, quando removermos IDs numéricos completamente,
    este mixin facilitará a transição.
    """
    
    def finalize_response(self, request, response, *args, **kwargs):
        """
        Adiciona header com UUID para facilitar debug e transição.
        """
        response = super().finalize_response(request, response, *args, **kwargs)
        
        # Se for uma response de detalhe (GET /resource/id/), adicionar header
        if (
            hasattr(response, 'data') 
            and isinstance(response.data, dict) 
            and 'uuid' in response.data
        ):
            response['X-Resource-UUID'] = str(response.data['uuid'])
        
        return response


class DeprecatedIDWarningMixin:
    """
    Mixin que adiciona warnings quando ID numérico é usado.
    Ajuda a identificar código que ainda usa IDs ao invés de UUIDs.
    """
    
    def get_object(self):
        """
        Adiciona warning se ID numérico for usado.
        """
        lookup_url_kwarg = self.lookup_url_kwarg or self.lookup_field
        lookup_value = self.kwargs.get(lookup_url_kwarg)
        
        # Verificar se é ID numérico
        try:
            int(lookup_value)
            is_numeric_id = True
        except (ValueError, TypeError):
            is_numeric_id = False
        
        obj = super().get_object()
        
        # Se usou ID numérico, adicionar warning no response
        if is_numeric_id and hasattr(self, 'finalize_response'):
            import logging
            logger = logging.getLogger(__name__)
            logger.info(
                f"⚠️ Numeric ID used: {lookup_value} for {obj.__class__.__name__}. "
                f"Consider using UUID: {obj.uuid}"
            )
        
        return obj
