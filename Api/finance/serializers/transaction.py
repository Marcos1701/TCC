"""
Serializers para o modelo Transaction e TransactionLink.
"""

from django.db.models import Q

from .base import serializers, Category, Transaction, TransactionLink
from .category import CategorySerializer


class TransactionSerializer(serializers.ModelSerializer):
    """Serializer para transações financeiras."""
    
    category = CategorySerializer(read_only=True)
    category_id = serializers.PrimaryKeyRelatedField(
        queryset=Category.objects.none(), source="category", write_only=True, allow_null=True, required=False
    )
    recurrence_description = serializers.SerializerMethodField()
    days_since_created = serializers.SerializerMethodField()
    formatted_amount = serializers.SerializerMethodField()
    linked_amount = serializers.SerializerMethodField()
    available_amount = serializers.SerializerMethodField()
    link_percentage = serializers.SerializerMethodField()
    outgoing_links_count = serializers.SerializerMethodField()
    incoming_links_count = serializers.SerializerMethodField()

    class Meta:
        model = Transaction
        fields = (
            "id",
            "type",
            "description",
            "amount",
            "date",
            "category",
            "category_id",
            "is_recurring",
            "recurrence_value",
            "recurrence_unit",
            "recurrence_end_date",
            "recurrence_description",
            "days_since_created",
            "formatted_amount",
            "linked_amount",
            "available_amount",
            "link_percentage",
            "outgoing_links_count",
            "incoming_links_count",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "recurrence_description",
            "days_since_created",
            "formatted_amount",
            "linked_amount",
            "available_amount",
            "link_percentage",
            "outgoing_links_count",
            "incoming_links_count",
            "created_at",
            "updated_at",
        )

    def get_recurrence_description(self, obj):
        if not obj.is_recurring or not obj.recurrence_value or not obj.recurrence_unit:
            return None
        
        value = obj.recurrence_value
        unit_map = {
            'DAYS': ('dia', 'dias'),
            'WEEKS': ('semana', 'semanas'),
            'MONTHS': ('mês', 'meses'),
        }
        
        singular, plural = unit_map.get(obj.recurrence_unit, ('período', 'períodos'))
        unit_text = singular if value == 1 else plural
        
        desc = f"A cada {value} {unit_text}"
        if obj.recurrence_end_date:
            end_date = obj.recurrence_end_date.strftime('%d/%m/%Y')
            desc += f" até {end_date}"
        
        return desc
    
    def get_days_since_created(self, obj):
        from django.utils import timezone
        delta = timezone.now() - obj.created_at
        return delta.days
    
    def get_formatted_amount(self, obj):
        return f"R$ {obj.amount:,.2f}".replace(',', 'X').replace('.', ',').replace('X', '.')
    
    def get_linked_amount(self, obj):
        if hasattr(obj, 'linked_amount_annotated'):
            return float(obj.linked_amount_annotated)
        return float(obj.linked_amount)
    
    def get_available_amount(self, obj):
        if hasattr(obj, 'linked_amount_annotated'):
            return float(obj.amount - obj.linked_amount_annotated)
        return float(obj.available_amount)
    
    def get_link_percentage(self, obj):
        if hasattr(obj, 'linked_amount_annotated') and obj.amount > 0:
            return float((obj.linked_amount_annotated / obj.amount) * 100)
        return float(obj.link_percentage)
    
    def get_outgoing_links_count(self, obj):
        if hasattr(obj, 'outgoing_links_count_annotated'):
            return obj.outgoing_links_count_annotated
        return obj.outgoing_links.count()
    
    def get_incoming_links_count(self, obj):
        if hasattr(obj, 'incoming_links_count_annotated'):
            return obj.incoming_links_count_annotated
        return obj.incoming_links.count()

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request and request.user.is_authenticated:
            self.fields["category_id"].queryset = Category.objects.filter(
                Q(user=request.user) | Q(user__isnull=True)
            )

    def create(self, validated_data):
        user = self.context["request"].user
        validated_data["user"] = user
        return super().create(validated_data)

    def validate(self, attrs):
        attrs = super().validate(attrs)
        instance = getattr(self, "instance", None)

        is_recurring = attrs.get("is_recurring")
        if is_recurring is None and instance is not None:
            is_recurring = instance.is_recurring

        recurrence_value = attrs.get(
            "recurrence_value",
            getattr(instance, "recurrence_value", None),
        )
        recurrence_unit = attrs.get(
            "recurrence_unit",
            getattr(instance, "recurrence_unit", None),
        )

        if is_recurring:
            if not recurrence_value or recurrence_value <= 0 or not recurrence_unit:
                raise serializers.ValidationError(
                    "Frequência obrigatória para transações recorrentes.",
                )
        else:
            attrs["recurrence_value"] = None
            attrs["recurrence_unit"] = None
            attrs["recurrence_end_date"] = None
            if "is_recurring" in attrs:
                attrs["is_recurring"] = False

        return attrs


