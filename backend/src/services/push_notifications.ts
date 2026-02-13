import { cert, getApps, initializeApp, type App, type ServiceAccount } from 'firebase-admin/app';
import { getMessaging, type Messaging } from 'firebase-admin/messaging';

import { config } from '../config';

type PushPayload = {
  title: string;
  body: string;
  data?: Record<string, string>;
};

type PushSendResult = {
  sentCount: number;
  failedCount: number;
  invalidTokens: string[];
};

let firebaseApp: App | null | undefined;

function normalizePrivateKey(value: string): string {
  let normalized = value.trim();
  if (
    (normalized.startsWith('"') && normalized.endsWith('"')) ||
    (normalized.startsWith("'") && normalized.endsWith("'"))
  ) {
    normalized = normalized.slice(1, -1);
  }
  return normalized.replace(/\\n/g, '\n').replace(/\r/g, '');
}

function toServiceAccount(): ServiceAccount | null {
  const rawJson = config.firebaseServiceAccountJson.trim();
  if (rawJson) {
    try {
      const parsed = JSON.parse(rawJson) as Record<string, unknown>;
      const privateKey =
        typeof parsed['privateKey'] === 'string'
          ? normalizePrivateKey(parsed['privateKey'])
          : typeof parsed['private_key'] === 'string'
            ? normalizePrivateKey(parsed['private_key'])
            : '';
      if (privateKey) {
        parsed['privateKey'] = privateKey;
      }
      return parsed as unknown as ServiceAccount;
    } catch {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is invalid JSON');
    }
  }

  const projectId = config.firebaseProjectId.trim();
  const clientEmail = config.firebaseClientEmail.trim();
  const privateKey = normalizePrivateKey(config.firebasePrivateKey);
  if (!projectId || !clientEmail || !privateKey) {
    return null;
  }

  return {
    projectId,
    clientEmail,
    privateKey,
  };
}

function getFirebaseApp(): App | null {
  if (firebaseApp !== undefined) {
    return firebaseApp;
  }

  const serviceAccount = toServiceAccount();
  if (!serviceAccount) {
    firebaseApp = null;
    return firebaseApp;
  }

  firebaseApp =
    getApps().find((app) => app.name === 'push-notifications') ||
    initializeApp(
      {
        credential: cert(serviceAccount),
      },
      'push-notifications',
    );
  return firebaseApp;
}

function getFirebaseMessaging(): Messaging {
  const app = getFirebaseApp();
  if (!app) {
    throw new Error(
      'Push notifications are not configured. Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_PROJECT_ID/FIREBASE_CLIENT_EMAIL/FIREBASE_PRIVATE_KEY.',
    );
  }
  return getMessaging(app);
}

function isInvalidTokenErrorCode(code: string): boolean {
  return (
    code === 'messaging/registration-token-not-registered' ||
    code === 'messaging/invalid-registration-token'
  );
}

export function isPushNotificationsConfigured(): boolean {
  return getFirebaseApp() !== null;
}

export async function sendPushToTokens(
  tokens: string[],
  payload: PushPayload,
): Promise<PushSendResult> {
  const uniqueTokens = Array.from(new Set(tokens.map((token) => token.trim()).filter(Boolean)));
  if (!uniqueTokens.length) {
    return { sentCount: 0, failedCount: 0, invalidTokens: [] };
  }

  const messaging = getFirebaseMessaging();
  const response = await messaging.sendEachForMulticast({
    tokens: uniqueTokens,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: payload.data,
  });

  const invalidTokens: string[] = [];
  response.responses.forEach((result, index) => {
    if (result.success) {
      return;
    }
    const code = result.error?.code || '';
    if (isInvalidTokenErrorCode(code)) {
      invalidTokens.push(uniqueTokens[index]);
    }
  });

  return {
    sentCount: response.successCount,
    failedCount: response.failureCount,
    invalidTokens,
  };
}
