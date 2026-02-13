import { randomBytes } from 'crypto';

import { Router } from 'express';
import bcrypt from 'bcryptjs';

import type { AuthenticatedRequest } from '../middleware/auth';
import { authRequired, requireRole } from '../middleware/auth';
import type { InviteMailer } from '../mailer';
import CompanyModel from '../models/Company';
import PropertyModel from '../models/Property';
import type { AppRedisClient } from '../redis';
import { isPushNotificationsConfigured, sendPushToTokens } from '../services/push_notifications';
import UserModel from '../models/User';
import VisitModel from '../models/Visit';

const serviceChecklistTemplates: Record<string, string[]> = {
  pool_cleaning: [
    'pool_filter_cleaned',
    'pool_chemicals_added',
    'pool_surface_skimmed',
    'pool_vacuumed',
    'pool_water_level_checked',
  ],
  garden_service: [
    'garden_mowed',
    'garden_hedges_trimmed',
    'garden_weeds_removed',
    'garden_irrigation_checked',
  ],
  general_cleaning: [
    'cleaning_floors_done',
    'cleaning_kitchen_done',
    'cleaning_bathroom_done',
    'cleaning_trash_removed',
  ],
  property_check: [
    'property_visual_inspection',
    'property_water_leaks_checked',
    'property_electricity_checked',
    'property_security_checked',
  ],
  key_holding: [
    'key_entry_exit_logged',
    'key_doors_windows_secured',
    'key_alarm_checked',
  ],
  handyman: [
    'handyman_minor_repairs_done',
    'handyman_fixtures_checked',
    'handyman_tools_supplies_checked',
  ],
  pest_control: [
    'pest_traps_checked',
    'pest_treatment_applied',
    'pest_activity_logged',
  ],
  other: [
    'other_service_completed',
  ],
};

const serviceTypeLabelMap: Record<string, string> = {
  pool_cleaning: 'Pool cleaning',
  garden_service: 'Garden service',
  general_cleaning: 'General cleaning',
  property_check: 'Property check',
  key_holding: 'Key holding',
  handyman: 'Handyman',
  pest_control: 'Pest control',
  other: 'Other',
};

const checklistLabelMap: Record<string, string> = {
  pool_filter_cleaned: 'Pool filter cleaned',
  pool_chemicals_added: 'Pool chemicals added',
  pool_surface_skimmed: 'Pool surface skimmed',
  pool_vacuumed: 'Pool vacuumed',
  pool_water_level_checked: 'Pool water level checked',
  garden_mowed: 'Garden mowed',
  garden_hedges_trimmed: 'Garden hedges trimmed',
  garden_weeds_removed: 'Garden weeds removed',
  garden_irrigation_checked: 'Garden irrigation checked',
  cleaning_floors_done: 'Floors cleaned',
  cleaning_kitchen_done: 'Kitchen cleaned',
  cleaning_bathroom_done: 'Bathroom cleaned',
  cleaning_trash_removed: 'Trash removed',
  property_visual_inspection: 'Visual inspection completed',
  property_water_leaks_checked: 'Water leaks checked',
  property_electricity_checked: 'Electricity checked',
  property_security_checked: 'Security checked',
  key_entry_exit_logged: 'Entry/exit logged',
  key_doors_windows_secured: 'Doors/windows secured',
  key_alarm_checked: 'Alarm checked',
  handyman_minor_repairs_done: 'Minor repairs done',
  handyman_fixtures_checked: 'Fixtures checked',
  handyman_tools_supplies_checked: 'Tools/supplies checked',
  pest_traps_checked: 'Traps checked',
  pest_treatment_applied: 'Treatment applied',
  pest_activity_logged: 'Pest activity logged',
  other_service_completed: 'Service completed',
};

const allowedReactionEmojis = new Set<string>(['👍', '❤️', '🔥', '👏', '😮']);

function reactionUserDisplayName(userRecord: Record<string, unknown> | null): string {
  if (!userRecord) {
    return 'Client';
  }
  const username = String(userRecord.username || '').trim();
  if (username) {
    return username;
  }
  const name = String(userRecord.name || '').trim();
  if (name) {
    return name;
  }
  return 'Client';
}

