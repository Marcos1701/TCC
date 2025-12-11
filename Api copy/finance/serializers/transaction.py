
from django.db.models import Q

from .base import serializers, Category, Transaction, TransactionLink
from .category import CategorySerializer


class TransactionSerializer(serializers.ModelSerializer):
    
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
            "is_scheduled",
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
            "is_scheduled",
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
    
    source_transaction = serializers.SerializerMethodField()
    target_transaction = serializers.SerializerMethodField()
    source_transaction_id = serializers.UUIDField(write_only=True)
    target_transaction_id = serializers.UUIDField(write_only=True)
    
    income_transaction = serializers.SerializerMethodField()
    expense_transaction = serializers.SerializerMethodField()
    income_transaction_id = serializers.UUIDField(write_only=True, required=False)
    expense_transaction_id = serializers.UUIDField(write_only=True, required=False)
    
    payment_status = serializers.SerializerMethodField()
    urgency_score = serializers.SerializerMethodField()
    category_info = serializers.SerializerMethodField()

    class Meta:
        model = TransactionLink
        fields = [
            'id',
            'source_transaction',
            'target_transaction',
            'source_transaction_id',
            'target_transaction_id',
            'income_transaction',
            'expense_transaction',
            'income_transaction_id',
            'expense_transaction_id',
            'linked_amount',
            'link_type',
            'description',
            'is_recurring',
            'payment_status',
            'urgency_score',
            'category_info',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'payment_status', 'urgency_score', 'category_info']
    
    def get_source_transaction(self, obj):
        if hasattr(obj, '_source_transaction_cache'):
            return TransactionSerializer(obj._source_transaction_cache).data
        return TransactionSerializer(obj.source_transaction).data
    
    def get_target_transaction(self, obj):
        if hasattr(obj, '_target_transaction_cache'):
            return TransactionSerializer(obj._target_transaction_cache).data
        return TransactionSerializer(obj.target_transaction).data
    
    def get_income_transaction(self, obj):
        if hasattr(obj, '_source_transaction_cache'):
            return TransactionSerializer(obj._source_transaction_cache).data
        return TransactionSerializer(obj.source_transaction).data
    
    def get_expense_transaction(self, obj):
        if hasattr(obj, '_target_transaction_cache'):
            return TransactionSerializer(obj._target_transaction_cache).data
        return TransactionSerializer(obj.target_transaction).data

    def get_payment_status(self, obj):
        if hasattr(obj, '_source_transaction_cache'):
            source = obj._source_transaction_cache
        else:
            source = obj.source_transaction
            
        if hasattr(obj, '_target_transaction_cache'):
            target = obj._target_transaction_cache
        else:
            target = obj.target_transaction
        
        if source.date <= target.date:
            return {
                'status': 'paid',
                'label': 'Reservado',
                'color': '#4CAF50'
            }
        else:
            from django.utils import timezone
            days_until = (source.date - timezone.now().date()).days
            if days_until < 0:
                return {
                    'status': 'overdue',
                    'label': 'Atrasado',
                    'color': '#F44336'
                }
            elif days_until <= 7:
                return {
                    'status': 'upcoming',
                    'label': f'Em {days_until} dias',
                    'color': '#FF9800'
                }
            else:
                return {
                    'status': 'planned',
                    'label': 'Planejado',
                    'color': '#2196F3'
                }

    def get_urgency_score(self, obj):
        from django.utils import timezone
        
        if hasattr(obj, '_source_transaction_cache'):
            source = obj._source_transaction_cache
        else:
            source = obj.source_transaction
            
        if hasattr(obj, '_target_transaction_cache'):
            target = obj._target_transaction_cache
        else:
            target = obj.target_transaction
        
        if source.date <= target.date:
            return 0
        
        days_until = (source.date - timezone.now().date()).days
        
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
        if hasattr(obj, '_target_transaction_cache'):
            target = obj._target_transaction_cache
        else:
            target = obj.target_transaction
            
        expense_cat = target.category
        if expense_cat:
            return {
                'id': expense_cat.id,
                'name': expense_cat.name,
                'color': expense_cat.color,
            }
        return None

    def validate(self, attrs):
        source_id = attrs.get('source_transaction_id') or attrs.get('income_transaction_id')
        target_id = attrs.get('target_transaction_id') or attrs.get('expense_transaction_id')
        linked_amount = attrs.get('linked_amount')
        
        if not source_id or not target_id:
            raise serializers.ValidationError({
                'non_field_errors': 'Informe source_transaction_id e target_transaction_id.'
            })
        
        user = self.context['request'].user
        
        try:
            source = Transaction.objects.get(id=source_id, user=user)
        except Transaction.DoesNotExist:
            raise serializers.ValidationError({
                'source_transaction_id': 'Transação de origem não encontrada ou não pertence ao usuário.'
            })
        
        try:
            target = Transaction.objects.get(id=target_id, user=user)
        except Transaction.DoesNotExist:
            raise serializers.ValidationError({
                'target_transaction_id': 'Transação de destino não encontrada ou não pertence ao usuário.'
            })
        
        if linked_amount and linked_amount > source.available_amount:
            raise serializers.ValidationError({
                'linked_amount': f'Valor excede o disponível na origem (R$ {source.available_amount:.2f}).'
            })
        
        if linked_amount and linked_amount > target.available_amount:
            raise serializers.ValidationError({
                'linked_amount': f'Valor excede o disponível no destino (R$ {target.available_amount:.2f}).'
            })
        
        attrs['source_transaction_uuid'] = source.id
        attrs['target_transaction_uuid'] = target.id
        
        return attrs

    def create(self, validated_data):
        validated_data.pop('source_transaction_id', None)
        validated_data.pop('target_transaction_id', None)
        validated_data.pop('income_transaction_id', None)
        validated_data.pop('expense_transaction_id', None)
        return super().create(validated_data)


class TransactionLinkSummarySerializer(serializers.Serializer):
    
    total_linked = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_available = serializers.DecimalField(max_digits=12, decimal_places=2)
    links_count = serializers.IntegerField()
    coverage_percentage = serializers.FloatField()
