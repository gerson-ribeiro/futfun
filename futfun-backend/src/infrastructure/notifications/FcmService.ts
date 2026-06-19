import * as admin from 'firebase-admin';

export class FcmService {
  private readonly app: admin.app.App | null = null;

  constructor() {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (!raw) {
      console.warn('[FcmService] FIREBASE_SERVICE_ACCOUNT_JSON not set — push notifications disabled');
      return;
    }
    try {
      const serviceAccount = JSON.parse(raw);
      this.app = admin.apps.length
        ? admin.app()
        : admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
      console.log('[FcmService] Firebase Admin initialized');
    } catch (err) {
      console.error('[FcmService] Failed to initialize Firebase Admin:', err);
    }
  }

  isAvailable(): boolean {
    return this.app !== null;
  }

  async sendMulticast(
    tokens: string[],
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<{ invalidTokens: string[] }> {
    if (!this.app || tokens.length === 0) return { invalidTokens: [] };

    const invalidTokens: string[] = [];

    // FCM multicast limit is 500 tokens per call
    for (let i = 0; i < tokens.length; i += 500) {
      const batch = tokens.slice(i, i + 500);
      const message: admin.messaging.MulticastMessage = {
        tokens: batch,
        notification: { title, body },
        ...(data && { data }),
        android: { priority: 'normal' },
      };

      const response = await admin.messaging(this.app).sendEachForMulticast(message);
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const code = resp.error?.code ?? '';
          if (
            code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token'
          ) {
            invalidTokens.push(batch[idx]);
          }
        }
      });
    }

    return { invalidTokens };
  }
}
