import logging
from rest_framework import permissions

logger = logging.getLogger(__name__)


class IsOwnerPermission(permissions.BasePermission):
    """
    Garante que apenas o dono do recurso pode acessá-lo.
    Aplica-se a objetos que têm um campo 'user'.
    
    Uso:
        permission_classes = [permissions.IsAuthenticated, IsOwnerPermission]
    """
    
    def has_object_permission(self, request, view, obj):
        """
        Verifica se o usuário autenticado é o dono do objeto.

        """
        # Verificar se o objeto tem atributo 'user'
        if not hasattr(obj, 'user'):
            # Se não tem campo 'user', permitir (ex: categorias padrão)
            return True
        
        # Verificar ownership
        is_owner = obj.user == request.user
        
        # Log de tentativas de acesso não autorizado
        if not is_owner:
            logger.warning(
                f"Unauthorized access attempt detected: "
                f"User {request.user.id} ({request.user.username}) "
                f"tried to access {obj.__class__.__name__} (ID: {obj.id}) "
                f"owned by user {getattr(obj, 'user', None)}"
            )
        
        return is_owner


class IsOwnerOrReadOnly(permissions.BasePermission):
    """
    Permite leitura para todos, mas escrita apenas para o dono.
    Uso:
        permission_classes = [permissions.IsAuthenticated, IsOwnerOrReadOnly]
    """
    
    def has_object_permission(self, request, view, obj):
        # Permitir métodos de leitura (GET, HEAD, OPTIONS)
        if request.method in permissions.SAFE_METHODS:
            return True
        
        # Para métodos de escrita, verificar ownership
        if not hasattr(obj, 'user'):
            return True
        
        is_owner = obj.user == request.user
        
        if not is_owner and request.method not in permissions.SAFE_METHODS:
            logger.warning(
                f"Unauthorized write attempt: "
                f"User {request.user.id} tried to {request.method} "
                f"{obj.__class__.__name__} {obj.id} owned by {obj.user}"
            )
        
        return is_owner


class IsFriendOrOwner(permissions.BasePermission):
    """
    Permite acesso ao dono ou a amigos aceitos.
    Uso:
        permission_classes = [permissions.IsAuthenticated, IsFriendOrOwner]
    """
    
    def has_object_permission(self, request, view, obj):
        # Se é o dono, permitir
        if not hasattr(obj, 'user'):
            return True
        
        if obj.user == request.user:
            return True
        
        # Verificar se são amigos
        from .models import Friendship
        are_friends = Friendship.are_friends(request.user, obj.user)
        
        if not are_friends:
            logger.info(
                f"Access denied: User {request.user.id} is not friends with "
                f"user {obj.user.id} (object: {obj.__class__.__name__} {obj.id})"
            )
        
        return are_friends
