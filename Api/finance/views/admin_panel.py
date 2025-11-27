"""
Views para Painel Administrativo Simplificado.

Este módulo fornece endpoints REST para o painel administrativo do aplicativo,
permitindo gerenciamento de missões, categorias e usuários de forma simplificada.

Desenvolvido para o TCC - Sistema de Educação Financeira Gamificada.
"""

import logging

from django.contrib.auth import get_user_model
from django.db.models import Count, Avg, Q
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import (
    Category,
    Mission,
    MissionProgress,
    UserProfile,
)
from ..serializers import (
    CategorySerializer,
    MissionSerializer,
)

logger = logging.getLogger(__name__)
User = get_user_model()


class AdminDashboardView(APIView):
    """
    View para a visão geral do painel administrativo.

    Fornece estatísticas consolidadas do sistema, permitindo ao
    administrador visualizar rapidamente o estado atual da aplicação,
    incluindo:

    - Total de usuários cadastrados e administradores;
    - Quantidade de missões por tipo e dificuldade;
    - Taxa de conclusão das missões;
    - Estatísticas de categorias do sistema.

    Permissões:
        Apenas administradores (is_staff=True) podem acessar.
    """

    permission_classes = [permissions.IsAdminUser]
    
    def get(self, request):
        """Retorna estatísticas gerais do sistema."""
        # Estatísticas de usuários
        total_users = User.objects.filter(is_active=True).count()
        admin_users = User.objects.filter(is_staff=True).count()
        
        # Estatísticas de missões
        total_missions = Mission.objects.count()
        active_missions = Mission.objects.filter(is_active=True).count()
        missions_by_type = dict(
            Mission.objects.values_list('mission_type')
            .annotate(count=Count('id'))
            .order_by('-count')
        )
        missions_by_difficulty = dict(
            Mission.objects.values_list('difficulty')
            .annotate(count=Count('id'))
        )
        
        # Estatísticas de progresso
        total_progress = MissionProgress.objects.count()
        completed_progress = MissionProgress.objects.filter(status='COMPLETED').count()
        
        # Estatísticas de categorias
        total_categories = Category.objects.count()
        system_categories = Category.objects.filter(is_system_default=True).count()
        
        return Response({
            'usuarios': {
                'total': total_users,
                'administradores': admin_users,
            },
            'missoes': {
                'total': total_missions,
                'ativas': active_missions,
                'por_tipo': missions_by_type,
                'por_dificuldade': missions_by_difficulty,
            },
            'progresso': {
                'total_iniciadas': total_progress,
                'total_concluidas': completed_progress,
                'taxa_conclusao': round(
                    (completed_progress / total_progress * 100) if total_progress > 0 else 0, 
                    1
                ),
            },
            'categorias': {
                'total': total_categories,
                'sistema': system_categories,
                'personalizadas': total_categories - system_categories,
            },
        })