function buildReactionSummary(
  reactions:
    | Array<{
        userId: unknown;
        emoji: string;
      }>
    | undefined,
  viewerUserId: string | null,
) {
  const counts: Record<string, number> = {};
  const namesByEmoji: Record<string, string[]> = {};
  let userReaction: string | null = null;
  for (const reaction of reactions || []) {
    const emoji = String(reaction.emoji || '').trim();
    if (!allowedReactionEmojis.has(emoji)) {
      continue;
    }
    counts[emoji] = (counts[emoji] || 0) + 1;
    const userObj =
      reaction.userId && typeof reaction.userId === 'object'
        ? (reaction.userId as Record<string, unknown>)
        : null;
    const reactionUserId = userObj && userObj._id != null ? String(userObj._id) : String(reaction.userId);
    if (!namesByEmoji[emoji]) {
      namesByEmoji[emoji] = [];
    }
    namesByEmoji[emoji].push(reactionUserDisplayName(userObj));
    if (viewerUserId && reactionUserId === viewerUserId) {
      userReaction = emoji;
    }
  }
  return {
    counts,
    userReaction,
    details: Object.entries(namesByEmoji).map(([emoji, names]) => ({
      emoji,
      names,
    })),
  };
}

function toPropertyDto(item: {
  _id: unknown;
  name: string;
  address: string;
  clientShareToken: string;
  companyId?: unknown;
  clientIds?: unknown[];
}) {
  const assignedClients = Array.isArray(item.clientIds)
    ? item.clientIds
        .map((entry) => {
          if (!entry || typeof entry !== 'object') {
            return null;
          }
          const mapped = entry as Record<string, unknown>;
          if (mapped._id == null) {
            return null;
          }
          return {
            id: String(mapped._id),
            name: String(mapped.name || ''),
            email: String(mapped.email || ''),
            username: String(mapped.username || ''),
            avatarUrl: mapped.avatarUrl == null ? null : String(mapped.avatarUrl),
          };
        })
        .filter(
          (
            entry,
          ): entry is {
            id: string;
            name: string;
            email: string;
            username: string;
            avatarUrl: string | null;
          } =>
            entry != null,
        )
    : [];

  return {
    id: String(item._id),
    name: item.name,
    address: item.address,
    clientShareToken: item.clientShareToken,
    companyLogoUrl:
      item.companyId && typeof item.companyId === 'object'
        ? String((item.companyId as Record<string, unknown>).logoUrl || '')
        : '',
    assignedClientAccounts: assignedClients,
  };
}

function toVisitDto(item: {
  _id: unknown;
  propertyId: unknown;
  createdAt: Date;
  workerName: string;
  note: string;
  serviceType: string;
  serviceChecklist?: string[];
  photos: Array<{ url: string; thumbnailUrl?: string | null; createdAt: Date }>;
  createdByUserId?: unknown;
  reactions?: Array<{ userId: unknown; emoji: string }>;
}, viewerUserId: string | null = null) {
  const createdBy =
    item.createdByUserId && typeof item.createdByUserId === 'object'
      ? (item.createdByUserId as Record<string, unknown>)
      : null;
  const workerAvatarUrl =
    createdBy && typeof createdBy.avatarUrl === 'string' ? createdBy.avatarUrl : null;
  const reactionSummary = buildReactionSummary(item.reactions, viewerUserId);

  return {
    id: String(item._id),
    propertyId: String(item.propertyId),
    createdAt: item.createdAt.toISOString(),
    createdByUserId:
      createdBy && createdBy._id != null ? String(createdBy._id) : String(item.createdByUserId || ''),
    workerName: item.workerName,
    workerAvatarUrl,
    note: item.note,
    serviceType: item.serviceType,
    serviceChecklist: Array.isArray(item.serviceChecklist) ? item.serviceChecklist : [],
    reactionCounts: reactionSummary.counts,
    userReaction: reactionSummary.userReaction,
    reactionDetails: reactionSummary.details,
    photos: item.photos.map((photo) => ({
      url: photo.url,
      thumbnailUrl: photo.thumbnailUrl || null,
      createdAt: photo.createdAt.toISOString(),
    })),
  };
}

type AccessResult =
  | { ok: true; property: any }
  | { ok: false; error: string; status: number };

