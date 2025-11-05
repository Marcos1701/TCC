import 'package:flutter/material.dart';

import '../../../../core/models/leaderboard.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../friends/presentation/pages/friends_page.dart';
import '../../data/leaderboard_viewmodel.dart';

/// Página de ranking com suporte para ranking geral e de amigos.
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  final _cacheManager = CacheManager();
  late TabController _tabController;
  late LeaderboardViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _viewModel = LeaderboardViewModel();
    _cacheManager.addListener(_onCacheInvalidated);
    
    // Carregar dados iniciais
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.loadGeneralLeaderboard();
      _viewModel.loadFriendsLeaderboard();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cacheManager.removeListener(_onCacheInvalidated);
    _viewModel.dispose();
    super.dispose();
  }

  void _onCacheInvalidated() {
    if (_cacheManager.isInvalidated(CacheType.leaderboard)) {
      if (mounted) {
        _viewModel.refresh();
      }
      _cacheManager.clearInvalidation(CacheType.leaderboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Ranking',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FriendsPage(),
                ),
              ).then((_) {
                // Recarregar após voltar da página de amigos
                _viewModel.refresh();
              });
            },
            tooltip: 'Gerenciar Amigos',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey[400],
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Ranking Geral'),
            Tab(text: 'Amigos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GeneralLeaderboardTab(viewModel: _viewModel),
          _FriendsLeaderboardTab(viewModel: _viewModel),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, child) {
          // Mostrar FAB apenas na tab de amigos
          if (_tabController.index == 1) {
            return FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FriendsPage(),
                  ),
                ).then((_) {
                  // Recarregar após voltar da página de amigos
                  _viewModel.refresh();
                });
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add),
              label: const Text('Adicionar Amigos'),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

/// Tab do ranking geral.
class _GeneralLeaderboardTab extends StatelessWidget {
  const _GeneralLeaderboardTab({required this.viewModel});

  final LeaderboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, child) {
        if (viewModel.isLoadingGeneral) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (viewModel.generalError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  viewModel.generalError!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => viewModel.loadGeneralLeaderboard(),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }

        final leaderboard = viewModel.generalLeaderboard;
        if (leaderboard == null || leaderboard.leaderboard.isEmpty) {
          return const Center(
            child: Text(
              'Nenhum usuário no ranking ainda.',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return _LeaderboardList(
          entries: leaderboard.leaderboard,
          onRefresh: () => viewModel.loadGeneralLeaderboard(),
        );
      },
    );
  }
}

/// Tab do ranking de amigos.
class _FriendsLeaderboardTab extends StatelessWidget {
  const _FriendsLeaderboardTab({required this.viewModel});

  final LeaderboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, child) {
        if (viewModel.isLoadingFriends) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (viewModel.friendsError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  viewModel.friendsError!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => viewModel.loadFriendsLeaderboard(),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }

        final leaderboard = viewModel.friendsLeaderboard;
        if (leaderboard == null || leaderboard.leaderboard.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, color: Colors.grey, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Você ainda não tem amigos.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adicione amigos para ver o ranking!',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FriendsPage(),
                        ),
                      );
                      viewModel.refresh();
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Adicionar Amigos'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return _LeaderboardList(
          entries: leaderboard.leaderboard,
          onRefresh: () => viewModel.loadFriendsLeaderboard(),
        );
      },
    );
  }
}

/// Lista de usuários no ranking.
class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({
    required this.entries,
    required this.onRefresh,
  });

  final List<LeaderboardEntryModel> entries;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    // Separar top 3 do resto
    final topThree = entries.take(3).toList();
    final rest = entries.skip(3).toList();

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: [
          // Card do usuário atual
          if (entries.any((e) => e.isCurrentUser))
            _CurrentUserRankCard(
              entry: entries.firstWhere((e) => e.isCurrentUser),
              tokens: tokens,
              theme: theme,
            ),
          if (entries.any((e) => e.isCurrentUser)) const SizedBox(height: 32),

          // Top 3 Pódio
          if (topThree.isNotEmpty) ...[
            Text(
              'Top 3',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 16),
            _PodiumWidget(
              topThree: topThree,
              tokens: tokens,
              theme: theme,
            ),
            const SizedBox(height: 32),
          ],

          // Restante do Ranking
          if (rest.isNotEmpty) ...[
            Text(
              'Classificação',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 12),
            ...rest.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RankTile(
                  entry: entry,
                  tokens: tokens,
                  theme: theme,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card com informações do usuário atual.
class _CurrentUserRankCard extends StatelessWidget {
  const _CurrentUserRankCard({
    required this.entry,
    required this.tokens,
    required this.theme,
  });

  final LeaderboardEntryModel entry;
  final AppDecorations tokens;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: tokens.cardRadius,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nível ${entry.level} • ${entry.xp} XP',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sua Posição',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '#${entry.rank}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget do pódio com os 3 primeiros.
class _PodiumWidget extends StatelessWidget {
  const _PodiumWidget({
    required this.topThree,
    required this.tokens,
    required this.theme,
  });

  final List<LeaderboardEntryModel> topThree;
  final AppDecorations tokens;
  final ThemeData theme;

  Color _getMedalColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Ouro
      case 2:
        return const Color(0xFFC0C0C0); // Prata
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Organizar pódio: 2º, 1º, 3º
    final List<MapEntry<int, LeaderboardEntryModel>> podiumOrder = [];
    
    if (topThree.length >= 2) {
      podiumOrder.add(MapEntry(1, topThree[1])); // 2º lugar à esquerda
    }
    if (topThree.isNotEmpty) {
      podiumOrder.add(MapEntry(0, topThree[0])); // 1º lugar no centro
    }
    if (topThree.length >= 3) {
      podiumOrder.add(MapEntry(2, topThree[2])); // 3º lugar à direita
    }

    final heights = [120.0, 150.0, 100.0]; // Alturas do pódio

    return SizedBox(
      height: 280,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: podiumOrder.map((entry) {
          final index = entry.key;
          final user = entry.value;
          final height = heights[index];

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  // Avatar e nome
                  CircleAvatar(
                    radius: user.rank == 1 ? 40 : 32,
                    backgroundColor: _getMedalColor(user.rank).withValues(alpha: 0.2),
                    child: Icon(
                      Icons.person,
                      color: _getMedalColor(user.rank),
                      size: user.rank == 1 ? 40 : 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${user.xp} XP',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pódio
                  Container(
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getMedalColor(user.rank).withValues(alpha: 0.3),
                          _getMedalColor(user.rank).withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      border: Border.all(
                        color: _getMedalColor(user.rank).withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: _getMedalColor(user.rank),
                            size: user.rank == 1 ? 40 : 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '#${user.rank}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: user.rank == 1 ? 28 : 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Tile de usuário no ranking (a partir do 4º lugar).
class _RankTile extends StatelessWidget {
  const _RankTile({
    required this.entry,
    required this.tokens,
    required this.theme,
  });

  final LeaderboardEntryModel entry;
  final AppDecorations tokens;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? AppColors.primary.withValues(alpha: 0.15)
            : const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        border: entry.isCurrentUser
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
        boxShadow: entry.isCurrentUser
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : tokens.mediumShadow,
      ),
      child: Row(
        children: [
          // Posição
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: entry.isCurrentUser
                  ? AppColors.primary
                  : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '#${entry.rank}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[800],
            child: Icon(
              Icons.person,
              color: entry.isCurrentUser ? AppColors.primary : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Nome e Level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Nível ${entry.level}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // XP
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.xp}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: entry.isCurrentUser ? AppColors.primary : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'XP',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[400],
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
