from django.contrib.auth import get_user_model
from django.db.models import Q
from rest_framework import mixins, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Category, Goal, Mission, MissionProgress, Transaction, UserProfile
from .serializers import (
    CategorySerializer,
    DashboardSerializer,
    GoalSerializer,
    MissionProgressSerializer,
    MissionSerializer,
    TransactionSerializer,
    UserProfileSerializer,
)
from .services import (
    apply_mission_reward,
    assign_missions_automatically,
    calculate_summary,
    cashflow_series,
    category_breakdown,
    indicator_insights,
    invalidate_indicators_cache,
    profile_snapshot,
    recommend_missions,
    update_mission_progress,
)

User = get_user_model()


class CategoryViewSet(viewsets.ModelViewSet):
    serializer_class = CategorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = Category.objects.filter(Q(user=user) | Q(user__isnull=True))
        category_type = self.request.query_params.get("type")
        if category_type:
            qs = qs.filter(type=category_type)
        group = self.request.query_params.get("group")
        if group:
            qs = qs.filter(group=group)
        return qs.order_by("name")

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class TransactionViewSet(viewsets.ModelViewSet):
    serializer_class = TransactionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = Transaction.objects.filter(user=self.request.user).select_related("category")
        tx_type = self.request.query_params.get("type")
        if tx_type:
            qs = qs.filter(type=tx_type)
        
        # Filtros avançados
        category_id = self.request.query_params.get("category")
        if category_id:
            qs = qs.filter(category_id=category_id)
        
        date_from = self.request.query_params.get("date_from")
        if date_from:
            qs = qs.filter(date__gte=date_from)
        
        date_to = self.request.query_params.get("date_to")
        if date_to:
            qs = qs.filter(date__lte=date_to)
        
        min_amount = self.request.query_params.get("min_amount")
        if min_amount:
            qs = qs.filter(amount__gte=min_amount)
        
        max_amount = self.request.query_params.get("max_amount")
        if max_amount:
            qs = qs.filter(amount__lte=max_amount)
        
        is_recurring = self.request.query_params.get("is_recurring")
        if is_recurring is not None:
            qs = qs.filter(is_recurring=is_recurring.lower() == 'true')
        
        return qs.order_by("-date", "-created_at")
    
    def perform_create(self, serializer):
        serializer.save()
        # Invalidar cache de indicadores após criar transação
        invalidate_indicators_cache(self.request.user)
    
    def perform_update(self, serializer):
        serializer.save()
        # Invalidar cache de indicadores após atualizar transação
        invalidate_indicators_cache(self.request.user)
    
    def perform_destroy(self, instance):
        instance.delete()
        # Invalidar cache de indicadores após deletar transação
        invalidate_indicators_cache(self.request.user)
    
    @action(detail=True, methods=['get'])
    def details(self, request, pk=None):
        """Retorna detalhes completos da transação com metadados."""
        transaction = self.get_object()
        serializer = self.get_serializer(transaction)
        
        # Adicionar informações extras
        data = serializer.data
        
        # Calcular impacto nos indicadores (estimativa)
        impact = self._calculate_transaction_impact(transaction)
        data['estimated_impact'] = impact
        
        # Estatísticas relacionadas
        stats = self._get_transaction_stats(transaction)
        data['related_stats'] = stats
        
        return Response(data)
    
    def _calculate_transaction_impact(self, transaction):
        """Calcula impacto estimado da transação nos indicadores."""
        from .services import calculate_summary
        
        summary = calculate_summary(transaction.user)
        total_income = float(summary.get('total_income', 0))
        
        if total_income == 0:
            return {
                'tps_impact': 0,
                'rdr_impact': 0,
                'message': 'Sem receitas registradas para calcular impacto',
            }
        
        amount = float(transaction.amount)
        
        # Impacto no TPS
        tps_impact = 0
        if transaction.type == Transaction.TransactionType.INCOME:
            # Receita aumenta TPS potencial
            tps_impact = (amount / (total_income + amount)) * 100
        elif transaction.type in [Transaction.TransactionType.EXPENSE, Transaction.TransactionType.DEBT_PAYMENT]:
            # Despesa/pagamento reduz TPS
            tps_impact = -(amount / total_income) * 100
        
        # Impacto no RDR (apenas para dívidas)
        rdr_impact = 0
        if transaction.category and transaction.category.type == Category.CategoryType.DEBT:
            if transaction.type == Transaction.TransactionType.EXPENSE:
                rdr_impact = (amount / total_income) * 100
            elif transaction.type == Transaction.TransactionType.DEBT_PAYMENT:
                rdr_impact = -(amount / total_income) * 100
        
        return {
            'tps_impact': round(tps_impact, 2),
            'rdr_impact': round(rdr_impact, 2),
            'message': 'Impacto estimado nos indicadores',
        }
    
    def _get_transaction_stats(self, transaction):
        """Retorna estatísticas relacionadas à transação."""
        from django.db.models import Sum, Count, Avg
        
        # Estatísticas da mesma categoria
        category_stats = None
        if transaction.category:
            category_qs = Transaction.objects.filter(
                user=transaction.user,
                category=transaction.category,
            )
            category_stats = category_qs.aggregate(
                total=Sum('amount'),
                count=Count('id'),
                avg=Avg('amount'),
            )
            if category_stats['total']:
                category_stats['total'] = float(category_stats['total'])
            if category_stats['avg']:
                category_stats['avg'] = float(category_stats['avg'])
        
        # Estatísticas do mesmo tipo
        type_stats = Transaction.objects.filter(
            user=transaction.user,
            type=transaction.type,
        ).aggregate(
            total=Sum('amount'),
            count=Count('id'),
            avg=Avg('amount'),
        )
        if type_stats['total']:
            type_stats['total'] = float(type_stats['total'])
        if type_stats['avg']:
            type_stats['avg'] = float(type_stats['avg'])
        
        return {
            'category_stats': category_stats,
            'type_stats': type_stats,
        }


