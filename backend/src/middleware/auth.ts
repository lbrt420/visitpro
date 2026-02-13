import type { NextFunction, Request, Response } from 'express';

import type { AppRedisClient } from '../redis';
import type { SessionPayload } from '../services/session';
import { getSession } from '../services/session';

export type AuthenticatedRequest = Request & {
  auth?: SessionPayload;
  authToken?: string;
};

function readBearerToken(authorizationHeader?: string): string | null {
  if (!authorizationHeader) {
    return null;
  }
  const [type, token] = authorizationHeader.split(' ');
  if (!type || !token) {
    return null;
  }
  if (type.toLowerCase() !== 'bearer') {
    return null;
  }
  return token.trim();
}

export function authRequired(redis: AppRedisClient) {
  return async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    const token = readBearerToken(req.headers.authorization);
    if (!token) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const session = await getSession(redis, token);
    if (!session) {
      return res.status(401).json({ error: 'Session expired' });
    }

    req.auth = session;
    req.authToken = token;
    return next();
  };
}

export function requireRole(allowed: Array<SessionPayload['role']>) {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.auth) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    if (!allowed.includes(req.auth.role)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    return next();
  };
}
