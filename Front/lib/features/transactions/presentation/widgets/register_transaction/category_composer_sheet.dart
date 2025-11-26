import 'package:flutter/material.dart';

import '../../../../../core/constants/category_groups.dart';
import '../../../../../core/repositories/finance_repository.dart';
import '../../../../../core/theme/app_colors.dart';
import 'category_widgets.dart';

/// Bottom sheet para criar nova categoria.
class CategoryComposerSheet extends StatefulWidget {
  const CategoryComposerSheet({
    super.key,
    required this.repository,
    required this.initialType,
    required this.existingNames,
  });

  final FinanceRepository repository;
  final String initialType;
  final Set<String> existingNames;

  @override
  State<CategoryComposerSheet> createState() => _CategoryComposerSheetState();
}

class _CategoryComposerSheetState extends State<CategoryComposerSheet> {
  static const List<Color> _swatches = [
    AppColors.primary,
    Color(0xFF0A62D1),
    AppColors.highlight,
    Color(0xFFFFC94D),
    Color(0xFF3DD598),
    Color(0xFF6C5CE7),
    Color(0xFFEF6F6C),
    Color(0xFF1ABCFE),
  ];

  static const _sheetColor = Color(0xFF05060A);
  static const _fieldColor = Color(0xFF111522);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  late String _type;
  late String _group;
  Color _selectedColor = _swatches.first;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _group = _defaultGroupForType(_type);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _defaultGroupForType(String type) {
    final options = CategoryGroupMetadata.groupsForType(type);
    return options.first;
  }

  void _updateType(String value) {
    if (_type == value) return;
    setState(() {
      _type = value;
      final options = CategoryGroupMetadata.groupsForType(_type);
      if (!options.contains(_group)) {
        _group = options.first;
      }
    });
  }

  void _updateGroup(String value) {
    setState(() => _group = value);
  }

  void _updateColor(Color color) {
    setState(() => _selectedColor = color);
  }

  String? _validateName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Informe um nome.';
    }
    if (widget.existingNames.contains(trimmed.toLowerCase())) {
      return 'Você já tem uma categoria com esse nome.';
    }
    return null;
  }

  String _colorToHex(Color color) {
    final value = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${value.substring(2)}';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final created = await widget.repository.createCategory(
        name: _nameController.text.trim(),
        type: _type,
        color: _colorToHex(_selectedColor),
        group: _group,
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível salvar a categoria. Tente novamente.';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewInsets.bottom;
    final outline = Colors.white.withOpacity(0.12);
    final theme = Theme.of(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * 0.82,
            minHeight: mediaQuery.size.height * 0.55,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _sheetColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                border: Border.all(color: outline),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x88000000),
                    blurRadius: 36,
                    offset: Offset(0, -12),
                  ),
                ],
              ),
              child: Theme(
                data: _buildThemeData(theme, outline),
                child: Column(
                  children: [
                    _buildHeader(theme, outline),
                    Divider(color: outline, height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        child: _buildForm(theme),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ThemeData _buildThemeData(ThemeData theme, Color outline) {
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        surface: _sheetColor,
        onSurface: Colors.white,
        primary: AppColors.primary,
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: _fieldColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color outline) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: _submitting ? null : () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              'Nova categoria',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTypeSection(theme),
          const SizedBox(height: 24),
          _buildNameSection(theme),
          const SizedBox(height: 24),
          _buildGroupSection(theme),
          const SizedBox(height: 24),
          _buildColorSection(theme),
          if (_error != null) ...[
            const SizedBox(height: 20),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.alert,
              ),
            ),
          ],
          const SizedBox(height: 28),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildTypeSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de categoria',
          style: theme.textTheme.labelLarge?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            CategoryChip(
              label: 'Receita',
              selected: _type == 'INCOME',
              onTap: () => _updateType('INCOME'),
            ),
            CategoryChip(
              label: 'Despesa',
              selected: _type == 'EXPENSE',
              onTap: () => _updateType('EXPENSE'),
            ),
            CategoryChip(
              label: 'Dívida',
              selected: _type == 'DEBT',
              onTap: () => _updateType('DEBT'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNameSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nome',
          style: theme.textTheme.labelLarge?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          validator: _validateName,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Ex.: Poupança Nubank',
          ),
        ),
      ],
    );
  }

  Widget _buildGroupSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Finalidade',
          style: theme.textTheme.labelLarge?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: CategoryGroupMetadata.groupsForType(_type).map((value) {
            return CategoryChip(
              label: CategoryGroupMetadata.labels[value] ?? value,
              selected: _group == value,
              onTap: () => _updateGroup(value),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildColorSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cor',
          style: theme.textTheme.labelLarge?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _swatches.map((color) {
            final isSelected = color == _selectedColor;
            return GestureDetector(
              onTap: () => _updateColor(color),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: isSelected ? Colors.white : color.withOpacity(0.6),
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submitting ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _submitting
            ? const SizedBox(
                key: ValueKey('category-loading'),
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Salvar categoria',
                key: ValueKey('category-label'),
              ),
      ),
    );
  }
}
