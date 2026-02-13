import { randomBytes } from "crypto";

import type { AppRedisClient } from "../redis";

export type SessionPayload = {
  userId: string;
  role: "owner" | "worker" | "client";
  companyId: string | null;
  name: string;
  companyAccessLevel: "owner" | "admin" | "member";
};

function sessionKey(token: string): string {
  return `sess:${token}`;
}

export async function createSession(
  redis: AppRedisClient,
  payload: SessionPayload,
  ttlSeconds: number,
): Promise<string> {
  const token = randomBytes(32).toString("hex");
  await redis.set(sessionKey(token), JSON.stringify(payload), {
    EX: ttlSeconds,
  });
  return token;
}

export async function getSession(
  redis: AppRedisClient,
  token: string,
): Promise<SessionPayload | null> {
  const raw = await redis.get(sessionKey(token));
  if (!raw) {
    return null;
  }
  try {
    const parsed = JSON.parse(raw) as Partial<SessionPayload>;
    if (
      !parsed ||
      !parsed.userId ||
      !parsed.role ||
      typeof parsed.userId !== "string" ||
      typeof parsed.role !== "string"
    ) {
      return null;
    }

    const normalizedRole = parsed.role as "owner" | "worker" | "client";
    const normalizedAccessLevel =
      parsed.companyAccessLevel ||
      (normalizedRole === "owner" ? "owner" : "member");

    return {
      userId: parsed.userId,
      role: normalizedRole,
      companyId: parsed.companyId ?? null,
      name: parsed.name || "",
      companyAccessLevel: normalizedAccessLevel,
    };
  } catch {
    return null;
  }
}

export async function deleteSession(
  redis: AppRedisClient,
  token: string,
): Promise<void> {
  await redis.del(sessionKey(token));
}
