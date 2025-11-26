"""
Serializers para o modelo Category.
"""

from .base import serializers, Category


class CategorySerializer(serializers.ModelSerializer):
    """Serializer para categorias de transações financeiras."""
    
    transaction_count = serializers.SerializerMethodField()
    total_amount = serializers.SerializerMethodField()

    class Meta:
        model = Category
        fields = [
            'id', 'name', 'type', 'icon', 'color',
            'is_active', 'transaction_count', 'total_amount'
        ]
        read_only_fields = ['id', 'transaction_count', 'total_amount']

    def validate_color(self, value):
        if value and not value.startswith('#'):
            value = f'#{value}'
        if value and (len(value) != 7 or not all(c in '0123456789ABCDEFabcdef' for c in value[1:])):
            raise serializers.ValidationError("Cor deve estar no formato hexadecimal (#RRGGBB)")
        return value

    def get_transaction_count(self, obj):
        return obj.transactions.count()

    def get_total_amount(self, obj):
        total = sum(t.amount for t in obj.transactions.all())
        return float(total)
