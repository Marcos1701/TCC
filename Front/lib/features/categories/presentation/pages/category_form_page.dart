import 'package:flutter/material.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/category_form_model.dart';
import 'color_picker_dialog.dart';

class CategoryFormPage extends StatefulWidget {
  final Map<String, dynamic>? category; // null = create new
  final String initialType; // 'INCOME' or 'EXPENSE'

  const CategoryFormPage({
    super.key,
    this.category,
    this.initialType = 'EXPENSE',
  });

  @override
  State<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends State<CategoryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _repository = FinanceRepository();
  
  late CategoryFormModel _formData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _formData = widget.category != null
        ? CategoryFormModel.fromCategory(widget.category!)
        : CategoryFormModel.empty(widget.initialType);
    
    _nameController.text = _formData.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedForm = _formData.copyWith(name: _nameController.text);

      if (widget.category == null) {
        // Create new
        await _repository.createCategory(
          name: updatedForm.name,
          type: updatedForm.type,
          color: updatedForm.color,
          group: updatedForm.group,
        );
      } else {
        // Update existing
        await _repository.updateCategory(
          id: updatedForm.id!,
          name: updatedForm.name,
          type: updatedForm.type,
          color: updatedForm.color,
          group: updatedForm.group,
        );
      }

      if (mounted) {
        Navigator.pop(context, true); // Returns true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.category == null
                ? 'Categoria criada com sucesso!'
                : 'Categoria atualizada com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: AppColors.alert,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSystemCategory = widget.category != null && 
        (widget.category!['is_system_default'] == true || 
         widget.category!['is_user_created'] == false);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'Nova Categoria' : 'Editar Categoria'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isSystemCategory)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Categoria do sistema - Apenas visualização',
                        style: TextStyle(
                          color: Colors.orange.shade300,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            TextFormField(
              controller: _nameController,
              enabled: !isSystemCategory,
              decoration: InputDecoration(
                labelText: 'Nome',
                border: const OutlineInputBorder(),
                filled: isSystemCategory,
                fillColor: isSystemCategory ? Colors.grey.withOpacity(0.1) : null,
                prefixIcon: isSystemCategory ? const Icon(Icons.lock_outline) : null,
              ),
              validator: (value) => _formData.copyWith(name: value).validateName(),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _formData.type,
              decoration: InputDecoration(
                labelText: 'Tipo',
                border: const OutlineInputBorder(),
                filled: isSystemCategory,
                fillColor: isSystemCategory ? Colors.grey.withOpacity(0.1) : null,
              ),
              items: const [
                DropdownMenuItem(value: 'INCOME', child: Text('Receita')),
                DropdownMenuItem(value: 'EXPENSE', child: Text('Despesa')),
              ],
              onChanged: isSystemCategory ? null : (value) {
                if (value != null) {
                  setState(() {
                    _formData = _formData.copyWith(type: value);
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            
            ListTile(
              title: const Text('Cor'),
              enabled: !isSystemCategory,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(int.parse(_formData.color.substring(1), radix: 16) + 0xFF000000),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: isSystemCategory ? Colors.grey : null,
                  ),
                ],
              ),
              onTap: isSystemCategory ? null : () {
                showDialog(
                  context: context,
                  builder: (context) => ColorPickerDialog(
                    initialColor: _formData.color,
                    onColorSelected: (color) {
                      setState(() {
                        _formData = _formData.copyWith(color: color);
                      });
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            
            if (!isSystemCategory)
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(widget.category == null ? 'Criar' : 'Salvar'),
              ),
          ],
        ),
      ),
    );
  }
}