class AdminMissionsView(APIView):
    """
    View para gerenciamento de missões do sistema.

    Esta view fornece endpoints para operações administrativas
    relacionadas às missões de gamificação, incluindo:

    - Listagem de todas as missões com suporte a filtros;
    - Criação de novas missões manualmente;
    - Paginação dos resultados.

    Os filtros disponíveis permitem refinar a busca por:
    - Tipo de missão (ONBOARDING, TPS_IMPROVEMENT, etc.);
    - Nível de dificuldade (EASY, MEDIUM, HARD);
    - Status de ativação (ativas ou inativas).

    Permissões:
        Apenas administradores (is_staff=True) podem acessar.
    """

    permission_classes = [permissions.IsAdminUser]
    
    def get(self, request):
        """Lista todas as missões com filtros opcionais."""
        queryset = Mission.objects.all().order_by('-created_at')
        
        # Filtros opcionais
        mission_type = request.query_params.get('tipo')
        if mission_type:
            queryset = queryset.filter(mission_type=mission_type)
        
        difficulty = request.query_params.get('dificuldade')
        if difficulty:
            queryset = queryset.filter(difficulty=difficulty)
        
        is_active = request.query_params.get('ativo')
        if is_active is not None:
            queryset = queryset.filter(is_active=is_active.lower() == 'true')
        
        # Paginação simples
        page = int(request.query_params.get('pagina', 1))
        per_page = int(request.query_params.get('por_pagina', 20))
        start = (page - 1) * per_page
        end = start + per_page
        
        total = queryset.count()
        missions = queryset[start:end]
        
        serializer = MissionSerializer(missions, many=True)
        
        return Response({
            'missoes': serializer.data,
            'total': total,
            'pagina': page,
            'por_pagina': per_page,
            'total_paginas': (total + per_page - 1) // per_page,
        })
    
    def post(self, request):
        """Cria uma nova missão manualmente."""
        serializer = MissionSerializer(data=request.data)
        
        if serializer.is_valid():
            mission = serializer.save()
            logger.info(f"Missão '{mission.title}' criada por {request.user.username}")
            
            return Response({
                'sucesso': True,
                'mensagem': 'Missão criada com sucesso',
                'missao': MissionSerializer(mission).data,
            }, status=status.HTTP_201_CREATED)
        
        return Response({
            'sucesso': False,
            'erros': serializer.errors,
        }, status=status.HTTP_400_BAD_REQUEST)


class AdminMissionDetailView(APIView):
    """
    Operações em uma missão específica.
    """
    
    permission_classes = [permissions.IsAdminUser]
    
    def get(self, request, pk):
        """Retorna detalhes de uma missão."""
        try:
            mission = Mission.objects.get(pk=pk)
            
            # Estatísticas da missão
            progress_stats = MissionProgress.objects.filter(mission=mission).aggregate(
                total=Count('id'),
                completadas=Count('id', filter=Q(status='COMPLETED')),
                ativas=Count('id', filter=Q(status='ACTIVE')),
            )
            
            serializer = MissionSerializer(mission)
            
            return Response({
                'missao': serializer.data,
                'estatisticas': progress_stats,
            })
        except Mission.DoesNotExist:
            return Response({
                'erro': 'Missão não encontrada',
            }, status=status.HTTP_404_NOT_FOUND)
    
    def put(self, request, pk):
        """Atualiza uma missão."""
        try:
            mission = Mission.objects.get(pk=pk)
            serializer = MissionSerializer(mission, data=request.data, partial=True)
            
            if serializer.is_valid():
                mission = serializer.save()
                logger.info(f"Missão '{mission.title}' atualizada por {request.user.username}")
                
                return Response({
                    'sucesso': True,
                    'mensagem': 'Missão atualizada com sucesso',
                    'missao': MissionSerializer(mission).data,
                })
            
            return Response({
                'sucesso': False,
                'erros': serializer.errors,
            }, status=status.HTTP_400_BAD_REQUEST)
        except Mission.DoesNotExist:
            return Response({
                'erro': 'Missão não encontrada',
            }, status=status.HTTP_404_NOT_FOUND)
    
    def delete(self, request, pk):
        """Desativa uma missão (soft delete)."""
        try:
            mission = Mission.objects.get(pk=pk)
            mission.is_active = False
            mission.save()
            
            logger.info(f"Missão '{mission.title}' desativada por {request.user.username}")
            
            return Response({
                'sucesso': True,
                'mensagem': 'Missão desativada com sucesso',
            })
        except Mission.DoesNotExist:
            return Response({
                'erro': 'Missão não encontrada',
            }, status=status.HTTP_404_NOT_FOUND)


