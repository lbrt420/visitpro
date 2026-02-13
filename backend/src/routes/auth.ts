import { Router } from 'express';
import bcrypt from 'bcryptjs';

import type { AuthenticatedRequest } from '../middleware/auth';
import { authRequired } from '../middleware/auth';
import CompanyModel from '../models/Company';
import type { AppRedisClient } from '../redis';
import UserModel from '../models/User';
import { createSession, deleteSession } from '../services/session';

type AuthRouterOptions = {
  redis: AppRedisClient;
  sessionTtlSeconds: number;
};

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function toUserDto(user: {
  _id: unknown;
  role: string;
  name: string;
  email: string;
  username?: string | null;
  avatarUrl?: string | null;
  companyId?: unknown;
  companyAccessLevel?: string | null;
}) {
  return {
    id: String(user._id),
    role: user.role,
    name: user.name,
    email: user.email,
    username: user.username || null,
    avatarUrl: user.avatarUrl || null,
    companyId: user.companyId ? String(user.companyId) : null,
    companyAccessLevel: user.companyAccessLevel || (user.role === 'owner' ? 'owner' : 'member'),
  };
}

export function createAuthRouter(options: AuthRouterOptions): Router {
  const router = Router();
  const { redis, sessionTtlSeconds } = options;

  router.post('/signup-company', async (req, res) => {
    const companyName = String(req.body?.companyName || '').trim();
    const email = String(req.body?.email || '').trim().toLowerCase();
    const password = String(req.body?.password || '');

    if (!companyName || !email || !password) {
      return res.status(400).json({ error: 'companyName, email and password are required' });
    }

    const existing = await UserModel.findOne({ email }).lean();
    if (existing) {
      return res.status(409).json({ error: 'Email already exists' });
    }

    const company = await CompanyModel.create({ name: companyName });
    const passwordHash = await bcrypt.hash(password, 10);
    const owner = await UserModel.create({
      companyId: company._id,
      role: 'owner',
      companyAccessLevel: 'owner',
      name: companyName,
      email,
      passwordHash,
    });

    const token = await createSession(
      redis,
      {
        userId: owner._id.toString(),
        role: 'owner',
        companyId: company._id.toString(),
        name: owner.name,
        companyAccessLevel: 'owner',
      },
      sessionTtlSeconds,
    );
    console.log(`[auth] signup-company token issued for ${email}: ${token}`);

    return res.status(201).json({
      token,
      user: toUserDto(owner),
    });
  });

  router.post('/login', async (req, res) => {
    const email = String(req.body?.email || '').trim().toLowerCase();
    const username = String(req.body?.username || '').trim();
    const password = String(req.body?.password || '');

    if ((!email && !username) || !password) {
      return res.status(400).json({ error: 'email or username and password are required' });
    }

    const user = email
      ? await UserModel.findOne({ email })
      : await UserModel.findOne({
          username: {
            $regex: `^${escapeRegExp(username)}$`,
            $options: 'i',
          },
        });
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = await createSession(
      redis,
      {
        userId: user._id.toString(),
        role: user.role,
        companyId: user.companyId ? user.companyId.toString() : null,
        name: user.name,
        companyAccessLevel:
          (user.companyAccessLevel as 'owner' | 'admin' | 'member') ||
          (user.role === 'owner' ? 'owner' : 'member'),
      },
      sessionTtlSeconds,
    );
    const principal = email || username || user.email;
    console.log(`[auth] login token issued for ${principal}: ${token}`);

    return res.json({
      token,
      user: toUserDto(user),
    });
  });

  router.get('/me', authRequired(redis), async (req: AuthenticatedRequest, res) => {
    if (!req.auth) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    const user = await UserModel.findById(req.auth.userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    return res.json({
      user: toUserDto(user),
    });
  });

  router.patch('/profile', authRequired(redis), async (req: AuthenticatedRequest, res) => {
    if (!req.auth) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    const user = await UserModel.findById(req.auth.userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const usernameRaw = req.body?.username;
    if (typeof usernameRaw === 'string') {
      const username = usernameRaw.trim();
      if (!username) {
        return res.status(400).json({ error: 'username cannot be empty' });
      }
      const taken = await UserModel.findOne({
        username: {
          $regex: `^${escapeRegExp(username)}$`,
          $options: 'i',
        },
        _id: { $ne: user._id },
      }).lean();
      if (taken) {
        return res.status(409).json({ error: 'Username already exists' });
      }
      user.username = username;
    }

    const avatarUrlRaw = req.body?.avatarUrl;
    if (typeof avatarUrlRaw === 'string') {
      const avatarUrl = avatarUrlRaw.trim();
      user.avatarUrl = avatarUrl || null;
    }

    await user.save();
    return res.json({ user: toUserDto(user) });
  });

  router.post('/change-password', authRequired(redis), async (req: AuthenticatedRequest, res) => {
    if (!req.auth) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    const oldPassword = String(req.body?.oldPassword || '');
    const newPassword = String(req.body?.newPassword || '');
    if (!oldPassword || !newPassword) {
      return res.status(400).json({ error: 'oldPassword and newPassword are required' });
    }
    if (newPassword.length < 8) {
      return res.status(400).json({ error: 'New password must be at least 8 characters' });
    }

    const user = await UserModel.findById(req.auth.userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    const validOldPassword = await bcrypt.compare(oldPassword, user.passwordHash);
    if (!validOldPassword) {
      return res.status(401).json({ error: 'Old password is incorrect' });
    }

    user.passwordHash = await bcrypt.hash(newPassword, 10);
    await user.save();
    return res.json({ ok: true });
  });

  router.post('/logout', authRequired(redis), async (req: AuthenticatedRequest, res) => {
    if (!req.authToken) {
      return res.status(204).send();
    }
    await deleteSession(redis, req.authToken);
    return res.status(204).send();
  });

  return router;
}
