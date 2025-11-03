import 'package:flutter/material.dart';

import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  // Dados simulados de ranking
  final List<_UserRankData> _topUsers = [
    _UserRankData(
      rank: 1,
      name: 'Ana Silva',
      level: 15,
      xp: 12500,
      isCurrentUser: false,
    ),
    _UserRankData(
      rank: 2,
      name: 'Carlos Mendes',
      level: 14,
      xp: 11800,
      isCurrentUser: false,
    ),
    _UserRankData(
      rank: 3,
      name: 'Beatriz Costa',
      level: 13,
      xp: 10900,
      isCurrentUser: false,
    ),
    _UserRankData(
      rank: 4,
      name: 'Diego Santos',
      level: 12,
      xp: 9800,
      isCurrentUser: false,
    ),
    _UserRankData(
      rank: 5,
      name: 'Elena Oliveira',
      level: 11,
      xp: 8900,
      isCurrentUser: false,
    ),
    _UserRankData(
      rank: 6,
      name: 'Felipe Lima',
      level: 10,
      xp: 7800,
      isCurrentUser: false,
    ),
    _UserRankData(
      rank: 7,
      name: 'Gabriela Rocha',
      level: 9,
      xp: 6900,
      isCurrentUser: false,
    ),
    _UserRankData(
      rank: 8,
      name: 'Você',
      level: 8,
      xp: 5800,
      isCurrentUser: true,
    ),
    _UserRankData(
      rank: 9,
      name: 'Igor Ferreira',
      level: 7,
      xp: 4900,
      isCurrentUser: false,
    ),
    _UserRankData(
      rank: 10,
      name: 'Julia Martins',
      level: 6,
      xp: 3800,
      isCurrentUser: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    final session = SessionScope.of(context);
    final userName = session.session?.user.name ?? 'Você';
    
    // Encontra o usuário atual no ranking
    final currentUserRank = _topUsers.firstWhere(
      (u) => u.isCurrentUser,
      orElse: () => _topUsers.last,
    );

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
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: [
          // Card de Posição do Usuário
          _CurrentUserRankCard(
            userName: userName,
            rank: currentUserRank,
            tokens: tokens,
            theme: theme,
          ),
          const SizedBox(height: 32),
          
          // Top 3 Pódio
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
            topThree: _topUsers.take(3).toList(),
            tokens: tokens,
            theme: theme,
          ),
          const SizedBox(height: 32),
          
          // Restante do Ranking
          Text(
            'Classificação Geral',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 12),
          
          // Lista de usuários do 4º ao 10º
          ..._topUsers.skip(3).map((user) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RankTile(
                  user: user,
                  tokens: tokens,
                  theme: theme,
                ),
              )),
        ],
      ),
    );
  }
}

class _CurrentUserRankCard extends StatelessWidget {
  const _CurrentUserRankCard({
    required this.userName,
    required this.rank,
    required this.tokens,
    required this.theme,
  });

  final String userName;
  final _UserRankData rank;
  final AppDecorations tokens;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: tokens.cardRadius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white.withOpacity(0.2),
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
                      userName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nível ${rank.level} • ${rank.xp} XP',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
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
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  rank.rank <= 3
                      ? Icons.emoji_events
                      : Icons.military_tech_outlined,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Text(
                      'Sua Posição',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '#${rank.rank}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 32,
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

class _PodiumWidget extends StatelessWidget {
  const _PodiumWidget({
    required this.topThree,
    required this.tokens,
    required this.theme,
  });

  final List<_UserRankData> topThree;
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
    if (topThree.length < 3) return const SizedBox.shrink();

    // Ordena para exibir: 2º, 1º, 3º
    final orderedUsers = [topThree[1], topThree[0], topThree[2]];
    final heights = [100.0, 130.0, 80.0];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: orderedUsers.asMap().entries.map((entry) {
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
                  backgroundColor: _getMedalColor(user.rank).withOpacity(0.2),
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
                        _getMedalColor(user.rank).withOpacity(0.3),
                        _getMedalColor(user.rank).withOpacity(0.1),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    border: Border.all(
                      color: _getMedalColor(user.rank).withOpacity(0.5),
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
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({
    required this.user,
    required this.tokens,
    required this.theme,
  });

  final _UserRankData user;
  final AppDecorations tokens;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: user.isCurrentUser
            ? AppColors.primary.withOpacity(0.15)
            : const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        border: user.isCurrentUser
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
        boxShadow: user.isCurrentUser
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
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
              color: user.isCurrentUser
                  ? AppColors.primary
                  : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '#${user.rank}',
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
              color: user.isCurrentUser ? AppColors.primary : Colors.white,
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
                  user.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Nível ${user.level}',
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
                '${user.xp}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: user.isCurrentUser ? AppColors.primary : Colors.white,
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

class _UserRankData {
  final int rank;
  final String name;
  final int level;
  final int xp;
  final bool isCurrentUser;

  _UserRankData({
    required this.rank,
    required this.name,
    required this.level,
    required this.xp,
    required this.isCurrentUser,
  });
}
