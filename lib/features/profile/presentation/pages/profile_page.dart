import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_outline,
                    size: 36,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Olá, Ana!',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nível 5 • Guardião Financeiro',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () {},
                  child: const Text('Editar'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Preferências', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                value: true,
                onChanged: (_) {},
                title: const Text('Notificações de lembrete'),
                subtitle: const Text('Receba alertas para registrar despesas ou metas próximas do vencimento.'),
              ),
              const Divider(height: 0),
              SwitchListTile.adaptive(
                value: false,
                onChanged: (_) {},
                title: const Text('Autenticação em duas etapas'),
                subtitle: const Text('Adicione uma camada extra de segurança utilizando códigos temporários.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Dados e segurança', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Gerenciar tokens de acesso'),
                subtitle: const Text('Revogue sessões antigas ou dispositivos que você não reconhece.'),
                onTap: () {},
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Exportar dados financeiros'),
                subtitle: const Text('Baixe um relatório com todas as suas transações e índices calculados.'),
                onTap: () {},
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Encerrar sessão'),
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}
