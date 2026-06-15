import { IOAuthProvider } from '@application/ports/IOAuthProvider';
import { GoogleOAuthService } from './GoogleOAuthService';
import { MicrosoftOAuthService } from './MicrosoftOAuthService';

export type OAuthProviderName = 'google' | 'microsoft';

export function createOAuthProvider(provider: OAuthProviderName): IOAuthProvider {
  switch (provider) {
    case 'google':
      return new GoogleOAuthService();
    case 'microsoft':
      return new MicrosoftOAuthService();
    default:
      throw new Error(`Unknown OAuth provider: ${provider}`);
  }
}
