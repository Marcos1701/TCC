"""
Comando Django para criar categorias padrão do sistema.
Cria 28 categorias (8 INCOME + 20 EXPENSE) com cores e grupos definidos.
"""
from decimal import Decimal
from django.core.management.base import BaseCommand
from django.db import transaction
from finance.models import Category


class Command(BaseCommand):
    help = 'Cria categorias padrão do sistema (8 INCOME + 20 EXPENSE)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Remove todas as categorias padrão antes de criar novas',
        )

    def handle(self, *args, **options):
        if options['clear']:
            deleted_count = Category.objects.filter(is_system_default=True).delete()[0]
            self.stdout.write(
                self.style.WARNING(f'🗑️  {deleted_count} categorias padrão removidas\n')
            )

        # Criar categorias de RECEITA
        income_created = self._create_income_categories()
        
        # Criar categorias de DESPESA
        expense_created = self._create_expense_categories()
        
        total = income_created + expense_created
        self.stdout.write(
            self.style.SUCCESS(f'\n🎉 Total: {total} categorias padrão criadas com sucesso!')
        )

    def _create_income_categories(self):
        """Cria 8 categorias de RECEITA."""
        self.stdout.write('📊 Criando categorias de RECEITA...')
        
        categories = [
            # ===== RENDA PRINCIPAL (3 categorias) =====
            {
                'name': '💼 Salário',
                'type': 'INCOME',
                'group': 'REGULAR_INCOME',
                'color': '#10B981',  # Verde
            },
            {
                'name': '💰 13º Salário',
                'type': 'INCOME',
                'group': 'REGULAR_INCOME',
                'color': '#059669',  # Verde escuro
            },
            {
                'name': '🎁 Bonificação',
                'type': 'INCOME',
                'group': 'REGULAR_INCOME',
                'color': '#34D399',  # Verde claro
            },
            
            # ===== RENDA EXTRA (3 categorias) =====
            {
                'name': '💻 Freelance',
                'type': 'INCOME',
                'group': 'EXTRA_INCOME',
                'color': '#8B5CF6',  # Roxo
            },
            {
                'name': '🛍️ Vendas',
                'type': 'INCOME',
                'group': 'EXTRA_INCOME',
                'color': '#A78BFA',  # Roxo claro
            },
            {
                'name': '📈 Investimentos',
                'type': 'INCOME',
                'group': 'EXTRA_INCOME',
                'color': '#6366F1',  # Índigo
            },
            
            # ===== OUTRAS RECEITAS (2 categorias) =====
            {
                'name': '🎉 Presente',
                'type': 'INCOME',
                'group': 'OTHER',
                'color': '#EC4899',  # Rosa
            },
            {
                'name': '🔄 Reembolso',
                'type': 'INCOME',
                'group': 'OTHER',
                'color': '#F472B6',  # Rosa claro
            },
        ]

        return self._batch_create_categories(categories)

    def _create_expense_categories(self):
        """Cria 20 categorias de DESPESA."""
        self.stdout.write('\n📊 Criando categorias de DESPESA...')
        
        categories = [
            # ===== DESPESAS ESSENCIAIS (8 categorias) =====
            {
                'name': '🏠 Moradia',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#EF4444',  # Vermelho
            },
            {
                'name': '⚡ Energia Elétrica',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#F59E0B',  # Âmbar
            },
            {
                'name': '💧 Água',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#3B82F6',  # Azul
            },
            {
                'name': '📱 Telefone/Internet',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#8B5CF6',  # Roxo
            },
            {
                'name': '🍎 Alimentação',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#10B981',  # Verde
            },
            {
                'name': '🚗 Transporte',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#6366F1',  # Índigo
            },
            {
                'name': '💊 Saúde',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#EF4444',  # Vermelho
            },
            {
                'name': '📚 Educação',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#3B82F6',  # Azul
            },
            
            # ===== ESTILO DE VIDA (9 categorias) =====
            {
                'name': '🍔 Restaurantes',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#F59E0B',  # Âmbar
            },
            {
                'name': '🎮 Lazer',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#EC4899',  # Rosa
            },
            {
                'name': '👕 Vestuário',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#8B5CF6',  # Roxo
            },
            {
                'name': '✂️ Beleza',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#EC4899',  # Rosa
            },
            {
                'name': '🏋️ Academia',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#10B981',  # Verde
            },
            {
                'name': '🐾 Pet',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#F59E0B',  # Âmbar
            },
            {
                'name': '🎬 Streaming',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#EF4444',  # Vermelho
            },
            {
                'name': '🎁 Presentes',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#EC4899',  # Rosa
            },
            {
                'name': '✈️ Viagens',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#3B82F6',  # Azul
            },
            
            # ===== OUTRAS DESPESAS (3 categorias) =====
            {
                'name': '🏦 Taxas Bancárias',
                'type': 'EXPENSE',
                'group': 'OTHER',
                'color': '#6B7280',  # Cinza
            },
            {
                'name': '💳 Cartão de Crédito',
                'type': 'EXPENSE',
                'group': 'OTHER',
                'color': '#DC2626',  # Vermelho escuro
            },
            {
                'name': '🔧 Outros',
                'type': 'EXPENSE',
                'group': 'OTHER',
                'color': '#9CA3AF',  # Cinza claro
            },
        ]

        return self._batch_create_categories(categories)

    def _batch_create_categories(self, categories_data):
        """
        Cria categorias em lote a partir de uma lista de dicionários.
        
        Args:
            categories_data: Lista de dicts com dados das categorias
            
        Returns:
            int: Número de categorias criadas
        """
        created_count = 0
        skipped_count = 0

        for data in categories_data:
            # Verificar se categoria já existe (mesmo nome e tipo, sem user)
            exists = Category.objects.filter(
                name=data['name'],
                type=data['type'],
                user__isnull=True,  # Categorias globais
            ).exists()

            if exists:
                self.stdout.write(
                    self.style.WARNING(f'  ⏭️  {data["name"]} (já existe)')
                )
                skipped_count += 1
                continue

            try:
                # Criar categoria global (user=None)
                Category.objects.create(
                    name=data['name'],
                    type=data['type'],
                    group=data['group'],
                    color=data['color'],
                    user=None,  # Categoria global
                    is_system_default=True,
                )
                
                self.stdout.write(f'  ✅ {data["name"]}')
                created_count += 1

            except Exception as e:
                self.stdout.write(
                    self.style.ERROR(f'  ❌ Erro ao criar "{data["name"]}": {str(e)}')
                )

        if skipped_count > 0:
            self.stdout.write(
                self.style.WARNING(f'  ℹ️  {skipped_count} categorias puladas (já existentes)')
            )

        self.stdout.write(
            self.style.SUCCESS(f'✅ {created_count} categorias criadas')
        )
        
        return created_count