class AdminMissionToggleView(APIView):
    """Ativa ou desativa uma missão."""
    
    permission_classes = [permissions.IsAdminUser]
    
    def post(self, request, pk):
        """Alterna o estado ativo/inativo de uma missão."""
        try:
            mission = Mission.objects.get(pk=pk)
            mission.is_active = not mission.is_active
            mission.save()
            
            estado = 'ativada' if mission.is_active else 'desativada'
            logger.info(f"Missão '{mission.title}' {estado} por {request.user.username}")
            
            return Response({
                'sucesso': True,
                'mensagem': f'Missão {estado} com sucesso',
                'ativo': mission.is_active,
            })
        except Mission.DoesNotExist:
            return Response({
                'erro': 'Missão não encontrada',
            }, status=status.HTTP_404_NOT_FOUND)


class AdminGenerateMissionsView(APIView):
    """
    View para geração automática de missões em lote.

    Esta view permite ao administrador gerar múltiplas missões
    de forma automatizada, utilizando dois métodos distintos:

    1. Templates: Utiliza modelos pré-definidos com variações
       nos parâmetros. Método mais rápido e previsível.

    2. Inteligência Artificial: Gera missões mais diversificadas
       através de modelo de linguagem (Gemini). Método mais lento,
       porém com maior variedade.

    As missões são distribuídas equilibradamente entre os níveis
    BEGINNER, INTERMEDIATE e ADVANCED para atender usuários em
    diferentes estágios de sua jornada financeira.

    Permissões:
        Apenas administradores (is_staff=True) podem acessar.
    """

    permission_classes = [permissions.IsAdminUser]
    
    def post(self, request):
        """
        Gera um lote de missões automaticamente.

        Este endpoint processa a solicitação de geração de missões,
        distribuindo-as entre diferentes níveis de dificuldade e
        tipos de missão de forma equilibrada.

        Args:
            request: Requisição HTTP contendo:
                - quantidade (int): Número de missões a gerar (10 ou 20).
                - usar_ia (bool): Se True, utiliza IA para geração.

        Returns:
            Response: Resultado da operação contendo:
                - sucesso (bool): Indica se a operação foi bem-sucedida.
                - metodo (str): Método utilizado ('templates' ou 'ia').
                - total_criadas (int): Número de missões criadas.
                - missoes (list): Lista das primeiras missões criadas.
                - mensagem (str): Mensagem descritiva do resultado.

        Raises:
            400 Bad Request: Se a quantidade for diferente de 10 ou 20.
            500 Internal Server Error: Se ocorrer erro na geração.
        """
        quantidade = request.data.get('quantidade', 10)
        usar_ia = request.data.get('usar_ia', False)
        
        # Validar quantidade (apenas 10 ou 20 para simplicidade)
        if quantidade not in [10, 20]:
            return Response({
                'sucesso': False,
                'erro': 'Quantidade deve ser 10 ou 20',
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            if usar_ia:
                # Geração via IA (simplificada)
                resultado = self._gerar_via_ia(quantidade, request.user)
            else:
                # Geração via templates (mais rápida)
                resultado = self._gerar_via_templates(quantidade, request.user)
            
            return Response(resultado)
            
        except Exception as e:
            logger.error(f"Erro ao gerar missões: {e}", exc_info=True)
            return Response({
                'sucesso': False,
                'erro': 'Erro ao gerar missões',
                'detalhes': str(e),
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def _gerar_via_templates(self, quantidade, admin_user):
        """
        Gera missões utilizando templates pré-definidos.

        Este método utiliza modelos de missão previamente configurados,
        aplicando variações nos parâmetros para criar missões únicas.
        A distribuição é feita equilibradamente entre os níveis.

        Args:
            quantidade (int): Número total de missões a gerar.
            admin_user: Usuário administrador que solicitou a geração.

        Returns:
            dict: Resultado contendo missões criadas e eventuais erros.
        """
        from ..mission_templates import generate_mission_batch_from_templates
        
        # Distribuição equilibrada entre níveis
        distribuicao = {
            'BEGINNER': quantidade // 3,
            'INTERMEDIATE': quantidade // 3,
            'ADVANCED': quantidade - (quantidade // 3 * 2),
        }
        
        missoes_criadas = []
        erros = []
        
        for tier, count in distribuicao.items():
            if count <= 0:
                continue
                
            try:
                # Métricas padrão para geração generalizada
                metricas_padrao = {
                    'BEGINNER': {'tps': 10, 'rdr': 50, 'ili': 1},
                    'INTERMEDIATE': {'tps': 20, 'rdr': 35, 'ili': 3},
                    'ADVANCED': {'tps': 30, 'rdr': 25, 'ili': 6},
                }
                
                missions_data = generate_mission_batch_from_templates(
                    tier=tier,
                    current_metrics=metricas_padrao[tier],
                    count=count,
                )
                
                for data in missions_data:
                    try:
                        mission = Mission.objects.create(**data)
                        missoes_criadas.append({
                            'id': mission.id,
                            'titulo': mission.title,
                            'tipo': mission.mission_type,
                            'dificuldade': mission.difficulty,
                        })
                    except Exception as e:
                        erros.append({
                            'titulo': data.get('title', 'Desconhecido'),
                            'erro': str(e),
                        })
            except Exception as e:
                erros.append({
                    'tier': tier,
                    'erro': str(e),
                })
        
        logger.info(
            f"Admin {admin_user.username} gerou {len(missoes_criadas)} missões via templates"
        )
        
        return {
            'sucesso': True,
            'metodo': 'templates',
            'total_criadas': len(missoes_criadas),
            'total_erros': len(erros),
            'missoes': missoes_criadas[:10],  # Primeiras 10 para não sobrecarregar resposta
            'erros': erros[:5] if erros else [],
            'mensagem': f'{len(missoes_criadas)} missões criadas com sucesso via templates',
        }
    
    def _gerar_via_ia(self, quantidade, admin_user):
        """
        Gera missões utilizando Inteligência Artificial.

        Este método utiliza o modelo de linguagem Gemini para gerar
        missões mais diversificadas e contextualizadas. Em caso de
        falha na comunicação com a IA, utiliza templates como fallback.

        Args:
            quantidade (int): Número total de missões a gerar.
            admin_user: Usuário administrador que solicitou a geração.

        Returns:
            dict: Resultado contendo missões criadas e eventuais erros.
        """
        from ..ai_services import generate_general_missions
        
        try:
            resultado = generate_general_missions(quantidade)
            
            missoes_criadas = resultado.get('created', [])
            erros = resultado.get('failed', [])
            
            logger.info(
                f"Admin {admin_user.username} gerou {len(missoes_criadas)} missões via IA"
            )
            
            return {
                'sucesso': True,
                'metodo': 'ia',
                'total_criadas': len(missoes_criadas),
                'total_erros': len(erros),
                'missoes': missoes_criadas[:10],
                'erros': erros[:5] if erros else [],
                'mensagem': f'{len(missoes_criadas)} missões criadas com sucesso via IA',
            }
        except Exception as e:
            # Fallback para templates se IA falhar
            logger.warning(f"IA falhou, usando templates: {e}")
            resultado = self._gerar_via_templates(quantidade, admin_user)
            resultado['metodo'] = 'templates (fallback)'
            resultado['aviso'] = 'IA indisponível, missões geradas via templates'
            return resultado


class AdminCategoriesView(APIView):
    """
    Gerenciamento de categorias padrão do sistema.
    
    Permite visualizar, criar e editar categorias que serão
    criadas automaticamente para novos usuários.
    """
    
    permission_classes = [permissions.IsAdminUser]
    
    def get(self, request):
        """Lista categorias do sistema."""
        # Filtro por tipo
        tipo = request.query_params.get('tipo')
        
        queryset = Category.objects.filter(is_system_default=True)
        
        if tipo:
            queryset = queryset.filter(type=tipo)
        
        queryset = queryset.order_by('type', 'name')
        
        serializer = CategorySerializer(queryset, many=True)
        
        # Agrupar por tipo
        por_tipo = {
            'INCOME': [],
            'EXPENSE': [],
        }
        
        for cat in serializer.data:
            tipo_cat = cat.get('type', 'EXPENSE')
            if tipo_cat in por_tipo:
                por_tipo[tipo_cat].append(cat)
        
        return Response({
            'categorias': serializer.data,
            'por_tipo': por_tipo,
            'total': len(serializer.data),
        })
    
    def post(self, request):
        """Cria uma nova categoria padrão do sistema."""
        data = request.data.copy()
        data['is_system_default'] = True
        data['user'] = None  # Categorias do sistema não têm usuário
        
        serializer = CategorySerializer(data=data)
        
        if serializer.is_valid():
            category = serializer.save(is_system_default=True, user=None)
            logger.info(f"Categoria '{category.name}' criada por {request.user.username}")
            
            return Response({
                'sucesso': True,
                'mensagem': 'Categoria criada com sucesso',
                'categoria': CategorySerializer(category).data,
            }, status=status.HTTP_201_CREATED)
        
        return Response({
            'sucesso': False,
            'erros': serializer.errors,
        }, status=status.HTTP_400_BAD_REQUEST)


class AdminCategoryDetailView(APIView):
    """Operações em uma categoria específica."""
    
    permission_classes = [permissions.IsAdminUser]
    
    def put(self, request, pk):
        """Atualiza uma categoria do sistema."""
        try:
            category = Category.objects.get(pk=pk, is_system_default=True)
            serializer = CategorySerializer(category, data=request.data, partial=True)
            
            if serializer.is_valid():
                category = serializer.save()
                logger.info(f"Categoria '{category.name}' atualizada por {request.user.username}")
                
                return Response({
                    'sucesso': True,
                    'mensagem': 'Categoria atualizada com sucesso',
                    'categoria': CategorySerializer(category).data,
                })
            
            return Response({
                'sucesso': False,
                'erros': serializer.errors,
            }, status=status.HTTP_400_BAD_REQUEST)
        except Category.DoesNotExist:
            return Response({
                'erro': 'Categoria não encontrada ou não é do sistema',
            }, status=status.HTTP_404_NOT_FOUND)
    
    def delete(self, request, pk):
        """Remove uma categoria do sistema."""
        try:
            category = Category.objects.get(pk=pk, is_system_default=True)
            nome = category.name
            category.delete()
            
            logger.info(f"Categoria '{nome}' removida por {request.user.username}")
            
            return Response({
                'sucesso': True,
                'mensagem': f'Categoria "{nome}" removida com sucesso',
            })
        except Category.DoesNotExist:
            return Response({
                'erro': 'Categoria não encontrada ou não é do sistema',
            }, status=status.HTTP_404_NOT_FOUND)


class AdminUsersView(APIView):
    """
    Gerenciamento básico de usuários.
    
    Permite visualizar lista de usuários e suas estatísticas,
    além de operações básicas como ativar/desativar contas.
    """
    
    permission_classes = [permissions.IsAdminUser]
    
    def get(self, request):
        """Lista usuários do sistema com estatísticas básicas."""
        # Filtros
        apenas_ativos = request.query_params.get('ativos', 'true').lower() == 'true'
        busca = request.query_params.get('busca', '').strip()
        
        queryset = User.objects.all()
        
        if apenas_ativos:
            queryset = queryset.filter(is_active=True)
        
        if busca:
            queryset = queryset.filter(
                Q(username__icontains=busca) |
                Q(email__icontains=busca) |
                Q(first_name__icontains=busca) |
                Q(last_name__icontains=busca)
            )
        
        queryset = queryset.order_by('-date_joined')
        
        # Paginação
        page = int(request.query_params.get('pagina', 1))
        per_page = int(request.query_params.get('por_pagina', 20))
        start = (page - 1) * per_page
        end = start + per_page
        
        total = queryset.count()
        users = queryset[start:end]
        
        usuarios_data = []
        for user in users:
            try:
                profile = user.userprofile
                nivel = profile.level
                xp = profile.experience_points
            except UserProfile.DoesNotExist:
                nivel = 1
                xp = 0
            
            usuarios_data.append({
                'id': user.id,
                'email': user.email,
                'nome': user.get_full_name() or user.username,
                'ativo': user.is_active,
                'administrador': user.is_staff,
                'nivel': nivel,
                'xp': xp,
                'data_cadastro': user.date_joined.isoformat(),
                'ultimo_acesso': user.last_login.isoformat() if user.last_login else None,
            })
        
        return Response({
            'usuarios': usuarios_data,
            'total': total,
            'pagina': page,
            'por_pagina': per_page,
            'total_paginas': (total + per_page - 1) // per_page,
        })


class AdminUserDetailView(APIView):
    """Operações em um usuário específico."""
    
    permission_classes = [permissions.IsAdminUser]
    
    def get(self, request, pk):
        """Retorna detalhes de um usuário."""
        try:
            user = User.objects.get(pk=pk)
            
            try:
                profile = user.userprofile
                profile_data = {
                    'nivel': profile.level,
                    'xp': profile.experience_points,
                    'proximo_nivel': profile.next_level_threshold,
                    'meta_tps': profile.target_tps,
                    'meta_rdr': profile.target_rdr,
                    'meta_ili': float(profile.target_ili),
                    'primeiro_acesso': profile.is_first_access,
                }
            except UserProfile.DoesNotExist:
                profile_data = None
            
            # Estatísticas do usuário
            missoes_completadas = MissionProgress.objects.filter(
                user=user, 
                status='COMPLETED'
            ).count()
            missoes_ativas = MissionProgress.objects.filter(
                user=user, 
                status='ACTIVE'
            ).count()
            
            return Response({
                'usuario': {
                    'id': user.id,
                    'email': user.email,
                    'nome': user.get_full_name() or user.username,
                    'ativo': user.is_active,
                    'administrador': user.is_staff,
                    'superusuario': user.is_superuser,
                    'data_cadastro': user.date_joined.isoformat(),
                    'ultimo_acesso': user.last_login.isoformat() if user.last_login else None,
                },
                'perfil': profile_data,
                'estatisticas': {
                    'missoes_completadas': missoes_completadas,
                    'missoes_ativas': missoes_ativas,
                },
            })
        except User.DoesNotExist:
            return Response({
                'erro': 'Usuário não encontrado',
            }, status=status.HTTP_404_NOT_FOUND)


class AdminUserToggleView(APIView):
    """Ativa ou desativa um usuário."""
    
    permission_classes = [permissions.IsAdminUser]
    
    def post(self, request, pk):
        """Alterna o estado ativo/inativo de um usuário."""
        try:
            user = User.objects.get(pk=pk)
            
            # Não permitir desativar a si mesmo
            if user.id == request.user.id:
                return Response({
                    'sucesso': False,
                    'erro': 'Não é possível desativar sua própria conta',
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Não permitir desativar superusuários
            if user.is_superuser and not request.user.is_superuser:
                return Response({
                    'sucesso': False,
                    'erro': 'Apenas superusuários podem desativar outros superusuários',
                }, status=status.HTTP_403_FORBIDDEN)
            
            user.is_active = not user.is_active
            user.save()
            
            estado = 'ativado' if user.is_active else 'desativado'
            logger.info(f"Usuário '{user.email}' {estado} por {request.user.username}")
            
            return Response({
                'sucesso': True,
                'mensagem': f'Usuário {estado} com sucesso',
                'ativo': user.is_active,
            })
        except User.DoesNotExist:
            return Response({
                'erro': 'Usuário não encontrado',
            }, status=status.HTTP_404_NOT_FOUND)
