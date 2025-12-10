
from .base import serializers, UserProfile
from .mission import MissionSerializer, MissionProgressSerializer


class DashboardSummarySerializer(serializers.Serializer):
    
    tps = serializers.DecimalField(max_digits=6, decimal_places=2)
    rdr = serializers.DecimalField(max_digits=6, decimal_places=2)
    ili = serializers.DecimalField(max_digits=6, decimal_places=2)
    total_income = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_expense = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_aportes = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, default=0)


class CategoryBreakdownSerializer(serializers.Serializer):
    
    name = serializers.CharField()
    total = serializers.DecimalField(max_digits=12, decimal_places=2)
    group = serializers.CharField()


class CashflowPointSerializer(serializers.Serializer):
    
    month = serializers.CharField()
    income = serializers.DecimalField(max_digits=12, decimal_places=2)
    expense = serializers.DecimalField(max_digits=12, decimal_places=2)
    tps = serializers.DecimalField(max_digits=6, decimal_places=2)
    rdr = serializers.DecimalField(max_digits=6, decimal_places=2)
    aportes = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, default=0)
    is_projection = serializers.BooleanField(default=False)


class IndicatorInsightSerializer(serializers.Serializer):
    
    severity = serializers.CharField()
    title = serializers.CharField()
    message = serializers.CharField()
    value = serializers.DecimalField(max_digits=6, decimal_places=2)
    target = serializers.DecimalField(max_digits=6, decimal_places=2)


class UserProfileSerializer(serializers.ModelSerializer):
    
    next_level_threshold = serializers.IntegerField(read_only=True)
    
    cached_tps = serializers.DecimalField(
        max_digits=5, decimal_places=2, read_only=True, required=False
    )
    cached_rdr = serializers.DecimalField(
        max_digits=5, decimal_places=2, read_only=True, required=False
    )
    cached_ili = serializers.DecimalField(
        max_digits=12, decimal_places=2, read_only=True, required=False
    )
    cache_timestamp = serializers.DateTimeField(
        source='indicators_updated_at', read_only=True, required=False
    )

    class Meta:
        model = UserProfile
        fields = (
            "level",
            "experience_points",
            "next_level_threshold",
            "target_tps",
            "target_rdr",
            "target_ili",
            "is_first_access",
            "cached_tps",
            "cached_rdr",
            "cached_ili",
            "cache_timestamp",
        )
        read_only_fields = (
            "level", 
            "experience_points", 
            "next_level_threshold",
            "cached_tps",
            "cached_rdr",
            "cached_ili",
            "cache_timestamp",
        )


class DashboardSerializer(serializers.Serializer):
    
    summary = DashboardSummarySerializer()
    categories = serializers.DictField(child=CategoryBreakdownSerializer(many=True))
    cashflow = CashflowPointSerializer(many=True)
    insights = serializers.DictField(child=IndicatorInsightSerializer())
    active_missions = MissionProgressSerializer(many=True)
    recommended_missions = MissionSerializer(many=True)
    profile = UserProfileSerializer()
