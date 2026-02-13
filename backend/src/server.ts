import cors from 'cors';
import express from 'express';
import mongoose from 'mongoose';

import { config } from './config';
import { connectMongo } from './db';
import { createInviteMailer } from './mailer';
import { connectRedis } from './redis';
import { createAuthRouter } from './routes/auth';
import { createPropertiesRouter } from './routes/properties';
import { createShareRouter } from './routes/share';
import { createUploadsRouter } from './routes/uploads';
import { createCompanyRouter } from './routes/company';
import { createStripeWebhookRouter } from './routes/stripe';
import { createNotificationsRouter } from './routes/notifications';
import { createStripeClient } from './services/stripe_billing';

async function bootstrap() {
  await connectMongo(config.mongoUri);
  const redis = await connectRedis(config.redisUrl);
  const inviteMailer = createInviteMailer({
    host: config.smtpHost,
    port: config.smtpPort,
    secure: config.smtpSecure,
    user: config.smtpUser,
    pass: config.smtpPass,
    fromEmail: config.smtpFromEmail,
    fromName: config.smtpFromName,
    brandName: config.appBrandName,
    appUrl: config.appPublicUrl,
    appLogoUrl: config.appLogoUrl,
  });

  const app = express();
  app.use(cors({ origin: config.corsOrigin }));
  const stripe = createStripeClient();
  if (stripe && config.stripeWebhookSecret) {
    app.use('/stripe', createStripeWebhookRouter({ stripe, webhookSecret: config.stripeWebhookSecret }));
  }
  app.use(express.json({ limit: '2mb' }));

  app.get('/health', (_req, res) => {
    res.json({
      ok: true,
      mongoState: mongoose.connection.readyState,
      uptimeSeconds: Math.round(process.uptime()),
    });
  });

  app.use(
    '/auth',
    createAuthRouter({
      redis,
      sessionTtlSeconds: config.sessionTtlSeconds,
    }),
  );
  app.use('/properties', createPropertiesRouter({ redis, inviteMailer }));
  app.use('/company', createCompanyRouter({ redis, inviteMailer }));
  app.use(
    '/uploads',
    createUploadsRouter({
      redis,
      cloudflareAccountId: config.cloudflareAccountId,
      cloudflareApiToken: config.cloudflareApiToken,
      cloudflareImagesApiBase: config.cloudflareImagesApiBase,
      cloudflareImagesDeliveryBase: config.cloudflareImagesDeliveryBase,
    }),
  );
  app.use('/share', createShareRouter());
  app.use('/notifications', createNotificationsRouter({ redis }));

  app.use((error: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    console.error(error);
    res.status(500).json({ error: 'Internal server error' });
  });

  app.listen(config.port, () => {
    console.log(`Backend listening on http://localhost:${config.port}`);
  });
}

bootstrap().catch((error) => {
  console.error('Failed to start backend:', error);
  process.exit(1);
});
