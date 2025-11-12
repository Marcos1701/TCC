from django.conf import settings
from django.contrib.auth.models import User
from django.db import transaction
from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver
import uuid

from .models import Category, Transaction, TransactionLink, Goal, Friendship, UserProfile


def _ensure_default_categories(user):
    """
    Cria categorias padrão do sistema para novos usuários.
    ATUALIZADO: Categorias agora são isoladas por usuário para conformidade LGPD.
    """
    default_categories = [
        # Receitas
        {'name': 'Salário', 'type': 'INCOME', 'group': 'REGULAR_INCOME', 'color': '#4CAF50'},
        {'name': 'Freelance', 'type': 'INCOME', 'group': 'EXTRA_INCOME', 'color': '#8BC34A'},
        {'name': 'Investimentos', 'type': 'INCOME', 'group': 'INVESTMENT', 'color': '#009688'},
        
        # Despesas Essenciais
        {'name': 'Alimentação', 'type': 'EXPENSE', 'group': 'ESSENTIAL_EXPENSE', 'color': '#FF9800'},
        {'name': 'Moradia', 'type': 'EXPENSE', 'group': 'ESSENTIAL_EXPENSE', 'color': '#FF5722'},
        {'name': 'Transporte', 'type': 'EXPENSE', 'group': 'ESSENTIAL_EXPENSE', 'color': '#2196F3'},
        {'name': 'Saúde', 'type': 'EXPENSE', 'group': 'ESSENTIAL_EXPENSE', 'color': '#F44336'},
        
        # Estilo de Vida
        {'name': 'Lazer', 'type': 'EXPENSE', 'group': 'LIFESTYLE_EXPENSE', 'color': '#9C27B0'},
        {'name': 'Educação', 'type': 'EXPENSE', 'group': 'LIFESTYLE_EXPENSE', 'color': '#3F51B5'},
        {'name': 'Vestuário', 'type': 'EXPENSE', 'group': 'LIFESTYLE_EXPENSE', 'color': '#E91E63'},
        
        # Poupança
        {'name': 'Reserva de Emergência', 'type': 'EXPENSE', 'group': 'SAVINGS', 'color': '#00BCD4'},
        {'name': 'Investimentos', 'type': 'EXPENSE', 'group': 'INVESTMENT', 'color': '#009688'},
        
        # Dívidas
        {'name': 'Cartão de Crédito', 'type': 'DEBT', 'group': 'DEBT', 'color': '#F44336'},
        {'name': 'Empréstimo', 'type': 'DEBT', 'group': 'DEBT', 'color': '#D32F2F'},
        
        # Outros
        {'name': 'Outros', 'type': 'EXPENSE', 'group': 'OTHER', 'color': '#9E9E9E'},
    ]
    
    created_count = 0
    for cat_data in default_categories:
        # Verificar se já existe (evitar duplicatas)
        exists = Category.objects.filter(
            user=user,
            name=cat_data['name'],
            type=cat_data['type']
        ).exists()
        
        if not exists:
            Category.objects.create(
                user=user,
                is_system_default=True,
                **cat_data
            )
            created_count += 1
    
    if created_count > 0:
        import logging
        logger = logging.getLogger(__name__)
        logger.info(f"Created {created_count} default categories for user {user.id}")


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def create_user_profile(sender, instance, created, **kwargs):
    """
    Cria perfil de usuário ao criar nova conta.
    Marca is_first_access=True para novos usuários (onboarding).
    """
    if created:
        with transaction.atomic():
            # Criar perfil com is_first_access=True (default do modelo)
            UserProfile.objects.create(user=instance)
            _ensure_default_categories(instance)
            
            # Atribuir missões iniciais
            from .services import assign_missions_automatically
            assign_missions_automatically(instance)
            
            # Log para auditoria
            import logging
            logger = logging.getLogger(__name__)
            logger.info(
                f"New user profile created: User {instance.id} ({instance.username}) - "
                f"is_first_access=True (onboarding enabled)"
            )


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def sync_user_profile(sender, instance, **kwargs):
    UserProfile.objects.get_or_create(user=instance)


@receiver(post_save, sender=Transaction)
def update_missions_on_transaction(sender, instance, created, **kwargs):
    """
    Atualiza progresso das missões e atribui novas quando necessário após cada transação.
    """
    if created:
        from .services import update_mission_progress, assign_missions_automatically
        
        # Atualizar progresso das missões existentes
        update_mission_progress(instance.user)
        
        # Verificar se precisa atribuir novas missões
        assign_missions_automatically(instance.user)


