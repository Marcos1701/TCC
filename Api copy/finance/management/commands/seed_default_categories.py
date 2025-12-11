"""
Comando Django para criar categorias padrão do sistema.
Cria lista abrangente de categorias (INCOME + EXPENSE) com cores e grupos definidos, sem emojis.
"""
from decimal import Decimal
from django.core.management.base import BaseCommand
from django.db import transaction
from finance.models import Category


class Command(BaseCommand):
    help = 'Cria categorias padrão do sistema (ampliadas e organizadas)'

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
        """Cria categorias de RECEITA."""
        self.stdout.write('📊 Criando categorias de RECEITA...')
        
        categories = [
            # ===== RENDA PRINCIPAL =====
            {
                'name': 'Salário',
                'type': 'INCOME',
                'group': 'REGULAR_INCOME',
                'color': '#10B981',  # Verde
            },
            {
                'name': '13º Salário',
                'type': 'INCOME',
                'group': 'REGULAR_INCOME',
                'color': '#059669',  # Verde escuro
            },
            {
                'name': 'Bonificação',
                'type': 'INCOME',
                'group': 'REGULAR_INCOME',
                'color': '#34D399',  # Verde claro
            },
            
            # ===== RENDA EXTRA =====
            {
                'name': 'Freelance',
                'type': 'INCOME',
                'group': 'EXTRA_INCOME',
                'color': '#8B5CF6',  # Roxo
            },
            {
                'name': 'Vendas',
                'type': 'INCOME',
                'group': 'EXTRA_INCOME',
                'color': '#A78BFA',  # Roxo claro
            },
            {
                'name': 'Rendimentos',
                'type': 'INCOME',
                'group': 'EXTRA_INCOME',
                'color': '#6366F1',  # Índigo
            },
             # ===== INVESTIMENTOS (Resgastes) =====
            {
                'name': 'Resgate de Investimento',
                'type': 'INCOME',
                'group': 'INVESTMENT',
                'color': '#6366F1',  # Índigo
            },
            
            # ===== OUTRAS RECEITAS =====
            {
                'name': 'Presente',
                'type': 'INCOME',
                'group': 'OTHER',
                'color': '#EC4899',  # Rosa
            },
            {
                'name': 'Reembolso',
                'type': 'INCOME',
                'group': 'OTHER',
                'color': '#F472B6',  # Rosa claro
            },
            {
                'name': 'Outras Receitas',
                'type': 'INCOME',
                'group': 'OTHER',
                'color': '#9CA3AF',  # Cinza claro
            },
        ]

        return self._batch_create_categories(categories)

    def _create_expense_categories(self):
        """Cria categorias de DESPESA."""
        self.stdout.write('\n📊 Criando categorias de DESPESA...')
        
        categories = [
            # ===== DESPESAS ESSENCIAIS =====
            {
                'name': 'Aluguel',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#EF4444',  # Vermelho
            },
            {
                'name': 'Condomínio',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#F87171',  # Vermelho claro
            },
            {
                'name': 'Energia Elétrica',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#F59E0B',  # Âmbar
            },
            {
                'name': 'Água',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#3B82F6',  # Azul
            },
            {
                'name': 'Gás',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#F97316',  # Laranja
            },
            {
                'name': 'Telefone & Internet',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#8B5CF6',  # Roxo
            },
            {
                'name': 'Supermercado',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#10B981',  # Verde
            },
            {
                'name': 'Transporte',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#6366F1',  # Índigo
            },
            {
                'name': 'Combustível',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#7C3AED',  # Roxo escuro
            },
            {
                'name': 'Saúde & Farmácia',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#EF4444',  # Vermelho
            },
            {
                'name': 'Educação',
                'type': 'EXPENSE',
                'group': 'ESSENTIAL_EXPENSE',
                'color': '#3B82F6',  # Azul
            },
            
            # ===== ESTILO DE VIDA =====
            {
                'name': 'Restaurantes',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#F59E0B',  # Âmbar
            },
            {
                'name': 'Lazer e Entretenimento',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#EC4899',  # Rosa
            },
            {
                'name': 'Vestuário',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#8B5CF6',  # Roxo
            },
            {
                'name': 'Cuidados Pessoais',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#EC4899',  # Rosa
            },
            {
                'name': 'Academia / Esportes',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#10B981',  # Verde
            },
            {
                'name': 'Pet',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#F59E0B',  # Âmbar
            },
            {
                'name': 'Serviços de Streaming',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#EF4444',  # Vermelho
            },
            {
                'name': 'Presentes',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#EC4899',  # Rosa
            },
            {
                'name': 'Viagens',
                'type': 'EXPENSE',
                'group': 'LIFESTYLE_EXPENSE',
                'color': '#3B82F6',  # Azul
            },
            
            # ===== POUPANÇA / INVESTIMENTOS (Saída) =====
            {
                'name': 'Poupança',
                'type': 'EXPENSE',
                'group': 'SAVINGS',
                'color': '#10B981',  # Verde
            },
            {
                'name': 'Investimentos',
                'type': 'EXPENSE',
                'group': 'INVESTMENT',
                'color': '#059669',  # Verde escuro
            },

            # ===== DÍVIDAS E OUTROS =====
            {
                'name': 'Pagamento de Empréstimo',
                'type': 'EXPENSE',
                'group': 'OTHER', 
                'color': '#6B7280',  # Cinza
            },
            {
                'name': 'Pagamento de Cartão',
                'type': 'EXPENSE',
                'group': 'OTHER',
                'color': '#DC2626',  # Vermelho escuro
            },
            {
                'name': 'Taxas Bancárias',
                'type': 'EXPENSE',
                'group': 'OTHER',
                'color': '#9CA3AF',  # Cinza claro
            },
            {
                'name': 'Outros',
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
