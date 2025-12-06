from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.response import Response
import uuid as uuid_lib


class UUIDLookupMixin:
    
    def get_object(self):
        queryset = self.filter_queryset(self.get_queryset())
        lookup_url_kwarg = self.lookup_url_kwarg or self.lookup_field
        lookup_value = self.kwargs.get(lookup_url_kwarg)
        
        if not lookup_value:
            return super().get_object()
        
        try:
            uuid_obj = uuid_lib.UUID(lookup_value)
            filter_kwargs = {'uuid': uuid_obj}
            obj = get_object_or_404(queryset, **filter_kwargs)
        except (ValueError, AttributeError):
            try:
                pk = int(lookup_value)
                filter_kwargs = {'pk': pk}
                obj = get_object_or_404(queryset, **filter_kwargs)
            except (ValueError, TypeError):
                from rest_framework.exceptions import NotFound
                raise NotFound('Recurso não encontrado.')
        
        self.check_object_permissions(self.request, obj)
        
        return obj


class UUIDResponseMixin:
    
    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        
        if (
            hasattr(response, 'data') 
            and isinstance(response.data, dict) 
            and 'uuid' in response.data
        ):
            response['X-Resource-UUID'] = str(response.data['uuid'])
        
        return response


class DeprecatedIDWarningMixin:
    
    def get_object(self):
        lookup_url_kwarg = self.lookup_url_kwarg or self.lookup_field
        lookup_value = self.kwargs.get(lookup_url_kwarg)
        
        try:
            int(lookup_value)
            is_numeric_id = True
        except (ValueError, TypeError):
            is_numeric_id = False
        
        obj = super().get_object()
        
        if is_numeric_id and hasattr(self, 'finalize_response'):
            import logging
            logger = logging.getLogger(__name__)
            logger.info(
                f"⚠️ Numeric ID used: {lookup_value} for {obj.__class__.__name__}. "
                f"Consider using UUID: {obj.uuid}"
            )
        
        return obj
