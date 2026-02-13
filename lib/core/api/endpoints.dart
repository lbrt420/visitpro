class Endpoints {
  static const login = '/auth/login';
  static const signupCompany = '/auth/signup-company';
  static const logout = '/auth/logout';
  static const me = '/auth/me';
  static const profile = '/auth/profile';
  static const changePassword = '/auth/change-password';
  static const notificationsToken = '/notifications/token';
  static const notificationsTest = '/notifications/test';
  static const company = '/company';
  static const companyMe = '/company/me';
  static const companyTeam = '/company/team';
  static const companyBillingStartTrial = '/company/billing/start-trial';
  static const companyBillingConfirmCheckout = '/company/billing/confirm-checkout';
  static const companyBillingPortalSession = '/company/billing/portal-session';
  static const companyTeamInviteWorker = '/company/team/invite-worker';
  static const properties = '/properties';
  static const uploadsSign = '/uploads/sign';

  static String visitsByProperty(String propertyId) {
    return '/properties/$propertyId/visits';
  }

  static String visitReactions(String propertyId, String visitId) {
    return '/properties/$propertyId/visits/$visitId/reactions';
  }

  static String inviteWorker(String propertyId) {
    return '/properties/$propertyId/invite-worker';
  }

  static String inviteClient(String propertyId) {
    return '/properties/$propertyId/invite-client';
  }

  static String removeClientFromProperty(String propertyId, String clientUserId) {
    return '/properties/$propertyId/clients/$clientUserId';
  }

  static String companyTeamAccessLevel(String userId) {
    return '/company/team/$userId/access-level';
  }

  static String companyTeamMember(String userId) {
    return '/company/team/$userId';
  }

  static String shareVisits(String token) {
    return '/share/$token/visits';
  }
}
