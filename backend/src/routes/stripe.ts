import express from 'express';
import Stripe from 'stripe';

import CompanyModel from '../models/Company';
import { applyStripeSubscriptionToCompany } from '../services/stripe_billing';

type CreateStripeWebhookRouterOptions = {
  stripe: Stripe;
  webhookSecret: string;
};

export function createStripeWebhookRouter(options: CreateStripeWebhookRouterOptions): express.Router {
  const router = express.Router();
  const { stripe, webhookSecret } = options;

  router.post(
    '/webhook',
    express.raw({ type: 'application/json' }),
    async (req: express.Request, res: express.Response) => {
      const signature = req.headers['stripe-signature'];
      if (!signature || typeof signature !== 'string') {
        return res.status(400).send('Missing stripe-signature header');
      }

      let event: Stripe.Event;
      try {
        event = stripe.webhooks.constructEvent(req.body, signature, webhookSecret);
      } catch (error) {
        return res.status(400).send(`Webhook signature verification failed: ${(error as Error).message}`);
      }

      try {
        if (event.type === 'checkout.session.completed') {
          const session = event.data.object as Stripe.Checkout.Session;
          if (session.mode === 'subscription' && session.subscription) {
            const companyId = String(session.metadata?.companyId || '').trim();
            const customerId =
              typeof session.customer === 'string' ? session.customer : String(session.customer?.id || '');
            const company =
              (companyId
                ? await CompanyModel.findById(companyId)
                : await CompanyModel.findOne({ stripeCustomerId: customerId })) || null;
            if (company) {
              const subscription = await stripe.subscriptions.retrieve(String(session.subscription), {
                expand: ['items.data.price'],
              });
              applyStripeSubscriptionToCompany(company, subscription);
              await company.save();
            }
          }
        }

        if (
          event.type === 'customer.subscription.created' ||
          event.type === 'customer.subscription.updated' ||
          event.type === 'customer.subscription.deleted'
        ) {
          const subscription = event.data.object as Stripe.Subscription;
          const companyId = String(subscription.metadata?.companyId || '').trim();
          const customerId = String(subscription.customer || '').trim();
          const company =
            (companyId
              ? await CompanyModel.findById(companyId)
              : await CompanyModel.findOne({
                  $or: [{ stripeSubscriptionId: String(subscription.id || '').trim() }, { stripeCustomerId: customerId }],
                })) || null;
          if (company) {
            applyStripeSubscriptionToCompany(company, subscription);
            await company.save();
          }
        }

        return res.json({ received: true });
      } catch (error) {
        return res.status(500).json({ error: (error as Error).message || 'Webhook processing failed' });
      }
    },
  );

  return router;
}
