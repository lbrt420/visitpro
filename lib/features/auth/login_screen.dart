import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../core/api/service_proof_api.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/company_onboarding_provider.dart';
import '../../core/providers/in_memory_store_provider.dart';
import '../../core/providers/session_provider.dart';

enum LoginAudience { company, client }
enum CompanyAuthMode { login, signup }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _companyNameController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _companyPasswordController = TextEditingController();
  final _companyConfirmPasswordController = TextEditingController();
  final _clientEmailController = TextEditingController();
  final _clientPasswordController = TextEditingController();

  bool _submitting = false;
  String? _formError;
  LoginAudience _loginAudience = LoginAudience.company;
  CompanyAuthMode _companyAuthMode = CompanyAuthMode.login;

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyEmailController.dispose();
    _companyPasswordController.dispose();
    _companyConfirmPasswordController.dispose();
    _clientEmailController.dispose();
    _clientPasswordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context);
    final sessionNotifier = ref.read(sessionProvider.notifier);
    setState(() {
      _formError = null;
    });

    var fromCompanySignup = false;
    try {
      if (_loginAudience == LoginAudience.client) {
        final email = _clientEmailController.text.trim();
        final password = _clientPasswordController.text.trim();
        if (email.isEmpty || password.isEmpty) {
          throw Exception(l10n.errorEmailPasswordRequired);
        }

        setState(() {
          _submitting = true;
        });
        await sessionNotifier.loginClientFake(
          email: email,
          password: password,
        );
      } else if (_companyAuthMode == CompanyAuthMode.signup) {
        fromCompanySignup = true;
        final companyName = _companyNameController.text.trim();
        final email = _companyEmailController.text.trim();
        final password = _companyPasswordController.text;
        final confirmPassword = _companyConfirmPasswordController.text;

        if (companyName.isEmpty || email.isEmpty || password.isEmpty) {
          throw Exception(l10n.errorRequiredFields);
        }
        if (password != confirmPassword) {
          throw Exception(l10n.errorPasswordsMismatch);
        }

        setState(() {
          _submitting = true;
        });
        await sessionNotifier.signupCompanyFake(
          companyName: companyName,
          email: email,
          password: password,
        );
      } else {
        final email = _companyEmailController.text.trim();
        final password = _companyPasswordController.text;
        if (email.isEmpty || password.isEmpty) {
          throw Exception(l10n.errorEmailPasswordRequired);
        }

        setState(() {
          _submitting = true;
        });
        await sessionNotifier.loginCompanyFake(
          email: email,
          password: password,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _formError = _toFriendlyAuthError(error, l10n);
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
    });
    await _syncOnboardingState(fromCompanySignup: fromCompanySignup);
    if (!mounted) {
      return;
    }
    context.go('/home');
  }

  Future<void> _syncOnboardingState({required bool fromCompanySignup}) async {
    final session = ref.read(sessionProvider);
    final onboarding = ref.read(companyOnboardingProvider.notifier);
    if (!session.isAuthenticated || session.role == UserRole.client) {
      await onboarding.clearAll();
      return;
    }

    final api = ref.read(serviceProofApiProvider);
    final token = session.token;
    var propertiesCount = 0;
    var subscriptionStatus = 'inactive';
    if (api != null && token != null && token.isNotEmpty) {
      try {
        final companyInfo = await api.getCompanyMe(authToken: token);
        subscriptionStatus = companyInfo.subscriptionStatus.trim().toLowerCase();
        propertiesCount = companyInfo.propertiesUsed;
      } catch (_) {
        propertiesCount = (await ref.read(inMemoryStoreProvider).fetchProperties()).length;
      }
    } else {
      propertiesCount = (await ref.read(inMemoryStoreProvider).fetchProperties()).length;
    }

    final hasActiveSubscription = subscriptionStatus == 'active' || subscriptionStatus == 'trialing';
    final shouldOnboard = fromCompanySignup || !hasActiveSubscription || propertiesCount == 0;
    if (!shouldOnboard) {
      await onboarding.clearAll();
      return;
    }
    await onboarding.configureForLogin(
      shouldOnboard: true,
      resetProgress: fromCompanySignup,
    );
  }

  String _toFriendlyAuthError(Object error, AppLocalizations l10n) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final responseData = error.response?.data;
      final apiError = responseData is Map<String, dynamic>
          ? (responseData['error'] as String?)?.toLowerCase()
          : null;

      if (statusCode == 401 || (apiError?.contains('invalid credentials') ?? false)) {
        if (_loginAudience == LoginAudience.company &&
            _companyAuthMode == CompanyAuthMode.login) {
          return l10n.errorCompanyAccountNotFound;
        }
        return l10n.errorInvalidCredentials;
      }

      if (statusCode == 409 || (apiError?.contains('already exists') ?? false)) {
        return _loginAudience == LoginAudience.company
            ? l10n.errorEmailAlreadyExists
            : l10n.somethingWentWrong;
      }

      if (statusCode == 400) {
        return l10n.errorRequiredFields;
      }

      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return l10n.networkFailureRetry;
      }
    }

    var message = error.toString().replaceAll('Exception: ', '').trim();
    if (message.toLowerCase().contains('invalid username or password')) {
      return l10n.errorInvalidCredentials;
    }
    if (message.isEmpty || message.toLowerCase().contains('dioexception')) {
      return l10n.somethingWentWrong;
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const SizedBox(
                  height: 96,
                  child: Image(
                    image: AssetImage('assets/images/logo.png'),
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.appTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.proofTagline,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SegmentedButton<LoginAudience>(
                  segments: [
                    ButtonSegment(
                      value: LoginAudience.company,
                      label: Text(l10n.companyLoginTab),
                      icon: Icon(Icons.business_outlined),
                    ),
                    ButtonSegment(
                      value: LoginAudience.client,
                      label: Text(l10n.clientLoginTab),
                      icon: Icon(Icons.person_outline),
                    ),
                  ],
                  selected: <LoginAudience>{_loginAudience},
                  onSelectionChanged: (value) {
                    setState(() {
                      _loginAudience = value.first;
                      _formError = null;
                    });
                  },
                ),
                const SizedBox(height: 14),
                if (_loginAudience == LoginAudience.company) ...[
                  Text(
                    _companyAuthMode == CompanyAuthMode.signup
                        ? l10n.companySignupHeader
                        : l10n.companyLoginHeader,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (_companyAuthMode == CompanyAuthMode.signup) ...[
                    TextField(
                      controller: _companyNameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.companyNameLabel,
                        hintText: l10n.companyNameHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _companyEmailController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      labelText: l10n.emailLabel,
                      hintText: l10n.emailHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _companyPasswordController,
                    obscureText: true,
                    textInputAction: _companyAuthMode == CompanyAuthMode.signup
                        ? TextInputAction.next
                        : TextInputAction.done,
                    decoration: InputDecoration(labelText: l10n.passwordLabel),
                    onSubmitted: (_) {
                      if (_companyAuthMode == CompanyAuthMode.login) {
                        _login();
                      }
                    },
                  ),
                  if (_companyAuthMode == CompanyAuthMode.signup) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _companyConfirmPasswordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.confirmPasswordLabel,
                      ),
                      onSubmitted: (_) => _login(),
                    ),
                  ],
                ] else ...[
                  TextField(
                    controller: _clientEmailController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      labelText: l10n.emailLabel,
                      hintText: l10n.emailHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clientPasswordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(labelText: l10n.passwordLabel),
                    onSubmitted: (_) => _login(),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  _loginAudience == LoginAudience.client
                      ? l10n.clientLoginHelp
                      : (_companyAuthMode == CompanyAuthMode.signup
                            ? l10n.companySignupHelp
                            : l10n.companyLoginHelp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_formError != null) ...[
                  const SizedBox(height: 10),
                  Container(
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
                            _formError!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.red.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _login,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _loginAudience == LoginAudience.client
                              ? l10n.clientLoginButton
                              : (_companyAuthMode == CompanyAuthMode.signup
                                    ? l10n.createCompanyAccountButton
                                    : l10n.companyLoginButton),
                        ),
                ),
                if (_loginAudience == LoginAudience.company) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _companyAuthMode == CompanyAuthMode.signup
                            ? l10n.alreadyRegistered
                            : l10n.notRegistered,
                      ),
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () {
                                setState(() {
                                  _companyAuthMode =
                                      _companyAuthMode == CompanyAuthMode.signup
                                      ? CompanyAuthMode.login
                                      : CompanyAuthMode.signup;
                                  _formError = null;
                                });
                              },
                        child: Text(
                          _companyAuthMode == CompanyAuthMode.signup
                              ? l10n.signIn
                              : l10n.registerNow,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
