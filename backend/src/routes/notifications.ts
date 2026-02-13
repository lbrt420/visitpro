import { Router } from 'express';

import type { AuthenticatedRequest } from '../middleware/auth';
import { authRequired } from '../middleware/auth';
import UserModel from '../models/User';
import type { AppRedisClient } from '../redis';
import { isPushNotificationsConfigured, sendPushToTokens } from '../services/push_notifications';

type NotificationsRouterOptions = {
  redis: AppRedisClient;
};

export function createNotificationsRouter(options: NotificationsRouterOptions): Router {
  const router = Router();
  const { redis } = options;

  router.post('/token', authRequired(redis), async (req: AuthenticatedRequest, res) => {
    if (!req.auth) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    const token = String(req.body?.token || '').trim();
    if (!token) {
      return res.status(400).json({ error: 'token is required' });
    }

    await UserModel.findByIdAndUpdate(req.auth.userId, {
      $addToSet: { pushTokens: token },
    });
    return res.status(204).send();
  });

  router.delete('/token', authRequired(redis), async (req: AuthenticatedRequest, res) => {
    if (!req.auth) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    const token = String(req.body?.token || '').trim();
    if (!token) {
      return res.status(400).json({ error: 'token is required' });
    }

    await UserModel.findByIdAndUpdate(req.auth.userId, {
      $pull: { pushTokens: token },
    });
    return res.status(204).send();
  });

  router.post('/test', authRequired(redis), async (req: AuthenticatedRequest, res) => {
    if (!req.auth) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    try {
      if (!isPushNotificationsConfigured()) {
        return res.status(503).json({ error: 'Push notifications are not configured on the server.' });
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Invalid push notifications configuration.';
      return res.status(503).json({ error: message });
    }

    const user = await UserModel.findById(req.auth.userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const tokens = (user.pushTokens || []).map((token) => token.trim()).filter(Boolean);
    if (!tokens.length) {
      return res.status(400).json({ error: 'No push token registered for this user.' });
    }

    const title = String(req.body?.title || '').trim() || 'visitpro test notification';
    const body =
      String(req.body?.body || '').trim() ||
      'Push notifications are configured correctly on your device.';

    const result = await sendPushToTokens(tokens, {
      title,
      body,
      data: {
        type: 'test',
      },
    });

    if (result.invalidTokens.length) {
      await UserModel.findByIdAndUpdate(req.auth.userId, {
        $pull: { pushTokens: { $in: result.invalidTokens } },
      });
    }

    return res.json({
      ok: true,
      sentCount: result.sentCount,
      failedCount: result.failedCount,
      invalidTokensRemoved: result.invalidTokens.length,
    });
  });

  return router;
}
