import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const CORRELATION_ID_COOKIE = 'correlation-id';

const ROUTES = {
  public: ['/', '/about', '/contact'],

  auth: ['/login', '/register', '/forgot-password', '/reset-password'],
  protected: ['/products', '/dashboard', '/profile', '/settings'],
  api: ['/api'],
} as const;

function matchesPath(pathname: string, paths: readonly string[]): boolean {
  return paths.some(
    (path) => pathname === path || pathname.startsWith(`${path}/`),
  );
}

function isTokenExpired(token: string): boolean {
  try {
    const payload = JSON.parse(atob(token.split('.')[1]));
    const exp = payload.exp * 1000;
    return Date.now() >= exp;
  } catch {
    return true;
  }
}

function redirect(request: NextRequest, path: string): NextResponse {
  const url = new URL(path, request.url);
  if (path === '/login') {
    url.searchParams.set('callbackUrl', request.nextUrl.pathname);
  }
  return NextResponse.redirect(url);
}

function withCorrelationId(
  request: NextRequest,
  response: NextResponse,
): NextResponse {
  const correlationId =
    request.cookies.get(CORRELATION_ID_COOKIE)?.value || crypto.randomUUID();

  response.cookies.set(CORRELATION_ID_COOKIE, correlationId, {
    sameSite: 'lax',
    path: '/',
  });
  response.headers.set('x-correlation-id', correlationId);

  return response;
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const accessToken = request.cookies.get('accessToken')?.value;

  if (matchesPath(pathname, ROUTES.api)) {
    return withCorrelationId(request, NextResponse.next());
  }

  if (matchesPath(pathname, ROUTES.public)) {
    return withCorrelationId(request, NextResponse.next());
  }

  const isLoggedIn = accessToken && !isTokenExpired(accessToken);

  if (matchesPath(pathname, ROUTES.auth)) {
    if (isLoggedIn) {
      return withCorrelationId(request, redirect(request, '/products'));
    }
    return withCorrelationId(request, NextResponse.next());
  }

  if (matchesPath(pathname, ROUTES.protected)) {
    if (!isLoggedIn) {
      return withCorrelationId(request, redirect(request, '/login'));
    }
    return withCorrelationId(request, NextResponse.next());
  }

  return withCorrelationId(request, NextResponse.next());
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
