import { Router } from 'express';

import type { AuthenticatedRequest } from '../middleware/auth';
import { authRequired, requireRole } from '../middleware/auth';
import type { AppRedisClient } from '../redis';

type UploadRouterOptions = {
  redis: AppRedisClient;
  cloudflareAccountId: string;
  cloudflareApiToken: string;
  cloudflareImagesApiBase: string;
  cloudflareImagesDeliveryBase: string;
};

export function createUploadsRouter(options: UploadRouterOptions): Router {
  const router = Router();
  const {
    redis,
    cloudflareAccountId,
    cloudflareApiToken,
    cloudflareImagesApiBase,
    cloudflareImagesDeliveryBase,
  } = options;

  router.post(
    '/sign',
    authRequired(redis),
    requireRole(['owner', 'worker', 'client']),
    async (req: AuthenticatedRequest, res) => {
      if (!cloudflareAccountId || !cloudflareApiToken) {
        return res.status(501).json({
          error: 'Cloudflare Images is not configured',
        });
      }

      const endpoint = `${cloudflareImagesApiBase}/accounts/${cloudflareAccountId}/images/v2/direct_upload`;
      const form = new FormData();
      form.append('requireSignedURLs', 'false');
      form.append(
        'metadata',
        JSON.stringify({
          fileName: String(req.body?.fileName || ''),
          contentType: String(req.body?.contentType || ''),
          uploadedBy: req.auth?.userId || '',
        }),
      );
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${cloudflareApiToken}`,
        },
        body: form,
      });

      const payload = (await response.json()) as {
        success?: boolean;
        result?: { id?: string; uploadURL?: string };
        errors?: Array<{ message?: string }>;
      };

      if (!response.ok || !payload.success || !payload.result?.uploadURL) {
        const cloudflareError =
          payload.errors?.[0]?.message || 'Cloudflare direct upload initialization failed';
        console.error(
          'Cloudflare direct upload error:',
          `status=${response.status}`,
          cloudflareError,
        );
        return res.status(502).json({
          error: cloudflareError,
          cloudflareStatus: response.status,
        });
      }

      return res.json({
        uploadURL: payload.result.uploadURL,
        imageId: payload.result.id || '',
        publicUrl:
          cloudflareImagesDeliveryBase && payload.result.id
            ? `${cloudflareImagesDeliveryBase}/${payload.result.id}/public`
            : '',
      });
    },
  );

  return router;
}
