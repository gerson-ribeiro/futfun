import * as admin from 'firebase-admin';

export class FcmService {
  private readonly app: admin.app.App | null = null;

  constructor() {
    try {
      // Prefer an explicit service account JSON (useful in local dev / non-GCP envs).
      // On Cloud Run the service account has ADC automatically — no JSON needed.
      const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
      const credential = raw
        ? admin.credential.cert(JSON.parse(raw))
        : admin.credential.applicationDefault();

      this.app = admin.apps.length
        ? admin.app()
        : admin.initializeApp({ credential });

      console.log('[FcmService] Firebase Admin initialized');
    } catch (err) {
      console.warn('[FcmService] Could not initialize Firebase Admin — push notifications disabled:', err);
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
