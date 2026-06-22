const LOCALHOST_ORIGIN = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

export function resolveCorsOrigins(allowedOrigins: string[], nodeEnv: string): Array<string | RegExp> {
  if (nodeEnv === 'development') {
    return [...allowedOrigins, LOCALHOST_ORIGIN];
  }
  return allowedOrigins;
}

export function isAllowedOrigin(
  origin: string | undefined,
  allowedOrigins: string[],
  nodeEnv: string,
): boolean {
  if (!origin) return true;
  if (allowedOrigins.includes(origin)) return true;
  return nodeEnv === 'development' && LOCALHOST_ORIGIN.test(origin);
}