class GoalViewSet(viewsets.ModelViewSet):
    serializer_class = GoalSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Goal.objects.filter(user=self.request.user).order_by("deadline", "title")


class MissionViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = MissionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Mission.objects.filter(is_active=True)


class MissionProgressViewSet(viewsets.ModelViewSet):
    serializer_class = MissionProgressSerializer
    permission_classes = [permissions.IsAuthenticated]
    # Remove create/delete - missões são atribuídas automaticamente
    http_method_names = ['get', 'put', 'patch', 'head', 'options']

    def get_queryset(self):
        qs = MissionProgress.objects.filter(user=self.request.user).select_related("mission")
        
        # Filtro por status
        status_filter = self.request.query_params.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter)
        
        # Filtro por tipo de missão
        mission_type = self.request.query_params.get("mission_type")
        if mission_type:
            qs = qs.filter(mission__mission_type=mission_type)
        
        return qs

    def perform_update(self, serializer):
        previous = serializer.instance.status
        progress = serializer.save()
        
        # Completar missão manualmente se usuário marcar como completa
        if (
            previous != MissionProgress.Status.COMPLETED
            and progress.status == MissionProgress.Status.COMPLETED
        ):
            from django.utils import timezone
            progress.progress = 100
            progress.completed_at = timezone.now()
            progress.save(update_fields=['progress', 'completed_at'])
            apply_mission_reward(progress)
            
            # Atribuir novas missões após completar uma
            assign_missions_automatically(self.request.user)
    
    @action(detail=True, methods=['get'])
    def details(self, request, pk=None):
        """Retorna detalhes completos da missão incluindo breakdown de progresso."""
        mission_progress = self.get_object()
        serializer = self.get_serializer(mission_progress)
        
        # Adicionar breakdown detalhado do progresso
        data = serializer.data
        breakdown = self._calculate_progress_breakdown(mission_progress)
        data['progress_breakdown'] = breakdown
        
        # Adicionar timeline de progresso (últimos registros)
        timeline = self._get_progress_timeline(mission_progress)
        data['progress_timeline'] = timeline
        
        return Response(data)
    
    def _calculate_progress_breakdown(self, mission_progress):
        """Calcula breakdown detalhado do progresso por critério."""
        from .services import calculate_summary
        from decimal import Decimal
        
        mission = mission_progress.mission
        summary = calculate_summary(mission_progress.user)
        
        breakdown = {
            'components': [],
            'overall_status': mission_progress.status,
        }
        
        # Componente TPS
        if mission.target_tps is not None and mission_progress.initial_tps is not None:
            current_tps = float(summary.get('tps', 0))
            initial_tps = float(mission_progress.initial_tps)
            target_tps = float(mission.target_tps)
            
            if target_tps > initial_tps:
                progress_pct = min(100, max(0, ((current_tps - initial_tps) / (target_tps - initial_tps)) * 100))
            else:
                progress_pct = 100 if current_tps >= target_tps else 0
            
            breakdown['components'].append({
                'indicator': 'TPS',
                'name': 'Taxa de Poupança Pessoal',
                'initial': initial_tps,
                'current': current_tps,
                'target': target_tps,
                'progress': round(progress_pct, 1),
                'met': current_tps >= target_tps,
            })
        
        # Componente RDR
        if mission.target_rdr is not None and mission_progress.initial_rdr is not None:
            current_rdr = float(summary.get('rdr', 0))
            initial_rdr = float(mission_progress.initial_rdr)
            target_rdr = float(mission.target_rdr)
            
            if initial_rdr > target_rdr:
                progress_pct = min(100, max(0, ((initial_rdr - current_rdr) / (initial_rdr - target_rdr)) * 100))
            else:
                progress_pct = 100 if current_rdr <= target_rdr else 0
            
            breakdown['components'].append({
                'indicator': 'RDR',
                'name': 'Razão Dívida/Renda',
                'initial': initial_rdr,
                'current': current_rdr,
                'target': target_rdr,
                'progress': round(progress_pct, 1),
                'met': current_rdr <= target_rdr,
            })
        
        # Componente ILI
        if mission.min_ili is not None and mission_progress.initial_ili is not None:
            current_ili = float(summary.get('ili', 0))
            initial_ili = float(mission_progress.initial_ili)
            target_ili = float(mission.min_ili)
            
            if target_ili > initial_ili:
                progress_pct = min(100, max(0, ((current_ili - initial_ili) / (target_ili - initial_ili)) * 100))
            else:
                progress_pct = 100 if current_ili >= target_ili else 0
            
            breakdown['components'].append({
                'indicator': 'ILI',
                'name': 'Índice de Liquidez Imediata',
                'initial': initial_ili,
                'current': current_ili,
                'target': target_ili,
                'progress': round(progress_pct, 1),
                'met': current_ili >= target_ili,
            })
        
        # Componente de transações (para onboarding)
        if mission.min_transactions:
            from .models import Transaction
            current_count = Transaction.objects.filter(user=mission_progress.user).count()
            initial_count = mission_progress.initial_transaction_count
            target_count = mission.min_transactions
            
            if target_count > initial_count:
                progress_pct = min(100, ((current_count - initial_count) / (target_count - initial_count)) * 100)
            else:
                progress_pct = 100 if current_count >= target_count else 0
            
            breakdown['components'].append({
                'indicator': 'TRANSACTIONS',
                'name': 'Transações Registradas',
                'initial': initial_count,
                'current': current_count,
                'target': target_count,
                'progress': round(progress_pct, 1),
                'met': current_count >= target_count,
            })
        
        return breakdown
    
    def _get_progress_timeline(self, mission_progress):
        """Retorna timeline simplificado do progresso (criação, início, conclusão)."""
        timeline = []
        
        # Criação
        timeline.append({
            'event': 'created',
            'label': 'Missão atribuída',
            'timestamp': mission_progress.updated_at.isoformat() if not mission_progress.started_at else None,
        })
        
        # Início
        if mission_progress.started_at:
            timeline.append({
                'event': 'started',
                'label': 'Missão iniciada',
                'timestamp': mission_progress.started_at.isoformat(),
            })
        
        # Conclusão
        if mission_progress.completed_at:
            timeline.append({
                'event': 'completed',
                'label': 'Missão concluída',
                'timestamp': mission_progress.completed_at.isoformat(),
                'reward': mission_progress.mission.reward_points,
            })
        
        # Prazo
        if mission_progress.started_at and mission_progress.mission.duration_days:
            from django.utils import timezone
            deadline = mission_progress.started_at + timezone.timedelta(days=mission_progress.mission.duration_days)
            timeline.append({
                'event': 'deadline',
                'label': 'Prazo final',
                'timestamp': deadline.isoformat(),
                'is_future': deadline > timezone.now(),
            })
        
        return timeline


class DashboardViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    permission_classes = [permissions.IsAuthenticated]

    def list(self, request, *args, **kwargs):
        # Atualizar progresso das missões antes de mostrar o dashboard
        update_mission_progress(request.user)
        
        # Garantir que o usuário tem missões atribuídas
        assign_missions_automatically(request.user)
        
        summary = calculate_summary(request.user)
        breakdown = category_breakdown(request.user)
        cashflow = cashflow_series(request.user)
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        insights = indicator_insights(summary, profile)
        
        # Buscar missões ativas (PENDING ou ACTIVE)
        active_missions = (
            MissionProgress.objects.filter(
                user=request.user,
                status__in=[MissionProgress.Status.PENDING, MissionProgress.Status.ACTIVE]
            )
            .select_related("mission")
            .order_by("mission__priority")
        )
        
        # Não mostrar mais "recomendações" - todas são atribuídas automaticamente
        # Mas mantém compatibilidade com serializer
        recommendations = []
        
        serializer = DashboardSerializer(
            {
                "summary": summary,
                "categories": breakdown,
                "cashflow": cashflow,
                "insights": insights,
                "active_missions": active_missions,
                "recommended_missions": recommendations,
                "profile": profile,
            },
            context={"request": request},
        )
        return Response(serializer.data)

    @action(detail=False, methods=["get"], url_path="missions")
    def missions_summary(self, request):
        # Atualizar progresso antes de mostrar
        update_mission_progress(request.user)
        
        progress_qs = MissionProgress.objects.filter(user=request.user).select_related("mission")
        serializer = MissionProgressSerializer(progress_qs, many=True)
        return Response(serializer.data)


class ProfileView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        data = {
            "user": {
                "id": request.user.id,
                "email": request.user.email,
                "name": request.user.get_full_name() or request.user.username,
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


class RegisterView(APIView):
    permission_classes = [permissions.AllowAny]

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
