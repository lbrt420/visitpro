import { Router } from "express";
import bcrypt from "bcryptjs";
import Stripe from "stripe";

import { config } from "../config";
import type { AuthenticatedRequest } from "../middleware/auth";
import { authRequired, requireRole } from "../middleware/auth";
import type { InviteMailer } from "../mailer";
import CompanyModel from "../models/Company";
import PropertyModel from "../models/Property";
import UserModel from "../models/User";
import type { AppRedisClient } from "../redis";
import {
  applyStripeSubscriptionToCompany,
  createStripeClient,
  lineItemForPlanAndCycle,
  syncCompanySubscriptionFromStripe,
} from "../services/stripe_billing";

type CreateCompanyRouterOptions = {
  redis: AppRedisClient;
  inviteMailer: InviteMailer | null;
};

const allowedServiceTypes = new Set<string>([
  "pool_cleaning",
  "garden_service",
  "general_cleaning",
  "property_check",
  "key_holding",
  "handyman",
  "pest_control",
  "other",
]);
const allowedBillingPlans = new Set<string>(["starter", "growth", "pro"]);
const allowedClientRanges = new Set<string>(["0-15", "16-40", "41+"]);
const allowedBillingCycles = new Set<string>(["monthly", "yearly"]);

function propertyLimitForPlan(plan: string): number | null {
  switch (
    String(plan || "")
      .trim()
      .toLowerCase()
  ) {
    case "starter":
      return 20;
    case "growth":
      return 60;
    case "pro":
      return null;
    default:
      return null;
  }
}

function employeeLimitForPlan(plan: string): number | null {
  switch (String(plan || "").trim().toLowerCase()) {
    case "starter":
      return 1;
    case "growth":
      return 5;
    case "pro":
      return null;
    default:
      return null;
  }
}

async function assertCanAddEmployeeForCompany(companyId: string) {
  const company = await CompanyModel.findById(companyId).select("billingPlan").lean();
  if (!company) {
    throw new Error("Company not found");
  }
  const limit = employeeLimitForPlan(String((company as any).billingPlan || ""));
  if (limit == null) {
    return;
  }
  const workersCount = await UserModel.countDocuments({
    companyId: companyId as any,
    role: "worker",
    isActive: true,
  });
  if (workersCount >= limit) {
    throw new Error(
      "Employee account limit reached for your subscription plan. Please upgrade to add more employees.",
    );
  }
}

function hasCompanyManagementAccess(req: AuthenticatedRequest): boolean {
  const auth = req.auth;
  if (!auth) {
    return false;
  }
  if (auth.role === "owner") {
    return true;
  }
  return (
    auth.companyAccessLevel === "owner" || auth.companyAccessLevel === "admin"
  );
}

