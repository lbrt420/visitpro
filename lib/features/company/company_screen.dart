import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/service_proof_api.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/service_catalog.dart';
import '../../core/providers/session_provider.dart';
import '../../core/ui/widgets/app_brand_header.dart';
import '../properties/properties_controller.dart';

final companyInfoProvider = FutureProvider<CompanyInfo?>((ref) async {
  final session = ref.watch(sessionProvider);
  final api = ref.watch(serviceProofApiProvider);
  final token = session.token;
  if (session.role == UserRole.client || api == null || token == null || token.isEmpty) {
    return null;
  }
  return api.getCompanyMe(authToken: token);
});

final companyTeamProvider = FutureProvider<List<CompanyTeamMember>>((ref) async {
  final session = ref.watch(sessionProvider);
  final api = ref.watch(serviceProofApiProvider);
  final token = session.token;
  if (session.role == UserRole.client || api == null || token == null || token.isEmpty) {
    return const <CompanyTeamMember>[];
  }
  return api.getCompanyTeam(authToken: token);
});

class CompanyController {
  CompanyController(this.ref);

  final Ref ref;

  Future<void> updateCompanyProfile({
    required String name,
    required String address,
    required String orgNumber,
    required String taxId,
    required List<String> servicesOffered,
  }) async {
    final api = ref.read(serviceProofApiProvider);
    final token = ref.read(sessionProvider).token;
    if (api == null || token == null || token.isEmpty) {
      throw Exception('API is not configured.');
    }
    await api.updateCompany(
      authToken: token,
      name: name,
      address: address,
      orgNumber: orgNumber,
      taxId: taxId,
      servicesOffered: servicesOffered,
    );
    ref.invalidate(companyInfoProvider);
    ref.invalidate(propertiesProvider);
  }

  Future<void> updateCompanyServices({
    required List<String> servicesOffered,
  }) async {
    final api = ref.read(serviceProofApiProvider);
    final token = ref.read(sessionProvider).token;
    if (api == null || token == null || token.isEmpty) {
      throw Exception('API is not configured.');
    }
    await api.updateCompany(
      authToken: token,
      servicesOffered: servicesOffered,
    );
    ref.invalidate(companyInfoProvider);
    ref.invalidate(propertiesProvider);
  }

  Future<void> updateMemberAccess({
    required String userId,
    required CompanyAccessLevel accessLevel,
  }) async {
    final api = ref.read(serviceProofApiProvider);
    final token = ref.read(sessionProvider).token;
    if (api == null || token == null || token.isEmpty) {
      throw Exception('API is not configured.');
    }
    await api.updateCompanyTeamAccessLevel(
      authToken: token,
      userId: userId,
      accessLevel: accessLevel,
    );
    ref.invalidate(companyTeamProvider);
  }

  Future<void> inviteWorkerToTeam({
    required String email,
    String? name,
  }) async {
    final api = ref.read(serviceProofApiProvider);
    final token = ref.read(sessionProvider).token;
    if (api == null || token == null || token.isEmpty) {
      throw Exception('API is not configured.');
    }
    await api.inviteCompanyWorker(
      authToken: token,
      email: email,
      name: name,
    );
    ref.invalidate(companyTeamProvider);
  }

  Future<void> removeTeamMember({
    required String userId,
  }) async {
    final api = ref.read(serviceProofApiProvider);
    final token = ref.read(sessionProvider).token;
    if (api == null || token == null || token.isEmpty) {
      throw Exception('API is not configured.');
    }
    await api.removeCompanyTeamMember(authToken: token, userId: userId);
    ref.invalidate(companyTeamProvider);
  }

