# Sistema de Administração - Documentação Completa

## Visão Geral

Este documento descreve o sistema completo de administração implementado no aplicativo de gamificação financeira. O sistema foi projetado para fornecer aos administradores uma interface moderna e intuitiva para gerenciar usuários, missões e categorias.

## Arquitetura

### Backend (Django REST Framework)

#### Endpoints de Administração

1. **AdminStatsViewSet** (`/admin/stats/`)
   - **Permissão**: `IsAdminUser` (apenas staff)
   - **Método**: `GET /admin/stats/overview/`
   - **Retorna**:
     ```json
     {
       "total_users": 150,
       "completed_missions": 342,
       "active_missions": 28,
       "avg_user_level": 8.3,
       "missions_by_tier": {
         "BEGINNER": 10,
         "INTERMEDIATE": 12,
         "ADVANCED": 6
       },
       "missions_by_type": {
         "SAVINGS": 8,
         "EXPENSE_CONTROL": 10,
         "DEBT_REDUCTION": 6,
         "ONBOARDING": 4
       },
       "recent_activity": [
         {
           "user": "joao_silva",
           "mission": "Economize R$ 100 este mês",
           "completed_at": "2025-01-15T14:30:00Z",
           "xp_earned": 50
         }
       ],
       "level_distribution": {
         "1-5": 45,
         "6-10": 60,
         "11-20": 35,
         "21+": 10
       },
       "mission_completion_rate": 73.5
     }
     ```

#### Campos de Administração no Usuário

Os seguintes endpoints retornam os campos `is_staff` e `is_superuser`:
- `GET /profile/` - ProfileView
- `POST /auth/register/` - RegisterView
- `GET /user/me/` - UserProfileViewSet.me()
- `PATCH /user/{id}/` - UserProfileViewSet.update_profile()

### Frontend (Flutter)

#### Estrutura de Páginas

```
lib/features/admin/presentation/pages/
├── admin_dashboard_page.dart          # Dashboard principal
├── admin_missions_management_page.dart # Gerenciamento de missões
├── admin_categories_management_page.dart # Gerenciamento de categorias
└── admin_ai_missions_page.dart        # Geração de missões com IA
```

## Páginas Administrativas

### 1. Dashboard Principal (`AdminDashboardPage`)

**Arquivo**: `admin_dashboard_page.dart`

#### Funcionalidades

- **Métricas principais** (grid 2x2):
  - Total de usuários
  - Missões completadas
  - Missões ativas
  - Nível médio dos usuários

- **Ações rápidas**:
  - Gerar missões com IA
  - Gerenciar missões
  - Gerenciar categorias

- **Estatísticas de missões**:
  - Distribuição por tier (BEGINNER/INTERMEDIATE/ADVANCED)
  - Distribuição por tipo (SAVINGS/EXPENSE_CONTROL/DEBT_REDUCTION/ONBOARDING)
  - Taxa de conclusão

- **Atividade recente**:
  - Últimas 10 missões completadas
  - Usuário, missão e XP ganho

#### Exemplo de Uso

```dart
// Navegação para o dashboard
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const AdminDashboardPage(),
  ),
);
```

### 2. Gerenciamento de Missões (`AdminMissionsManagementPage`)

**Arquivo**: `admin_missions_management_page.dart`

#### Funcionalidades

- **Filtros**:
  - Por tipo: TODAS, ECONOMIA, CONTROLE DE GASTOS, REDUÇÃO DE DÍVIDAS, ONBOARDING
  - Por dificuldade: TODAS, FÁCIL, MÉDIA, DIFÍCIL

- **Visualização**:
  - Cards com informações completas da missão
  - Chips visuais para tipo, dificuldade e XP
  - Métricas TPS, RDR, ILI quando aplicável

- **Ações**:
  - Toggle ativo/inativo para cada missão
  - Atualização em tempo real
  - Pull-to-refresh

#### Exemplo de Card de Missão

```
┌─────────────────────────────────────┐
│ Economize R$ 100 este mês          │
│                                     │
│ [ECONOMIA] [FÁCIL] [50 XP]         │
│ [30 dias]                          │
│                                     │
│ Atinja TPS > 10%                   │
│                                     │
│ ●───────○ ATIVA                    │
└─────────────────────────────────────┘
```

### 3. Gerenciamento de Categorias (`AdminCategoriesManagementPage`)

