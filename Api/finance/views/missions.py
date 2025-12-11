
import logging
from collections import Counter, defaultdict
from decimal import Decimal

from django.db.models import Q
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from .base import (
    Category,
    CategorySerializer,
    invalidate_user_dashboard_cache,
    Mission,
    MissionProgress,
    MissionProgressSerializer,
    MissionSerializer,
    Transaction,
    UserProfile,
    apply_mission_reward,
    assign_missions_automatically,
)
from ..services import (
    start_mission,
    skip_mission,
)

logger = logging.getLogger(__name__)


class MissionViewSet(viewsets.ModelViewSet):
    serializer_class = MissionSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = [
        'mission_type',
        'validation_type',
        'difficulty',
        'is_active',
        'transaction_type_filter',
        'requires_payment_tracking',
        'is_system_generated',
    ]
    search_fields = ['title', 'description']
    ordering_fields = ['created_at', 'priority', 'reward_points', 'difficulty']
    ordering = ['priority', '-created_at']

    def _get_tier_level_range(self, tier):
        tier_ranges = {
            'BEGINNER': (1, 5),
            'INTERMEDIATE': (6, 15),
            'ADVANCED': (16, 100)
        }
        return tier_ranges.get(tier, (1, 100))
    
    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [permissions.IsAdminUser()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        queryset = Mission.objects.all().select_related(
            'target_category'
        ).prefetch_related(
            'target_categories'
        )
        
        if not self.request.user.is_staff:
            queryset = queryset.filter(is_active=True)
        
        tier = self.request.query_params.get('tier', None)
        if tier:
            tier_level_range = self._get_tier_level_range(tier)
            queryset = queryset.filter(
                Q(min_transactions__isnull=True) | 
                Q(min_transactions__lte=tier_level_range[1])
            )
        
        has_category = self.request.query_params.get('has_category', None)
        if has_category is not None:
            if has_category.lower() == 'true':
                queryset = queryset.filter(
                    Q(target_category__isnull=False) | Q(target_categories__isnull=False)
                ).distinct()
            else:
                queryset = queryset.filter(
                    target_category__isnull=True,
                    target_categories__isnull=True
                )
        

        return queryset
    
    def perform_create(self, serializer):
        mission = serializer.save()
        logger.info(f"Missão '{mission.title}' criada por admin {self.request.user.username}")
        invalidate_user_dashboard_cache(self.request.user)
        return mission
    
    def perform_update(self, serializer):
        mission = serializer.save()
        logger.info(f"Missão '{mission.title}' atualizada por admin {self.request.user.username}")
        for progress in MissionProgress.objects.filter(mission=mission).select_related('user'):
            invalidate_user_dashboard_cache(progress.user)
        return mission
    
    def perform_destroy(self, instance):
        for progress in MissionProgress.objects.filter(mission=instance).select_related('user'):
            invalidate_user_dashboard_cache(progress.user)
        instance.is_active = False
        instance.save()
        logger.info(f"Missão '{instance.title}' desativada por admin {self.request.user.username}")
    
    @action(detail=True, methods=['post'])
    def start(self, request, pk=None):
        try:
            mission = self.get_object()
            
            # Categorias selecionadas para missões de variação percentual
            # None ou [] = "Geral" (todas as categorias)
            selected_category_ids = request.data.get('category_ids', None)
            
            progress = start_mission(
                request.user, 
                mission.id,
                selected_category_ids=selected_category_ids
            )
            invalidate_user_dashboard_cache(request.user)
            return Response(MissionProgressSerializer(progress).data)
        except MissionProgress.DoesNotExist:
            return Response(
                {'error': 'Missão não atribuída ao usuário'},
                status=status.HTTP_404_NOT_FOUND
            )
        except ValueError as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )

    @action(detail=True, methods=['post'])
    def skip(self, request, pk=None):
        try:
            mission = self.get_object()
            progress = skip_mission(request.user, mission.id)
            invalidate_user_dashboard_cache(request.user)
            return Response(MissionProgressSerializer(progress).data)
        except MissionProgress.DoesNotExist:
            return Response(
                {'error': 'Missão não atribuída ao usuário'},
                status=status.HTTP_404_NOT_FOUND
            )
        except ValueError as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def duplicate(self, request, pk=None):
        original_mission = self.get_object()
        title_suffix = request.data.get('title_suffix', ' - Cópia')
        
        duplicated = Mission.objects.create(
            title=f"{original_mission.title}{title_suffix}",
            description=original_mission.description,
            reward_points=original_mission.reward_points,
            difficulty=original_mission.difficulty,
            mission_type=original_mission.mission_type,
            priority=original_mission.priority + 1,
            target_tps=original_mission.target_tps,
            target_rdr=original_mission.target_rdr,
            min_ili=original_mission.min_ili,
            max_ili=original_mission.max_ili,
            min_transactions=original_mission.min_transactions,
            duration_days=original_mission.duration_days,
            is_active=False,
            validation_type=original_mission.validation_type,
            requires_consecutive_days=original_mission.requires_consecutive_days,
            min_consecutive_days=original_mission.min_consecutive_days,
            target_category=original_mission.target_category,
            target_reduction_percent=original_mission.target_reduction_percent,
            category_spending_limit=original_mission.category_spending_limit,
            savings_increase_amount=original_mission.savings_increase_amount,
        )
        
        logger.info(f"Missão '{original_mission.title}' duplicada por admin {request.user.username}")
        
        serializer = self.get_serializer(duplicated)
        return Response({
            'success': True,
            'message': 'Missão duplicada com sucesso',
            'original_id': str(original_mission.id),
            'duplicated': serializer.data
        }, status=status.HTTP_201_CREATED)
    
    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def toggle_active(self, request, pk=None):
        mission = self.get_object()
        mission.is_active = not mission.is_active
        mission.save()
        
        status_text = 'ativada' if mission.is_active else 'desativada'
        logger.info(f"Missão '{mission.title}' {status_text} por admin {request.user.username}")
        
        serializer = self.get_serializer(mission)
        return Response({
            'success': True,
            'message': f'Missão {status_text} com sucesso',
            'mission': serializer.data
        })
    
    @action(detail=False, methods=['get'])
    def by_validation_type(self, request):
        queryset = self.filter_queryset(self.get_queryset())
        
        missions_by_type = defaultdict(list)
        
        for mission in queryset:
            serializer = self.get_serializer(mission)
            missions_by_type[mission.validation_type].append(serializer.data)
        
        return Response(dict(missions_by_type))
    
    @action(detail=False, methods=['get'])
    def statistics(self, request):
        queryset = self.filter_queryset(self.get_queryset())
        
        stats = {
            'total': queryset.count(),
            'by_mission_type': dict(Counter(queryset.values_list('mission_type', flat=True))),
            'by_validation_type': dict(Counter(queryset.values_list('validation_type', flat=True))),
            'by_difficulty': dict(Counter(queryset.values_list('difficulty', flat=True))),
            'by_transaction_filter': dict(Counter(queryset.values_list('transaction_type_filter', flat=True))),
            'active': queryset.filter(is_active=True).count(),
            'inactive': queryset.filter(is_active=False).count(),
            'system_generated': queryset.filter(is_system_generated=True).count(),
            'with_category': queryset.filter(
                Q(target_category__isnull=False) | Q(target_categories__isnull=False)
            ).distinct().count(),
            'with_payment_tracking': queryset.filter(requires_payment_tracking=True).count(),
        }
        
        return Response(stats)
    
    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def recommend(self, request):
        from ..services import analyze_user_context, calculate_mission_priorities
        
        limit = int(request.query_params.get('limit', 5))
        
        try:
            context = analyze_user_context(request.user)
            mission_priorities = calculate_mission_priorities(request.user, context)
        except Exception:
            return Response({
                'error': 'Análise não disponível no momento',
                'message': 'Registre algumas transações para obter recomendações personalizadas',
                'recommended_missions': [],
                'context_summary': None
            })
        
        top_missions = mission_priorities[:limit]
        
        recommended = []
        for mission, score in top_missions:
            reason = self._get_recommendation_reason(mission, context, score)
            
            recommended.append({
                'mission': MissionSerializer(mission).data,
                'priority_score': round(score, 2),
                'recommendation_reason': reason
            })
        
        return Response({
            'context_summary': {
                'at_risk_indicators': context.get('at_risk_indicators', []),
                'top_opportunities': context.get('spending_patterns', [])[:3],
                'transaction_count': context.get('transaction_count', 0),
                'days_active': context.get('days_active', 0),
                'summary': context.get('summary', {})
            },
            'recommended_missions': recommended
        })
    
    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated], url_path='by-category/(?P<category_id>[^/.]+)')
    def by_category(self, request, category_id=None):
        if not category_id:
            category_id = request.query_params.get('category_id')
        
        if not category_id:
            return Response(
                {'error': 'category_id é obrigatório'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            category = Category.objects.get(id=category_id, user=request.user)
        except Category.DoesNotExist:
            return Response(
                {'error': 'Categoria não encontrada'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        missions = Mission.objects.filter(
            Q(target_category=category) | Q(target_categories=category),
            is_active=True
        ).distinct()
        
        serializer = MissionSerializer(missions, many=True)
        return Response({
            'category': CategorySerializer(category).data,
            'missions': serializer.data,
            'count': missions.count()
        })
    
    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated], url_path='context-analysis')
    def context_analysis(self, request):
        from ..services import analyze_user_context, identify_improvement_opportunities
        
        try:
            context = analyze_user_context(request.user)
            opportunities = identify_improvement_opportunities(request.user)
        except Exception:
            return Response({
                'available': False,
                'error': 'Análise não disponível',
                'message': 'Certifique-se de ter transações registradas.',
                'context': None,
                'opportunities': [],
                'suggested_actions': []
            })
        
        suggested_actions = []
        for opp in opportunities[:5]:
            action = self._opportunity_to_action(opp)
            if action:
                suggested_actions.append(action)
        
        return Response({
            'available': True,
            'context': context,
            'opportunities': opportunities,
            'suggested_actions': suggested_actions
        })
    
    def _get_recommendation_reason(self, mission, context, score):
        at_risk = context.get('at_risk_indicators', [])
        
        for indicator in at_risk:
            if indicator['indicator'] == 'TPS' and 'TPS' in mission.mission_type:
                return f"Alta prioridade: TPS atual ({indicator['current']:.1f}%) abaixo da meta"
            elif indicator['indicator'] == 'RDR' and 'RDR' in mission.mission_type:
                return f"Alta prioridade: RDR atual ({indicator['current']:.1f}%) acima da meta"
            elif indicator['indicator'] == 'ILI' and 'ILI' in mission.mission_type:
                return f"Alta prioridade: ILI atual ({indicator['current']:.1f} meses) abaixo da meta"
        
        if score >= 70:
            return "Altamente recomendada para seu perfil atual"
        elif score >= 50:
            return "Recomendada com base em seu histórico"
        else:
            return "Adequada para desenvolvimento contínuo"
    
    def _opportunity_to_action(self, opportunity):
        opp_type = opportunity.get('type')
        
        if opp_type == 'CATEGORY_GROWTH':
            category_name = opportunity['data'].get('category_name')
            growth = opportunity['data'].get('growth_percent', 0)
            return {
                'action': 'REDUCE_CATEGORY_SPENDING',
                'description': f"Reduzir gastos em {category_name} que cresceram {growth:.1f}%",
                'priority': opportunity.get('priority'),
                'data': opportunity['data']
            }
        
        
        elif opp_type in ['INDICATOR_BELOW_TARGET', 'INDICATOR_ABOVE_TARGET']:
            return {
                'action': 'IMPROVE_INDICATOR',
                'description': opportunity.get('description'),
                'priority': opportunity.get('priority'),
                'data': opportunity['data']
            }
        
        return None

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def templates(self, request):
        from ..mission_templates import (
            ONBOARDING_TEMPLATES,
            TPS_TEMPLATES,
            RDR_TEMPLATES,
            ILI_TEMPLATES,
            CATEGORY_TEMPLATES,
        )
        
        include_inactive = request.query_params.get('include_inactive', '').lower() == 'true'
        
        templates_list = [
            {'key': 'ONBOARDING', 'name': 'Onboarding', 'templates': ONBOARDING_TEMPLATES},
            {'key': 'TPS_IMPROVEMENT', 'name': 'Melhoria de TPS', 'templates': TPS_TEMPLATES},
            {'key': 'RDR_REDUCTION', 'name': 'Redução de RDR', 'templates': RDR_TEMPLATES},
            {'key': 'ILI_BUILDING', 'name': 'Construção de ILI', 'templates': ILI_TEMPLATES},
            {'key': 'CATEGORY_REDUCTION', 'name': 'Redução por Categoria', 'templates': CATEGORY_TEMPLATES},
        ]
        
        result = []
        for group in templates_list:
            templates_data = []
            for i, template in enumerate(group['templates']):
                templates_data.append({
                    'id': f"{group['key']}_{i}",
                    'key': group['key'],
                    'title': template.get('title', ''),
                    'description': template.get('description', ''),
                    'difficulty': template.get('difficulty', 'MEDIUM'),
                    'duration_days': template.get('duration_days', 30),
                    'xp_reward': template.get('xp_reward', 100),
                })
            
            result.append({
                'key': group['key'],
                'name': group['name'],
                'count': len(templates_data),
                'templates': templates_data,
            })
        
        return Response({
            'groups': result,
            'total': sum(len(g['templates']) for g in result),
        })

    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAuthenticated], url_path='generate-from-template')
    def generate_from_template(self, request):
        from ..mission_templates import generate_from_template as gen_template
        from ..services import calculate_summary
        
        template_key = request.data.get('template_key', '')
        overrides = request.data.get('overrides', {})
        
        if not template_key:
            return Response(
                {'error': 'template_key é obrigatório'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        parts = template_key.rsplit('_', 1)
        if len(parts) != 2:
            return Response(
                {'error': 'template_key inválido'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        mission_type = parts[0]
        try:
            index = int(parts[1])
        except ValueError:
            return Response(
                {'error': 'Índice do template inválido'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        from ..mission_templates import (
            ONBOARDING_TEMPLATES,
            TPS_TEMPLATES,
            RDR_TEMPLATES,
            ILI_TEMPLATES,
            CATEGORY_TEMPLATES,
        )
        
        template_map = {
            'ONBOARDING': ONBOARDING_TEMPLATES,
            'TPS_IMPROVEMENT': TPS_TEMPLATES,
            'RDR_REDUCTION': RDR_TEMPLATES,
            'ILI_BUILDING': ILI_TEMPLATES,
            'CATEGORY_REDUCTION': CATEGORY_TEMPLATES,
        }
        
        if mission_type not in template_map:
            return Response(
                {'error': f'Tipo de missão desconhecido: {mission_type}'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        templates = template_map[mission_type]
        if index < 0 or index >= len(templates):
            return Response(
                {'error': f'Índice fora do range (0-{len(templates)-1})'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        template = templates[index]
        
        summary = calculate_summary(request.user)
        current_metrics = {
            'tps': summary.get('tps', 0),
            'rdr': summary.get('rdr', 0),
            'ili': summary.get('ili', 0),
        }
        
        try:
            mission_data = gen_template(template, 'INTERMEDIATE', current_metrics)
            
            for key, value in overrides.items():
                if key in mission_data:
                    mission_data[key] = value
            
            mission = Mission.objects.create(
                title=mission_data.get('title', 'Nova Missão'),
                description=mission_data.get('description', ''),
                reward_points=mission_data.get('xp_reward', 100),
                difficulty=mission_data.get('difficulty', 'MEDIUM'),
                mission_type=mission_type,
                target_tps=mission_data.get('target_tps'),
                target_rdr=mission_data.get('target_rdr'),
                min_ili=mission_data.get('min_ili'),
                duration_days=mission_data.get('duration_days', 30),
                min_transactions=mission_data.get('min_transactions'),
                is_active=True,
                is_system_generated=True,
            )
            
            serializer = MissionSerializer(mission)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
            
        except Exception as e:
            logger.error(f"Erro ao gerar missão de template: {e}")
            return Response(
                {'error': 'Erro ao gerar missão', 'detail': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def generate_template_missions(self, request):
        import time
        
        from ..mission_templates import generate_mission_batch_from_templates
        from ..services import calculate_summary
        
        start_time = time.time()
        
        tier = request.data.get('tier', 'BEGINNER')
        count = request.data.get('count', 20)
        distribution = request.data.get('distribution')
        
        if tier not in ['BEGINNER', 'INTERMEDIATE', 'ADVANCED']:
            return Response(
                {'error': 'tier deve ser BEGINNER, INTERMEDIATE ou ADVANCED'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            count = int(count)
            if count < 1 or count > 100:
                return Response(
                    {'error': 'count deve estar entre 1 e 100'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        except (ValueError, TypeError):
            return Response(
                {'error': 'count deve ser um número inteiro'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            current_metrics = {'tps': 15, 'rdr': 30, 'ili': 50000}
            
            try:
                tier_level_range = self._get_tier_level_range(tier)
                representative_profile = UserProfile.objects.filter(
                    level__range=tier_level_range
                ).select_related('user').order_by('-user__last_login').first()
                
                if representative_profile and representative_profile.user:
                    summary = calculate_summary(representative_profile.user)
                    current_metrics = {
                        'tps': summary.get('tps', 15),
                        'rdr': summary.get('rdr', 30),
                        'ili': summary.get('ili', 50000)
                    }
            except Exception as e:
                logger.warning(f"Usando métricas padrão: {e}")
            
            missions_data = generate_mission_batch_from_templates(
                tier=tier,
                current_metrics=current_metrics,
                count=count,
                distribution=distribution
            )
            
            missions = []
            for data in missions_data:
                mission = Mission.objects.create(**data)
                missions.append(mission)
            
            end_time = time.time()
            generation_time_ms = int((end_time - start_time) * 1000)
            
            missions_by_type = {}
            for mission in missions:
                m_type = mission.mission_type
                missions_by_type[m_type] = missions_by_type.get(m_type, 0) + 1
            
            serializer = MissionSerializer(missions, many=True)
            
            return Response({
                'success': True,
                'total_created': len(missions),
                'missions_by_type': missions_by_type,
                'created_missions': serializer.data[:10],
                'generation_time_ms': generation_time_ms,
                'tier': tier,
                'message': f'{len(missions)} missões criadas via templates em {generation_time_ms}ms'
            })
            
        except Exception as e:
            logger.error(f"Erro ao gerar missões via templates: {e}", exc_info=True)
            return Response({
                'success': False,
                'error': 'Erro ao gerar missões via templates',
                'detail': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def generate_ai_missions(self, request):
        from ..ai_services import generate_hybrid_missions
        
        tier = request.data.get('tier', 'BEGINNER')
        scenario = request.data.get('scenario', 'low_activity')
        count = request.data.get('count', 20)
        use_async = request.data.get('async', True)
        
        try:
            count = int(count)
            if count < 1 or count > 100:
                return Response(
                    {'error': 'count deve estar entre 1 e 100'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        except (ValueError, TypeError):
            return Response(
                {'error': 'count deve ser um número inteiro'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if tier not in ['BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'EXPERT']:
            return Response(
                {'error': 'tier deve ser BEGINNER, INTERMEDIATE, ADVANCED ou EXPERT'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            if use_async:
                from ..tasks import generate_missions_async
                
                task = generate_missions_async.delay(
                    tier=tier,
                    scenario_key=scenario,
                    count=count,
                    use_templates_first=True
                )
                
                logger.info(f"Task de geração iniciada: {task.id}")
                
                return Response({
                    'success': True,
                    'task_id': task.id,
                    'message': 'Geração de missões iniciada em background',
                    'poll_url': f'/api/missions/generation_status/{task.id}/',
                    'tier': tier,
                    'scenario': scenario,
                    'count': count,
                    'estimated_time': '30-90 segundos'
                }, status=status.HTTP_202_ACCEPTED)
            
            else:
                logger.warning(f"Geração SÍNCRONA solicitada: {tier}/{scenario}")
                
                result = generate_hybrid_missions(
                    tier=tier,
                    scenario_key=scenario,
                    count=count,
                    use_templates_first=True
                )
                
                created = result.get('created', [])
                failed = result.get('failed', [])
                summary = result.get('summary', {})
                
                return Response({
                    'success': summary['total_created'] > 0,
                    'total_created': summary['total_created'],
                    'total_failed': summary['total_failed'],
                    'summary': summary,
                    'created_missions': created[:10],
                    'failed_missions': failed[:5],
                    'tier': tier,
                    'scenario': scenario
                })
            
        except Exception as e:
            logger.error(f"Erro ao gerar missões: {e}", exc_info=True)
            return Response({
                'success': False,
                'error': 'Erro ao gerar missões',
                'detail': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(
        detail=False, 
        methods=['get'], 
        permission_classes=[permissions.IsAdminUser],
        url_path='generation_status/(?P<task_id>[^/.]+)'
    )
    def generation_status(self, request, task_id=None):
        from celery.result import AsyncResult
        from django.core.cache import cache
        
        if not task_id:
            return Response(
                {'error': 'task_id é obrigatório'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        cache_key = f'mission_generation_{task_id}'
        cached_data = cache.get(cache_key)
        
        if cached_data:
            return Response(cached_data)
        
        task = AsyncResult(task_id)
        
        if task.state == 'PENDING':
            return Response({
                'task_id': task_id,
                'status': 'PENDING',
                'current': 0,
                'total': 0,
                'percent': 0,
                'message': 'Aguardando worker disponível...'
            })
        
        elif task.state == 'STARTED':
            return Response({
                'task_id': task_id,
                'status': 'STARTED',
                'current': 0,
                'total': 0,
                'percent': 0,
                'message': 'Iniciando geração...'
            })
        
        elif task.state == 'SUCCESS':
            result = task.result
            return Response({
                'task_id': task_id,
                'status': 'SUCCESS',
                'current': result.get('summary', {}).get('total_created', 0),
                'total': result.get('summary', {}).get('total_created', 0) + result.get('summary', {}).get('total_failed', 0),
                'percent': 100,
                'message': 'Geração concluída',
                'created': result.get('created', [])[:10],
                'failed': result.get('failed', [])[:5],
                'summary': result.get('summary', {})
            })
        
        elif task.state == 'FAILURE':
            return Response({
                'task_id': task_id,
                'status': 'FAILURE',
                'current': 0,
                'total': 0,
                'percent': 0,
                'message': 'Erro na geração',
                'error': str(task.info)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        else:
            return Response({
                'task_id': task_id,
                'status': task.state,
                'current': 0,
                'total': 0,
                'percent': 0,
                'message': f'Estado: {task.state}'
            })
    
    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def generate_auto(self, request):
        import random
        
        total = request.data.get('total', 100)
        use_async = request.data.get('use_async', True)
        
        if not isinstance(total, int) or total < 1 or total > 500:
            return Response(
                {'error': 'total deve ser entre 1 e 500'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        beginner_count = int(total * 0.4)
        intermediate_count = int(total * 0.4)
        advanced_count = total - beginner_count - intermediate_count
        
        scenarios = ['ONBOARDING', 'SAVINGS', 'DEBT_REDUCTION', 'BUDGET_CONTROL', 'INVESTMENT']
        
        try:
            if use_async:
                from ..tasks import generate_missions_async
                tasks = []
                
                for tier, count in [('BEGINNER', beginner_count), ('INTERMEDIATE', intermediate_count), ('ADVANCED', advanced_count)]:
                    if count > 0:
                        scenario = random.choice(scenarios)
                        task = generate_missions_async.delay(
                            tier=tier,
                            scenario_key=scenario,
                            count=count,
                            use_templates_first=True
                        )
                        tasks.append({'tier': tier, 'scenario': scenario, 'count': count, 'task_id': task.id})
                
                return Response({
                    'success': True,
                    'message': f'Geração automática de {total} missões iniciada',
                    'distribution': {
                        'beginner': beginner_count,
                        'intermediate': intermediate_count,
                        'advanced': advanced_count
                    },
                    'tasks': tasks
                }, status=status.HTTP_202_ACCEPTED)
            else:
                created_total = 0
                failed_total = 0
                details = []
                
                for tier, count in [('BEGINNER', beginner_count), ('INTERMEDIATE', intermediate_count), ('ADVANCED', advanced_count)]:
                    if count > 0:
                        scenario = random.choice(scenarios)
                        from ..ai_services import generate_missions_by_scenario
                        result = generate_missions_by_scenario(scenario, [tier])
                        
                        tier_created = len([m for m in result.get('created', []) if m])
                        tier_failed = len(result.get('failed', []))
                        
                        created_total += tier_created
                        failed_total += tier_failed
                        details.append({
                            'tier': tier,
                            'scenario': scenario,
                            'created': tier_created,
                            'failed': tier_failed
                        })
                
                return Response({
                    'success': True,
                    'total_created': created_total,
                    'total_failed': failed_total,
                    'distribution': {
                        'beginner': beginner_count,
                        'intermediate': intermediate_count,
                        'advanced': advanced_count
                    },
                    'details': details
                })
        except Exception as e:
            logger.error(f"Erro na geração automática: {e}", exc_info=True)
            return Response(
                {'success': False, 'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class MissionProgressViewSet(viewsets.ModelViewSet):
    serializer_class = MissionProgressSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'put', 'patch', 'head', 'options']

    def get_queryset(self):
        qs = MissionProgress.objects.filter(user=self.request.user).select_related("mission")
        
        status_filter = self.request.query_params.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter)
        
        mission_type = self.request.query_params.get("mission_type")
        if mission_type:
            qs = qs.filter(mission__mission_type=mission_type)
        
        return qs

    def update(self, request, *args, **kwargs):
        from django.db import transaction
        
        partial = kwargs.pop('partial', False)
        
        with transaction.atomic():
            instance = MissionProgress.objects.select_for_update().get(pk=kwargs['pk'])
            serializer = self.get_serializer(instance, data=request.data, partial=partial)
            serializer.is_valid(raise_exception=True)
            self.perform_update(serializer)

            if getattr(instance, '_prefetched_objects_cache', None):
                instance._prefetched_objects_cache = {}

            return Response(serializer.data)

    def perform_update(self, serializer):
        from django.utils import timezone
        
        previous = serializer.instance.status
        progress = serializer.save()
        
        if (
            previous != MissionProgress.Status.COMPLETED
            and progress.status == MissionProgress.Status.COMPLETED
        ):
            progress.progress = 100
            progress.completed_at = timezone.now()
            progress.save(update_fields=['progress', 'completed_at'])
            apply_mission_reward(progress)
            
            assign_missions_automatically(self.request.user)
            invalidate_user_dashboard_cache(self.request.user)

    
    @action(detail=True, methods=['get'])
    def details(self, request, pk=None):
        mission_progress = self.get_object()
        serializer = self.get_serializer(mission_progress)
        
        data = serializer.data
        breakdown = self._calculate_progress_breakdown(mission_progress)
        data['progress_breakdown'] = breakdown
        
        timeline = self._get_progress_timeline(mission_progress)
        data['progress_timeline'] = timeline
        
        return Response(data)
    
    def _calculate_progress_breakdown(self, mission_progress):
        from ..services import calculate_summary
        
        mission = mission_progress.mission
        summary = calculate_summary(mission_progress.user)
        
        breakdown = {
            'components': [],
            'overall_status': mission_progress.status,
        }
        
        if mission.target_tps is not None and mission_progress.initial_tps is not None:
            current_tps = float(summary.get('tps', 0))
            initial_tps = float(mission_progress.initial_tps)
            target_tps = float(mission.target_tps)
            
            if current_tps >= target_tps:
                progress_pct = 100.0
            elif target_tps > initial_tps and (target_tps - initial_tps) > 0:
                progress_pct = min(100, max(0, ((current_tps - initial_tps) / (target_tps - initial_tps)) * 100))
            elif initial_tps >= target_tps:
                progress_pct = 100.0
            else:
                progress_pct = 100.0 if current_tps >= target_tps else 0.0
            
            breakdown['components'].append({
                'indicator': 'TPS',
                'name': 'Taxa de Poupança Pessoal',
                'initial': round(initial_tps, 2),
                'current': round(current_tps, 2),
                'target': target_tps,
                'progress': round(progress_pct, 1),
                'met': current_tps >= target_tps,
            })
        
        if mission.target_rdr is not None and mission_progress.initial_rdr is not None:
            current_rdr = float(summary.get('rdr', 0))
            initial_rdr = float(mission_progress.initial_rdr)
            target_rdr = float(mission.target_rdr)
            
            if current_rdr <= target_rdr:
                progress_pct = 100.0
            elif initial_rdr > target_rdr and (initial_rdr - target_rdr) > 0:
                progress_pct = min(100, max(0, ((initial_rdr - current_rdr) / (initial_rdr - target_rdr)) * 100))
            elif initial_rdr <= target_rdr:
                progress_pct = 100.0
            else:
                progress_pct = 100.0 if current_rdr <= target_rdr else 0.0
            
            breakdown['components'].append({
                'indicator': 'RDR',
                'name': 'Razão Dívida/Renda',
                'initial': round(initial_rdr, 2),
                'current': round(current_rdr, 2),
                'target': target_rdr,
                'progress': round(progress_pct, 1),
                'met': current_rdr <= target_rdr,
            })
        
        if mission.min_ili is not None and mission_progress.initial_ili is not None:
            current_ili = float(summary.get('ili', 0))
            initial_ili = float(mission_progress.initial_ili)
            target_ili = float(mission.min_ili)
            
            if current_ili >= target_ili:
                progress_pct = 100.0
            elif target_ili > initial_ili and (target_ili - initial_ili) > 0:
                progress_pct = min(100, max(0, ((current_ili - initial_ili) / (target_ili - initial_ili)) * 100))
            elif initial_ili >= target_ili:
                progress_pct = 100.0
            else:
                progress_pct = 100.0 if current_ili >= target_ili else 0.0
            
            breakdown['components'].append({
                'indicator': 'ILI',
                'name': 'Índice de Liquidez Imediata',
                'initial': round(initial_ili, 2),
                'current': round(current_ili, 2),
                'target': target_ili,
                'progress': round(progress_pct, 1),
                'met': current_ili >= target_ili,
            })
        
        if mission.min_transactions:
            current_count = Transaction.objects.filter(user=mission_progress.user).count()
            initial_count = mission_progress.initial_transaction_count or 0
            target_count = mission.min_transactions
            
            if target_count > initial_count:
                progress_pct = min(100, ((current_count - initial_count) / (target_count - initial_count)) * 100)
            else:
                progress_pct = 100 if current_count >= target_count else 0
            
            breakdown['components'].append({
                'indicator': 'Transações',
                'name': 'Transações Registradas',
                'initial': int(initial_count),
                'current': int(current_count),
                'target': int(target_count),
                'progress': round(progress_pct, 1),
                'met': current_count >= target_count,
            })
        
        return breakdown
    
    def _get_progress_timeline(self, mission_progress):
        from django.utils import timezone
        
        timeline = []
        
        timeline.append({
            'event': 'created',
            'label': 'Missão atribuída',
            'timestamp': mission_progress.updated_at.isoformat() if not mission_progress.started_at else None,
        })
        
        if mission_progress.started_at:
            timeline.append({
                'event': 'started',
                'label': 'Missão iniciada',
                'timestamp': mission_progress.started_at.isoformat(),
            })
        
        if mission_progress.completed_at:
            timeline.append({
                'event': 'completed',
                'label': 'Missão concluída',
                'timestamp': mission_progress.completed_at.isoformat(),
                'reward': mission_progress.mission.reward_points,
            })
        
        if mission_progress.started_at and mission_progress.mission.duration_days:
            deadline = mission_progress.started_at + timezone.timedelta(days=mission_progress.mission.duration_days)
            timeline.append({
                'event': 'deadline',
                'label': 'Prazo final',
                'timestamp': deadline.isoformat(),
                'is_future': deadline > timezone.now(),
            })
        
        return timeline