function readRouteParam(value: string | string[] | undefined): string {
  if (Array.isArray(value)) {
    return value[0] || '';
  }
  return value || '';
}

function generateStrongTemporaryPassword(length = 16): string {
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const lower = 'abcdefghijkmnopqrstuvwxyz';
  const digits = '23456789';
  const symbols = '!@#$%^&*()-_=+';
  const all = upper + lower + digits + symbols;

  finalPasswordLoop:
  while (true) {
    const passwordChars: string[] = [
      upper[Math.floor(Math.random() * upper.length)],
      lower[Math.floor(Math.random() * lower.length)],
      digits[Math.floor(Math.random() * digits.length)],
      symbols[Math.floor(Math.random() * symbols.length)],
    ];

    while (passwordChars.length < length) {
      passwordChars.push(all[Math.floor(Math.random() * all.length)]);
    }

    for (let i = passwordChars.length - 1; i > 0; i -= 1) {
      const j = Math.floor(Math.random() * (i + 1));
      const temp = passwordChars[i];
      passwordChars[i] = passwordChars[j];
      passwordChars[j] = temp;
    }

    const password = passwordChars.join('');
    if (password.length < 12) {
      continue finalPasswordLoop;
    }
    return password;
  }
}

function capitalizeFirst(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) {
    return trimmed;
  }
  return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
}

function suggestedUsernameFromNameOrEmail(name: string, email: string): string {
  const firstName = name
    .split(/\s+/)
    .map((part) => part.trim())
    .find((part) => part.length > 0);
  if (firstName) {
    return capitalizeFirst(firstName);
  }
  const local = email.split('@')[0] || 'Client';
  return capitalizeFirst(local);
}

class RouteError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

function clientLimitForPlan(plan: string): number | null {
  switch (String(plan || '').trim().toLowerCase()) {
    case 'starter':
      return 20;
    case 'growth':
      return 60;
    case 'pro':
      return null;
    default:
      return null;
  }
}

function employeeLimitForPlan(plan: string): number | null {
  switch (String(plan || '').trim().toLowerCase()) {
    case 'starter':
      return 1;
    case 'growth':
      return 5;
    case 'pro':
      return null;
    default:
      return null;
  }
}

async function assertCanAddClientForCompany(companyId: unknown) {
  const company = await CompanyModel.findById(companyId).select('billingPlan').lean();
  if (!company) {
    throw new RouteError(404, 'Company not found');
  }
  const limit = clientLimitForPlan(String((company as any).billingPlan || ''));
  if (limit == null) {
    return;
  }
  const activeClients = await UserModel.countDocuments({
    companyId: companyId as any,
    role: 'client',
    isActive: true,
  });
  if (activeClients >= limit) {
    throw new RouteError(
      402,
      'Client limit reached for your subscription plan. Please upgrade to add more clients.',
    );
  }
}

async function assertCanAddPropertyForCompany(companyId: unknown) {
  const company = await CompanyModel.findById(companyId).select('billingPlan').lean();
  if (!company) {
    throw new RouteError(404, 'Company not found');
  }
  const limit = clientLimitForPlan(String((company as any).billingPlan || ''));
  if (limit == null) {
    return;
  }
  const propertiesCount = await PropertyModel.countDocuments({ companyId: companyId as any });
  if (propertiesCount >= limit) {
    throw new RouteError(
      402,
      'Property limit reached for your subscription plan. Please upgrade to add more properties.',
    );
  }
}

async function assertCanAddEmployeeForCompany(companyId: unknown) {
  const company = await CompanyModel.findById(companyId).select('billingPlan').lean();
  if (!company) {
    throw new RouteError(404, 'Company not found');
  }
  const limit = employeeLimitForPlan(String((company as any).billingPlan || ''));
  if (limit == null) {
    return;
  }
  const workersCount = await UserModel.countDocuments({
    companyId: companyId as any,
    role: 'worker',
    isActive: true,
  });
  if (workersCount >= limit) {
    throw new RouteError(
      402,
      'Employee account limit reached for your subscription plan. Please upgrade to add more employees.',
    );
  }
}