  Future<void> uploadCompanyLogo({
    required XFile file,
  }) async {
    final api = ref.read(serviceProofApiProvider);
    final token = ref.read(sessionProvider).token;
    if (api == null || token == null || token.isEmpty) {
      throw Exception('API is not configured.');
    }

    final sign = await api.signUpload(
      authToken: token,
      fileName: file.name,
      contentType: _contentTypeFromFileName(file.name),
    );
    final uploadURL = (sign['uploadURL'] as String?) ?? '';
    final publicUrl = (sign['publicUrl'] as String?) ?? '';
    if (uploadURL.isEmpty || publicUrl.isEmpty) {
      throw Exception('Could not start image upload.');
    }

    final bytes = await file.readAsBytes();
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: file.name,
      ),
    });
    await Dio().post(uploadURL, data: form);

    await api.updateCompany(
      authToken: token,
      logoUrl: publicUrl,
    );
    final verify = await api.getCompanyMe(authToken: token);
    if (verify.logoUrl.trim().isEmpty) {
      throw Exception('Company logo was not saved.');
    }
    ref.invalidate(companyInfoProvider);
    ref.invalidate(propertiesProvider);
  }

  String _contentTypeFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    return 'image/jpeg';
  }
}

final companyControllerProvider = Provider<CompanyController>((ref) {
  return CompanyController(ref);
});

class CompanyScreen extends ConsumerStatefulWidget {
  const CompanyScreen({
    super.key,
    this.initialTab = 0,
  });

  final int initialTab;

