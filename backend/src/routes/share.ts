import { Router } from 'express';

import PropertyModel from '../models/Property';
import VisitModel from '../models/Visit';

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
}) {
  const createdBy =
    item.createdByUserId && typeof item.createdByUserId === 'object'
      ? (item.createdByUserId as Record<string, unknown>)
      : null;
  const workerAvatarUrl =
    createdBy && typeof createdBy.avatarUrl === 'string' ? createdBy.avatarUrl : null;
  const reactionCounts: Record<string, number> = {};
  const reactionNamesByEmoji: Record<string, string[]> = {};
  for (const reaction of item.reactions || []) {
    const emoji = String(reaction.emoji || '').trim();
    if (!allowedReactionEmojis.has(emoji)) {
      continue;
    }
    reactionCounts[emoji] = (reactionCounts[emoji] || 0) + 1;
    const userObj =
      reaction.userId && typeof reaction.userId === 'object'
        ? (reaction.userId as Record<string, unknown>)
        : null;
    if (!reactionNamesByEmoji[emoji]) {
      reactionNamesByEmoji[emoji] = [];
    }
    reactionNamesByEmoji[emoji].push(reactionUserDisplayName(userObj));
  }

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
    reactionCounts,
    userReaction: null,
    reactionDetails: Object.entries(reactionNamesByEmoji).map(([emoji, names]) => ({
      emoji,
      names,
    })),
    photos: item.photos.map((photo) => ({
      url: photo.url,
      thumbnailUrl: photo.thumbnailUrl || null,
      createdAt: photo.createdAt.toISOString(),
    })),
  };
}

export function createShareRouter(): Router {
  const router = Router();

  router.get('/:token/visits', async (req, res) => {
    const token = String(req.params.token || '').trim();
    if (!token) {
      return res.status(400).json({ error: 'token is required' });
    }

    const property = await PropertyModel.findOne({ clientShareToken: token }).lean();
    if (!property) {
      return res.status(404).json({ error: 'Share token not found' });
    }

    const visits = await VisitModel.find({ propertyId: property._id })
      .sort({ createdAt: -1 })
      .populate('createdByUserId', 'avatarUrl')
      .populate('reactions.userId', 'name username')
      .lean();
    return res.json(visits.map(toVisitDto));
  });

  return router;
}
