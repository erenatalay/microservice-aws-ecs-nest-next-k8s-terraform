const CORRELATION_ID_COOKIE = 'correlation-id';

function readCookie(name: string) {
  if (typeof document === 'undefined') return undefined;

  const cookie = document.cookie
    .split('; ')
    .find((entry) => entry.startsWith(`${name}=`));

  return cookie?.split('=')[1];
}

function generateCorrelationId() {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }

  return `cid-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

export function getBrowserCorrelationId() {
  const existing = readCookie(CORRELATION_ID_COOKIE);

  if (existing) return existing;

  if (typeof document === 'undefined') return undefined;

  const correlationId = generateCorrelationId();
  document.cookie = `${CORRELATION_ID_COOKIE}=${correlationId}; path=/; SameSite=Lax`;

  return correlationId;
}
