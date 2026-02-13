import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../company/company_screen.dart';
import 'properties_controller.dart';

class PropertyFormScreen extends ConsumerStatefulWidget {
  const PropertyFormScreen({super.key});

  @override
  ConsumerState<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends ConsumerState<PropertyFormScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _clientEmailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _clientEmailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _submitting = true;
    });
    try {
      await ref.read(propertiesControllerProvider).createProperty(
            name: _nameController.text.trim(),
            address: _addressController.text.trim(),
            clientEmail: _clientEmailController.text.trim(),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
      });
      context.go('/home');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
      });
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.isEmpty ? l10n.somethingWentWrong : message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final companyInfo = ref.watch(companyInfoProvider).value;
    final canCreateProperty = companyInfo?.canCreateProperty ?? true;
    if (!canCreateProperty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.createPropertyTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.propertiesLimitReached,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => context.go('/company?tab=3'),
                  child: Text(l10n.upgradeNow),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/properties'),
                  child: Text(l10n.properties),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createPropertyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: l10n.propertyNameLabel),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.requiredField;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(labelText: l10n.addressLabel),
                  minLines: 2,
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.requiredField;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _clientEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.clientEmailOptionalRecommended,
                    hintText: l10n.emailHint,
                  ),
                  validator: (value) {
                    final email = (value ?? '').trim();
                    if (email.isEmpty) {
                      return null;
                    }
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(email)) {
                      return l10n.emailRequiredError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.createPropertyClientEmailHelp,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.saveProperty),
          ),
        ],
      ),
    );
  }
}
