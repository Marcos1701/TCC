import 'package:flutter/material.dart';

/// Widget para selecionar cor com paleta Material
class ColorPickerDialog extends StatelessWidget {
  final String initialColor;
  final Function(String) onColorSelected;

  const ColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.onColorSelected,
  });

  static const _materialColors = [
    // Vermelho/Rosa
    {'name': 'Vermelho', 'hex': '#EF4444'},
    {'name': 'Rosa', 'hex': '#EC4899'},
    {'name': 'Rosa Claro', 'hex': '#F472B6'},
    
    // Laranja/Amarelo
    {'name': 'Laranja', 'hex': '#F97316'},
    {'name': 'Amarelo', 'hex': '#EAB308'},
    {'name': 'Âmbar', 'hex': '#F59E0B'},
    
    // Verde
    {'name': 'Verde', 'hex': '#10B981'},
    {'name': 'Esmeralda', 'hex': '#059669'},
    {'name': 'Lima', 'hex': '#84CC16'},
    
    // Azul/Ciano
    {'name': 'Azul', 'hex': '#3B82F6'},
    {'name': 'Azul Escuro', 'hex': '#1E40AF'},
    {'name': 'Ciano', 'hex': '#06B6D4'},
    {'name': 'Água', 'hex': '#0EA5E9'},
    
    // Roxo
    {'name': 'Roxo', 'hex': '#8B5CF6'},
    {'name': 'Violeta', 'hex': '#A855F7'},
    {'name': 'Índigo', 'hex': '#6366F1'},
    
    // Neutros
    {'name': 'Cinza', 'hex': '#808080'},
    {'name': 'Cinza Escuro', 'hex': '#4B5563'},
    {'name': 'Preto', 'hex': '#1F2937'},
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Escolher Cor'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _materialColors.length,
          itemBuilder: (context, index) {
            final colorData = _materialColors[index];
            final hex = colorData['hex']!;
            final isSelected = hex.toUpperCase() == initialColor.toUpperCase();

            return InkWell(
              onTap: () {
                onColorSelected(hex);
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000),
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 24)
                    : null,
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