export function createCompanyRouter(
  options: CreateCompanyRouterOptions,
): Router {
  const router = Router();
  const { redis, inviteMailer } = options;
  const stripe = createStripeClient();

  router.get(
    "/me",
    authRequired(redis),
    requireRole(["owner", "worker"]),
    async (req: AuthenticatedRequest, res) => {
      const auth = req.auth;
      if (!auth || !auth.companyId) {
        return res.status(401).json({ error: "Unauthorized" });
      }
      const company = await CompanyModel.findById(auth.companyId);
      if (!company) {
        return res.status(404).json({ error: "Company not found" });
      }
      await syncCompanySubscriptionFromStripe(company, stripe);
      const me = await UserModel.findById(auth.userId).lean();
      if (!me) {
        return res.status(404).json({ error: "User not found" });
      }
      const billingPlan = String((company as any).billingPlan || "")
        .trim()
        .toLowerCase();
      const propertiesLimit = propertyLimitForPlan(billingPlan);
      const propertiesUsed = await PropertyModel.countDocuments({
        companyId: auth.companyId,
      });
      const propertiesRemaining =
        propertiesLimit == null
          ? null
          : Math.max(propertiesLimit - propertiesUsed, 0);

      return res.json({
        company: {
          id: String(company._id || ""),
          name: String(company.name || ""),
          address: String(company.address || ""),
          orgNumber: String(company.orgNumber || ""),
          taxId: String(company.taxId || ""),
          logoUrl: String(company.logoUrl || ""),
          servicesOffered: Array.isArray((company as any).servicesOffered)
            ? (company as any).servicesOffered.filter(
                (item: unknown) => typeof item === "string",
              )
            : [],
          billingPlan,
          billingCycle: String((company as any).billingCycle || "yearly")
            .trim()
            .toLowerCase(),
          subscriptionStatus: String(
            (company as any).subscriptionStatus || "inactive",
          )
            .trim()
            .toLowerCase(),
          propertiesLimit,
          propertiesUsed,
          propertiesRemaining,
          canCreateProperty:
            propertiesLimit == null ? true : propertiesUsed < propertiesLimit,
        },
        me: {
          id: String(me._id),
          name: me.name,
          email: me.email,
          role: me.role,
          companyAccessLevel: me.companyAccessLevel || "member",
        },
      });
    },
  );

  router.patch(
    "/",
    authRequired(redis),
    requireRole(["owner", "worker"]),
    async (req: AuthenticatedRequest, res) => {
      const auth = req.auth;
      if (!auth || !auth.companyId) {
        return res.status(401).json({ error: "Unauthorized" });
      }
      if (!hasCompanyManagementAccess(req)) {
        return res.status(403).json({ error: "Forbidden" });
      }

      const nameRaw = req.body?.name;
      const addressRaw = req.body?.address;
      const orgNumberRaw = req.body?.orgNumber;
      const taxIdRaw = req.body?.taxId;
      const logoUrlRaw = req.body?.logoUrl;
      const servicesOfferedRaw = req.body?.servicesOffered;
      const company = await CompanyModel.findById(auth.companyId);
      if (!company) {
        return res.status(404).json({ error: "Company not found" });
      }
      if (typeof nameRaw === "string") {
        const name = nameRaw.trim();
        if (!name) {
          return res.status(400).json({ error: "Company name is required" });
        }
        company.name = name;
      }
      if (typeof addressRaw === "string") {
        company.address = addressRaw.trim();
      }
      if (typeof orgNumberRaw === "string") {
        company.orgNumber = orgNumberRaw.trim();
      }
      if (typeof taxIdRaw === "string") {
        company.taxId = taxIdRaw.trim();
      }
      if (typeof logoUrlRaw === "string") {
        company.logoUrl = logoUrlRaw.trim();
      }
      if (Array.isArray(servicesOfferedRaw)) {
        const normalized = Array.from(
          new Set(
            servicesOfferedRaw
              .map((item) => String(item || "").trim())
              .filter((item) => allowedServiceTypes.has(item)),
          ),
        );
        company.servicesOffered = normalized;
      }
      await company.save();
      return res.json({
        company: {
          id: String(company._id),
          name: company.name,
          address: company.address || "",
          orgNumber: company.orgNumber || "",
          taxId: company.taxId || "",
          logoUrl: company.logoUrl || "",
          servicesOffered: company.servicesOffered || [],
        },
      });
    },
  );

  router.get(
    "/team",
    authRequired(redis),
    requireRole(["owner", "worker"]),
    async (req: AuthenticatedRequest, res) => {
      const auth = req.auth;
      if (!auth || !auth.companyId) {
        return res.status(401).json({ error: "Unauthorized" });
      }
      if (!hasCompanyManagementAccess(req)) {
        return res.status(403).json({ error: "Forbidden" });
      }

      const users = await UserModel.find({
        companyId: auth.companyId,
        role: { $in: ["owner", "worker"] },
      })
        .sort({ role: 1, name: 1 })
        .lean();

      return res.json({
        members: users.map((user) => ({
          id: String(user._id),
          name: user.name,
          email: user.email,
          role: user.role,
          companyAccessLevel:
            user.companyAccessLevel ||
            (user.role === "owner" ? "owner" : "member"),
        })),
      });
    },
  );

  router.patch(
    "/team/:userId/access-level",
    authRequired(redis),
    requireRole(["owner", "worker"]),
    async (req: AuthenticatedRequest, res) => {
      const auth = req.auth;
      if (!auth || !auth.companyId) {
        return res.status(401).json({ error: "Unauthorized" });
      }
      // Owner-only for security and to avoid circular privilege escalation.
      if (auth.companyAccessLevel !== "owner") {
        return res
          .status(403)
          .json({ error: "Only company owner can change admin access" });
      }

      const userId = String(req.params.userId || "").trim();
      const accessLevel = String(req.body?.accessLevel || "")
        .trim()
        .toLowerCase();
      if (!userId || !["admin", "member"].includes(accessLevel)) {
        return res
          .status(400)
          .json({ error: "userId and valid accessLevel are required" });
      }

      const target = await UserModel.findById(userId);
      if (!target || String(target.companyId || "") !== auth.companyId) {
        return res.status(404).json({ error: "Team member not found" });
      }
      if (target.role !== "worker") {
        return res
          .status(400)
          .json({ error: "Only workers can be promoted or demoted as admin" });
      }

      target.companyAccessLevel = accessLevel as "admin" | "member";
      await target.save();

      return res.json({
        member: {
          id: String(target._id),
          name: target.name,
          email: target.email,
          role: target.role,
          companyAccessLevel: target.companyAccessLevel,
        },
      });
    },
  );

  router.post(
    "/team/invite-worker",
    authRequired(redis),
    requireRole(["owner", "worker"]),
    async (req: AuthenticatedRequest, res) => {
      const auth = req.auth;
      if (!auth || !auth.companyId) {
        return res.status(401).json({ error: "Unauthorized" });
      }
      if (!hasCompanyManagementAccess(req)) {
        return res.status(403).json({ error: "Forbidden" });
      }

      const email = String(req.body?.email || "")
        .trim()
        .toLowerCase();
      const name =
        String(req.body?.name || "").trim() || email.split("@")[0] || "Worker";
      const password = String(req.body?.password || "").trim();
      if (!email) {
        return res.status(400).json({ error: "email is required" });
      }

      const company = await CompanyModel.findById(auth.companyId).lean();
      if (!company) {
        return res.status(404).json({ error: "Company not found" });
      }

      let user = await UserModel.findOne({ email });
      let temporaryPassword: string | undefined;
      if (!user) {
        try {
          await assertCanAddEmployeeForCompany(auth.companyId);
        } catch (error) {
          return res.status(402).json({
            error:
              error instanceof Error
                ? error.message
                : "Employee account limit reached for your subscription plan.",
          });
        }
        temporaryPassword =
          password || Math.random().toString(36).slice(-10) + "A1!";
        const passwordHash = await bcrypt.hash(temporaryPassword, 10);
        user = await UserModel.create({
          companyId: auth.companyId,
          role: "worker",
          companyAccessLevel: "member",
          name,
          email,
          passwordHash,
        });
      } else {
        if (user.role !== "worker" && user.role !== "owner") {
          return res
            .status(400)
            .json({ error: "User exists with a non-worker role" });
        }
        if (String(user.companyId || "") !== auth.companyId) {
          return res
            .status(409)
            .json({ error: "This email is already used by an account in another company." });
        }
        if (!user.companyAccessLevel) {
          user.companyAccessLevel = user.role === "owner" ? "owner" : "member";
          await user.save();
        }
      }

      let emailSent = false;
      if (inviteMailer) {
        try {
          await inviteMailer.sendWorkerInvite({
            toEmail: email,
            workerName: user.name || name,
            companyName: company.name,
            invitedByName: auth.name || company.name,
            temporaryPassword,
          });
          emailSent = true;
        } catch (error) {
          console.error("Failed to send worker invite email:", error);
        }
      }

      return res.json({
        ok: true,
        userId: String(user._id),
        emailSent,
      });
    },
  );

  router.delete(
    "/team/:userId",
    authRequired(redis),
    requireRole(["owner", "worker"]),
    async (req: AuthenticatedRequest, res) => {
      const auth = req.auth;
      if (!auth || !auth.companyId) {
        return res.status(401).json({ error: "Unauthorized" });
      }
      if (!hasCompanyManagementAccess(req)) {
        return res.status(403).json({ error: "Forbidden" });
      }

      const userId = String(req.params.userId || "").trim();
      if (!userId) {
        return res.status(400).json({ error: "userId is required" });
      }

      const target = await UserModel.findById(userId);
      if (!target || String(target.companyId || "") !== auth.companyId) {
        return res.status(404).json({ error: "Team member not found" });
      }
      if (target.role !== "worker") {
        return res
          .status(400)
          .json({ error: "Only workers can be removed from team" });
      }
      if (String(target._id) === auth.userId) {
        return res
          .status(400)
          .json({ error: "You cannot remove your own account" });
      }

      await target.deleteOne();
      return res.json({ ok: true });
    },
  );

  router.post(
    "/billing/start-trial",
    authRequired(redis),
    requireRole(["owner", "worker"]),
    async (req: AuthenticatedRequest, res) => {
      const auth = req.auth;
      if (!auth || !auth.companyId) {
        return res.status(401).json({ error: "Unauthorized" });
      }

      const plan = String(req.body?.plan || "")
        .trim()
        .toLowerCase();
      const clientRange = String(req.body?.clientRange || "").trim();
      const billingCycle = String(req.body?.billingCycle || "yearly")
        .trim()
        .toLowerCase();
      if (
        !allowedBillingPlans.has(plan) ||
        !allowedClientRanges.has(clientRange) ||
        !allowedBillingCycles.has(billingCycle)
      ) {
        return res.status(400).json({ error: "Invalid billing selection" });
      }

      const company = await CompanyModel.findById(auth.companyId);
      if (!company) {
        return res.status(404).json({ error: "Company not found" });
      }

      if (!stripe) {
        return res.status(503).json({ error: "Stripe is not configured" });
      }
      const lineItem = lineItemForPlanAndCycle(plan, billingCycle);
      if (!lineItem) {
        return res
          .status(503)
          .json({ error: "Stripe price is not configured for this plan" });
      }
      const returnUrlRaw = String(req.body?.returnUrl || "").trim();
      const fallbackReturnUrl = `${config.appPublicUrl.replace(/\/$/, "")}/#/onboarding/company`;
      const returnUrl =
        /^https?:\/\//i.test(returnUrlRaw) && returnUrlRaw.length > 0
          ? returnUrlRaw
          : fallbackReturnUrl;
      const separator = returnUrl.includes("?") ? "&" : "?";
      const successUrl = `${returnUrl}${separator}stripe=success&session_id={CHECKOUT_SESSION_ID}`;
      const cancelUrl = `${returnUrl}${separator}stripe=cancel`;

      let stripeCustomerId = String(
        (company as any).stripeCustomerId || "",
      ).trim();
      if (!stripeCustomerId) {
        const me = await UserModel.findById(auth.userId).lean();
        const customer = await stripe.customers.create({
          email: me?.email || undefined,
          name: company.name || undefined,
          metadata: { companyId: auth.companyId },
        });
        stripeCustomerId = customer.id;
        (company as any).stripeCustomerId = stripeCustomerId;
      }

      const session = await stripe.checkout.sessions.create({
        mode: "subscription",
        customer: stripeCustomerId,
        line_items: [lineItem],
        subscription_data: {
          trial_period_days: Number(process.env.STRIPE_TRIAL_PERIOD_DAYS || 14),
          metadata: {
            companyId: auth.companyId,
            billingPlan: plan,
            billingCycle,
            billingClientRange: clientRange,
          },
        },
        metadata: {
          companyId: auth.companyId,
          billingPlan: plan,
          billingCycle,
          billingClientRange: clientRange,
        },
        success_url: successUrl,
        cancel_url: cancelUrl,
      });

      (company as any).billingPlan = plan;
      (company as any).billingCycle = billingCycle;
      (company as any).billingClientRange = clientRange;
      (company as any).subscriptionStatus = "incomplete";
      await company.save();

      return res.json({
        status: "checkout_required",
        checkoutUrl: session.url || "",
        sessionId: session.id,
      });
    },
  );

  router.post(
    "/billing/confirm-checkout",
    authRequired(redis),
    requireRole(["owner", "worker"]),
    async (req: AuthenticatedRequest, res) => {
      const auth = req.auth;
      if (!auth || !auth.companyId) {
        return res.status(401).json({ error: "Unauthorized" });
      }
      if (!stripe) {
        return res.status(503).json({ error: "Stripe is not configured" });
      }
      const sessionId = String(req.body?.sessionId || "").trim();
      if (!sessionId) {
        return res.status(400).json({ error: "sessionId is required" });
      }

      const company = await CompanyModel.findById(auth.companyId);
      if (!company) {
        return res.status(404).json({ error: "Company not found" });
      }

      const checkoutSession = await stripe.checkout.sessions.retrieve(
        sessionId,
        {
          expand: ["subscription"],
        },
      );
      if (
        !checkoutSession ||
        checkoutSession.mode !== "subscription" ||
        String(checkoutSession.metadata?.companyId || "") !== auth.companyId
      ) {
        return res.status(400).json({ error: "Invalid checkout session" });
      }
      if (checkoutSession.status !== "complete") {
        return res.status(400).json({ error: "Checkout is not complete yet" });
      }

      const checkoutSubscription = checkoutSession.subscription as
        | Stripe.Subscription
        | string
        | null;
      const subscriptionId =
        typeof checkoutSubscription === "string"
          ? checkoutSubscription
          : typeof checkoutSubscription?.id === "string"
            ? checkoutSubscription.id
            : "";
      if (!subscriptionId) {
        return res
          .status(400)
          .json({ error: "Stripe subscription was not created" });
      }
      const subscription =
        typeof checkoutSubscription === "string"
          ? await stripe.subscriptions.retrieve(checkoutSubscription, {
              expand: ["items.data.price"],
            })
          : checkoutSubscription;
      if (!subscription) {
        return res
          .status(400)
          .json({ error: "Stripe subscription was not created" });
      }
      applyStripeSubscriptionToCompany(company, subscription);
      await company.save();

      return res.json({
        status: (company as any).subscriptionStatus || "active",
        billingPlan: String((company as any).billingPlan || "")
          .trim()
          .toLowerCase(),
        billingCycle: String((company as any).billingCycle || "yearly")
          .trim()
          .toLowerCase(),
      });
    },
  );

  router.post(
    "/billing/portal-session",
    authRequired(redis),
    requireRole(["owner", "worker"]),
    async (req: AuthenticatedRequest, res) => {
      const auth = req.auth;
      if (!auth || !auth.companyId) {
        return res.status(401).json({ error: "Unauthorized" });
      }
      if (!stripe) {
        return res.status(503).json({ error: "Stripe is not configured" });
      }
      const company = await CompanyModel.findById(auth.companyId);
      if (!company) {
        return res.status(404).json({ error: "Company not found" });
      }
      let stripeCustomerId = String((company as any).stripeCustomerId || "").trim();
      if (!stripeCustomerId) {
        const me = await UserModel.findById(auth.userId).lean();
        const customer = await stripe.customers.create({
          email: me?.email || undefined,
          name: company.name || undefined,
          metadata: { companyId: auth.companyId },
        });
        stripeCustomerId = customer.id;
        (company as any).stripeCustomerId = stripeCustomerId;
        await company.save();
      }
      if (!stripeCustomerId) {
        return res.status(400).json({ error: "Missing Stripe customer" });
      }

      const returnUrlRaw = String(req.body?.returnUrl || "").trim();
      const fallbackReturnUrl = `${config.appPublicUrl.replace(/\/$/, "")}/#/company?tab=3`;
      const returnUrl =
        /^https?:\/\//i.test(returnUrlRaw) && returnUrlRaw.length > 0
          ? returnUrlRaw
          : fallbackReturnUrl;
      const portalSession = await stripe.billingPortal.sessions.create({
        customer: stripeCustomerId,
        return_url: returnUrl,
        ...(config.stripeBillingPortalConfigurationId
          ? { configuration: config.stripeBillingPortalConfigurationId }
          : {}),
      });
      return res.json({ url: portalSession.url });
    },
  );

  return router;
}
