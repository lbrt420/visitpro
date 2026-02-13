import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: Number(process.env.PORT || 4000),
  corsOrigin: process.env.CORS_ORIGIN || '*',
  mongoUri: process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/visitapro',
  redisUrl: process.env.REDIS_URL || 'redis://127.0.0.1:6379',
  sessionTtlSeconds: Number(process.env.SESSION_TTL_SECONDS || 60 * 60 * 24 * 7),
  smtpHost: process.env.SMTP_HOST || '',
  smtpPort: Number(process.env.SMTP_PORT || 465),
  smtpSecure: String(process.env.SMTP_SECURE || 'true').toLowerCase() !== 'false',
  smtpUser: process.env.SMTP_USER || '',
  smtpPass: process.env.SMTP_PASS || '',
  smtpFromEmail: process.env.SMTP_FROM_EMAIL || '',
  smtpFromName: process.env.SMTP_FROM_NAME || 'visitpro',
  appBrandName:
    process.env.APP_BRAND_NAME ||
    process.env.APP_BRAND_LABEL ||
    process.env.SMTP_FROM_NAME ||
    'visitpro',
  appPublicUrl: process.env.APP_PUBLIC_URL || 'http://localhost:3000',
  appLogoUrl: process.env.APP_LOGO_URL || '',
  cloudflareAccountId: process.env.CLOUDFLARE_ACCOUNT_ID || '',
  cloudflareApiToken: process.env.CLOUDFLARE_API_TOKEN || '',
  cloudflareImagesApiBase:
    process.env.CLOUDFLARE_IMAGES_API_BASE ||
    'https://api.cloudflare.com/client/v4',
  cloudflareImagesDeliveryBase: process.env.CLOUDFLARE_IMAGES_DELIVERY_BASE || '',
  stripeSecretKey: process.env.STRIPE_SECRET_KEY || '',
  stripeStarterMonthlyPriceId: process.env.STRIPE_PRICE_STARTER_MONTHLY || '',
  stripeStarterYearlyPriceId: process.env.STRIPE_PRICE_STARTER_YEARLY || '',
  stripeGrowthMonthlyPriceId: process.env.STRIPE_PRICE_GROWTH_MONTHLY || '',
  stripeGrowthYearlyPriceId: process.env.STRIPE_PRICE_GROWTH_YEARLY || '',
  stripeProMonthlyPriceId: process.env.STRIPE_PRICE_PRO_MONTHLY || '',
  stripeProYearlyPriceId: process.env.STRIPE_PRICE_PRO_YEARLY || '',
  stripeBillingPortalConfigurationId:
    process.env.STRIPE_BILLING_PORTAL_CONFIGURATION_ID || '',
  stripeWebhookSecret: process.env.STRIPE_WEBHOOK_SECRET || '',
  firebaseServiceAccountJson: process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '',
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || '',
  firebaseClientEmail: process.env.FIREBASE_CLIENT_EMAIL || '',
  firebasePrivateKey: process.env.FIREBASE_PRIVATE_KEY || '',
};
