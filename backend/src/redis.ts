import { createClient } from "redis";

export type AppRedisClient = ReturnType<typeof createClient>;

export async function connectRedis(redisUrl: string): Promise<AppRedisClient> {
  const client = createClient({
    url: redisUrl,
    socket: { tls: true, rejectUnauthorized: false },
  });
  client.on("error", (error: Error) => {
    console.error("Redis error:", error.message);
  });
  await client.connect();
  return client;
}
