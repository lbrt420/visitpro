import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_provider.dart';

const _needsOnboardingKey = 'company_onboarding_needs';
const _onboardingSkippedKey = 'company_onboarding_skipped';
const _companySetupDoneKey = 'company_onboarding_company_setup_done';
const _firstPropertyDoneKey = 'company_onboarding_first_property_done';
const _invitesDoneKey = 'company_onboarding_invites_done';
const _subscriptionDoneKey = 'company_onboarding_subscription_done';
const _lastPropertyIdKey = 'company_onboarding_last_property_id';

class CompanyOnboardingState {
  const CompanyOnboardingState({
    required this.needsOnboarding,
    required this.hasSkipped,
    required this.companySetupCompleted,
    required this.firstPropertyCompleted,
    required this.invitesCompleted,
    required this.subscriptionCompleted,
    required this.lastCreatedPropertyId,
  });

  final bool needsOnboarding;
  final bool hasSkipped;
  final bool companySetupCompleted;
  final bool firstPropertyCompleted;
  final bool invitesCompleted;
  final bool subscriptionCompleted;
  final String? lastCreatedPropertyId;

  bool get shouldForceRoute => needsOnboarding && !subscriptionCompleted;

  CompanyOnboardingState copyWith({
    bool? needsOnboarding,
    bool? hasSkipped,
    bool? companySetupCompleted,
    bool? firstPropertyCompleted,
    bool? invitesCompleted,
    bool? subscriptionCompleted,
    String? lastCreatedPropertyId,
    bool clearLastCreatedPropertyId = false,
  }) {
    return CompanyOnboardingState(
      needsOnboarding: needsOnboarding ?? this.needsOnboarding,
      hasSkipped: hasSkipped ?? this.hasSkipped,
      companySetupCompleted: companySetupCompleted ?? this.companySetupCompleted,
      firstPropertyCompleted: firstPropertyCompleted ?? this.firstPropertyCompleted,
      invitesCompleted: invitesCompleted ?? this.invitesCompleted,
      subscriptionCompleted: subscriptionCompleted ?? this.subscriptionCompleted,
      lastCreatedPropertyId: clearLastCreatedPropertyId
          ? null
          : (lastCreatedPropertyId ?? this.lastCreatedPropertyId),
    );
  }
}

class CompanyOnboardingNotifier extends Notifier<CompanyOnboardingState> {
  @override
  CompanyOnboardingState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs == null) {
      return const CompanyOnboardingState(
        needsOnboarding: false,
        hasSkipped: false,
        companySetupCompleted: false,
        firstPropertyCompleted: false,
        invitesCompleted: false,
        subscriptionCompleted: false,
        lastCreatedPropertyId: null,
      );
    }
    return CompanyOnboardingState(
      needsOnboarding: prefs.getBool(_needsOnboardingKey) ?? false,
      hasSkipped: prefs.getBool(_onboardingSkippedKey) ?? false,
      companySetupCompleted: prefs.getBool(_companySetupDoneKey) ?? false,
      firstPropertyCompleted: prefs.getBool(_firstPropertyDoneKey) ?? false,
      invitesCompleted: prefs.getBool(_invitesDoneKey) ?? false,
      subscriptionCompleted: prefs.getBool(_subscriptionDoneKey) ?? false,
      lastCreatedPropertyId: prefs.getString(_lastPropertyIdKey),
    );
  }

  Future<void> configureForLogin({
    required bool shouldOnboard,
    bool resetProgress = false,
  }) async {
    final next = resetProgress
        ? state.copyWith(
            needsOnboarding: shouldOnboard,
            hasSkipped: false,
            companySetupCompleted: false,
            firstPropertyCompleted: false,
            invitesCompleted: false,
            subscriptionCompleted: false,
            clearLastCreatedPropertyId: true,
          )
        : state.copyWith(
            needsOnboarding: shouldOnboard,
            hasSkipped: false,
          );
    state = next;
    await _persist(next);
  }

  Future<void> skipForNow() async {
    final next = state.copyWith(hasSkipped: true);
    state = next;
    await _persist(next);
  }

  Future<void> resume() async {
    final next = state.copyWith(hasSkipped: false);
    state = next;
    await _persist(next);
  }

  Future<void> markCompanySetupCompleted() async {
    final next = state.copyWith(companySetupCompleted: true);
    state = next;
    await _persist(next);
  }

  Future<void> markFirstPropertyCompleted(String propertyId) async {
    final next = state.copyWith(
      firstPropertyCompleted: true,
      lastCreatedPropertyId: propertyId,
    );
    state = next;
    await _persist(next);
  }

  Future<void> markInvitesCompleted() async {
    final next = state.copyWith(invitesCompleted: true);
    state = next;
    await _persist(next);
  }

  Future<void> markSubscriptionCompleted() async {
    final next = state.copyWith(subscriptionCompleted: true);
    state = next;
    await _persist(next);
  }

  Future<void> completeOnboarding() async {
    final next = state.copyWith(
      needsOnboarding: false,
      hasSkipped: false,
      companySetupCompleted: true,
      firstPropertyCompleted: true,
      invitesCompleted: true,
      subscriptionCompleted: true,
    );
    state = next;
    await _persist(next);
  }

  Future<void> clearAll() async {
    const next = CompanyOnboardingState(
      needsOnboarding: false,
      hasSkipped: false,
      companySetupCompleted: false,
      firstPropertyCompleted: false,
      invitesCompleted: false,
      subscriptionCompleted: false,
      lastCreatedPropertyId: null,
    );
    state = next;
    await _persist(next);
  }

  Future<void> _persist(CompanyOnboardingState next) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs == null) {
      return;
    }
    await prefs.setBool(_needsOnboardingKey, next.needsOnboarding);
    await prefs.setBool(_onboardingSkippedKey, next.hasSkipped);
    await prefs.setBool(_companySetupDoneKey, next.companySetupCompleted);
    await prefs.setBool(_firstPropertyDoneKey, next.firstPropertyCompleted);
    await prefs.setBool(_invitesDoneKey, next.invitesCompleted);
    await prefs.setBool(_subscriptionDoneKey, next.subscriptionCompleted);
    if (next.lastCreatedPropertyId != null && next.lastCreatedPropertyId!.isNotEmpty) {
      await prefs.setString(_lastPropertyIdKey, next.lastCreatedPropertyId!);
    } else {
      await prefs.remove(_lastPropertyIdKey);
    }
  }
}

final companyOnboardingProvider =
    NotifierProvider<CompanyOnboardingNotifier, CompanyOnboardingState>(
  CompanyOnboardingNotifier.new,
);
