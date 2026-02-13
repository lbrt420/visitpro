import Stripe from 'stripe';

import { config } from '../config';

const allowedBillingPlans = new Set<string>(['starter', 'growth', 'pro']);
const allowedClientRanges = new Set<string>(['0-15', '16-40', '41+']);

function planCycleFromConfiguredPrice(priceId: string): { plan: string; billingCycle: string } | null {
  const normalized = String(priceId || '').trim();
  if (!normalized) {
    return null;
  }
  if (normalized === config.stripeStarterMonthlyPriceId) {
    return { plan: 'starter', billingCycle: 'monthly' };
  }
  if (normalized === config.stripeStarterYearlyPriceId) {
    return { plan: 'starter', billingCycle: 'yearly' };
  }
  if (normalized === config.stripeGrowthMonthlyPriceId) {
    return { plan: 'growth', billingCycle: 'monthly' };
  }
  if (normalized === config.stripeGrowthYearlyPriceId) {
    return { plan: 'growth', billingCycle: 'yearly' };
  }
  if (normalized === config.stripeProMonthlyPriceId) {
    return { plan: 'pro', billingCycle: 'monthly' };
  }
  if (normalized === config.stripeProYearlyPriceId) {
    return { plan: 'pro', billingCycle: 'yearly' };
  }
  return null;
}

export function createStripeClient(): Stripe | null {
  if (!config.stripeSecretKey) {
    return null;
  }
  return new Stripe(config.stripeSecretKey, { apiVersion: '2026-01-28.clover' });
}

export function lineItemForPlanAndCycle(
  plan: string,
  billingCycle: string,
): Stripe.Checkout.SessionCreateParams.LineItem | null {
  const normalizedPlan = String(plan || '').trim().toLowerCase();
  const normalizedCycle = String(billingCycle || '').trim().toLowerCase();
  const configuredPriceId =
    normalizedPlan === 'starter'
      ? normalizedCycle === 'yearly'
        ? config.stripeStarterYearlyPriceId
        : config.stripeStarterMonthlyPriceId
      : normalizedPlan === 'growth'
        ? normalizedCycle === 'yearly'
          ? config.stripeGrowthYearlyPriceId
          : config.stripeGrowthMonthlyPriceId
        : normalizedPlan === 'pro'
          ? normalizedCycle === 'yearly'
            ? config.stripeProYearlyPriceId
            : config.stripeProMonthlyPriceId
          : '';

  const normalizedConfigured = String(configuredPriceId || '').trim();
  if (normalizedConfigured.startsWith('price_')) {
    return { price: normalizedConfigured, quantity: 1 };
  }

  const numericAmount = Number(normalizedConfigured);
  if (!Number.isFinite(numericAmount) || numericAmount <= 0) {
    return null;
  }
  const planLabel =
    normalizedPlan === 'starter' ? 'Starter' : normalizedPlan === 'growth' ? 'Growth' : 'Pro';
  const cycleLabel = normalizedCycle === 'yearly' ? 'Yearly' : 'Monthly';

  return {
    quantity: 1,
    price_data: {
      currency: 'eur',
      unit_amount: Math.round(numericAmount * 100),
      recurring: { interval: normalizedCycle === 'yearly' ? 'year' : 'month' },
      product_data: {
        name: `${config.appBrandName} ${planLabel} (${cycleLabel})`,
      },
    },
  };
}

export function applyStripeSubscriptionToCompany(
  company: any,
  subscription: Stripe.Subscription,
): void {
  const subscriptionStatus = String(subscription.status || '').trim().toLowerCase();
  const metadataPlan = String(subscription.metadata?.billingPlan || '')
    .trim()
    .toLowerCase();
  const metadataCycle = String(subscription.metadata?.billingCycle || '')
    .trim()
    .toLowerCase();
  const metadataRange = String(subscription.metadata?.billingClientRange || '').trim();
  const firstPrice = subscription.items.data[0]?.price;
  const firstPriceId = String(firstPrice?.id || '').trim();
  const mappedFromPrice = planCycleFromConfiguredPrice(firstPriceId);
  const interval = String(firstPrice?.recurring?.interval || '')
    .trim()
    .toLowerCase();

  // Source of truth is the current Stripe subscription price.
  // Metadata can be stale after plan changes in Billing Portal.
  const billingPlan = mappedFromPrice?.plan ??
    (allowedBillingPlans.has(metadataPlan) ? metadataPlan : '');
  const billingCycle = mappedFromPrice?.billingCycle ??
    (metadataCycle === 'monthly' || metadataCycle === 'yearly'
      ? metadataCycle
      : (interval === 'year' ? 'yearly' : interval === 'month' ? 'monthly' : 'yearly'));
  const trialEndsAt =
    typeof subscription.trial_end === 'number' && subscription.trial_end > 0
      ? new Date(subscription.trial_end * 1000)
      : null;

  (company as any).stripeCustomerId = String(subscription.customer || '').trim();
  (company as any).stripeSubscriptionId = String(subscription.id || '').trim();
  (company as any).subscriptionStatus = subscriptionStatus || 'active';
  (company as any).trialEndsAt = trialEndsAt;
  if (billingPlan) {
    (company as any).billingPlan = billingPlan;
  }
  (company as any).billingCycle = billingCycle;
  if (allowedClientRanges.has(metadataRange)) {
    (company as any).billingClientRange = metadataRange;
  }
}

export async function syncCompanySubscriptionFromStripe(
  company: any,
  stripe: Stripe | null,
): Promise<void> {
  if (!stripe || !company) {
    return;
  }
  let subscriptionId = String((company as any).stripeSubscriptionId || '').trim();
  const stripeCustomerId = String((company as any).stripeCustomerId || '').trim();

  if (!subscriptionId && stripeCustomerId) {
    const listed = await stripe.subscriptions.list({
      customer: stripeCustomerId,
      status: 'all',
      limit: 1,
    });
    if (listed.data.length > 0) {
      subscriptionId = String(listed.data[0]?.id || '').trim();
    }
  }
  if (!subscriptionId) {
    return;
  }

  const subscription = await stripe.subscriptions.retrieve(subscriptionId, {
    expand: ['items.data.price'],
  });
  applyStripeSubscriptionToCompany(company, subscription);
  await company.save();
}
