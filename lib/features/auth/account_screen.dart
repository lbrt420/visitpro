import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/providers/session_provider.dart';
import '../../core/ui/widgets/app_brand_header.dart';
import '../../core/ui/widgets/language_debug_tile.dart';
import 'profile_controller.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _firstNameController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _firstNameExpanded = false;
  bool _passwordExpanded = false;
  bool _savingFirstName = false;
  bool _savingPassword = false;
  String? _firstNameError;
  String? _passwordError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final profileAsync = ref.watch(myProfileProvider);

    final profile = profileAsync.value;
    final currentFirstName = profile?.username.isNotEmpty == true
        ? profile!.username
        : (session.userName ?? l10n.unknownUser);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppBrandHeader(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
          ),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundImage: (profile?.avatarUrl.isNotEmpty ?? false)
                      ? NetworkImage(profile!.avatarUrl)
                      : null,
                  child: (profile?.avatarUrl.isNotEmpty ?? false)
                      ? null
                      : const Icon(Icons.account_circle_outlined, size: 44),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () => _showAvatarOptions(context),
                      icon: const Icon(Icons.camera_alt_outlined),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              currentFirstName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              l10n.roleLabel(session.role?.name ?? 'unknown'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(l10n.firstNameLabel),
                  subtitle: Text(currentFirstName),
                  trailing: Icon(
                    _firstNameExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.chevron_right,
                  ),
                  onTap: () => _toggleFirstNameEditor(currentFirstName),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  crossFadeState: _firstNameExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        TextField(
                          controller: _firstNameController,
                          decoration: InputDecoration(labelText: l10n.firstNameLabel),
                        ),
                        if (_firstNameError != null) ...[
                          const SizedBox(height: 8),
                          _InlineErrorMessage(message: _firstNameError!),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: _savingFirstName
                                ? null
                                : () => _saveFirstNameInline(context),
                            child: _savingFirstName
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(l10n.saveProfile),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(l10n.passwordSettings),
                  trailing: Icon(
                    _passwordExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.chevron_right,
                  ),
                  onTap: _togglePasswordEditor,
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  crossFadeState: _passwordExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        TextField(
                          controller: _oldPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(labelText: l10n.oldPassword),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _newPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(labelText: l10n.newPassword),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(labelText: l10n.confirmNewPassword),
                        ),
                        if (_passwordError != null) ...[
                          const SizedBox(height: 8),
                          _InlineErrorMessage(message: _passwordError!),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonal(
                            onPressed: _savingPassword
                                ? null
                                : () => _changePasswordInline(context),
                            child: _savingPassword
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(l10n.updatePassword),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const LanguageDebugTile(),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () async {
              await ref.read(sessionProvider.notifier).logout();
              if (!context.mounted) {
                return;
              }
              context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: Text(l10n.logout),
          ),
        ],
      ),
    );
  }

  void _toggleFirstNameEditor(String currentFirstName) {
    setState(() {
      _firstNameExpanded = !_firstNameExpanded;
      if (_firstNameExpanded) {
        _firstNameController.text = currentFirstName;
      }
      _passwordExpanded = false;
      _firstNameError = null;
      _passwordError = null;
    });
  }

  void _togglePasswordEditor() {
    setState(() {
      _passwordExpanded = !_passwordExpanded;
      _firstNameExpanded = false;
      if (_passwordExpanded) {
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
      _firstNameError = null;
      _passwordError = null;
    });
  }

  Future<void> _showAvatarOptions(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.gallery),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l10n.camera),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAvatar(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (file == null) {
        return;
      }
      await ref.read(profileControllerProvider).uploadAvatar(file: file);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileUpdated)),
      );
    } on PlatformException {
      if (!mounted) {
        return;
      }
      final message = source == ImageSource.camera
          ? l10n.permissionDeniedCamera
          : l10n.permissionDeniedLibrary;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _saveFirstNameInline(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final next = _firstNameController.text.trim();
    if (next.isEmpty) {
      setState(() {
        _firstNameError = l10n.firstNameRequired;
      });
      return;
    }
    setState(() {
      _savingFirstName = true;
      _firstNameError = null;
    });
    try {
      await ref.read(profileControllerProvider).updateProfile(username: next);
      if (!mounted) {
        return;
      }
      setState(() {
        _firstNameExpanded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileUpdated)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _firstNameError = error.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingFirstName = false;
        });
      }
    }
  }

  Future<void> _changePasswordInline(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    if (_oldPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() {
        _passwordError = l10n.errorRequiredFields;
      });
      return;
    }
    if (_newPasswordController.text.length < 8) {
      setState(() {
        _passwordError = l10n.newPasswordMinLength;
      });
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _passwordError = l10n.passwordConfirmMismatch;
      });
      return;
    }

    setState(() {
      _savingPassword = true;
      _passwordError = null;
    });
    try {
      await ref.read(profileControllerProvider).changePassword(
            oldPassword: _oldPasswordController.text,
            newPassword: _newPasswordController.text,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _passwordExpanded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordUpdated)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _passwordError = error.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingPassword = false;
        });
      }
    }
  }
}

class _InlineErrorMessage extends StatelessWidget {
  const _InlineErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red.shade900,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
