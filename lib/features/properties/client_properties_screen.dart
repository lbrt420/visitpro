import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/property.dart';
import '../../core/providers/session_provider.dart';
import '../../core/ui/widgets/app_brand_header.dart';
import '../../core/ui/widgets/async_state_view.dart';
import 'properties_controller.dart';

class ClientPropertiesScreen extends ConsumerWidget {
  const ClientPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final properties = ref.watch(propertiesProvider);
    final session = ref.watch(sessionProvider);

    return Scaffold(
      body: AsyncStateView<List<Property>>(
        value: properties,
        onRetry: () => ref.invalidate(propertiesProvider),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.noAssignedPropertiesYet,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 100),
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const AppBrandHeader(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                );
              }
              final item = items[index - 1];
              final visibleAccounts = item.assignedClientAccounts.where((account) {
                if (session.userId != null && session.userId!.isNotEmpty) {
                  return account.id != session.userId;
                }
                if (session.userName != null && session.userName!.isNotEmpty) {
                  return account.name.toLowerCase() != session.userName!.toLowerCase();
                }
                return true;
              }).toList();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Tooltip(
                            message: l10n.inviteSomeoneFeed,
                            child: IconButton.filledTonal(
                              onPressed: () => _showInviteViewerDialog(
                                context: context,
                                ref: ref,
                                propertyId: item.id,
                              ),
                              icon: const Icon(Icons.person_add_alt_1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(item.address),
                      const SizedBox(height: 12),
                      Text(
                        l10n.assignedAccountsTitle,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      if (visibleAccounts.isEmpty)
                        Text(
                          l10n.noOtherAssignedAccounts,
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: visibleAccounts
                              .map(
                                (account) => InputChip(
                                  avatar: const Icon(Icons.person, size: 16),
                                  label: Text(
                                    account.name.isEmpty
                                        ? account.email
                                        : '${account.name} (${account.email})',
                                  ),
                                  deleteIcon: const Icon(Icons.close),
                                  onDeleted: () => _confirmRemoveAssignedClient(
                                    context: context,
                                    ref: ref,
                                    propertyId: item.id,
                                    account: account,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
          );
        },
      ),
    );
  }

  Future<void> _showInviteViewerDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String propertyId,
  }) async {
    final l10n = AppLocalizations.of(context);
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? inlineError;
    bool submitting = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(l10n.inviteViewer),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: l10n.emailLabel),
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return l10n.emailRequiredError;
                        }
                        return null;
                      },
                    ),
                    if (inlineError != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          inlineError!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setDialogState(() {
                            submitting = true;
                            inlineError = null;
                          });
                          try {
                            await ref.read(propertiesControllerProvider).inviteClient(
                                  propertyId: propertyId,
                                  email: emailController.text.trim(),
                                );
                            if (!dialogContext.mounted) {
                              return;
                            }
                            Navigator.of(dialogContext).pop(true);
                          } catch (error) {
                            final message = error.toString().replaceFirst('Exception: ', '').trim();
                            setDialogState(() {
                              submitting = false;
                              inlineError =
                                  message.isEmpty ? l10n.somethingWentWrong : message;
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.sendInvite),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.viewerInviteSent)),
    );
  }

  Future<void> _confirmRemoveAssignedClient({
    required BuildContext context,
    required WidgetRef ref,
    required String propertyId,
    required AssignedClientAccount account,
  }) async {
    final l10n = AppLocalizations.of(context);
    final nameOrEmail = account.name.isEmpty ? account.email : account.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.removeAccess),
          content: Text(l10n.removeAccessPrompt(nameOrEmail)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.remove),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    await ref.read(propertiesControllerProvider).removeClientFromProperty(
          propertyId: propertyId,
          clientUserId: account.id,
        );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.removedFromProperty)),
    );
  }
}
