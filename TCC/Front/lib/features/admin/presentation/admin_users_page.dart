import 'package:flutter/material.dart';

import '../data/admin_viewmodel.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key, required this.viewModel});

  final AdminViewModel viewModel;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _buscaController = TextEditingController();
  bool _apenasAtivos = true;

  @override
  void initState() {
    super.initState();
    widget.viewModel.loadUsers(apenasAtivos: _apenasAtivos);
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  void _buscar() {
    widget.viewModel.loadUsers(
      busca: _buscaController.text.trim(),
      apenasAtivos: _apenasAtivos,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gerenciamento de Usuários',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Visualize e gerencie os usuários cadastrados no sistema',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _buscaController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome ou e-mail...',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _buscaController.clear();
                          _buscar();
                        },
                      ),
                    ),
                    onSubmitted: (_) => _buscar(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Apenas ativos'),
                        selected: _apenasAtivos,
                        onSelected: (selected) {
                          setState(() => _apenasAtivos = selected);
                          _buscar();
                        },
                      ),
                      ElevatedButton.icon(
                        onPressed: _buscar,
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: _buildUsersList(),
            ),

            if (widget.viewModel.usersTotalPages > 1)
              _Pagination(
                currentPage: widget.viewModel.usersCurrentPage,
                totalPages: widget.viewModel.usersTotalPages,
                onPageChanged: (page) {
                  widget.viewModel.loadUsers(
                    busca: _buscaController.text.trim(),
                    apenasAtivos: _apenasAtivos,
                    pagina: page,
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildUsersList() {
    final viewModel = widget.viewModel;

    if (viewModel.isLoading && viewModel.users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.errorMessage != null && viewModel.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(viewModel.errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _buscar,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (viewModel.users.isEmpty) {
      return const Center(
        child: Text('Nenhum usuário encontrado'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: viewModel.users.length,
      itemBuilder: (context, index) {
        final user = viewModel.users[index];
        return _UserCard(
          user: user,
          onToggle: () => _toggleUser(user),
        );
      },
    );
  }

  Future<void> _toggleUser(Map<String, dynamic> user) async {
    final id = user['id'] as int;
    final nome = user['nome'] as String? ?? 'Usuário';
    final estaAtivo = user['ativo'] as bool? ?? true;
    final novoEstado = estaAtivo ? 'desativar' : 'ativar';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar ${estaAtivo ? 'desativação' : 'ativação'}'),
        content: Text('Deseja realmente $novoEstado o usuário "$nome"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(estaAtivo ? 'Desativar' : 'Ativar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final sucesso = await widget.viewModel.toggleUser(id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sucesso
                  ? 'Usuário ${estaAtivo ? 'desativado' : 'ativado'} com sucesso!'
                  : 'Erro ao atualizar usuário',
            ),
            backgroundColor: sucesso ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onToggle,
  });

  final Map<String, dynamic> user;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final nome = user['nome'] as String? ?? 'Usuário';
    final email = user['email'] as String? ?? '';
    final nivel = user['nivel'] as int? ?? 1;
    final xp = user['xp'] as int? ?? 0;
    final ativo = user['ativo'] as bool? ?? true;
    final admin = user['administrador'] as bool? ?? false;
    final ultimoAcesso = user['ultimo_acesso'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: ativo
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              child: Text(
                nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: ativo
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nome,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (admin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Admin',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.military_tech,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Nível $nivel',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$xp XP',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      if (ultimoAcesso != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(ultimoAcesso),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (ativo ? Colors.green : Colors.grey).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ativo ? 'Ativo' : 'Inativo',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: ativo ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (!admin)
                  IconButton(
                    icon: Icon(
                      ativo ? Icons.person_off : Icons.person_add,
                      color: ativo ? Colors.red : Colors.green,
                    ),
                    tooltip: ativo ? 'Desativar' : 'Ativar',
                    onPressed: onToggle,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        return 'Hoje';
      } else if (diff.inDays == 1) {
        return 'Ontem';
      } else if (diff.inDays < 7) {
        return 'Há ${diff.inDays} dias';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Data desconhecida';
    }
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
          ),
          const SizedBox(width: 16),
          Text('Página $currentPage de $totalPages'),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
          ),
        ],
      ),
    );
  }
}