class TransactionLinkSerializer(serializers.ModelSerializer):
    """Serializer para links entre transações."""
    
    income_transaction = TransactionSerializer(read_only=True)
    expense_transaction = TransactionSerializer(read_only=True)
    income_transaction_id = serializers.UUIDField(write_only=True)
    expense_transaction_id = serializers.UUIDField(write_only=True)
    
    payment_status = serializers.SerializerMethodField()
    urgency_score = serializers.SerializerMethodField()
    category_info = serializers.SerializerMethodField()

    class Meta:
        model = TransactionLink
        fields = [
            'id',
            'income_transaction',
            'expense_transaction',
            'income_transaction_id',
            'expense_transaction_id',
            'amount',
            'description',
            'payment_status',
            'urgency_score',
            'category_info',
            'created_at',
        ]
        read_only_fields = ['id', 'created_at', 'payment_status', 'urgency_score', 'category_info']

    def get_payment_status(self, obj):
        income = obj.income_transaction
        expense = obj.expense_transaction
        
        if income.date <= expense.date:
            return {
                'status': 'paid',
                'label': 'Reservado',
                'color': '#4CAF50',
            }
        else:
            from django.utils import timezone
            days_until = (income.date - timezone.now().date()).days
            if days_until < 0:
                return {
                    'status': 'overdue',
                    'label': 'Atrasado',
                    'color': '#F44336',
                }
            elif days_until <= 7:
                return {
                    'status': 'upcoming',
                    'label': f'Em {days_until} dias',
                    'color': '#FF9800',
                }
            else:
                return {
                    'status': 'planned',
                    'label': 'Planejado',
                    'color': '#2196F3',
                }

    def get_urgency_score(self, obj):
        from django.utils import timezone
        income = obj.income_transaction
        expense = obj.expense_transaction
        
        if income.date <= expense.date:
            return 0
        
        days_until = (income.date - timezone.now().date()).days
        
        if days_until < 0:
            return 100
        elif days_until <= 3:
            return 80
        elif days_until <= 7:
            return 60
        elif days_until <= 14:
            return 40
        elif days_until <= 30:
            return 20
        else:
            return 10
    
    def get_category_info(self, obj):
        expense_cat = obj.expense_transaction.category
        if expense_cat:
            return {
                'id': expense_cat.id,
                'name': expense_cat.name,
                'icon': expense_cat.icon,
                'color': expense_cat.color,
            }
        return None

    def validate(self, attrs):
        income_id = attrs.get('income_transaction_id')
        expense_id = attrs.get('expense_transaction_id')
        amount = attrs.get('amount')
        
        user = self.context['request'].user
        
        try:
            income = Transaction.objects.get(id=income_id, user=user, type='INCOME')
        except Transaction.DoesNotExist:
            raise serializers.ValidationError({
                'income_transaction_id': 'Receita não encontrada ou não pertence ao usuário.'
            })
        
        try:
            expense = Transaction.objects.get(id=expense_id, user=user, type='EXPENSE')
        except Transaction.DoesNotExist:
            raise serializers.ValidationError({
                'expense_transaction_id': 'Despesa não encontrada ou não pertence ao usuário.'
            })
        
        if amount > income.available_amount:
            raise serializers.ValidationError({
                'amount': f'Valor excede o disponível na receita (R$ {income.available_amount:.2f}).'
            })
        
        if amount > expense.available_amount:
            raise serializers.ValidationError({
                'amount': f'Valor excede o disponível na despesa (R$ {expense.available_amount:.2f}).'
            })
        
        attrs['income_transaction'] = income
        attrs['expense_transaction'] = expense
        
        return attrs

    def create(self, validated_data):
        validated_data.pop('income_transaction_id', None)
        validated_data.pop('expense_transaction_id', None)
        return super().create(validated_data)


class TransactionLinkSummarySerializer(serializers.Serializer):
    """Serializer resumido para links de transação."""
    
    total_linked = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_available = serializers.DecimalField(max_digits=12, decimal_places=2)
    links_count = serializers.IntegerField()
    coverage_percentage = serializers.FloatField()