**Arquivo**: `admin_categories_management_page.dart`

#### Funcionalidades

- **Filtros**:
  - Por tipo: TODAS, RECEITA, DESPESA, DÍVIDA

- **Visualização**:
  - Agrupadas por tipo
  - Ícones contextuais baseados no nome
  - Cores personalizadas para cada categoria
  - Labels de grupo (Renda principal, Essencial, etc.)

- **Informações exibidas**:
  - Nome da categoria
  - Tipo (Receita/Despesa/Dívida)
  - Grupo (quando aplicável)
  - Cor personalizada

#### Exemplo de Seção

```
Receitas (12)
┌─────────────────────────────────────┐
│ [💼] Salário Principal              │
│      Renda principal    [Receita]   │
├─────────────────────────────────────┤
│ [💰] Freelance                      │
│      Renda extra        [Receita]   │
└─────────────────────────────────────┘
```

## Fluxo de Navegação

```
Settings Page
    │
    └─> [Botão Administração]
            │
            ├─> Admin Dashboard
            │       │
            │       ├─> Gerar Missões IA
            │       ├─> Gerenciar Missões
            │       └─> Gerenciar Categorias
            │
            ├─> Admin Missions Management
            │       │
            │       ├─> Filtrar por tipo
            │       ├─> Filtrar por dificuldade
            │       └─> Toggle ativo/inativo
            │
            └─> Admin Categories Management
                    │
                    └─> Visualizar categorias globais
```

## Segurança

### Backend

1. **Permissões**: Todos os endpoints admin usam `permissions.IsAdminUser`
2. **Validação**: Apenas usuários com `is_staff=True` podem acessar
3. **Autenticação**: JWT tokens obrigatórios

### Frontend

1. **Verificação de permissão**:
   ```dart
   final isAdmin = profileProvider.profile?.isAdmin ?? false;
   if (isAdmin) {
     // Mostrar opções de admin
   }
   ```

2. **Getter `isAdmin`**:
   ```dart
   bool get isAdmin => isStaff || isSuperuser;
   ```

## Design Pattern

### Material Design 3

- **Cores primárias**: 
  - Teal (`Colors.teal`) para AppBar
  - Purple (`AppColors.primary`) para elementos de destaque
  
- **Cards**: Elevação sutil com bordas arredondadas
- **Chips**: Para tags visuais (tipo, dificuldade, métricas)
- **SegmentedButton**: Para filtros de seleção única
- **Switch**: Para toggle de estado ativo/inativo

### Responsividade

- Grid adaptativo (2 colunas em tablets, 1 em mobile)
- Textos responsivos com `fontSize` ajustáveis
- Layout flexível com `Expanded` e `Flexible`

## Melhorias Futuras

### Curto Prazo

1. **Gerenciamento de usuários**:
   - Listar todos os usuários
   - Editar permissões
   - Desativar/ativar contas

2. **Análises avançadas**:
   - Gráficos de evolução de usuários
   - Taxa de retenção
   - Métricas de engajamento

3. **Edição de categorias**:
   - Adicionar novas categorias globais
   - Editar cores e ícones
   - Remover categorias

### Médio Prazo

4. **Logs de auditoria**:
   - Histórico de ações administrativas
   - Exportação de relatórios

5. **Notificações push**:
   - Enviar notificações para usuários
   - Campanhas de engajamento

6. **Personalização de recompensas**:
   - Ajustar valores de XP
   - Criar eventos especiais

### Longo Prazo

7. **Dashboard analytics**:
   - Power BI/Metabase integração
   - Dashboards personalizáveis

8. **A/B Testing**:
   - Testar diferentes estratégias de gamificação
   - Métricas de conversão

## Referências

### Backend
- `Api/finance/views.py` - AdminStatsViewSet
- `Api/finance/urls.py` - Rotas de admin
- `Api/finance/models.py` - Modelos de dados

### Frontend
- `Front/lib/features/admin/presentation/pages/` - Páginas admin
- `Front/lib/core/models/profile.dart` - Modelo de usuário
- `Front/lib/core/network/api_client.dart` - Cliente HTTP

### Documentação relacionada
- `GERACAO_MISSOES_IA.md` - Sistema de geração de missões com IA
- `RESUMO_CORRECOES_GERACAO_IA.md` - Histórico de correções
