export function createSimpleRateLimiter(maxRequests: number = 100, windowMs: number = 900000) {
  const requests = new Map<string, { count: number; resetTime: number }>();

  return (key: string): boolean => {
    const now = Date.now();
    const record = requests.get(key);

    if (!record || now > record.resetTime) {
      requests.set(key, { count: 1, resetTime: now + windowMs });
      return true;
    }

    if (record.count < maxRequests) {
      record.count++;
      return true;
    }

    return false;
  };
}
