import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/service_proof_api.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/service_catalog.dart';
import '../../core/providers/session_provider.dart';
import 'visits_controller.dart';

final visitServiceTypesProvider = FutureProvider<List<String>>((ref) async {
  final api = ref.watch(serviceProofApiProvider);
  final token = ref.watch(sessionProvider).token;
  if (api == null || token == null || token.isEmpty) {
    return serviceTypeIds;
  }
  try {
    final company = await api.getCompanyMe(authToken: token);
    if (company.servicesOffered.isNotEmpty) {
      return company.servicesOffered;
    }
  } catch (_) {
    // Fall back to default catalog if company data is unavailable.
  }
  return serviceTypeIds;
});

class NewVisitScreen extends ConsumerStatefulWidget {
  const NewVisitScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  ConsumerState<NewVisitScreen> createState() => _NewVisitScreenState();
}

class _NewVisitScreenState extends ConsumerState<NewVisitScreen> {
  final _noteController = TextEditingController();
  final _picker = ImagePicker();
  final _photos = <XFile>[];
  String? _selectedServiceType;
  final Set<String> _selectedChecklistItems = <String>{};
  bool _submitting = false;
  bool _sendVisitEmail = true;
  String? _photoError;
  String? _serviceError;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _picker.pickMultiImage();
      if (picked.isEmpty) {
        return;
      }
      setState(() {
        _photos.addAll(picked);
        _photoError = null;
      });
    } on PlatformException {
      setState(() {
        _photoError = AppLocalizations.of(context).permissionDeniedLibrary;
      });
    } catch (_) {
      setState(() {
        _photoError = AppLocalizations.of(context).couldNotPickImages;
      });
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.camera);
      if (picked == null) {
        return;
      }
      setState(() {
        _photos.add(picked);
        _photoError = null;
      });
    } on PlatformException {
      setState(() {
        _photoError = AppLocalizations.of(context).permissionDeniedCamera;
      });
    } catch (_) {
      setState(() {
        _photoError = AppLocalizations.of(context).couldNotOpenCamera;
      });
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final session = ref.read(sessionProvider);
    final workerName = session.userName ?? l10n.workerFallback;
    final selectedServiceType = _selectedServiceType;
    if (selectedServiceType == null || selectedServiceType.isEmpty) {
      setState(() {
        _serviceError = l10n.visitServiceTypeRequired;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _serviceError = null;
    });
    try {
      await ref.read(visitsControllerProvider).submitVisit(
            propertyId: widget.propertyId,
            workerName: workerName,
            note: _noteController.text.trim(),
            serviceType: selectedServiceType,
            serviceChecklist: _selectedChecklistItems.toList(),
            photos: _photos,
            sendEmailUpdate: _sendVisitEmail,
          );
      if (!mounted) {
        return;
      }
      context.go('/properties/${widget.propertyId}/timeline');
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.networkFailureRetry)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Widget _buildPhotoPreview(XFile item) {
    return FutureBuilder<Uint8List>(
      future: item.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 92,
            height: 92,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return Container(
            width: 92,
            height: 92,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          );
        }
        return Image.memory(
          bytes,
          width: 92,
          height: 92,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final serviceTypesAsync = ref.watch(visitServiceTypesProvider);
    final serviceTypes = serviceTypesAsync.when(
      data: (items) => items,
      loading: () => serviceTypeIds,
      error: (_, __) => serviceTypeIds,
    );
    final selectedServiceType = _selectedServiceType;
    final checklistItems = selectedServiceType == null
        ? const <String>[]
        : (serviceChecklistByType[selectedServiceType] ?? const <String>[]);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newVisitTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _noteController,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: l10n.visitNoteLabel,
              hintText: l10n.visitNoteHint,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: selectedServiceType != null && serviceTypes.contains(selectedServiceType)
                ? selectedServiceType
                : null,
            items: serviceTypes
                .map(
                  (serviceType) => DropdownMenuItem<String>(
                    value: serviceType,
                    child: Text(l10n.serviceTypeLabel(serviceType)),
                  ),
                )
                .toList(),
            onChanged: _submitting
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedServiceType = value;
                      _selectedChecklistItems.clear();
                      _serviceError = null;
                    });
                  },
            decoration: InputDecoration(
              labelText: l10n.visitServiceTypeLabel,
            ),
          ),
          if (_serviceError != null) ...[
            const SizedBox(height: 8),
            Text(
              _serviceError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Text(l10n.serviceChecklistTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          if (checklistItems.isEmpty)
            Text(
              l10n.selectServiceToLoadChecklist,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ...checklistItems.map(
              (itemId) => CheckboxListTile(
                value: _selectedChecklistItems.contains(itemId),
                onChanged: (value) {
                  setState(() {
                    if (value ?? false) {
                      _selectedChecklistItems.add(itemId);
                    } else {
                      _selectedChecklistItems.remove(itemId);
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.serviceChecklistItemLabel(itemId)),
              ),
            ),
          const SizedBox(height: 4),
          SwitchListTile(
            value: _sendVisitEmail,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.sendVisitEmailToggle),
            subtitle: Text(l10n.sendVisitEmailHelp),
            onChanged: (value) {
              setState(() {
                _sendVisitEmail = value;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(l10n.photos, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: Text(l10n.gallery),
              ),
              OutlinedButton.icon(
                onPressed: _pickFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: Text(l10n.camera),
              ),
            ],
          ),
          if (_photoError != null) ...[
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                title: Text(_photoError!),
                trailing: TextButton(
                  onPressed: _pickFromGallery,
                  child: Text(l10n.retry),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (_photos.isEmpty)
            Text(l10n.noPhotosSelected)
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final item = _photos[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildPhotoPreview(item),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: _photos.length,
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.submitVisit),
          ),
        ],
      ),
    );
  }
}
