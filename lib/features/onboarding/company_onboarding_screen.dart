import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/service_proof_api.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/service_catalog.dart';
import '../../core/providers/company_onboarding_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/ui/widgets/app_brand_header.dart';
import '../properties/properties_controller.dart';

enum _ClientRange { upto15, upto40, above40 }

enum _PlanTier { starter, growth, pro }

enum _BillingCycle { monthly, yearly }

class CompanyOnboardingScreen extends ConsumerStatefulWidget {
  const CompanyOnboardingScreen({super.key});

  @override
  ConsumerState<CompanyOnboardingScreen> createState() => _CompanyOnboardingScreenState();
}

class _CompanyOnboardingScreenState extends ConsumerState<CompanyOnboardingScreen> {
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _propertyNameController = TextEditingController();
  final _propertyAddressController = TextEditingController();
  final _propertyClientEmailController = TextEditingController();
  final _inviteWorkerEmailController = TextEditingController();
  final _selectedServices = <String>{};

  int _step = 0;
  bool _busy = false;
  String? _errorMessage;
  String? _createdPropertyId;
  _ClientRange? _selectedClientRange;
  _PlanTier? _selectedPlan;
  _BillingCycle _billingCycle = _BillingCycle.yearly;
  String? _lastHandledStripeSessionId;
  bool _handledStripeCancel = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapCompanyData();
    });
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _propertyNameController.dispose();
    _propertyAddressController.dispose();
    _propertyClientEmailController.dispose();
    _inviteWorkerEmailController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapCompanyData() async {
    final onboardingState = ref.read(companyOnboardingProvider);
    final session = ref.read(sessionProvider);
    final api = ref.read(serviceProofApiProvider);
    final token = session.token;
    if (api == null || token == null || token.isEmpty) {
      return;
    }

    try {
      final info = await api.getCompanyMe(authToken: token);
      if (!mounted) {
        return;
      }
      setState(() {
        _step = _stepFromOnboarding(onboardingState);
        _companyNameController.text = info.name;
        _companyAddressController.text = info.address;
        _selectedServices
          ..clear()
          ..addAll(info.servicesOffered.where(serviceTypeIds.contains));
        _createdPropertyId = onboardingState.lastCreatedPropertyId;
      });
    } catch (_) {
      // Keep onboarding usable even if this prefill fails.
    }
  }

  int _stepFromOnboarding(CompanyOnboardingState state) {
    if (state.subscriptionCompleted) {
      return 3;
    }
    if (state.invitesCompleted) {
      return 3;
    }
    if (state.firstPropertyCompleted) {
      return 2;
    }
    if (state.companySetupCompleted) {
      return 1;
    }
    return 0;
  }

  Future<void> _skipCurrentStep() async {
    final onboardingNotifier = ref.read(companyOnboardingProvider.notifier);
    if (_step == 0) {
      await onboardingNotifier.markCompanySetupCompleted();
      if (!mounted) {
        return;
      }
      setState(() {
        _step = 1;
        _errorMessage = null;
      });
      return;
    }
    if (_step == 1) {
      if (!mounted) {
        return;
      }
      setState(() {
        _step = 2;
        _errorMessage = null;
      });
      return;
    }
    if (_step == 2) {
      await onboardingNotifier.markInvitesCompleted();
      if (!mounted) {
        return;
      }
      setState(() {
        _step = 3;
        _errorMessage = null;
      });
    }
  }

  Future<void> _continueFromCompanyStep() async {
    final l10n = AppLocalizations.of(context);
    final session = ref.read(sessionProvider);
    final api = ref.read(serviceProofApiProvider);
    final token = session.token;
    final name = _companyNameController.text.trim();
    final address = _companyAddressController.text.trim();
    if (name.isEmpty || address.isEmpty) {
      setState(() {
        _errorMessage = l10n.errorRequiredFields;
      });
      return;
    }
    if (api == null || token == null || token.isEmpty) {
      setState(() {
        _errorMessage = l10n.apiNotConfigured;
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await api.updateCompany(
        authToken: token,
        name: name,
        address: address,
        servicesOffered: _selectedServices.toList(),
      );
      await ref.read(companyOnboardingProvider.notifier).markCompanySetupCompleted();
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _step = 1;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _errorMessage = l10n.somethingWentWrong;
      });
    }
  }

  Future<void> _continueFromPropertyStep() async {
    final l10n = AppLocalizations.of(context);
    final name = _propertyNameController.text.trim();
    final address = _propertyAddressController.text.trim();
    final clientEmail = _propertyClientEmailController.text.trim();
    if (name.isEmpty || address.isEmpty) {
      setState(() {
        _errorMessage = l10n.errorRequiredFields;
      });
      return;
    }
    if (clientEmail.isNotEmpty) {
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!emailRegex.hasMatch(clientEmail)) {
        setState(() {
          _errorMessage = l10n.emailRequiredError;
        });
        return;
      }
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final created = await ref.read(propertiesControllerProvider).createProperty(
            name: name,
            address: address,
            clientEmail: clientEmail,
          );
      await ref.read(companyOnboardingProvider.notifier).markFirstPropertyCompleted(created.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _createdPropertyId = created.id;
        _step = 2;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _errorMessage = l10n.somethingWentWrong;
      });
    }
  }

  Future<void> _finishOnboarding({required bool sendInvites}) async {
    final l10n = AppLocalizations.of(context);
    final propertyId = _createdPropertyId;
    final hasProperty = propertyId != null && propertyId.isNotEmpty;
    if (!hasProperty && sendInvites) {
      setState(() {
        _errorMessage = l10n.onboardingCreatePropertyFirst;
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      if (sendInvites) {
        final workerEmail = _inviteWorkerEmailController.text.trim();
        final role = ref.read(sessionProvider).role;
        if (hasProperty && workerEmail.isNotEmpty && role == UserRole.owner) {
          await ref.read(propertiesControllerProvider).inviteWorker(
                propertyId: propertyId,
                email: workerEmail,
              );
        }
      }
      await ref.read(companyOnboardingProvider.notifier).markInvitesCompleted();
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _step = 3;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _errorMessage = l10n.somethingWentWrong;
      });
    }
  }

  Future<void> _startTrialAndFinish() async {
    final l10n = AppLocalizations.of(context);
    final range = _selectedClientRange;
    final plan = _selectedPlan;
    if (range == null || plan == null) {
      setState(() {
        _errorMessage = l10n.onboardingSelectClientCountFirst;
      });
      return;
    }
    final session = ref.read(sessionProvider);
    final api = ref.read(serviceProofApiProvider);
    final token = session.token;
    if (api == null || token == null || token.isEmpty) {
      setState(() {
        _errorMessage = l10n.apiNotConfigured;
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final result = await api.startOnboardingTrial(
        authToken: token,
        plan: _planToApi(plan),
        clientRange: _rangeToApi(range),
        billingCycle: _billingCycle == _BillingCycle.yearly ? 'yearly' : 'monthly',
        returnUrl: _onboardingReturnUrl(),
      );
      if (!mounted) {
        return;
      }
      if (result.checkoutUrl.isEmpty) {
        setState(() {
          _busy = false;
          _errorMessage = l10n.somethingWentWrong;
        });
        return;
      }
      final opened = await launchUrl(
        Uri.parse(result.checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        setState(() {
          _busy = false;
          _errorMessage = l10n.somethingWentWrong;
        });
        return;
      }
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _errorMessage = l10n.somethingWentWrong;
      });
    }
  }

  String _onboardingReturnUrl() {
    final base = Uri.base;
    if (base.scheme == 'http' || base.scheme == 'https') {
      return '${base.origin}/#/onboarding/company';
    }
    return 'visitpro://app/onboarding/company';
  }

  Future<void> _handleCheckoutSuccess(String sessionId) async {
    final l10n = AppLocalizations.of(context);
    final session = ref.read(sessionProvider);
    final api = ref.read(serviceProofApiProvider);
    final token = session.token;
    if (api == null || token == null || token.isEmpty) {
      setState(() {
        _errorMessage = l10n.apiNotConfigured;
      });
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
      _lastHandledStripeSessionId = sessionId;
    });
    try {
      await api.confirmOnboardingCheckout(
        authToken: token,
        sessionId: sessionId,
      );
      final onboardingNotifier = ref.read(companyOnboardingProvider.notifier);
      await onboardingNotifier.markSubscriptionCompleted();
      await onboardingNotifier.completeOnboarding();
      ref.invalidate(propertiesProvider);
      if (!mounted) {
        return;
      }
      context.go('/home');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _errorMessage = l10n.somethingWentWrong;
      });
    }
  }

  _PlanTier _recommendedPlan(_ClientRange range) {
    return switch (range) {
      _ClientRange.upto15 => _PlanTier.starter,
      _ClientRange.upto40 => _PlanTier.growth,
      _ClientRange.above40 => _PlanTier.pro,
    };
  }

  String _planToApi(_PlanTier plan) {
    return switch (plan) {
      _PlanTier.starter => 'starter',
      _PlanTier.growth => 'growth',
      _PlanTier.pro => 'pro',
    };
  }

  String _rangeToApi(_ClientRange range) {
    return switch (range) {
      _ClientRange.upto15 => '0-15',
      _ClientRange.upto40 => '16-40',
      _ClientRange.above40 => '41+',
    };
  }

  Widget _buildSubscriptionStep(BuildContext context, AppLocalizations l10n) {
    final selectedRange = _selectedClientRange;
    if (selectedRange == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.onboardingHowManyClientsQuestion,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          _RangeChoiceTile(
            label: l10n.onboardingClientsRange0to15,
            selected: _selectedClientRange == _ClientRange.upto15,
            onTap: _busy
                ? null
                : () {
                    setState(() {
                      _selectedClientRange = _ClientRange.upto15;
                      _selectedPlan = _recommendedPlan(_ClientRange.upto15);
                    });
                  },
          ),
          const SizedBox(height: 8),
          _RangeChoiceTile(
            label: l10n.onboardingClientsRange16to40,
            selected: _selectedClientRange == _ClientRange.upto40,
            onTap: _busy
                ? null
                : () {
                    setState(() {
                      _selectedClientRange = _ClientRange.upto40;
                      _selectedPlan = _recommendedPlan(_ClientRange.upto40);
                    });
                  },
          ),
          const SizedBox(height: 8),
          _RangeChoiceTile(
            label: l10n.onboardingClientsRange41Plus,
            selected: _selectedClientRange == _ClientRange.above40,
            onTap: _busy
                ? null
                : () {
                    setState(() {
                      _selectedClientRange = _ClientRange.above40;
                      _selectedPlan = _recommendedPlan(_ClientRange.above40);
                    });
                  },
          ),
        ],
      );
    }

    final recommended = _recommendedPlan(selectedRange);
    final selectedPlan = _selectedPlan ?? recommended;
    final planOrder = <_PlanTier>[
      _PlanTier.starter,
      _PlanTier.growth,
      _PlanTier.pro,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            l10n.onboardingFourteenDayTrialInfo,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<_BillingCycle>(
          segments: [
            ButtonSegment(
              value: _BillingCycle.monthly,
              label: Text(l10n.onboardingMonthly),
            ),
            ButtonSegment(
              value: _BillingCycle.yearly,
              label: Text(l10n.onboardingYearly),
            ),
          ],
          selected: {_billingCycle},
          onSelectionChanged: _busy
              ? null
              : (value) {
                  setState(() {
                    _billingCycle = value.first;
                  });
                },
        ),
        const SizedBox(height: 6),
        if (_billingCycle == _BillingCycle.yearly)
          Text(
            l10n.onboardingYearlyDiscountInfo,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        const SizedBox(height: 10),
        const SizedBox(height: 10),
        ...planOrder.map(
          (plan) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PlanCard(
                planLabel: _planLabel(l10n, plan),
                priceLabel: _planPriceLabel(plan, l10n),
                originalPriceLabel: _planOriginalPriceLabel(plan, l10n),
                clientsLabel: _planClientsLabel(l10n, plan),
                featureLines: _planFeatureLines(l10n, plan),
                extraNote: _planExtraNote(l10n, plan),
                mostPopular: plan == _PlanTier.growth,
                recommended: plan == recommended,
                selected: plan == selectedPlan,
                recommendedLabel: l10n.onboardingRecommendedForCompanySize,
                onTap: _busy
                    ? null
                    : () {
                        setState(() {
                          _selectedPlan = plan;
                        });
                      },
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          l10n.onboardingAddonsTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _AddonCard(
          title: l10n.onboardingAddonExtraUser,
          description: l10n.onboardingAddonExtraUserDesc,
          priceLabel: '€5 / month',
          comingSoonLabel: l10n.onboardingComingSoon,
        ),
        const SizedBox(height: 8),
        _AddonCard(
          title: l10n.onboardingAddonWhiteLabeling,
          description: l10n.onboardingAddonWhiteLabelingDesc,
          priceLabel: '€19 / month',
          comingSoonLabel: l10n.onboardingComingSoon,
        ),
        const SizedBox(height: 8),
        _AddonCard(
          title: l10n.onboardingAddonPdfReports,
          description: l10n.onboardingAddonPdfReportsDesc,
          priceLabel: '€7 / month',
          comingSoonLabel: l10n.onboardingComingSoon,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _startTrialAndFinish,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.onboardingStartTrialCta),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.onboardingUpgradeDowngradeAnytime,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          l10n.onboardingCancelAnytimeTrial,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _planLabel(AppLocalizations l10n, _PlanTier plan) {
    return switch (plan) {
      _PlanTier.starter => l10n.onboardingPlanStarter,
      _PlanTier.growth => l10n.onboardingPlanGrowth,
      _PlanTier.pro => l10n.onboardingPlanPro,
    };
  }

  String _planPriceLabel(_PlanTier plan, AppLocalizations l10n) {
    final monthly = _monthlyPrice(plan);
    if (_billingCycle == _BillingCycle.yearly) {
      final discountedMonthly = (monthly * 10) / 12;
      final rounded = discountedMonthly.round();
      return '€$rounded / ${l10n.onboardingMonth}';
    }
    return '€$monthly / ${l10n.onboardingMonth}';
  }

  String? _planOriginalPriceLabel(_PlanTier plan, AppLocalizations l10n) {
    if (_billingCycle != _BillingCycle.yearly) {
      return null;
    }
    final monthly = _monthlyPrice(plan);
    return '€$monthly / ${l10n.onboardingMonth}';
  }

  String _planClientsLabel(AppLocalizations l10n, _PlanTier plan) {
    return switch (plan) {
      _PlanTier.starter => l10n.onboardingPlanClientsUpTo20,
      _PlanTier.growth => l10n.onboardingPlanClientsUpTo60,
      _PlanTier.pro => l10n.onboardingPlanClientsFrom61,
    };
  }

  List<String> _planFeatureLines(AppLocalizations l10n, _PlanTier plan) {
    return switch (plan) {
      _PlanTier.starter => <String>[
          l10n.onboardingPlanStarterFeatureUsers,
          l10n.onboardingPlanStarterFeaturePortal,
          l10n.onboardingPlanStarterFeatureEmailReports,
        ],
      _PlanTier.growth => <String>[
          l10n.onboardingPlanGrowthFeatureUsers,
          l10n.onboardingPlanGrowthFeatureEverythingStarter,
          l10n.onboardingPlanGrowthFeatureFlexibility,
        ],
      _PlanTier.pro => <String>[
          l10n.onboardingPlanProFeatureUnlimitedUsers,
          l10n.onboardingPlanProFeatureEverythingGrowth,
          l10n.onboardingPlanProFeaturePrioritySupport,
        ],
    };
  }

  String? _planExtraNote(AppLocalizations l10n, _PlanTier plan) {
    return switch (plan) {
      _PlanTier.starter => _billingCycle == _BillingCycle.yearly
          ? l10n.onboardingPlanStarterExtraUserNoteYearly
          : l10n.onboardingPlanStarterExtraUserNote,
      _PlanTier.growth => null,
      _PlanTier.pro => null,
    };
  }

  int _monthlyPrice(_PlanTier plan) {
    return switch (plan) {
      _PlanTier.starter => 29,
      _PlanTier.growth => 49,
      _PlanTier.pro => 69,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = GoRouterState.of(context).uri.queryParameters;
    final stripeStatus = query['stripe']?.trim().toLowerCase();
    final sessionId = query['session_id']?.trim() ?? '';
    if (stripeStatus == 'success' &&
        sessionId.isNotEmpty &&
        _lastHandledStripeSessionId != sessionId &&
        !_busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _lastHandledStripeSessionId != sessionId) {
          _handleCheckoutSuccess(sessionId);
        }
      });
    }
    if (stripeStatus == 'cancel' && !_handledStripeCancel && !_busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_handledStripeCancel) {
          setState(() {
            _handledStripeCancel = true;
            _errorMessage = l10n.somethingWentWrong;
          });
        }
      });
    }
    final hasCreatedProperty = _createdPropertyId != null && _createdPropertyId!.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            AppBrandHeader(
              trailing: _step < 3
                  ? TextButton(
                      onPressed: _busy ? null : _skipCurrentStep,
                      child: Text(l10n.onboardingSkipForNow),
                    )
                  : null,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.onboardingCompanyTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.onboardingStepLabel(_step + 1, 4),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                  ),
                ),
              ),
            if (_step == 0) ...[
              _OnboardingCard(
                title: l10n.onboardingCompanyStepTitle,
                subtitle: l10n.onboardingCompanyStepSubtitle,
                child: Column(
                  children: [
                    TextField(
                      controller: _companyNameController,
                      decoration: InputDecoration(labelText: l10n.companyNameLabel),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _companyAddressController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: InputDecoration(labelText: l10n.companyAddressLabel),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.companyServicesLabel,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: serviceTypeIds
                          .map(
                            (serviceType) => FilterChip(
                              label: Text(l10n.serviceTypeLabel(serviceType)),
                              selected: _selectedServices.contains(serviceType),
                              onSelected: _busy
                                  ? null
                                  : (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedServices.add(serviceType);
                                        } else {
                                          _selectedServices.remove(serviceType);
                                        }
                                      });
                                    },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _continueFromCompanyStep,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.onboardingContinue),
              ),
            ],
            if (_step == 1) ...[
              _OnboardingCard(
                title: l10n.onboardingPropertyStepTitle,
                subtitle: l10n.onboardingPropertyStepSubtitle,
                child: Column(
                  children: [
                    TextField(
                      controller: _propertyNameController,
                      decoration: InputDecoration(labelText: l10n.propertyNameLabel),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _propertyAddressController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: InputDecoration(labelText: l10n.addressLabel),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _propertyClientEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.clientEmailOptionalRecommended,
                        hintText: l10n.emailHint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                _step = 0;
                                _errorMessage = null;
                              });
                            },
                      child: Text(l10n.onboardingBack),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _continueFromPropertyStep,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.onboardingContinue),
                    ),
                  ),
                ],
              ),
            ],
            if (_step == 2) ...[
              _OnboardingCard(
                title: l10n.onboardingInvitesStepTitle,
                subtitle: l10n.onboardingInvitesStepSubtitle,
                child: Column(
                  children: [
                    TextField(
                      controller: _inviteWorkerEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.onboardingInviteWorkerLabel,
                        hintText: l10n.emailHint,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.onboardingInvitesOptionalHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                _step = 1;
                                _errorMessage = null;
                              });
                            },
                      child: Text(l10n.onboardingBack),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _busy ? null : () => _finishOnboarding(sendInvites: false),
                      child: Text(l10n.onboardingContinueWithoutInvites),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy || !hasCreatedProperty
                    ? null
                    : () => _finishOnboarding(sendInvites: true),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.onboardingSendInvitesAndContinue),
              ),
            ],
            if (_step == 3) ...[
              _OnboardingCard(
                title: l10n.onboardingSubscriptionStepTitle,
                subtitle: l10n.onboardingSubscriptionStepSubtitle,
                child: _buildSubscriptionStep(context, l10n),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _RangeChoiceTile extends StatelessWidget {
  const _RangeChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7)
          : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (selected)
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              if (selected) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.planLabel,
    required this.priceLabel,
    required this.originalPriceLabel,
    required this.clientsLabel,
    required this.featureLines,
    required this.extraNote,
    required this.mostPopular,
    required this.recommended,
    required this.selected,
    required this.recommendedLabel,
    required this.onTap,
  });

  final String planLabel;
  final String priceLabel;
  final String? originalPriceLabel;
  final String clientsLabel;
  final List<String> featureLines;
  final String? extraNote;
  final bool mostPopular;
  final bool recommended;
  final bool selected;
  final String recommendedLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? colorScheme.primaryContainer.withValues(alpha: 0.45)
                : (recommended
                    ? colorScheme.primaryContainer.withValues(alpha: 0.28)
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : (recommended
                      ? colorScheme.primary.withValues(alpha: 0.5)
                      : colorScheme.outline),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (selected) ...[
                              Icon(
                                Icons.check_circle,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                planLabel,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        if (mostPopular) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '⭐ ${AppLocalizations.of(context).onboardingMostPopular}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Row(
                      children: [
                        Text(
                          priceLabel,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (originalPriceLabel != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            originalPriceLabel!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(clientsLabel),
              const SizedBox(height: 6),
              ...featureLines.map(
                (line) => Text('✓ $line'),
              ),
              if (extraNote != null) ...[
                const SizedBox(height: 6),
                Text(
                  extraNote!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              if (recommended) ...[
                const SizedBox(height: 8),
                Text(
                  '⭐ $recommendedLabel',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AddonCard extends StatelessWidget {
  const _AddonCard({
    required this.title,
    required this.description,
    required this.priceLabel,
    required this.comingSoonLabel,
  });

  final String title;
  final String description;
  final String priceLabel;
  final String comingSoonLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: 0.62,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              priceLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.6)),
              ),
              child: Text(
                comingSoonLabel,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
