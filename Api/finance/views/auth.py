"""
Views para autenticação, perfil e onboarding.
"""

import logging
from datetime import timedelta
from decimal import Decimal, InvalidOperation
import random

from django.contrib.auth import get_user_model
from django.db import transaction as db_transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework import mixins, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .base import (
    Category,
    MissionProgress,
    Transaction,
    TransactionLink,
    UserProfile,
    UserProfileSerializer,
    invalidate_user_dashboard_cache,
    profile_snapshot,
)

logger = logging.getLogger(__name__)
User = get_user_model()


class ProfileView(APIView):
    """View para gerenciamento de perfil do usuário."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        data = {
            "user": {
                "id": request.user.id,
                "email": request.user.email,
                "name": request.user.get_full_name() or request.user.username,
                "is_staff": request.user.is_staff,
                "is_superuser": request.user.is_superuser,
            },
            "profile": UserProfileSerializer(profile).data,
            "snapshot": profile_snapshot(request.user),
        }
        return Response(data)

    def put(self, request):
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        serializer = UserProfileSerializer(
            profile, data=request.data, partial=True
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        data = {
            "profile": serializer.data,
            "snapshot": profile_snapshot(request.user),
        }
        return Response(data)
    
    def patch(self, request):
        """Atualiza parcialmente o perfil."""
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        
        update_data = request.data.copy()
        
        # Verificar se metas financeiras estão sendo atualizadas
        goal_fields = {'target_tps', 'target_rdr', 'target_ili'}
        updating_goals = bool(goal_fields & set(update_data.keys()))
        
        if update_data.get('complete_first_access'):
            update_data['is_first_access'] = False
            update_data.pop('complete_first_access')
            
            logger.info(
                f"User {request.user.id} ({request.user.username}) completed first access/onboarding"
            )
        
        serializer = UserProfileSerializer(
            profile, data=update_data, partial=True
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        
        profile.refresh_from_db()
        
        # Invalidar cache se metas foram atualizadas
        if updating_goals:
            invalidate_user_dashboard_cache(request.user)
            logger.info(
                f"User {request.user.id} updated financial goals - cache invalidated"
            )
        
        response_serializer = UserProfileSerializer(profile)
        
        data = {
            "profile": response_serializer.data,
            "snapshot": profile_snapshot(request.user),
        }
        return Response(data)


class XPHistoryView(APIView):
    """Endpoint para visualizar histórico de XP do usuário."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from ..models import XPTransaction
        
        transactions = XPTransaction.objects.filter(
            user=request.user
        ).select_related('mission_progress__mission')[:50]
        
        data = []
        for tx in transactions:
            data.append({
                'id': tx.id,
                'mission_title': tx.mission_progress.mission.title,
                'mission_type': tx.mission_progress.mission.mission_type,
                'points_awarded': tx.points_awarded,
                'level_before': tx.level_before,
                'level_after': tx.level_after,
                'xp_before': tx.xp_before,
                'xp_after': tx.xp_after,
                'created_at': tx.created_at.isoformat(),
                'leveled_up': tx.level_after > tx.level_before,
            })
        
        return Response({
            'count': len(data),
            'transactions': data,
        })