  @override
  ConsumerState<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends ConsumerState<CompanyScreen> {
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _orgNumberController = TextEditingController();
  final _taxIdController = TextEditingController();
  bool _editingOverview = false;
  bool _savingOverview = false;
  bool _editingServices = false;
  bool _savingServices = false;
  bool _invitingWorker = false;
  bool _uploadingLogo = false;
  bool _openingBillingPortal = false;
  final Set<String> _selectedServices = <String>{};

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _orgNumberController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final company = ref.watch(companyInfoProvider);
    final team = ref.watch(companyTeamProvider);
    final isOwnerRole = session.role == UserRole.owner;
    final canManageAdmins = isOwnerRole || session.companyAccessLevel == CompanyAccessLevel.owner;
    final canEditCompany = isOwnerRole ||
        session.companyAccessLevel == CompanyAccessLevel.owner ||
        session.companyAccessLevel == CompanyAccessLevel.admin;
    final myUserId = session.userId ?? '';

    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTab.clamp(0, 3).toInt(),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          toolbarHeight: 60,
          title: const AppBrandHeader(
            useSafeArea: false,
            padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      Text(
                        l10n.company,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  tabs: [
                    Tab(text: l10n.companyOverviewTab),
                    Tab(text: l10n.companyServicesTab),
                    Tab(text: l10n.companyTeamTab),
                    Tab(text: l10n.companySubscriptionTab),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: company.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(l10n.somethingWentWrong)),
                data: (info) {
                  if (info == null) {
                    return Center(child: Text(l10n.somethingWentWrong));
                  }
                  if (!_editingOverview) {
                    _companyNameController.text = info.name;
                    _companyAddressController.text = info.address;
                    _orgNumberController.text = info.orgNumber;
                    _taxIdController.text = info.taxId;
                  }
                  return ListView(
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 68,
                              height: 68,
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: (info.logoUrl.isNotEmpty && info.logoUrl.startsWith('http'))
                                  ? Image.network(
                                      info.logoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.business_outlined,
                                        size: 28,
                                      ),
                                    )
                                  : const Icon(Icons.business_outlined, size: 28),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: canEditCompany && !_uploadingLogo
                                  ? () => _showLogoSourcePicker(context)
                                  : null,
                              icon: _uploadingLogo
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.upload_outlined),
                              label: Text(l10n.uploadCompanyLogo),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _companyNameController,
                        enabled: canEditCompany && _editingOverview && !_savingOverview,
                        decoration: InputDecoration(
                          labelText: l10n.companyNameLabel,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _companyAddressController,
                        enabled: canEditCompany && _editingOverview && !_savingOverview,
                        decoration: InputDecoration(
                          labelText: l10n.companyAddressLabel,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _orgNumberController,
                        enabled: canEditCompany && _editingOverview && !_savingOverview,
                        decoration: InputDecoration(
                          labelText: l10n.orgNumberLabel,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _taxIdController,
                        enabled: canEditCompany && _editingOverview && !_savingOverview,
                        decoration: InputDecoration(
                          labelText: l10n.taxIdLabel,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (canEditCompany && !_editingOverview)
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _editingOverview = true;
                            });
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(l10n.companyOverviewTab),
                        ),
                      if (canEditCompany && _editingOverview)
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _savingOverview
                                    ? null
                                    : () => _saveCompanyOverview(context, info: info),
                                child: _savingOverview
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(l10n.saveCompany),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: _savingOverview
                                  ? null
                                  : () {
                                      setState(() {
                                        _editingOverview = false;
                                        _companyNameController.text = info.name;
                                        _companyAddressController.text = info.address;
                                        _orgNumberController.text = info.orgNumber;
                                        _taxIdController.text = info.taxId;
                                      });
                                    },
                              child: Text(l10n.cancel),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: company.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(l10n.somethingWentWrong)),
                data: (info) {
                  if (info == null) {
                    return Center(child: Text(l10n.somethingWentWrong));
                  }
                  if (!_editingServices) {
                    _selectedServices
                      ..clear()
                      ..addAll(info.servicesOffered);
                  }
                  return ListView(
                    children: [
                      Text(
                        l10n.companyServicesLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: serviceTypeIds
                            .map(
                              (serviceType) => FilterChip(
                                label: Text(l10n.serviceTypeLabel(serviceType)),
                                selected: _selectedServices.contains(serviceType),
                                onSelected: canEditCompany && _editingServices && !_savingServices
                                    ? (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedServices.add(serviceType);
                                          } else {
                                            _selectedServices.remove(serviceType);
                                          }
                                        });
                                      }
                                    : null,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      if (canEditCompany && !_editingServices)
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _editingServices = true;
                            });
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(l10n.companyServicesTab),
                        ),
                      if (canEditCompany && _editingServices)
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _savingServices
                                    ? null
                                    : () => _saveCompanyServices(context, info: info),
                                child: _savingServices
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(l10n.saveCompany),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: _savingServices
                                  ? null
                                  : () {
                                      setState(() {
                                        _editingServices = false;
                                        _selectedServices
                                          ..clear()
                                          ..addAll(info.servicesOffered);
                                      });
                                    },
                              child: Text(l10n.cancel),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: team.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(l10n.somethingWentWrong)),
                data: (members) {
                  return Column(
                    children: [
                      if (canEditCompany)
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _invitingWorker ? null : () => _showInviteWorkerSheet(context),
                            icon: _invitingWorker
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.person_add_alt_1_outlined),
                            label: Text(l10n.inviteWorker),
                          ),
                        ),
                      if (canEditCompany) const SizedBox(height: 12),
                      Expanded(
                        child: members.isEmpty
                            ? Center(
                                child: Text(l10n.noTeamMembersYet),
                              )
                            : ListView.separated(
                                itemCount: members.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final member = members[index];
                                  final isOwner =
                                      member.companyAccessLevel == CompanyAccessLevel.owner;
                                  final isAdmin = member.companyAccessLevel == CompanyAccessLevel.admin;
                                  final isMe = myUserId.isNotEmpty && member.id == myUserId;
                                  final displayName = member.name.isEmpty ? member.email : member.name;
                                  return Card(
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        child: Text(
                                          member.name.isEmpty
                                              ? '?'
                                              : member.name.substring(0, 1).toUpperCase(),
                                        ),
                                      ),
                                      title: Text(
                                        isMe ? '$displayName ${l10n.youSuffix}' : displayName,
                                      ),
                                      subtitle: Text(
                                        '${member.email}\n${_accessLevelText(l10n, member.companyAccessLevel)}',
                                      ),
                                      isThreeLine: true,
                                      trailing: isOwner || member.role != 'worker' || isMe || !canEditCompany
                                          ? null
                                          : PopupMenuButton<String>(
                                              tooltip: l10n.manageTeamMember,
                                              onSelected: (value) async {
                                                if (value == 'toggle_admin') {
                                                  await _toggleAdmin(
                                                    context,
                                                    member: member,
                                                    promote: !isAdmin,
                                                  );
                                                  return;
                                                }
                                                if (value == 'remove_worker') {
                                                  await _removeWorker(context, member: member);
                                                }
                                              },
                                              itemBuilder: (context) {
                                                final items = <PopupMenuEntry<String>>[];
                                                if (canManageAdmins) {
                                                  items.add(
                                                    PopupMenuItem<String>(
                                                      value: 'toggle_admin',
                                                      child: Text(
                                                        isAdmin ? l10n.makeEmployee : l10n.makeAdmin,
                                                      ),
                                                    ),
                                                  );
                                                }
                                                if (canEditCompany) {
                                                  items.add(
                                                    PopupMenuItem<String>(
                                                      value: 'remove_worker',
                                                      child: Text(l10n.removeWorker),
                                                    ),
                                                  );
                                                }
                                                return items;
                                              },
                                              icon: const Icon(Icons.more_horiz),
                                            ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: company.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(l10n.somethingWentWrong)),
                data: (info) {
                  if (info == null) {
                    return Center(child: Text(l10n.somethingWentWrong));
                  }
                  final plan = info.billingPlan.isEmpty
                      ? l10n.onboardingPlanGrowth
                      : info.billingPlan[0].toUpperCase() + info.billingPlan.substring(1);
                  final limitLabel = info.propertiesLimit == null
                      ? l10n.companyPropertyLimitUnlimited
                      : l10n.companyPropertyLimitCount(info.propertiesLimit!);
                  final usedOverLimitLabel = info.propertiesLimit == null
                      ? '${info.propertiesUsed}/${l10n.companyPropertyLimitUnlimited}'
                      : '${info.propertiesUsed}/${info.propertiesLimit}';
                  return ListView(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.companySubscriptionOverview,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text('${l10n.companyCurrentPlan}: $plan'),
                              const SizedBox(height: 6),
                              Text('${l10n.companyPropertyLimitLabel}: $limitLabel'),
                              const SizedBox(height: 6),
                              Text('${l10n.companyPropertiesUsedLabel}: $usedOverLimitLabel'),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: _openingBillingPortal
                                    ? null
                                    : () => _openBillingPortal(context),
                                icon: _openingBillingPortal
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.upgrade),
                                label: Text(l10n.upgradeNow),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _accessLevelText(AppLocalizations l10n, CompanyAccessLevel level) {
    return switch (level) {
      CompanyAccessLevel.owner => l10n.accessLevelOwner,
      CompanyAccessLevel.admin => l10n.accessLevelAdmin,
      CompanyAccessLevel.member => l10n.accessLevelMember,
    };
  }

  Future<void> _saveCompanyOverview(
    BuildContext context, {
    required CompanyInfo info,
  }) async {
    final l10n = AppLocalizations.of(context);
    final nextName = _companyNameController.text.trim();
    final nextAddress = _companyAddressController.text.trim();
    final nextOrg = _orgNumberController.text.trim();
    final nextTax = _taxIdController.text.trim();
    final nextServices = _selectedServices.toList();
    if (nextName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.requiredField)),
      );
      return;
    }
    final unchanged = nextName == info.name &&
        nextAddress == info.address &&
        nextOrg == info.orgNumber &&
        nextTax == info.taxId &&
        _sameServices(nextServices, info.servicesOffered);
    if (unchanged) {
      setState(() {
        _editingOverview = false;
      });
      return;
    }
    setState(() {
      _savingOverview = true;
    });
    try {
      await ref.read(companyControllerProvider).updateCompanyProfile(
            name: nextName,
            address: nextAddress,
            orgNumber: nextOrg,
            taxId: nextTax,
            servicesOffered: nextServices,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _editingOverview = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.companyUpdated)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingOverview = false;
        });
      }
    }
  }

  bool _sameServices(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    final aa = [...a]..sort();
    final bb = [...b]..sort();
    for (var i = 0; i < aa.length; i += 1) {
      if (aa[i] != bb[i]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _saveCompanyServices(
    BuildContext context, {
    required CompanyInfo info,
  }) async {
    final l10n = AppLocalizations.of(context);
    final nextServices = _selectedServices.toList();
    if (_sameServices(nextServices, info.servicesOffered)) {
      setState(() {
        _editingServices = false;
      });
      return;
    }
    setState(() {
      _savingServices = true;
    });
    try {
      await ref.read(companyControllerProvider).updateCompanyServices(
            servicesOffered: nextServices,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _editingServices = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.companyUpdated)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingServices = false;
        });
      }
    }
  }

  Future<void> _showInviteWorkerSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    bool submitting = false;
    String? inlineError;
    await showDialog<void>(
      context: context,
      builder: (dialogRootContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(l10n.inviteWorkerToTeam),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.inviteWorkerToTeamHelp,
                        style: Theme.of(dialogContext).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: l10n.emailLabel,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: l10n.firstNameLabel,
                        ),
                      ),
                      if (inlineError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          inlineError!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          final name = nameController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            setDialogState(() {
                              inlineError = l10n.emailRequiredError;
                            });
                            return;
                          }
                          setDialogState(() {
                            submitting = true;
                            inlineError = null;
                          });
                          setState(() {
                            _invitingWorker = true;
                          });
                          try {
                            await ref.read(companyControllerProvider).inviteWorkerToTeam(
                                  email: email,
                                  name: name.isEmpty ? null : name,
                                );
                            if (!dialogContext.mounted) {
                              return;
                            }
                            Navigator.of(dialogContext).pop();
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.workerInvitedToTeam)),
                            );
                          } catch (error) {
                            setDialogState(() {
                              submitting = false;
                              inlineError = _inviteWorkerErrorMessage(error, l10n);
                            });
                          } finally {
                            if (mounted) {
                              setState(() {
                                _invitingWorker = false;
                              });
                            }
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
    emailController.dispose();
    nameController.dispose();
  }

  Future<void> _showLogoSourcePicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.gallery),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickCompanyLogo(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l10n.camera),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickCompanyLogo(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickCompanyLogo(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 90,
      );
      if (file == null) {
        return;
      }
      setState(() {
        _uploadingLogo = true;
      });
      await ref.read(companyControllerProvider).uploadCompanyLogo(file: file);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.companyLogoUpdated)),
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
    } finally {
      if (mounted) {
        setState(() {
          _uploadingLogo = false;
        });
      }
    }
  }

  String _inviteWorkerErrorMessage(Object error, AppLocalizations l10n) {
    final message = error.toString().replaceAll('Exception: ', '').trim();
    final lower = message.toLowerCase();
    if (lower.contains('employee account limit reached')) {
      return l10n.employeeAccountsLimitReached;
    }
    if (lower.contains('already used by an account in another company') ||
        lower.contains('belongs to a different company')) {
      return l10n.emailBelongsToAnotherCompany;
    }
    if (lower.contains('non-worker role') || lower.contains('incompatible account role')) {
      return l10n.accountExistsWithDifferentRole;
    }
    return message.isEmpty ? l10n.somethingWentWrong : message;
  }

  Future<void> _openBillingPortal(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final api = ref.read(serviceProofApiProvider);
    final token = ref.read(sessionProvider).token;
    if (api == null || token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.apiNotConfigured)),
      );
      return;
    }
    setState(() {
      _openingBillingPortal = true;
    });
    try {
      final base = Uri.base;
      final returnUrl = (base.scheme == 'http' || base.scheme == 'https')
          ? '${base.origin}/#/company?tab=3'
          : 'visitpro://app/company?tab=3';
      final portalUrl = await api.createBillingPortalSession(
        authToken: token,
        returnUrl: returnUrl,
      );
      if (portalUrl.isEmpty) {
        throw Exception(l10n.somethingWentWrong);
      }
      final opened = await launchUrl(
        Uri.parse(portalUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.somethingWentWrong)),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingBillingPortal = false;
        });
      }
    }
  }

  Future<void> _toggleAdmin(
    BuildContext context, {
    required CompanyTeamMember member,
    required bool promote,
  }) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(companyControllerProvider).updateMemberAccess(
            userId: member.id,
            accessLevel: promote ? CompanyAccessLevel.admin : CompanyAccessLevel.member,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(promote ? l10n.adminGranted : l10n.adminRevoked),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _removeWorker(
    BuildContext context, {
    required CompanyTeamMember member,
  }) async {
    final l10n = AppLocalizations.of(context);
    final label = member.name.isEmpty ? member.email : member.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.removeWorker),
          content: Text(l10n.removeWorkerPrompt(label)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.remove),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(companyControllerProvider).removeTeamMember(userId: member.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.workerRemovedFromTeam)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    }
  }
}