async function inviteClientToProperty(params: {
  property: any;
  email: string;
  name?: string;
  invitedByName: string;
  inviteMailer: InviteMailer | null;
  password?: string;
}) {
  const email = params.email.trim().toLowerCase();
  const name = (params.name || '').trim() || email.split('@')[0] || 'Client';
  const requestedPassword = String(params.password || '').trim();

  let user = await UserModel.findOne({ email });
  let temporaryPassword: string | undefined;
  if (!user) {
    await assertCanAddClientForCompany(params.property.companyId);
    temporaryPassword = requestedPassword || generateStrongTemporaryPassword();
    const passwordHash = await bcrypt.hash(temporaryPassword, 10);
    user = await UserModel.create({
      companyId: params.property.companyId,
      role: 'client',
      companyAccessLevel: 'member',
      name,
      email,
      username: suggestedUsernameFromNameOrEmail(name, email),
      passwordHash,
    });
  } else {
    if (user.role !== 'client') {
      throw new RouteError(400, 'User exists with a non-client role');
    }
    if (user.companyId && String(user.companyId) !== String(params.property.companyId)) {
      throw new RouteError(409, 'User belongs to a different company');
    }
    if (!user.companyId) {
      await assertCanAddClientForCompany(params.property.companyId);
      user.companyId = params.property.companyId;
    }
    if (!user.username || !user.username.trim()) {
      user.username = suggestedUsernameFromNameOrEmail(user.name || name, email);
    }
    await user.save();
  }

  if (!params.property.clientIds.some((id: unknown) => String(id) === String(user._id))) {
    params.property.clientIds.push(user._id);
    await params.property.save();
  }

  let emailSent = false;
  if (params.inviteMailer) {
    try {
      const username = String(user.username || user.email || email.split('@')[0]);
      await params.inviteMailer.sendClientInvite({
        toEmail: email,
        clientName: user.name || name,
        propertyName: params.property.name,
        invitedByName: params.invitedByName,
        username,
        temporaryPassword,
      });
      emailSent = true;
    } catch (error) {
      console.error('Failed to send client invite email:', error);
    }
  }

  return {
    user,
    emailSent,
  };
}

async function ensurePropertyAccess(
  req: AuthenticatedRequest,
  propertyId: string,
): Promise<AccessResult> {
  const auth = req.auth;
  if (!auth) {
    return { ok: false, error: 'Unauthorized', status: 401 };
  }

  const property = await PropertyModel.findById(propertyId);
  if (!property) {
    return { ok: false, error: 'Property not found', status: 404 };
  }

  if (auth.role === 'owner') {
    if (String(property.companyId) !== auth.companyId) {
      return { ok: false, error: 'Forbidden', status: 403 };
    }
    return { ok: true, property };
  }

  if (auth.role === 'worker') {
    const isAssigned = property.workerIds.some((id: unknown) => String(id) === auth.userId);
    if (!isAssigned) {
      return { ok: false, error: 'Forbidden', status: 403 };
    }
    return { ok: true, property };
  }

  const isAssigned = property.clientIds.some((id: unknown) => String(id) === auth.userId);
  if (!isAssigned) {
    return { ok: false, error: 'Forbidden', status: 403 };
  }
  return { ok: true, property };
}

type CreatePropertiesRouterOptions = {
  redis: AppRedisClient;
  inviteMailer: InviteMailer | null;
};

