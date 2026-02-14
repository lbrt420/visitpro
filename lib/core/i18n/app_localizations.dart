import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/brand_config.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[Locale('en'), Locale('es')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return localizations ?? const AppLocalizations(Locale('en'));
  }

  bool get _isEs => locale.languageCode == 'es';

  String get appTitle => appBrandName;
  String get proofTagline => _isEs
      ? 'Prueba de servicio en cada visita.'
      : 'Proof of service for every visit.';

  String get home => _isEs ? 'Inicio' : 'Home';
  String get company => _isEs ? 'Empresa' : 'Company';
  String get properties => _isEs ? 'Propiedades' : 'Properties';
  String get profile => _isEs ? 'Perfil' : 'Profile';
  String get account => _isEs ? 'Cuenta' : 'Account';
  String get logout => _isEs ? 'Cerrar sesion' : 'Logout';
  String get unknownUser => _isEs ? 'Usuario desconocido' : 'Unknown user';
  String roleLabel(String role) => _isEs ? 'Rol: $role' : 'Role: $role';

  String get companyLoginTab => _isEs ? 'Acceso empresa' : 'Company Login';
  String get clientLoginTab => _isEs ? 'Acceso cliente' : 'Client Login';
  String get companyLoginHeader => _isEs ? 'Acceso empresa' : 'Company login';
  String get companySignupHeader =>
      _isEs ? 'Crear cuenta de empresa' : 'Create company account';
  String get companyNameLabel => _isEs ? 'Nombre de empresa' : 'Company name';
  String get companyNameHint =>
      _isEs ? 'Ingresa el nombre de la empresa' : 'Enter company name';
  String get emailLabel => 'Email';
  String get emailHint => _isEs ? 'nombre@empresa.com' : 'name@company.com';
  String get passwordLabel => _isEs ? 'Contrasena' : 'Password';
  String get confirmPasswordLabel =>
      _isEs ? 'Confirmar contrasena' : 'Confirm password';
  String get usernameLabel => _isEs ? 'Usuario' : 'Username';
  String get firstNameLabel => _isEs ? 'Nombre' : 'First name';
  String get usernameHint =>
      _isEs ? 'Ingresa tu usuario cliente' : 'Enter client username';
  String get clientLoginButton => _isEs ? 'Acceso cliente' : 'Client login';
  String get companyLoginButton => _isEs ? 'Acceso empresa' : 'Company login';
  String get createCompanyAccountButton =>
      _isEs ? 'Crear cuenta empresa' : 'Create company account';
  String get alreadyRegistered =>
      _isEs ? 'Ya estas registrado?' : 'Already registered?';
  String get notRegistered =>
      _isEs ? 'No estas registrado?' : 'Not registered?';
  String get signIn => _isEs ? 'Iniciar sesion' : 'Sign in';
  String get registerNow => _isEs ? 'Registrate ahora' : 'Register now';
  String get clientLoginHelp => _isEs
      ? 'Las cuentas de cliente las crea el administrador. Solo puedes ver cronologias asignadas.'
      : 'Client accounts are created by your company admin. You can only view assigned timelines.';
  String get companySignupHelp => _isEs
      ? 'Crea tu cuenta de propietario para comenzar.'
      : 'Create your company owner account to get started.';
  String get companyLoginHelp => _isEs
      ? 'Las cuentas de empresa pueden gestionar propiedades, trabajadores y clientes.'
      : 'Company accounts can manage properties, workers, and clients.';
  String get errorUsernamePasswordRequired => _isEs
      ? 'Ingresa usuario y contrasena.'
      : 'Please enter username and password.';
  String get errorRequiredFields => _isEs
      ? 'Completa todos los campos requeridos.'
      : 'Please complete all required fields.';
  String get errorPasswordsMismatch =>
      _isEs ? 'Las contrasenas no coinciden.' : 'Passwords do not match.';
  String get errorEmailPasswordRequired => _isEs
      ? 'Ingresa email y contrasena.'
      : 'Please enter email and password.';
  String get errorInvalidCredentials => _isEs
      ? 'Usuario o contrasena invalidos.'
      : 'Invalid username or password.';
  String get errorCompanyAccountNotFound => _isEs
      ? 'No encontramos una cuenta de empresa con esos datos. Usa "Registrate ahora" para crearla.'
      : 'No company account found with those credentials. Use "Register now" to create one.';
  String get errorEmailAlreadyExists => _isEs
      ? 'El email ya existe. Inicia sesion.'
      : 'Email already exists. Sign in instead.';

  String get allProperties =>
      _isEs ? 'Todas las propiedades' : 'All properties';
  String get assignedProperties =>
      _isEs ? 'Propiedades asignadas' : 'Assigned properties';
  String propertiesCount(int count) => _isEs
      ? '$count ${count == 1 ? 'propiedad' : 'propiedades'}'
      : '$count ${count == 1 ? 'property' : 'properties'}';
  String get viewTimeline => _isEs ? 'Ver cronologia' : 'View timeline';
  String get manageAccess => _isEs ? 'Gestionar acceso' : 'Manage access';
  String get inviteWorker => _isEs ? 'Invitar trabajador' : 'Invite worker';
  String get inviteClient => _isEs ? 'Invitar cliente' : 'Invite client';
  String get showMore => _isEs ? 'Mostrar mas' : 'Show more';
  String get showLess => _isEs ? 'Mostrar menos' : 'Show less';
  String get createProperty => _isEs ? 'Crear propiedad' : 'Create property';
  String get onboardingCompanyTitle =>
      _isEs ? 'Onboarding de empresa' : 'Company onboarding';
  String onboardingStepLabel(int current, int total) =>
      _isEs ? 'Paso $current de $total' : 'Step $current of $total';
  String get onboardingSkipForNow =>
      _isEs ? 'Saltar por ahora' : 'Skip for now';
  String get onboardingResume =>
      _isEs ? 'Reanudar onboarding' : 'Resume onboarding';
  String get onboardingContinue => _isEs ? 'Continuar' : 'Continue';
  String get onboardingBack => _isEs ? 'Atras' : 'Back';
  String get onboardingMonthly => _isEs ? 'Mensual' : 'Monthly';
  String get onboardingYearly => _isEs ? 'Anual' : 'Yearly';
  String get onboardingMonth => _isEs ? 'mes' : 'month';
  String get onboardingYear => _isEs ? 'ano' : 'year';
  String get onboardingYearlyDiscountInfo => _isEs
      ? 'Plan anual: 2 meses gratis (pagas 10).'
      : 'Yearly plan: 2 months free (pay for 10).';
  String get onboardingFinish => _isEs ? 'Finalizar' : 'Finish';
  String get onboardingContinueWithoutInvites =>
      _isEs ? 'Continuar sin invitaciones' : 'Continue without invites';
  String get onboardingSendInvitesAndContinue =>
      _isEs ? 'Enviar invitaciones y continuar' : 'Send invites and continue';
  String get onboardingSendInvitesAndFinish =>
      _isEs ? 'Enviar invitaciones y finalizar' : 'Send invites and finish';
  String get onboardingCreatePropertyFirst => _isEs
      ? 'Primero debes crear la propiedad.'
      : 'Create the property first.';
  String get onboardingCompanyStepTitle =>
      _isEs ? 'Configura tu empresa' : 'Set up your company';
  String get onboardingCompanyStepSubtitle => _isEs
      ? 'Confirma los datos principales y los servicios que ofreces.'
      : 'Confirm main details and services you provide.';
  String get onboardingPropertyStepTitle =>
      _isEs ? 'Crea tu primera propiedad' : 'Create your first property';
  String get onboardingPropertyStepSubtitle => _isEs
      ? 'Este paso habilita tu timeline y el trabajo diario.'
      : 'This unlocks your timeline and daily workflow.';
  String get onboardingInvitesStepTitle => _isEs
      ? 'Invita a un empleado o companero (opcional)'
      : 'Invite an employee or coworker (optional)';
  String get onboardingInvitesStepSubtitle => _isEs
      ? 'Invita a un empleado o companero ahora, o hazlo mas tarde.'
      : 'Invite an employee or coworker now, or do it later.';
  String get onboardingInviteClientLabel =>
      _isEs ? 'Email cliente (opcional)' : 'Client email (optional)';
  String get onboardingInviteWorkerLabel => _isEs
      ? 'Invitar a un empleado o companero (opcional)'
      : 'Invite an employee or coworker (optional)';
  String get onboardingInvitesOptionalHint => _isEs
      ? 'Tambien podras enviar invitaciones desde Propiedades o Empresa.'
      : 'You can also send invites later from Properties or Company.';
  String get onboardingSubscriptionStepTitle =>
      _isEs ? 'Suscripcion' : 'Subscription';
  String get onboardingSubscriptionStepSubtitle => _isEs
      ? 'Ultimo paso: elige un plan e inicia la prueba.'
      : 'Final step: choose a plan and start your trial.';
  String get onboardingHowManyClientsQuestion => _isEs
      ? 'Cuantos clientes gestionas actualmente?'
      : 'How many clients do you currently manage?';
  String get onboardingClientsRange0to15 =>
      _isEs ? '0-15 clientes' : '0-15 clients';
  String get onboardingClientsRange16to40 =>
      _isEs ? '16-40 clientes' : '16-40 clients';
  String get onboardingClientsRange41Plus =>
      _isEs ? '41+ clientes' : '41+ clients';
  String get onboardingWeRecommendPlan =>
      _isEs ? 'Te recomendamos este plan' : 'We recommend this plan for you';
  String get onboardingPlanStarter => 'Starter';
  String get onboardingPlanGrowth => 'Growth';
  String get onboardingPlanPro => 'Pro';
  String get onboardingMostPopular => _isEs ? 'Mas popular' : 'Most popular';
  String get onboardingPlanClientsUpTo20 =>
      _isEs ? 'Hasta 20 propiedades' : 'Up to 20 properties';
  String get onboardingPlanClientsUpTo60 =>
      _isEs ? 'Hasta 60 propiedades' : 'Up to 60 properties';
  String get onboardingPlanClientsFrom61 =>
      _isEs ? '61+ propiedades' : '61+ properties';
  String get onboardingPlanStarterFeatureUsers =>
      _isEs ? '1 cuenta de empleado incluida' : '1 employee account included';
  String get onboardingPlanStarterFeaturePortal =>
      _isEs ? 'Portal de clientes' : 'Client portal';
  String get onboardingPlanStarterFeatureEmailReports =>
      _isEs ? 'Reportes por email' : 'Email reports';
  String get onboardingPlanStarterExtraUserNote =>
      _isEs ? 'Usuario extra: €5 / mes' : 'Extra user: €5 / month';
  String get onboardingPlanStarterExtraUserNoteYearly => _isEs
      ? 'Usuario extra: €50 / ano (2 meses gratis)'
      : 'Extra user: €50 / year (2 months free)';
  String get onboardingPlanGrowthFeatureUsers => _isEs
      ? 'Hasta 5 cuentas de empleado incluidas'
      : 'Up to 5 employee accounts included';
  String get onboardingPlanGrowthFeatureEverythingStarter =>
      _isEs ? 'Todo lo de Starter' : 'Everything in Starter';
  String get onboardingPlanGrowthFeatureFlexibility =>
      _isEs ? 'Mejor flexibilidad de equipo' : 'Better team flexibility';
  String get onboardingPlanProFeatureUnlimitedUsers =>
      _isEs ? 'Cuentas de empleado ilimitadas' : 'Unlimited employee accounts';
  String get onboardingPlanProFeatureEverythingGrowth =>
      _isEs ? 'Todo lo de Growth' : 'Everything in Growth';
  String get onboardingPlanProFeaturePrioritySupport =>
      _isEs ? 'Soporte prioritario' : 'Prioritized support';
  String get onboardingAddonsTitle => _isEs ? 'Add-ons' : 'Add-ons';
  String get onboardingAddonExtraUser => _isEs ? 'Usuario extra' : 'Extra user';
  String get onboardingAddonExtraUserDesc => _isEs
      ? 'Agrega usuarios adicionales cuando tu equipo crezca.'
      : 'Add additional users as your team grows.';
  String get onboardingAddonWhiteLabeling =>
      _isEs ? 'White labeling' : 'White labeling';
  String get onboardingAddonWhiteLabelingDesc => _isEs
      ? 'Usa tu propio logo, colores y marca en toda la experiencia del cliente.'
      : 'Use your own logo, colors, and branding across the full client experience.';
  String get onboardingAddonPdfReports => 'PDF reports';
  String get onboardingAddonPdfReportsDesc => _isEs
      ? 'Genera y comparte reportes de visita en PDF con diseno profesional.'
      : 'Generate and share professional PDF visit reports.';
  String get onboardingComingSoon => _isEs ? 'Proximamente' : 'Coming soon';
  String get onboardingRecommendedForCompanySize => _isEs
      ? 'Recomendado segun el tamano de tu empresa'
      : 'Recommended based on your company size';
  String get onboardingFourteenDayTrialInfo =>
      _isEs ? 'Prueba gratis de 14 dias.' : '14-day free trial.';
  String get onboardingStartTrialCta =>
      _isEs ? 'Iniciar prueba de 14 dias' : 'Start 14-day free trial';
  String onboardingDowngradeToPlan(String plan, String price) =>
      _isEs ? 'Bajar a $plan ($price)' : 'Downgrade to $plan ($price)';
  String onboardingUpgradeToPlan(String plan, String price) =>
      _isEs ? 'Subir a $plan ($price)' : 'Upgrade to $plan ($price)';
  String get onboardingUpgradeDowngradeAnytime => _isEs
      ? 'Puedes cambiar de plan en cualquier momento.'
      : 'You can upgrade or downgrade anytime.';
  String get onboardingCancelAnytimeTrial => _isEs
      ? 'Cancela cuando quieras durante la prueba.'
      : 'Cancel anytime during the trial.';
  String get onboardingSelectClientCountFirst => _isEs
      ? 'Selecciona el rango de clientes primero.'
      : 'Please select your client range first.';
  String get onboardingStripeRedirectTitle =>
      _isEs ? 'Redireccion a Stripe' : 'Stripe redirect';
  String onboardingStripeRedirectHelp(String url) => _isEs
      ? 'Tu checkout de Stripe esta listo: $url'
      : 'Your Stripe checkout is ready: $url';
  String get ok => 'OK';
  String get noPropertiesYet =>
      _isEs ? 'Aun no hay propiedades' : 'No properties yet';
  String get noAssignedPropertiesYet => _isEs
      ? 'Aun no tienes propiedades asignadas.'
      : 'No assigned properties yet.';
  String get ownerEmptyPropertiesHelp => _isEs
      ? 'Crea tu primera propiedad para comenzar a registrar visitas.'
      : 'Create your first property to start tracking service visits.';
  String get workerEmptyPropertiesHelp => _isEs
      ? 'Aun no tienes propiedades asignadas.'
      : 'You have not been assigned to any properties yet.';
  String get inviteViewer => _isEs ? 'Invitar visualizador' : 'Invite viewer';
  String get inviteSomeoneFeed =>
      _isEs ? 'Invitar a alguien a este feed' : 'Invite someone to this feed';
  String get assignedAccountsTitle =>
      _isEs ? 'Clientes asignados' : 'Assigned clients';
  String get noOtherAssignedAccounts => _isEs
      ? 'No hay otras cuentas asignadas a esta propiedad.'
      : 'No other accounts are assigned to this property.';
  String get remove => _isEs ? 'Quitar' : 'Remove';
  String get removeAccess => _isEs ? 'Quitar acceso' : 'Remove access';
  String removeAccessPrompt(String nameOrEmail) => _isEs
      ? 'Quitar acceso de $nameOrEmail a esta propiedad?'
      : 'Remove $nameOrEmail from this property?';
  String get removedFromProperty => _isEs
      ? 'Acceso removido de la propiedad.'
      : 'Access removed from property.';
  String get emailRequiredError =>
      _isEs ? 'Ingresa un email valido' : 'Enter a valid email';
  String get cancel => _isEs ? 'Cancelar' : 'Cancel';
  String get sendInvite => _isEs ? 'Enviar invitacion' : 'Send invite';
  String get clientInviteSent => _isEs
      ? 'Invitacion a cliente enviada (stub v1).'
      : 'Client invite sent (stubbed for v1).';
  String get workerInviteSent => _isEs
      ? 'Invitacion a trabajador enviada (stub v1).'
      : 'Worker invite sent (stubbed for v1).';
  String get viewerInviteSent => _isEs
      ? 'Invitacion enviada (stub v1).'
      : 'Viewer invite sent (stubbed for v1).';

  String get createPropertyTitle =>
      _isEs ? 'Crear propiedad' : 'Create property';
  String get propertyNameLabel =>
      _isEs ? 'Nombre de propiedad' : 'Property name';
  String get addressLabel => _isEs ? 'Direccion' : 'Address';
  String get clientEmailOptionalRecommended => _isEs
      ? 'Email del cliente (opcional, recomendado)'
      : 'Client email (optional, recommended)';
  String get createPropertyClientEmailHelp => _isEs
      ? 'Si lo agregas ahora, enviaremos la invitacion al crear la propiedad.'
      : 'If provided now, we will send the invite when the property is created.';
  String get requiredField => _isEs ? 'Requerido' : 'Required';
  String get saveProperty => _isEs ? 'Guardar propiedad' : 'Save property';
  String get companyOverviewTab => _isEs ? 'Resumen' : 'Overview';
  String get companyServicesTab => _isEs ? 'Servicios' : 'Services';
  String get companyTeamTab => _isEs ? 'Equipo' : 'Team';
  String get companySubscriptionTab => _isEs ? 'Suscripcion' : 'Subscription';
  String get companySubscriptionOverview =>
      _isEs ? 'Resumen de suscripcion' : 'Subscription overview';
  String get companyCurrentPlan => _isEs ? 'Plan actual' : 'Current plan';
  String get companyPropertyLimitLabel =>
      _isEs ? 'Limite de propiedades' : 'Property limit';
  String companyPropertyLimitCount(int count) =>
      _isEs ? '$count propiedades' : '$count properties';
  String get companyPropertyLimitUnlimited => _isEs ? 'Ilimitado' : 'Unlimited';
  String get companyPropertiesUsedLabel =>
      _isEs ? 'Propiedades usadas' : 'Properties used';
  String get companyPropertiesRemainingLabel =>
      _isEs ? 'Propiedades restantes' : 'Properties remaining';
  String companyPropertyRemainingCount(int count) =>
      _isEs ? '$count restantes' : '$count remaining';
  String get companyPropertyRemainingUnlimited =>
      _isEs ? 'Ilimitadas' : 'Unlimited';
  String propertiesLimitAlmostReached(int remaining) => _isEs
      ? 'Tu limite de propiedades esta por alcanzarse. Te quedan $remaining.'
      : 'Your property limit is almost reached. You have $remaining left.';
  String get propertiesLimitReached => _isEs
      ? 'Has alcanzado el limite de propiedades de tu plan. Actualiza tu suscripcion para crear mas.'
      : 'You have reached your plan property limit. Upgrade your subscription to create more.';
  String get upgradeNow => _isEs ? 'Actualizar ahora' : 'Upgrade now';
  String get companyAddressLabel =>
      _isEs ? 'Direccion de empresa' : 'Company address';
  String get orgNumberLabel => _isEs ? 'Numero de organizacion' : 'Org number';
  String get taxIdLabel => _isEs ? 'ID fiscal' : 'Tax ID';
  String get companyServicesLabel =>
      _isEs ? 'Servicios ofrecidos' : 'Services offered';
  String get uploadCompanyLogo =>
      _isEs ? 'Subir logo de empresa' : 'Upload company logo';
  String get companyLogoUpdated =>
      _isEs ? 'Logo de empresa actualizado.' : 'Company logo updated.';
  String get saveCompany => _isEs ? 'Guardar empresa' : 'Save company';
  String get inviteWorkerToTeam =>
      _isEs ? 'Invitar trabajador al equipo' : 'Invite worker to team';
  String get inviteWorkerToTeamHelp => _isEs
      ? 'Agrega un trabajador por email para gestionarlo desde Empresa > Equipo.'
      : 'Add a worker by email so you can manage them from Company > Team.';
  String get employeeAccountsLimitReached => _isEs
      ? 'Has alcanzado el limite de cuentas de empleado de tu plan. Actualiza tu suscripcion para agregar mas empleados.'
      : 'Employee account limit reached for your subscription plan. Please upgrade to add more employees.';
  String get emailBelongsToAnotherCompany => _isEs
      ? 'Este email ya esta en uso por una cuenta de otra empresa.'
      : 'This email is already used by an account in another company.';
  String get accountExistsWithDifferentRole => _isEs
      ? 'Este email ya existe con un rol de cuenta incompatible.'
      : 'This email already exists with an incompatible account role.';
  String get workerInvitedToTeam =>
      _isEs ? 'Trabajador invitado al equipo.' : 'Worker invited to the team.';
  String get noTeamMembersYet =>
      _isEs ? 'Aun no hay miembros del equipo.' : 'No team members yet.';
  String get accessLevelOwner =>
      _isEs ? 'Acceso: Propietario' : 'Access: Owner';
  String get accessLevelAdmin =>
      _isEs ? 'Acceso: Administrador' : 'Access: Admin';
  String get accessLevelMember =>
      _isEs ? 'Acceso: Empleado' : 'Access: Employee';
  String get youSuffix => _isEs ? '(Tu)' : '(You)';
  String get manageTeamMember => _isEs ? 'Gestionar' : 'Manage';
  String get makeAdmin => _isEs ? 'Asignar como administrador' : 'Set as admin';
  String get makeEmployee =>
      _isEs ? 'Asignar como empleado' : 'Set as employee';
  String get removeWorker => _isEs ? 'Quitar trabajador' : 'Remove worker';
  String removeWorkerPrompt(String nameOrEmail) => _isEs
      ? 'Quitar a $nameOrEmail del equipo?'
      : 'Remove $nameOrEmail from team?';
  String get workerRemovedFromTeam =>
      _isEs ? 'Trabajador removido del equipo.' : 'Worker removed from team.';
  String get companyUpdated =>
      _isEs ? 'Empresa actualizada.' : 'Company updated.';
  String get adminGranted =>
      _isEs ? 'Permiso de administrador asignado.' : 'Admin access granted.';
  String get adminRevoked =>
      _isEs ? 'Permiso de administrador removido.' : 'Admin access removed.';

  String get timeline => _isEs ? 'Cronologia' : 'Timeline';
  String get lastVisit => _isEs ? 'Ultima visita' : 'Last visit';
  String propertyTimelineTitle(String name) =>
      _isEs ? 'Cronologia de $name' : '$name timeline';
  String get clientTimeline => _isEs ? 'Cronologia cliente' : 'Client timeline';
  String visitsCount(int count) => _isEs
      ? '$count ${count == 1 ? 'visita' : 'visitas'}'
      : '$count ${count == 1 ? 'visit' : 'visits'}';
  String get noVisitsYet => _isEs ? 'Aun no hay visitas' : 'No visits yet';
  String get visitsWillAppearHere => _isEs
      ? 'Las visitas enviadas por trabajadores apareceran aqui.'
      : 'Visits submitted by workers will appear here.';
  String get note => _isEs ? 'Nota' : 'Note';
  String get noNoteAdded => _isEs ? 'Sin nota agregada.' : 'No note added.';
  String get checklist => _isEs ? 'Checklist' : 'Checklist';
  String get photos => _isEs ? 'Fotos' : 'Photos';
  String get noPhotos => _isEs ? 'Sin fotos' : 'No photos';
  String get newVisit => _isEs ? 'Nueva visita' : 'New visit';
  String get filterCleaned => _isEs ? 'Filtro limpio' : 'Filter cleaned';
  String get chemicalsAdded => _isEs ? 'Quimicos agregados' : 'Chemicals added';
  String get vacuumed => _isEs ? 'Aspirado' : 'Vacuumed';
  String get gardenDone => _isEs ? 'Jardin listo' : 'Garden done';

  String get newVisitTitle => _isEs ? 'Nueva visita' : 'New visit';
  String get visitNoteLabel => _isEs ? 'Nota de visita' : 'Visit note';
  String get visitNoteHint => _isEs
      ? 'Que se hizo en esta visita?'
      : 'What was done during this visit?';
  String get visitServiceTypeLabel =>
      _isEs ? 'Servicio realizado' : 'Service performed';
  String get visitServiceTypeRequired =>
      _isEs ? 'Por favor selecciona un servicio.' : 'Please select a service.';
  String get serviceChecklistTitle =>
      _isEs ? 'Checklist del servicio' : 'Service checklist';
  String get selectServiceToLoadChecklist => _isEs
      ? 'Selecciona un servicio para ver su checklist.'
      : 'Select a service to load its checklist.';
  String get noCompletedServiceChecklistItems =>
      _isEs ? 'No hay items completados.' : 'No completed checklist items.';
  String get gallery => _isEs ? 'Galeria' : 'Gallery';
  String get camera => _isEs ? 'Camara' : 'Camera';
  String get retry => _isEs ? 'Reintentar' : 'Retry';
  String get noPhotosSelected =>
      _isEs ? 'No hay fotos seleccionadas.' : 'No photos selected.';
  String get submitVisit => _isEs ? 'Enviar visita' : 'Submit visit';
  String get sendVisitEmailToggle =>
      _isEs ? 'Enviar esta visita por email' : 'Email this visit report';
  String get sendVisitEmailHelp => _isEs
      ? 'Incluye nota, checklist y fotos para clientes que prefieren email.'
      : 'Includes note, checklist, and photos for clients who prefer email.';
  String get workerFallback => _isEs ? 'Trabajador' : 'Worker';
  String get networkFailureRetry =>
      _isEs ? 'Fallo de red. Reintenta.' : 'Network failure. Please retry.';
  String get permissionDeniedLibrary => _isEs
      ? 'Permiso denegado para la galeria.'
      : 'Permission denied for photo library.';
  String get couldNotPickImages =>
      _isEs ? 'No se pudieron seleccionar imagenes.' : 'Could not pick images.';
  String get permissionDeniedCamera => _isEs
      ? 'Permiso denegado para la camara.'
      : 'Permission denied for camera.';
  String get couldNotOpenCamera =>
      _isEs ? 'No se pudo abrir la camara.' : 'Could not open camera.';

  String get yourFeed => _isEs ? 'Tu feed' : 'Your feed';
  String get notifications => _isEs ? 'Notificaciones' : 'Notifications';
  String get noNotificationsYet =>
      _isEs ? 'Aun no hay notificaciones' : 'No notifications yet';
  String get markAllAsRead => _isEs ? 'Marcar todo como leido' : 'Mark all as read';
  String newVisitAtProperty(String propertyName) => _isEs
      ? 'Nueva visita en tu propiedad $propertyName'
      : 'New visit at your property $propertyName';
  String workerVisitedProperty(String workerName, String propertyName) => _isEs
      ? '$workerName visito $propertyName'
      : '$workerName visited $propertyName';
  String get youWord => _isEs ? 'Tu' : 'You';
  String get visitedPropertyPhrase =>
      _isEs ? 'visito la propiedad' : 'visited property';
  String get visitedYourProperty =>
      _isEs ? 'visito tu propiedad' : 'visited your property';
  String get visitedWord => _isEs ? 'visito' : 'visited';
  String visitedProperty(String propertyName) =>
      _isEs ? 'visito $propertyName' : 'visited $propertyName';
  String get noUpdatesYet => _isEs ? 'Aun no hay novedades' : 'No updates yet';
  String get feedEmptyHelp => _isEs
      ? 'Cuando tus propiedades asignadas reciban visitas, apareceran aqui.'
      : 'When your assigned properties get new visits, they appear here.';
  String get noVisitNote => _isEs ? 'Sin nota de visita.' : 'No visit note.';
  String get filter => _isEs ? 'Filtro' : 'Filter';
  String get chemicals => _isEs ? 'Quimicos' : 'Chemicals';
  String get vacuum => _isEs ? 'Aspirado' : 'Vacuum';
  String get garden => _isEs ? 'Jardin' : 'Garden';

  String get clientAccount => _isEs ? 'Cuenta cliente' : 'Client account';
  String assignedPropertiesCount(int count) => _isEs
      ? '$count ${count == 1 ? 'propiedad' : 'propiedades'}'
      : '$count properties';
  String get profileSettings =>
      _isEs ? 'Configuracion de perfil' : 'Profile settings';
  String get profilePhotoUrlLabel =>
      _isEs ? 'URL de foto de perfil' : 'Profile photo URL';
  String get profilePhotoUrlHint => _isEs ? 'https://...' : 'https://...';
  String get saveProfile => _isEs ? 'Guardar perfil' : 'Save profile';
  String get passwordSettings =>
      _isEs ? 'Cambiar contrasena' : 'Change password';
  String get oldPassword => _isEs ? 'Contrasena actual' : 'Old password';
  String get newPassword => _isEs ? 'Nueva contrasena' : 'New password';
  String get confirmNewPassword =>
      _isEs ? 'Confirmar nueva contrasena' : 'Confirm new password';
  String get updatePassword =>
      _isEs ? 'Actualizar contrasena' : 'Update password';
  String get profileUpdated =>
      _isEs ? 'Perfil actualizado.' : 'Profile updated.';
  String get passwordUpdated =>
      _isEs ? 'Contrasena actualizada.' : 'Password updated.';
  String get usernameRequired =>
      _isEs ? 'El usuario es requerido.' : 'Username is required.';
  String get firstNameRequired =>
      _isEs ? 'El nombre es requerido.' : 'First name is required.';
  String get newPasswordMinLength => _isEs
      ? 'La nueva contrasena debe tener al menos 8 caracteres.'
      : 'New password must be at least 8 characters.';
  String get passwordConfirmMismatch =>
      _isEs ? 'Las contrasenas no coinciden.' : 'Passwords do not match.';
  String get oldPasswordIncorrect => _isEs
      ? 'La contrasena actual es incorrecta.'
      : 'Old password is incorrect.';
  String get usernameAlreadyExists => _isEs
      ? 'Ese usuario ya existe. Elige otro.'
      : 'That username already exists. Choose another one.';
  String get sessionExpiredSignInAgain => _isEs
      ? 'Tu sesion expiro. Inicia sesion nuevamente.'
      : 'Your session has expired. Please sign in again.';
  String get userNotFound =>
      _isEs ? 'Usuario no encontrado.' : 'User not found.';
  String get uploadNotConfigured => _isEs
      ? 'La carga de imagenes no esta configurada.'
      : 'Image upload is not configured.';
  String get uploadUrlMissing => _isEs
      ? 'No se pudo iniciar la carga de imagen.'
      : 'Could not start image upload.';
  String get uploadPublicUrlUnavailable => _isEs
      ? 'La imagen se subio, pero la URL publica no esta disponible.'
      : 'Image uploaded, but the public URL is unavailable.';
  String get apiNotConfigured =>
      _isEs ? 'La API no esta configurada.' : 'API is not configured.';

  String get forceSpanishDebug =>
      _isEs ? 'Forzar espanol (debug)' : 'Force Spanish (debug)';
  String get forceSpanishDebugHelp => _isEs
      ? 'Activado: siempre espanol. Desactivado: idioma del dispositivo (EN por defecto salvo ES).'
      : 'On: always Spanish. Off: device language (EN by default unless ES).';

  String get somethingWentWrong =>
      _isEs ? 'Algo salio mal.' : 'Something went wrong.';

  String serviceTypeLabel(String id) {
    return switch (id) {
      'pool_cleaning' => _isEs ? 'Limpieza de piscina' : 'Pool cleaning',
      'garden_service' => _isEs ? 'Servicio de jardin' : 'Garden service',
      'general_cleaning' => _isEs ? 'Limpieza general' : 'General cleaning',
      'property_check' => _isEs ? 'Revision de propiedad' : 'Property check',
      'key_holding' => _isEs ? 'Custodia de llaves' : 'Key holding',
      'handyman' => _isEs ? 'Mantenimiento' : 'Handyman',
      'pest_control' => _isEs ? 'Control de plagas' : 'Pest control',
      'other' => _isEs ? 'Otro' : 'Other',
      _ => id,
    };
  }

  String serviceChecklistItemLabel(String id) {
    return switch (id) {
      'pool_filter_cleaned' =>
        _isEs ? 'Filtro de piscina limpio' : 'Pool filter cleaned',
      'pool_chemicals_added' =>
        _isEs ? 'Quimicos de piscina agregados' : 'Pool chemicals added',
      'pool_surface_skimmed' =>
        _isEs ? 'Superficie de piscina limpia' : 'Pool surface skimmed',
      'pool_vacuumed' => _isEs ? 'Piscina aspirada' : 'Pool vacuumed',
      'pool_water_level_checked' =>
        _isEs ? 'Nivel de agua revisado' : 'Pool water level checked',
      'garden_mowed' => _isEs ? 'Cesped cortado' : 'Garden mowed',
      'garden_hedges_trimmed' =>
        _isEs ? 'Setos podados' : 'Garden hedges trimmed',
      'garden_weeds_removed' =>
        _isEs ? 'Maleza removida' : 'Garden weeds removed',
      'garden_irrigation_checked' =>
        _isEs ? 'Riego revisado' : 'Garden irrigation checked',
      'cleaning_floors_done' => _isEs ? 'Pisos limpiados' : 'Floors cleaned',
      'cleaning_kitchen_done' => _isEs ? 'Cocina limpiada' : 'Kitchen cleaned',
      'cleaning_bathroom_done' => _isEs ? 'Bano limpiado' : 'Bathroom cleaned',
      'cleaning_trash_removed' => _isEs ? 'Basura retirada' : 'Trash removed',
      'property_visual_inspection' =>
        _isEs ? 'Inspeccion visual completada' : 'Visual inspection completed',
      'property_water_leaks_checked' =>
        _isEs ? 'Fugas de agua revisadas' : 'Water leaks checked',
      'property_electricity_checked' =>
        _isEs ? 'Electricidad revisada' : 'Electricity checked',
      'property_security_checked' =>
        _isEs ? 'Seguridad revisada' : 'Security checked',
      'key_entry_exit_logged' =>
        _isEs ? 'Entrada/salida registrada' : 'Entry/exit logged',
      'key_doors_windows_secured' =>
        _isEs ? 'Puertas/ventanas aseguradas' : 'Doors/windows secured',
      'key_alarm_checked' => _isEs ? 'Alarma revisada' : 'Alarm checked',
      'handyman_minor_repairs_done' =>
        _isEs ? 'Reparaciones menores realizadas' : 'Minor repairs done',
      'handyman_fixtures_checked' =>
        _isEs ? 'Instalaciones revisadas' : 'Fixtures checked',
      'handyman_tools_supplies_checked' =>
        _isEs ? 'Herramientas/insumos revisados' : 'Tools/supplies checked',
      'pest_traps_checked' => _isEs ? 'Trampas revisadas' : 'Traps checked',
      'pest_treatment_applied' =>
        _isEs ? 'Tratamiento aplicado' : 'Treatment applied',
      'pest_activity_logged' =>
        _isEs ? 'Actividad de plagas registrada' : 'Pest activity logged',
      'other_service_completed' =>
        _isEs ? 'Servicio completado' : 'Service completed',
      _ => id,
    };
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return locale.languageCode == 'en' || locale.languageCode == 'es';
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    final resolved = locale.languageCode == 'es'
        ? const Locale('es')
        : const Locale('en');
    return SynchronousFuture<AppLocalizations>(AppLocalizations(resolved));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}
