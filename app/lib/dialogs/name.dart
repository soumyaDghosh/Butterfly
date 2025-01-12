import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class NameDialog extends StatelessWidget {
  final GlobalKey<FormState> _formKey = GlobalKey();
  final FormFieldValidator<String> Function(String?)? validator;
  final String? value;

  NameDialog({
    super.key,
    this.validator,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController(text: value);
    void submit() {
      if (_formKey.currentState!.validate()) {
        Navigator.of(context).pop(nameController.text);
      }
    }

    return Form(
      key: _formKey,
      child: AlertDialog(
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context).cancel)),
          ElevatedButton(
              onPressed: submit,
              child: Text(AppLocalizations.of(context).create)),
        ],
        title: Text(AppLocalizations.of(context).enterName),
        content: TextFormField(
          decoration: InputDecoration(
            filled: true,
            hintText: AppLocalizations.of(context).name,
          ),
          autofocus: true,
          controller: nameController,
          validator: validator?.call(value),
          onFieldSubmitted: (value) => submit(),
        ),
      ),
    );
  }
}

FormFieldValidator<String> Function(String?) defaultNameValidator(
    BuildContext context, List<String> existingNames) {
  return (currentName) => (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context).shouldNotEmpty;
        }
        if (value == currentName) return null;
        if (existingNames.contains(value)) {
          return AppLocalizations.of(context).alreadyExists;
        }
        return null;
      };
}