export function createPropertiesRouter(options: CreatePropertiesRouterOptions): Router {
  const router = Router();
  const { redis, inviteMailer } = options;

  router.get('/', authRequired(redis), async (req: AuthenticatedRequest, res) => {
    const auth = req.auth;
    if (!auth) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    if (auth.role === 'owner') {
      const properties = await PropertyModel.find({ companyId: auth.companyId })
        .populate('companyId', 'logoUrl')
        .populate('clientIds', 'name email username avatarUrl')
        .lean();
      return res.json(properties.map(toPropertyDto));
    }

    if (auth.role === 'worker') {
      const properties = await PropertyModel.find({ workerIds: auth.userId })
        .populate('companyId', 'logoUrl')
        .populate('clientIds', 'name email username avatarUrl')
        .lean();
      return res.json(properties.map(toPropertyDto));
    }

    const properties = await PropertyModel.find({ clientIds: auth.userId })
      .populate('companyId', 'logoUrl')
      .populate('clientIds', 'name email username avatarUrl')
      .lean();
    return res.json(properties.map(toPropertyDto));
  });

  router.post(
    '/',
    authRequired(redis),
    requireRole(['owner']),
    async (req: AuthenticatedRequest, res) => {
      if (!req.auth || !req.auth.companyId) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      const name = String(req.body?.name || '').trim();
      const address = String(req.body?.address || '').trim();
      const clientEmail = String(req.body?.clientEmail || '').trim().toLowerCase();
      if (!name || !address) {
        return res.status(400).json({ error: 'name and address are required' });
      }

      try {
        await assertCanAddPropertyForCompany(req.auth.companyId);
      } catch (error) {
        if (error instanceof RouteError) {
          return res.status(error.status).json({ error: error.message });
        }
        throw error;
      }

      const property = await PropertyModel.create({
        companyId: req.auth.companyId,
        name,
        address,
        clientShareToken: randomBytes(16).toString('hex'),
        workerIds: [],
        clientIds: [],
      });

      let invitedClient: {
        userId: string;
        email: string;
        emailSent: boolean;
      } | null = null;
      let invitedClientError: string | null = null;
      if (clientEmail) {
        try {
          const invited = await inviteClientToProperty({
            property,
            email: clientEmail,
            invitedByName: req.auth.name || 'Your company',
            inviteMailer,
          });
          invitedClient = {
            userId: invited.user._id.toString(),
            email: clientEmail,
            emailSent: invited.emailSent,
          };
        } catch (error) {
          if (error instanceof RouteError) {
            invitedClientError = error.message;
          } else {
            throw error;
          }
        }
      }

      return res.status(201).json({
        ...toPropertyDto(property),
        invitedClient,
        invitedClientError,
      });
    },
  );

  router.post(
    '/:id/invite-worker',
    authRequired(redis),
    requireRole(['owner']),
    async (req: AuthenticatedRequest, res) => {
      const propertyId = readRouteParam(req.params.id as string | string[] | undefined);
      const access = await ensurePropertyAccess(req, propertyId);
      if (!access.ok) {
        return res.status(access.status).json({ error: access.error });
      }
      const property = access.property;

      const email = String(req.body?.email || '').trim().toLowerCase();
      const name = String(req.body?.name || '').trim() || email.split('@')[0] || 'Worker';
      const password = String(req.body?.password || 'changeme123');
      if (!email) {
        return res.status(400).json({ error: 'email is required' });
      }

      let user = await UserModel.findOne({ email });
      if (!user) {
        try {
          await assertCanAddEmployeeForCompany(property.companyId);
          const passwordHash = await bcrypt.hash(password, 10);
          user = await UserModel.create({
            companyId: property.companyId,
            role: 'worker',
            companyAccessLevel: 'member',
            name,
            email,
            passwordHash,
          });
        } catch (error) {
          if (error instanceof RouteError) {
            return res.status(error.status).json({ error: error.message });
          }
          throw error;
        }
      } else {
        if (user.role !== 'worker' && user.role !== 'owner') {
          return res.status(400).json({ error: 'User exists with a non-worker role' });
        }
        if (String(user.companyId || '') !== String(property.companyId || '')) {
          return res.status(409).json({ error: 'User belongs to a different company' });
        }
      }

      if (!property.workerIds.some((id: unknown) => String(id) === String(user._id))) {
        property.workerIds.push(user._id);
        await property.save();
      }

      return res.json({ ok: true, userId: user._id.toString(), role: 'worker' });
    },
  );

  router.post(
    '/:id/invite-client',
    authRequired(redis),
    requireRole(['owner', 'client']),
    async (req: AuthenticatedRequest, res) => {
      const propertyId = readRouteParam(req.params.id as string | string[] | undefined);
      const access = await ensurePropertyAccess(req, propertyId);
      if (!access.ok) {
        return res.status(access.status).json({ error: access.error });
      }
      const property = access.property;

      const email = String(req.body?.email || '').trim().toLowerCase();
      const name = String(req.body?.name || '').trim() || email.split('@')[0] || 'Client';
      const password = String(req.body?.password || '');
      if (!email) {
        return res.status(400).json({ error: 'email is required' });
      }

      let invited;
      try {
        invited = await inviteClientToProperty({
          property,
          email,
          name,
          invitedByName: req.auth?.name || 'Your company',
          inviteMailer,
          password,
        });
      } catch (error) {
        if (error instanceof RouteError) {
          return res.status(error.status).json({ error: error.message });
        }
        throw error;
      }

      return res.json({
        ok: true,
        userId: invited.user._id.toString(),
        role: 'client',
        emailSent: invited.emailSent,
      });
    },
  );

  router.delete(
    '/:id/clients/:clientUserId',
    authRequired(redis),
    requireRole(['owner', 'client']),
    async (req: AuthenticatedRequest, res) => {
      const propertyId = readRouteParam(req.params.id as string | string[] | undefined);
      const clientUserId = readRouteParam(
        req.params.clientUserId as string | string[] | undefined,
      );
      const access = await ensurePropertyAccess(req, propertyId);
      if (!access.ok) {
        return res.status(access.status).json({ error: access.error });
      }

      if (!clientUserId) {
        return res.status(400).json({ error: 'clientUserId is required' });
      }
      if (req.auth?.userId === clientUserId) {
        return res.status(400).json({ error: 'You cannot remove your own access' });
      }

      const property = access.property;
      const beforeCount = property.clientIds.length;
      property.clientIds = property.clientIds.filter(
        (id: unknown) => String(id) !== clientUserId,
      );
      if (property.clientIds.length == beforeCount) {
        return res.status(404).json({ error: 'Client is not assigned to this property' });
      }
      await property.save();
      return res.json({ ok: true });
    },
  );

  router.get('/:id/visits', authRequired(redis), async (req: AuthenticatedRequest, res) => {
    const propertyId = readRouteParam(req.params.id as string | string[] | undefined);
    const access = await ensurePropertyAccess(req, propertyId);
    if (!access.ok) {
      return res.status(access.status).json({ error: access.error });
    }

    const visits = await VisitModel.find({ propertyId })
      .sort({ createdAt: -1 })
      .populate('createdByUserId', 'avatarUrl')
      .populate('reactions.userId', 'name username')
      .lean();
    return res.json(visits.map((visit) => toVisitDto(visit, req.auth?.userId || null)));
  });

  router.post(
    '/:id/visits',
    authRequired(redis),
    requireRole(['owner', 'worker']),
    async (req: AuthenticatedRequest, res) => {
      const propertyId = readRouteParam(req.params.id as string | string[] | undefined);
      const access = await ensurePropertyAccess(req, propertyId);
      if (!access.ok) {
        return res.status(access.status).json({ error: access.error });
      }
      const property = access.property;

      if (!req.auth || !req.auth.companyId) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      const note = String(req.body?.note || '');
      const workerName = String(req.body?.workerName || req.auth.name || 'Worker');
      const serviceType = String(req.body?.serviceType || '').trim();
      const serviceChecklistRaw = Array.isArray(req.body?.serviceChecklist)
        ? req.body.serviceChecklist
        : [];
      const photos = Array.isArray(req.body?.photos) ? req.body.photos : [];
      const sendEmailUpdate = Boolean(req.body?.sendEmailUpdate);
      if (!serviceType || !(serviceType in serviceChecklistTemplates)) {
        return res.status(400).json({ error: 'Valid serviceType is required' });
      }
      const allowedChecklist = new Set(serviceChecklistTemplates[serviceType] || []);
      const serviceChecklist: string[] = Array.from(
        new Set(
          serviceChecklistRaw
            .map((item: unknown) => String(item || '').trim())
            .filter((item: string) => allowedChecklist.has(item)),
        ),
      );

      const visit = await VisitModel.create({
        companyId: req.auth.companyId,
        propertyId: property._id,
        createdByUserId: req.auth.userId,
        workerName,
        note,
        serviceType,
        serviceChecklist,
        photos: photos.map((photo: { url?: string; thumbnailUrl?: string; createdAt?: string }) => ({
          url: String(photo.url || ''),
          thumbnailUrl: photo.thumbnailUrl || null,
          createdAt: photo.createdAt ? new Date(photo.createdAt) : new Date(),
        })),
      });

      let emailSent = false;
      if (sendEmailUpdate && inviteMailer) {
        const clientUsers = await UserModel.find({
          _id: { $in: property.clientIds },
        })
          .select('email')
          .lean();
        const toEmails = clientUsers
          .map((user) => String(user.email || '').trim())
          .filter((email) => email.length > 0);

        if (toEmails.length > 0) {
          try {
            await inviteMailer.sendVisitReport({
              toEmails,
              propertyName: property.name,
              workerName,
              note,
              createdAtIso: visit.createdAt.toISOString(),
              serviceTypeLabel: serviceTypeLabelMap[serviceType] || serviceType,
              checklistItems: serviceChecklist
                .map((item) => checklistLabelMap[item] || item)
                .filter((item) => item.trim().length > 0),
              photoUrls: photos
                .map((photo: { url?: string }) => String(photo.url || '').trim())
                .filter((url: string) => url.length > 0),
            });
            emailSent = true;
          } catch (error) {
            console.error('Failed to send visit update email:', error);
          }
        }
      }

      let pushSentCount = 0;
      let pushFailedCount = 0;
      if (isPushNotificationsConfigured()) {
        try {
          const clientUsers = await UserModel.find({
            _id: { $in: property.clientIds },
          })
            .select('_id pushTokens')
            .lean();

          const pushTokens = clientUsers.flatMap((user) =>
            Array.isArray(user.pushTokens)
              ? user.pushTokens
                  .map((token: unknown) => String(token || '').trim())
                  .filter((token: string) => token.length > 0)
              : [],
          );

          if (pushTokens.length > 0) {
            const pushResult = await sendPushToTokens(pushTokens, {
              title: `New visit at ${property.name}`,
              body: `${workerName} submitted a ${serviceTypeLabelMap[serviceType] || serviceType} update.`,
              data: {
                type: 'visit_created',
                propertyId: String(property._id),
                visitId: String(visit._id),
              },
            });

            pushSentCount = pushResult.sentCount;
            pushFailedCount = pushResult.failedCount;

            if (pushResult.invalidTokens.length > 0) {
              await UserModel.updateMany(
                { _id: { $in: property.clientIds } },
                { $pull: { pushTokens: { $in: pushResult.invalidTokens } } },
              );
            }
          }
        } catch (error) {
          console.error('Failed to send visit push notifications:', error);
        }
      }

      return res.status(201).json({
        ...toVisitDto(visit, req.auth?.userId || null),
        emailSent,
        pushSentCount,
        pushFailedCount,
      });
    },
  );

  router.post(
    '/:id/visits/:visitId/reactions',
    authRequired(redis),
    requireRole(['client']),
    async (req: AuthenticatedRequest, res) => {
      const propertyId = readRouteParam(req.params.id as string | string[] | undefined);
      const visitId = readRouteParam(req.params.visitId as string | string[] | undefined);
      const access = await ensurePropertyAccess(req, propertyId);
      if (!access.ok) {
        return res.status(access.status).json({ error: access.error });
      }
      if (!req.auth) {
        return res.status(401).json({ error: 'Unauthorized' });
      }
      const emoji = String(req.body?.emoji || '').trim();
      if (!allowedReactionEmojis.has(emoji)) {
        return res.status(400).json({ error: 'Valid emoji is required' });
      }

      const visit = await VisitModel.findOne({
        _id: visitId,
        propertyId: access.property._id,
      });
      if (!visit) {
        return res.status(404).json({ error: 'Visit not found' });
      }

      const existingIndex = visit.reactions.findIndex(
        (entry: { userId: unknown }) => String(entry.userId) === req.auth?.userId,
      );
      if (existingIndex >= 0 && visit.reactions[existingIndex]?.emoji === emoji) {
        visit.reactions.splice(existingIndex, 1);
      } else if (existingIndex >= 0) {
        visit.reactions[existingIndex].emoji = emoji;
      } else {
        visit.reactions.push({
          userId: req.auth.userId,
          emoji,
        } as any);
      }
      await visit.save();

      const refreshed = await VisitModel.findById(visit._id)
        .populate('createdByUserId', 'avatarUrl')
        .populate('reactions.userId', 'name username');
      if (!refreshed) {
        return res.status(404).json({ error: 'Visit not found' });
      }
      return res.json(toVisitDto(refreshed.toObject(), req.auth.userId));
    },
  );

  return router;
}