class SimplifiedOnboardingView(APIView):
    """
    Endpoint para onboarding simplificado.
    Recebe apenas 2 valores: renda mensal e gastos essenciais.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        try:
            monthly_income = Decimal(str(request.data.get('monthly_income', 0)))
        except (InvalidOperation, ValueError, TypeError):
            return Response(
                {"error": "Renda mensal inválida. Use um número válido."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            essential_expenses = Decimal(str(request.data.get('essential_expenses', 0)))
        except (InvalidOperation, ValueError, TypeError):
            return Response(
                {"error": "Gastos essenciais inválidos. Use um número válido."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if monthly_income <= 0:
            return Response(
                {"error": "Renda mensal deve ser maior que zero."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if essential_expenses < 0:
            return Response(
                {"error": "Gastos essenciais não podem ser negativos."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if essential_expenses > monthly_income:
            return Response(
                {"error": "Gastos essenciais não podem exceder a renda."},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        user = request.user
        
        try:
            with db_transaction.atomic():
                income_cat, _ = Category.objects.get_or_create(
                    user=user,
                    name="Salário",
                    type=Category.CategoryType.INCOME,
                    defaults={
                        'group': Category.CategoryGroup.REGULAR_INCOME,
                        'color': '#4CAF50'
                    }
                )
                
                housing_cat, _ = Category.objects.get_or_create(
                    user=user,
                    name="Habitação",
                    type=Category.CategoryType.EXPENSE,
                    defaults={
                        'group': Category.CategoryGroup.ESSENTIAL_EXPENSE,
                        'color': '#FF5722'
                    }
                )
                
                Category.objects.get_or_create(
                    user=user,
                    name="Alimentação",
                    type=Category.CategoryType.EXPENSE,
                    defaults={
                        'group': Category.CategoryGroup.ESSENTIAL_EXPENSE,
                        'color': '#FF9800'
                    }
                )
                
                Category.objects.get_or_create(
                    user=user,
                    name="Transporte",
                    type=Category.CategoryType.EXPENSE,
                    defaults={
                        'group': Category.CategoryGroup.ESSENTIAL_EXPENSE,
                        'color': '#2196F3'
                    }
                )
                
                Category.objects.get_or_create(
                    user=user,
                    name="Contas Básicas",
                    type=Category.CategoryType.EXPENSE,
                    defaults={
                        'group': Category.CategoryGroup.ESSENTIAL_EXPENSE,
                        'color': '#FFC107'
                    }
                )
                
                Category.objects.get_or_create(
                    user=user,
                    name="Lazer",
                    type=Category.CategoryType.EXPENSE,
                    defaults={
                        'group': Category.CategoryGroup.LIFESTYLE_EXPENSE,
                        'color': '#9C27B0'
                    }
                )
                
                Category.objects.get_or_create(
                    user=user,
                    name="Reserva de Emergência",
                    type=Category.CategoryType.INCOME,
                    defaults={
                        'group': Category.CategoryGroup.SAVINGS,
                        'color': '#00BCD4'
                    }
                )
                
                Transaction.objects.create(
                    user=user,
                    description="Salário mensal",
                    amount=monthly_income,
                    category=income_cat,
                    type=Transaction.TransactionType.INCOME,
                    date=timezone.now().date()
                )
                
                if essential_expenses > 0:
                    Transaction.objects.create(
                        user=user,
                        description="Despesas essenciais mensais",
                        amount=essential_expenses,
                        category=housing_cat,
                        type=Transaction.TransactionType.EXPENSE,
                        date=timezone.now().date()
                    )
                
                profile = user.userprofile
                profile.is_first_access = False
                profile.indicators_updated_at = None
                profile.save()
        
        except Exception as e:
            logger.error(f"Erro ao processar onboarding simplificado: {e}")
            return Response(
                {"error": "Erro ao processar onboarding. Tente novamente."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        from ..services import calculate_summary, invalidate_indicators_cache
        invalidate_indicators_cache(user)
        invalidate_user_dashboard_cache(user)
        summary = calculate_summary(user)
        
        logger.info(f"Onboarding concluído para {user.username}. Summary: {summary}")
        
        balance = monthly_income - essential_expenses
        savings_rate = (balance / monthly_income * 100) if monthly_income > 0 else Decimal('0')
        
        recommendation = self._get_recommendation(savings_rate)
        
        return Response({
            "success": True,
            "insights": {
                "monthly_balance": float(balance),
                "savings_rate": float(savings_rate),
                "can_save": balance > 0,
                "recommendation": recommendation,
                "next_steps": [
                    "Registre suas transações diárias",
                    "Crie metas de economia",
                    "Complete desafios para ganhar pontos"
                ]
            }
        }, status=status.HTTP_201_CREATED)
    
    def _get_recommendation(self, savings_rate: Decimal) -> str:
        """Retorna recomendação baseada na taxa de poupança."""
        if savings_rate >= 20:
            return "Excelente! Você está no caminho certo para construir patrimônio."
        elif savings_rate >= 10:
            return "Bom começo! Tente aumentar gradualmente sua taxa de poupança."
        elif savings_rate >= 5:
            return "Você está começando a poupar. Procure oportunidades para economizar mais."
        else:
            return "Revise seus gastos e tente encontrar áreas onde pode economizar."


class RegisterView(APIView):
    """View pública para registro de novos usuários."""
    permission_classes = [permissions.AllowAny]
    authentication_classes = []
    throttle_classes = []

    def post(self, request):
        email = request.data.get("email", "").strip().lower()
        password = request.data.get("password")
        name = request.data.get("name", "").strip()

        if not email or not password:
            return Response(
                {"detail": "Email e senha são obrigatórios."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if User.objects.filter(email__iexact=email).exists():
            return Response(
                {"detail": "Já existe uma conta com esse email."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        username = email.split("@", 1)[0]
        user = User.objects.create_user(username=username, email=email, password=password)
        if name:
            parts = name.split(" ")
            user.first_name = parts[0]
            if len(parts) > 1:
                user.last_name = " ".join(parts[1:])
            user.save(update_fields=["first_name", "last_name"])

        refresh = RefreshToken.for_user(user)
        tokens = {"access": str(refresh.access_token), "refresh": str(refresh)}

        user_payload = {
            "id": user.id,
            "email": user.email,
            "name": user.get_full_name() or user.username,
            "is_staff": user.is_staff,
            "is_superuser": user.is_superuser,
        }

        return Response(
            {
                "access": tokens["access"],
                "refresh": tokens["refresh"],
                "tokens": tokens,
                "user": user_payload,
            },
            status=status.HTTP_201_CREATED,
        )


class UserProfileViewSet(
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    """ViewSet para gerenciar perfil do usuário."""
    serializer_class = UserProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user

    @action(detail=False, methods=['get'])
    def me(self, request):
        """Retorna dados do usuário autenticado com informações do profile."""
        user = request.user
        
        profile, _ = UserProfile.objects.get_or_create(user=user)
        
        return Response({
            'id': user.id,
            'email': user.email,
            'name': user.get_full_name() or user.username,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'username': user.username,
            'is_staff': user.is_staff,
            'is_superuser': user.is_superuser,
            'level': profile.level,
            'experience_points': profile.experience_points,
            'next_level_threshold': profile.next_level_threshold,
            'target_tps': profile.target_tps,
            'target_rdr': profile.target_rdr,
            'target_ili': float(profile.target_ili),
            'is_first_access': profile.is_first_access,
        })

    @action(detail=False, methods=['patch'])
    def update_profile(self, request):
        """Atualiza nome e/ou email do usuário."""
        user = request.user
        name = request.data.get('name', '').strip()
        email = request.data.get('email', '').strip().lower()

        if name:
            parts = name.split(' ', 1)
            user.first_name = parts[0]
            user.last_name = parts[1] if len(parts) > 1 else ''

        if email and email != user.email:
            if User.objects.filter(email__iexact=email).exclude(id=user.id).exists():
                return Response(
                    {'detail': 'Este email já está em uso.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            user.email = email
            user.username = email.split('@')[0]

        user.save()

        return Response({
            'id': user.id,
            'email': user.email,
            'name': user.get_full_name() or user.username,
            'is_staff': user.is_staff,
            'is_superuser': user.is_superuser,
            'message': 'Perfil atualizado com sucesso.',
        })

    @action(detail=False, methods=['post'])
    def change_password(self, request):
        """Altera senha do usuário após validar senha atual."""
        user = request.user
        current_password = request.data.get('current_password', '')
        new_password = request.data.get('new_password', '')

        if not current_password or not new_password:
            return Response(
                {'detail': 'Senha atual e nova senha são obrigatórias.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not user.check_password(current_password):
            return Response(
                {'detail': 'Senha atual incorreta.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if len(new_password) < 6:
            return Response(
                {'detail': 'A nova senha deve ter pelo menos 6 caracteres.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.set_password(new_password)
        user.save()

        return Response({
            'message': 'Senha alterada com sucesso.',
        })

    @action(detail=False, methods=['delete'])
    def delete_account(self, request):
        """Exclui conta do usuário após validar senha."""
        user = request.user
        password = request.data.get('password', '')

        if not password:
            return Response(
                {'detail': 'Senha é obrigatória para excluir a conta.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not user.check_password(password):
            return Response(
                {'detail': 'Senha incorreta.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user_id = user.id
        user.delete()

        return Response({
            'message': f'Conta {user_id} excluída permanentemente.',
        }, status=status.HTTP_200_OK)
    
    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def dev_reset_account(self, request):
        """Reseta conta do usuário (apenas para desenvolvimento)."""
        user = request.user
        
        Transaction.objects.filter(user=user).delete()
        TransactionLink.objects.filter(user=user).delete()
        MissionProgress.objects.filter(user=user).delete()
        
        profile = UserProfile.objects.get(user=user)
        profile.level = 1
        profile.experience_points = 0
        profile.save()
        
        invalidate_user_dashboard_cache(user)
        
        return Response({
            'success': True,
            'message': 'Conta resetada com sucesso',
            'level': 1,
            'xp': 0
        })
    
    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def dev_add_xp(self, request):
        """Adiciona XP ao usuário (apenas para desenvolvimento)."""
        from ..services import _xp_threshold
        
        xp_amount = request.data.get('xp', 1000)
        user = request.user
        
        profile = UserProfile.objects.get(user=user)
        old_level = profile.level
        profile.experience_points += xp_amount
        
        while profile.experience_points >= _xp_threshold(profile.level):
            profile.experience_points -= _xp_threshold(profile.level)
            profile.level += 1
        
        profile.save()
        
        return Response({
            'success': True,
            'xp_added': xp_amount,
            'old_level': old_level,
            'new_level': profile.level,
            'current_xp': profile.experience_points
        })
    
    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def dev_complete_missions(self, request):
        """Completa todas as missões ativas (apenas para desenvolvimento)."""
        user = request.user
        
        active_missions = MissionProgress.objects.filter(
            user=user,
            status__in=['PENDING', 'ACTIVE']
        )
        
        count = 0
        for mp in active_missions:
            mp.status = 'COMPLETED'
            mp.progress = 100.0
            mp.completed_at = timezone.now()
            mp.save()
            count += 1
        
        return Response({
            'success': True,
            'completed_count': count
        })

    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def dev_clear_cache(self, request):
        """Limpa cache do usuário (apenas para desenvolvimento)."""
        user = request.user
        invalidate_user_dashboard_cache(user)
        
        return Response({
            'success': True,
            'message': 'Cache invalidado com sucesso'
        })
    
    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def dev_add_test_data(self, request):
        """Adiciona dados de teste (apenas para desenvolvimento)."""
        user = request.user
        count = request.data.get('count', 10)
        
        categories = list(Category.objects.filter(Q(user=user) | Q(user=None))[:5])
        if not categories:
            return Response({'error': 'Nenhuma categoria disponível'}, status=400)
        
        created = []
        for i in range(count):
            tx_type = random.choice(['INCOME', 'EXPENSE'])
            amount = Decimal(random.randint(10, 500))
            date = timezone.now().date() - timedelta(days=random.randint(0, 30))
            
            tx = Transaction.objects.create(
                user=user,
                type=tx_type,
                description=f'Teste {tx_type} #{i+1}',
                amount=amount,
                date=date,
                category=random.choice(categories)
            )
            created.append(str(tx.id))
        
        invalidate_user_dashboard_cache(user)
        
        return Response({
            'success': True,
            'created_count': len(created),
            'transaction_ids': created[:5]
        })
