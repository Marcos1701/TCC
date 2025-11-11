"""
Testes de Integração - Sistema de Conquistas
Valida todo o fluxo: geração IA, validação automática, desbloqueio, progresso
"""
import os
import sys
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth import get_user_model
from finance.models import Achievement, UserAchievement, Transaction, Category, UserProfile
from finance.services import check_achievements_for_user, check_criteria_met
from finance.ai_services import generate_achievements_with_ai
from decimal import Decimal

User = get_user_model()

class TestAchievements:
    def __init__(self):
        self.results = []
        self.test_user = None
        
    def log(self, message, status="INFO"):
        prefix = {
            "INFO": "[INFO]",
            "SUCCESS": "[OK]",
            "ERROR": "[ERRO]",
            "WARNING": "[AVISO]"
        }
        print(f"{prefix.get(status, '[INFO]')} {message}")
        self.results.append((status, message))
    
    def setup(self):
        """Prepara ambiente de teste"""
        self.log("Iniciando setup de testes...", "INFO")
        
        # Criar usuário de teste
        username = "test_achievements_user"
        User.objects.filter(username=username).delete()
        
        self.test_user = User.objects.create_user(
            username=username,
            email="test@achievements.com",
            password="testpass123"
        )
        
        # Criar profile
        profile, created = UserProfile.objects.get_or_create(
            user=self.test_user,
            defaults={'experience_points': 0, 'level': 1}
        )
        
        self.log(f"Usuário de teste criado: {self.test_user.username}", "SUCCESS")
        self.log(f"XP inicial: {profile.experience_points}", "INFO")
        
    def cleanup(self):
        """Limpa dados de teste"""
        if self.test_user:
            self.test_user.delete()
            self.log("Usuário de teste removido", "INFO")
    
    def test_1_model_creation(self):
        """Teste 1: Criar conquista manualmente"""
        self.log("\n=== TESTE 1: Criação Manual de Conquista ===", "INFO")
        
        try:
            achievement = Achievement.objects.create(
                title="Primeira Transação",
                description="Registre sua primeira transação no sistema",
                category="FINANCIAL",
                tier="BEGINNER",
                xp_reward=25,
                icon="💰",
                criteria={
                    "type": "count",
                    "target": 1,
                    "metric": "transactions"
                },
                is_active=True,
                is_ai_generated=False
            )
            
            self.log(f"Conquista criada: {achievement.title}", "SUCCESS")
            self.log(f"  Categoria: {achievement.category}", "INFO")
            self.log(f"  Tier: {achievement.tier}", "INFO")
            self.log(f"  XP: {achievement.xp_reward}", "INFO")
            self.log(f"  Critério: {achievement.criteria}", "INFO")
            
            return achievement
            
        except Exception as e:
            self.log(f"Erro ao criar conquista: {str(e)}", "ERROR")
            return None
    
    def test_2_criteria_validation(self):
        """Teste 2: Validação de critérios"""
        self.log("\n=== TESTE 2: Validação de Critérios ===", "INFO")
        
        # Teste com 0 transações (não deve desbloquear)
        criteria_1_transaction = {
            "type": "count",
            "target": 1,
            "metric": "transactions"
        }
        
        result = check_criteria_met(self.test_user, criteria_1_transaction)
        self.log(f"Critério '1 transação' atendido? {result} (esperado: False)", 
                 "SUCCESS" if not result else "ERROR")
        
        # Criar categoria para transação
        category, _ = Category.objects.get_or_create(
            name="Teste",
            user=self.test_user,
            defaults={
                'type': Category.CategoryType.EXPENSE,
                'group': Category.CategoryGroup.ESSENTIAL_EXPENSE,
                'color': '#FF0000'
            }
        )
        
        # Criar transação
        transaction = Transaction.objects.create(
            user=self.test_user,
            description="Transação de teste",
            amount=Decimal("100.00"),
            type=Transaction.TransactionType.EXPENSE,
            category=category,
            date=django.utils.timezone.now().date()
        )
        
        self.log(f"Transação criada: {transaction.description}", "INFO")
        
        # Testar novamente
        result = check_criteria_met(self.test_user, criteria_1_transaction)
        self.log(f"Critério '1 transação' atendido? {result} (esperado: True)", 
                 "SUCCESS" if result else "ERROR")
        
        return result
    
    def test_3_auto_unlock(self):
        """Teste 3: Desbloqueio automático via signal"""
        self.log("\n=== TESTE 3: Desbloqueio Automático ===", "INFO")
        
        # Criar conquista de 5 transações
        achievement = Achievement.objects.create(
            title="5 Transações",
            description="Registre 5 transações",
            category="FINANCIAL",
            tier="BEGINNER",
            xp_reward=50,
            icon="📊",
            criteria={
                "type": "count",
                "target": 5,
                "metric": "transactions"
            },
            is_active=True
        )
        
        # Verificar XP inicial
        profile = UserProfile.objects.get(user=self.test_user)
        xp_before = profile.experience_points
        self.log(f"XP antes: {xp_before}", "INFO")
        
        # Criar mais 4 transações (já temos 1)
        category = Category.objects.filter(user=self.test_user).first()
        for i in range(4):
            Transaction.objects.create(
                user=self.test_user,
                description=f"Teste {i+2}",
                amount=Decimal("50.00"),
                type=Transaction.TransactionType.EXPENSE,
                category=category,
                date=django.utils.timezone.now().date()
            )
        
        self.log(f"5 transações criadas", "INFO")
        
        # Validar conquistas
        unlocked = check_achievements_for_user(self.test_user, event_type='transaction')
        
        # Verificar se desbloqueou
        user_achievement = UserAchievement.objects.filter(
            user=self.test_user,
            achievement=achievement
        ).first()
        
        if user_achievement and user_achievement.is_unlocked:
            profile.refresh_from_db()
            xp_after = profile.experience_points
            xp_gained = xp_after - xp_before
            
            self.log(f"Conquista desbloqueada automaticamente!", "SUCCESS")
            self.log(f"XP ganho: {xp_gained} (esperado: {achievement.xp_reward})", 
                     "SUCCESS" if xp_gained == achievement.xp_reward else "ERROR")
            self.log(f"XP total: {xp_after}", "INFO")
            return True
        else:
            self.log("Conquista NÃO foi desbloqueada automaticamente", "ERROR")
            return False
    
    def test_4_progress_tracking(self):
        """Teste 4: Rastreamento de progresso"""
        self.log("\n=== TESTE 4: Rastreamento de Progresso ===", "INFO")
        
        # Criar conquista de 10 transações
        achievement = Achievement.objects.create(
            title="10 Transações",
            description="Registre 10 transações",
            category="FINANCIAL",
            tier="INTERMEDIATE",
            xp_reward=100,
            icon="📈",
            criteria={
                "type": "count",
                "target": 10,
                "metric": "transactions"
            },
            is_active=True
        )
        
        # Criar UserAchievement
        user_achievement, created = UserAchievement.objects.get_or_create(
            user=self.test_user,
            achievement=achievement,
            defaults={
                'progress': 0,
                'progress_max': 10
            }
        )
        
        # Contar transações atuais
        current_count = Transaction.objects.filter(user=self.test_user).count()
        self.log(f"Transações atuais: {current_count}", "INFO")
        
        # Atualizar progresso
        from finance.services import update_achievement_progress
        updated = update_achievement_progress(self.test_user, achievement.id)
        
        if updated:
            self.log(f"Progresso atualizado: {updated.progress}/{updated.progress_max}", "SUCCESS")
            self.log(f"Porcentagem: {updated.progress_percentage()}%", "INFO")
            
            if updated.progress == current_count:
                self.log("Progresso correto!", "SUCCESS")
                return True
            else:
                self.log(f"Progresso incorreto! Esperado: {current_count}, Obtido: {updated.progress}", "ERROR")
                return False
        else:
            self.log("Falha ao atualizar progresso", "ERROR")
            return False
    
    def test_5_manual_unlock(self):
        """Teste 5: Desbloqueio manual"""
        self.log("\n=== TESTE 5: Desbloqueio Manual ===", "INFO")
        
        # Criar conquista especial
        achievement = Achievement.objects.create(
            title="Conquista Especial",
            description="Desbloqueio manual para testes",
            category="GENERAL",
            tier="ADVANCED",
            xp_reward=200,
            icon="🌟",
            criteria={
                "type": "count",
                "target": 100,
                "metric": "transactions"
            },
            is_active=True
        )
        
        # Verificar XP antes
        profile = UserProfile.objects.get(user=self.test_user)
        xp_before = profile.experience_points
        
        # Criar UserAchievement e desbloquear
        user_achievement, created = UserAchievement.objects.get_or_create(
            user=self.test_user,
            achievement=achievement,
            defaults={
                'progress': 0,
                'progress_max': 100
            }
        )
        
        result = user_achievement.unlock()
        
        if result:
            profile.refresh_from_db()
            xp_after = profile.experience_points
            xp_gained = xp_after - xp_before
            
            self.log("Conquista desbloqueada manualmente!", "SUCCESS")
            self.log(f"XP ganho: {xp_gained} (esperado: {achievement.xp_reward})", 
                     "SUCCESS" if xp_gained == achievement.xp_reward else "ERROR")
            self.log(f"Data de desbloqueio: {user_achievement.unlocked_at}", "INFO")
            return True
        else:
            self.log("Falha ao desbloquear manualmente", "ERROR")
            return False
    
    def test_6_ai_generation(self):
        """Teste 6: Geração de conquistas com IA (se API disponível)"""
        self.log("\n=== TESTE 6: Geração com IA ===", "INFO")
        
        try:
            # Tentar gerar conquistas com IA
            achievements_data = generate_achievements_with_ai(
                category="FINANCIAL",
                tier="BEGINNER"
            )
            
            if len(achievements_data) > 0:
                self.log(f"IA gerou {len(achievements_data)} conquistas", "SUCCESS")
                
                # Mostrar algumas amostras
                for i, data in enumerate(achievements_data[:3]):
                    self.log(f"  Amostra {i+1}: {data.get('title')}", "INFO")
                    self.log(f"    XP: {data.get('xp_reward')}", "INFO")
                    self.log(f"    Critério: {data.get('criteria')}", "INFO")
            else:
                self.log("IA retornou 0 conquistas (API não configurada)", "WARNING")
            
            return True
            
        except Exception as e:
            error_msg = str(e)
            if "API" in error_msg or "key" in error_msg.lower() or "not configured" in error_msg:
                self.log("IA não configurada (esperado em ambiente de teste)", "WARNING")
                return True  # Não é erro
            else:
                self.log(f"Erro inesperado ao gerar com IA: {error_msg}", "ERROR")
                return False
    
    def test_7_duplicate_prevention(self):
        """Teste 7: Prevenção de desbloqueio duplicado"""
        self.log("\n=== TESTE 7: Prevenção de Duplicatas ===", "INFO")
        
        achievement = Achievement.objects.create(
            title="Teste Duplicata",
            description="Não deve desbloquear duas vezes",
            category="GENERAL",
            tier="BEGINNER",
            xp_reward=30,
            icon="🔒",
            criteria={"type": "count", "target": 1, "metric": "transactions"},
            is_active=True
        )
        
        # Verificar XP antes
        profile = UserProfile.objects.get(user=self.test_user)
        xp_before = profile.experience_points
        
        # Criar e desbloquear
        user_achievement, _ = UserAchievement.objects.get_or_create(
            user=self.test_user,
            achievement=achievement,
            defaults={'progress': 0, 'progress_max': 1}
        )
        
        # Primeiro desbloqueio
        result1 = user_achievement.unlock()
        profile.refresh_from_db()
        xp_after_1 = profile.experience_points
        
        # Segundo desbloqueio (deve retornar False)
        user_achievement.refresh_from_db()
        result2 = user_achievement.unlock()
        profile.refresh_from_db()
        xp_after_2 = profile.experience_points
        
        xp_gained = xp_after_1 - xp_before
        
        if result1 and not result2 and xp_after_1 == xp_after_2:
            self.log("Prevenção de duplicatas funcionando!", "SUCCESS")
            self.log(f"XP ganho apenas uma vez: {xp_gained}", "SUCCESS")
            return True
        else:
            self.log(f"Falha na prevenção! result1={result1}, result2={result2}", "ERROR")
            return False
    
    def print_summary(self):
        """Imprime resumo dos testes"""
        self.log("\n" + "="*60, "INFO")
        self.log("RESUMO DOS TESTES", "INFO")
        self.log("="*60, "INFO")
        
        success = sum(1 for status, _ in self.results if status == "SUCCESS")
        errors = sum(1 for status, _ in self.results if status == "ERROR")
        warnings = sum(1 for status, _ in self.results if status == "WARNING")
        
        self.log(f"\nTotal de Sucessos: {success}", "SUCCESS")
        self.log(f"Total de Erros: {errors}", "ERROR" if errors > 0 else "INFO")
        self.log(f"Total de Avisos: {warnings}", "WARNING" if warnings > 0 else "INFO")
        
        # Mostrar XP final
        if self.test_user:
            profile = UserProfile.objects.get(user=self.test_user)
            total_achievements = UserAchievement.objects.filter(
                user=self.test_user,
                is_unlocked=True
            ).count()
            
            self.log(f"\nXP Final: {profile.experience_points}", "INFO")
            self.log(f"Conquistas Desbloqueadas: {total_achievements}", "INFO")
        
        return errors == 0

def run_tests():
    """Executa todos os testes"""
    print("\n" + "="*60)
    print("INICIANDO TESTES DE INTEGRAÇÃO - SISTEMA DE CONQUISTAS")
    print("="*60 + "\n")
    
    tester = TestAchievements()
    
    try:
        # Setup
        tester.setup()
        
        # Executar testes
        tester.test_1_model_creation()
        tester.test_2_criteria_validation()
        tester.test_3_auto_unlock()
        tester.test_4_progress_tracking()
        tester.test_5_manual_unlock()
        tester.test_6_ai_generation()
        tester.test_7_duplicate_prevention()
        
        # Resumo
        success = tester.print_summary()
        
        return success
        
    finally:
        # Cleanup
        tester.cleanup()

if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