@receiver(post_save, sender=Transaction)
def update_goals_on_transaction_change(sender, instance, **kwargs):
    """
    Atualiza apenas as metas relevantes quando uma transação é criada ou atualizada.
    
    Otimização: Só atualiza metas que podem ser afetadas por esta transação específica:
    - Metas SAVINGS: se transação é em categoria SAVINGS/INVESTMENT ou está em tracked_categories
    - Metas CATEGORY_EXPENSE: se transação é EXPENSE na categoria monitorada
    - Metas CATEGORY_INCOME: se transação é INCOME na categoria monitorada
    - Metas CUSTOM: se transação está em tracked_categories
    """
    from .services import update_goal_progress
    from .models import Goal, Category
    
    # Buscar apenas metas ativas com auto_update
    active_goals = Goal.objects.filter(user=instance.user, auto_update=True)
    
    for goal in active_goals:
        should_update = False
        
        if goal.goal_type == Goal.GoalType.SAVINGS:
            # Atualiza se transação é em categoria monitorada ou SAVINGS/INVESTMENT
            if goal.tracked_categories.exists():
                if instance.category in goal.tracked_categories.all():
                    should_update = True
            elif instance.category and instance.category.group in [
                Category.CategoryGroup.SAVINGS,
                Category.CategoryGroup.INVESTMENT
            ]:
                should_update = True
        
        elif goal.goal_type == Goal.GoalType.CATEGORY_EXPENSE:
            # Atualiza APENAS se é EXPENSE nas categorias monitoradas
            if instance.type == Transaction.TransactionType.EXPENSE:
                if goal.tracked_categories.exists():
                    if instance.category in goal.tracked_categories.all():
                        should_update = True
                elif goal.target_category == instance.category:
                    should_update = True
        
        elif goal.goal_type == Goal.GoalType.CATEGORY_INCOME:
            # Atualiza APENAS se é INCOME nas categorias monitoradas
            if instance.type == Transaction.TransactionType.INCOME:
                if goal.tracked_categories.exists():
                    if instance.category in goal.tracked_categories.all():
                        should_update = True
                elif goal.target_category == instance.category:
                    should_update = True
        
        elif goal.goal_type == Goal.GoalType.CUSTOM:
            # Atualiza se transação está em tracked_categories
            if goal.tracked_categories.exists():
                if instance.category in goal.tracked_categories.all():
                    should_update = True
        
        # Atualizar meta se necessário
        if should_update:
            update_goal_progress(goal)


from django.db.models.signals import post_delete


@receiver(post_delete, sender=Transaction)
def update_goals_on_transaction_delete(sender, instance, **kwargs):
    """
    Atualiza metas com auto_update quando uma transação é deletada.
    Verifica se o usuário ainda existe antes de atualizar (para evitar erros em deleções em cascata).
    """
    from .services import update_all_active_goals
    
    # Verifica se o usuário ainda existe antes de tentar atualizar
    # (evita erro quando transações são deletadas em cascata ao deletar usuário)
    try:
        if instance.user_id and instance.user:
            update_all_active_goals(instance.user)
    except User.DoesNotExist:
        # Usuário foi deletado, não há metas para atualizar
        pass


# ======= Signals para garantir UUID em novos registros =======

@receiver(pre_save, sender=Transaction)
def ensure_transaction_uuid(sender, instance, **kwargs):
    """Garante que toda transação tenha UUID antes de salvar."""
    if not instance.id:
        instance.id = uuid.uuid4()


@receiver(pre_save, sender=Goal)
def ensure_goal_uuid(sender, instance, **kwargs):
    """Garante que toda meta tenha UUID antes de salvar."""
    if not instance.id:
        instance.id = uuid.uuid4()


@receiver(pre_save, sender=TransactionLink)
def ensure_transaction_link_uuid(sender, instance, **kwargs):
    """Garante que todo link tenha UUID antes de salvar."""
    if not instance.id:
        instance.id = uuid.uuid4()


@receiver(pre_save, sender=Friendship)
def ensure_friendship_uuid(sender, instance, **kwargs):
    """Garante que toda amizade tenha UUID antes de salvar."""
    if not instance.id:
        instance.id = uuid.uuid4()


# ======= Signals para validação automática de conquistas =======

@receiver(post_save, sender=Transaction)
def check_achievements_on_transaction(sender, instance, created, **kwargs):
    """
    Valida conquistas quando uma transação é criada.
    
    Conquistas verificadas:
    - Contagem de transações (10, 50, 100, etc.)
    - Totais de receita/despesa
    - Indicadores financeiros (TPS, ILI, RDR)
    """
    if created:
        from .services import check_achievements_for_user
        check_achievements_for_user(instance.user, event_type='transaction')


@receiver(post_save, sender='finance.MissionProgress')
def check_achievements_on_mission_complete(sender, instance, **kwargs):
    """
    Valida conquistas quando uma missão é completada.
    
    Conquistas verificadas:
    - Contagem de missões completadas (5, 20, 50, etc.)
    - Conclusão de missões específicas
    """
    if instance.status == 'COMPLETED' and instance.completed_at and not instance._state.adding:
        from .services import check_achievements_for_user
        check_achievements_for_user(instance.user, event_type='mission')


@receiver(post_save, sender=Goal)
def update_missions_on_goal_change(sender, instance, created, **kwargs):
    """
    Atualiza progresso das missões quando uma meta é criada ou atualizada.
    """
    from .services import update_mission_progress
    
    # Atualizar progresso das missões do usuário
    # Importante para missões como "Criar primeira meta"
    update_mission_progress(instance.user)


@receiver(post_save, sender=Goal)
def check_achievements_on_goal_complete(sender, instance, **kwargs):
    """
    Valida conquistas quando uma meta é concluída.
    
    Conquistas verificadas:
    - Contagem de metas concluídas (3, 10, 25, etc.)
    - Conclusão de metas específicas
    
    Nota: Goal não possui campo 'status'. Uma meta é considerada completa
    quando current_amount >= target_amount.
    """
    # Verificar se a meta foi recém-concluída (não estava sendo criada)
    if not instance._state.adding:
        # Verificar se a meta está completa (atingiu o alvo)
        if instance.current_amount >= instance.target_amount:
            from .services import check_achievements_for_user
            check_achievements_for_user(instance.user, event_type='goal')


@receiver(post_save, sender=Friendship)
def check_achievements_on_friendship(sender, instance, created, **kwargs):
    """
    Valida conquistas quando uma amizade é aceita.
    
    Conquistas verificadas:
    - Contagem de amigos (1, 5, 10, 20, etc.)
    - Interações sociais
    """
    if instance.status == Friendship.FriendshipStatus.ACCEPTED:
        from .services import check_achievements_for_user
        # Verificar para ambos os usuários
        check_achievements_for_user(instance.from_user, event_type='social')
        check_achievements_for_user(instance.to_user, event_type='social')
