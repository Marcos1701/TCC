import 'package:flutter/material.dart';

class IconPickerDialog extends StatelessWidget {
  final String? initialIcon;
  final Function(String) onIconSelected;

  const IconPickerDialog({
    super.key,
    this.initialIcon,
    required this.onIconSelected,
  });

  static const _categoryIcons = [
    {'name': 'Dinheiro', 'icon': Icons.attach_money},
    {'name': 'Carteira', 'icon': Icons.account_balance_wallet},
    {'name': 'Cartão', 'icon': Icons.credit_card},
    {'name': 'Moedas', 'icon': Icons.monetization_on},
    {'name': 'Poupança', 'icon': Icons.savings},
    
    {'name': 'Restaurante', 'icon': Icons.restaurant},
    {'name': 'Café', 'icon': Icons.local_cafe},
    {'name': 'Pizza', 'icon': Icons.local_pizza},
    {'name': 'Mercado', 'icon': Icons.shopping_cart},
    {'name': 'Fast Food', 'icon': Icons.fastfood},
    
    {'name': 'Carro', 'icon': Icons.directions_car},
    {'name': 'Ônibus', 'icon': Icons.directions_bus},
    {'name': 'Gasolina', 'icon': Icons.local_gas_station},
    {'name': 'Avião', 'icon': Icons.flight},
    {'name': 'Trem', 'icon': Icons.train},
    
    {'name': 'Casa', 'icon': Icons.home},
    {'name': 'Luz', 'icon': Icons.lightbulb},
    {'name': 'Água', 'icon': Icons.water_drop},
    {'name': 'Ferramentas', 'icon': Icons.build},
    
    {'name': 'Saúde', 'icon': Icons.local_hospital},
    {'name': 'Remédio', 'icon': Icons.medication},
    {'name': 'Academia', 'icon': Icons.fitness_center},
    {'name': 'Spa', 'icon': Icons.spa},
    
    {'name': 'Filme', 'icon': Icons.movie},
    {'name': 'Música', 'icon': Icons.music_note},
    {'name': 'Jogo', 'icon': Icons.sports_esports},
    {'name': 'Livro', 'icon': Icons.menu_book},
    {'name': 'Praia', 'icon': Icons.beach_access},
    {'name': 'Parque', 'icon': Icons.park},
    
    {'name': 'Escola', 'icon': Icons.school},
    {'name': 'Livro Educação', 'icon': Icons.import_contacts},
    {'name': 'Lápis', 'icon': Icons.edit},
    
    {'name': 'Trabalho', 'icon': Icons.work},
    {'name': 'Laptop', 'icon': Icons.laptop},
    {'name': 'Briefcase', 'icon': Icons.business_center},
    
    {'name': 'Roupa', 'icon': Icons.checkroom},
    {'name': 'Sapato', 'icon': Icons.shopping_bag},
    
    {'name': 'Pet', 'icon': Icons.pets},
    
    {'name': 'Celular', 'icon': Icons.phone_android},
    {'name': 'Wi-Fi', 'icon': Icons.wifi},
    {'name': 'Headphone', 'icon': Icons.headphones},
    
    {'name': 'Presente', 'icon': Icons.card_giftcard},
    {'name': 'Celebração', 'icon': Icons.celebration},
    
    {'name': 'Estrela', 'icon': Icons.star},
    {'name': 'Favorito', 'icon': Icons.favorite},
    {'name': 'Categoria', 'icon': Icons.category},
    {'name': 'Outros', 'icon': Icons.more_horiz},
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Escolher Ícone'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _categoryIcons.length,
          itemBuilder: (context, index) {
            final iconData = _categoryIcons[index];
            final icon = iconData['icon'] as IconData;
            final iconName = icon.codePoint.toString();
            final isSelected = iconName == initialIcon;

            return InkWell(
              onTap: () {
                onIconSelected(iconName);
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                      : Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[400],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
